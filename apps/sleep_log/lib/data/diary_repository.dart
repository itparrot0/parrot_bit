import 'package:drift/drift.dart';

import '../domain/domain.dart';
import 'database.dart';

/// 하루 기록의 저장·조회. drift 행과 도메인 [DiaryEntry] 사이를 옮긴다.
///
/// 화면은 이 클래스만 알고 drift 타입을 보지 않는다 (docs/03-architecture.md §4).
final class DiaryRepository {
  DiaryRepository(this._db);

  final AppDatabase _db;

  /// 모든 기록을 날짜 오름차순으로. 저장·삭제가 일어날 때마다 새 목록이 온다.
  ///
  /// 전부 읽는 이유: 하루 한 줄이라 몇 년을 써도 수천 줄이고, 달력·안전 안내·
  /// 리포트가 모두 같은 목록을 쓴다. 느려지면 그때 범위 조회로 나눈다.
  Stream<List<DiaryEntry>> watchAll() {
    final query = _db.select(_db.diaryEntries).join([
      leftOuterJoin(
        _db.entryTags,
        _db.entryTags.date.equalsExp(_db.diaryEntries.date),
      ),
    ])..orderBy([OrderingTerm.asc(_db.diaryEntries.date)]);
    return query.watch().map(_toEntries);
  }

  /// [date]의 기록. 없으면 null.
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

  /// 기록을 저장한다. 같은 날짜가 있으면 통째로 바꾼다(편집).
  ///
  /// 빈 기록(수면도 태그도 없음)은 저장하지 않고 그날 기록을 지운다 — 빈 줄이
  /// 남으면 달력에 "기록 있음"으로 찍힌다.
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

  /// [date]의 기록을 지운다. 태그도 함께 지워진다. 없으면 아무 일도 없다.
  Future<void> delete(DiaryDate date) async {
    await (_db.delete(
      _db.diaryEntries,
    )..where((t) => t.date.equals(date.toIso()))).go();
  }

  /// 모든 기록을 지운다. 건강 데이터이므로 전체 삭제 수단이 반드시 있어야 한다
  /// (docs/screen-flow/sleep_log.md §5 `settings`).
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
