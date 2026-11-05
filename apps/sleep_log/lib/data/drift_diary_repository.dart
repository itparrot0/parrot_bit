import 'package:drift/drift.dart';

import '../domain/domain.dart';
import 'database.dart';
import 'diary_repository.dart';

/// [DiaryRepository]의 drift(SQLite) 구현. drift 행과 도메인 [DiaryEntry]
/// 사이를 옮긴다.
final class DriftDiaryRepository implements DiaryRepository {
  DriftDiaryRepository(this._db);

  final AppDatabase _db;

  /// 하루 한 줄이라 몇 년을 써도 수천 줄이다. 그래서 전부 읽는다 — 느려지면
  /// 그때 범위 조회로 나눈다.
  @override
  Stream<List<DiaryEntry>> watchAll() {
    final query = _db.select(_db.diaryEntries).join([
      leftOuterJoin(
        _db.entryTags,
        _db.entryTags.date.equalsExp(_db.diaryEntries.date),
      ),
    ])..orderBy([OrderingTerm.asc(_db.diaryEntries.date)]);
    return query.watch().map(_toEntries);
  }

  @override
  Future<DiaryEntry?> find(DiaryDate date) async {
    final key = date.toIso();
    final row = await (_db.select(
      _db.diaryEntries,
    )..where((t) => t.date.equals(key))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final tags = await (_db.select(
      _db.entryTags,
    )..where((t) => t.date.equals(key))).get();
    return _toEntry(row, tags.map((t) => t.tagId));
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    if (entry.isEmpty) {
      await delete(entry.date);
      return;
    }
    final key = entry.date.toIso();
    await _db.transaction(() async {
      await _db
          .into(_db.diaryEntries)
          .insertOnConflictUpdate(
            DiaryEntriesCompanion.insert(
              date: key,
              bedMinute: Value(entry.sleep?.bedTime.totalMinutes),
              wakeMinute: Value(entry.sleep?.wakeTime.totalMinutes),
              rested: Value(entry.rested?.name),
            ),
          );
      await (_db.delete(_db.entryTags)..where((t) => t.date.equals(key))).go();
      await _db.batch((batch) {
        batch.insertAll(_db.entryTags, [
          for (final tag in entry.tags)
            EntryTagsCompanion.insert(date: key, tagId: tag.id),
        ]);
      });
    });
  }

  @override
  Future<void> delete(DiaryDate date) async {
    await (_db.delete(
      _db.diaryEntries,
    )..where((t) => t.date.equals(date.toIso()))).go();
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete(_db.diaryEntries).go();
  }

  List<DiaryEntry> _toEntries(List<TypedResult> rows) {
    // 조인 결과는 (기록, 태그) 쌍이라 태그 수만큼 같은 기록이 반복된다.
    // 날짜 오름차순으로 왔으므로 삽입 순서를 지키는 Map으로 묶으면 정렬이 유지된다.
    final entryRows = <String, DiaryEntryRow>{};
    final tagIds = <String, List<String>>{};
    for (final row in rows) {
      final entry = row.readTable(_db.diaryEntries);
      entryRows[entry.date] = entry;
      final tags = tagIds.putIfAbsent(entry.date, () => []);
      final tag = row.readTableOrNull(_db.entryTags);
      if (tag != null) {
        tags.add(tag.tagId);
      }
    }
    return [
      for (final MapEntry(key: date, value: row) in entryRows.entries)
        ?_toEntry(row, tagIds[date]!),
    ];
  }

  /// 행을 도메인 기록으로. 읽을 수 없는 날짜면 null — 그 줄은 건너뛴다.
  ///
  /// 모르는 태그 id(이후 버전의 커스텀 태그 등)는 버린다. 수면 시각이 같은
  /// 값이면(정의할 수 없는 수면) 수면 없이 태그만 남긴다. 기록 하나가 깨졌다고
  /// 달력 전체를 못 띄우게 하지 않는다.
  DiaryEntry? _toEntry(DiaryEntryRow row, Iterable<String> tagIds) {
    final date = DiaryDate.tryParseIso(row.date);
    if (date == null) {
      return null;
    }
    return DiaryEntry(
      date: date,
      sleep: _toSleep(row.bedMinute, row.wakeMinute),
      tags: {...tagIds.map(DefaultMoodTags.byId).nonNulls},
      rested: RestFeeling.tryParse(row.rested),
    );
  }

  static SleepSession? _toSleep(int? bedMinute, int? wakeMinute) {
    final bed = _toClock(bedMinute);
    final wake = _toClock(wakeMinute);
    if (bed == null || wake == null || !SleepSession.isValidRange(bed, wake)) {
      return null;
    }
    return SleepSession(bedTime: bed, wakeTime: wake);
  }

  static ClockTime? _toClock(int? minutes) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) {
      return null;
    }
    return ClockTime(minutes ~/ 60, minutes % 60);
  }
}
