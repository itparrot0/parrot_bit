import 'package:drift/drift.dart';

import '../domain/domain.dart';
import 'check_in_repository.dart';
import 'database.dart';

/// [CheckInRepository]의 drift 구현.
final class DriftCheckInRepository implements CheckInRepository {
  DriftCheckInRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ThoughtCheckIn>> watchAll() {
    // slot 문자열 정렬(afternoon < morning)은 시간 순서가 아니라서 Dart에서 정렬한다.
    return _db.select(_db.thoughtCheckIns).watch().map((rows) {
      final checkIns = rows.map(_toCheckIn).nonNulls.toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.slot.index.compareTo(b.slot.index);
        });
      return checkIns;
    });
  }

  @override
  Future<ThoughtCheckIn?> find(DiaryDate date, CheckInSlot slot) async {
    final row =
        await (_db.select(_db.thoughtCheckIns)..where(
              (t) => t.date.equals(date.toIso()) & t.slot.equals(slot.name),
            ))
            .getSingleOrNull();
    return row == null ? null : _toCheckIn(row);
  }

  @override
  Future<void> save(ThoughtCheckIn checkIn) async {
    if (checkIn.isEmpty) {
      await delete(checkIn.date, checkIn.slot);
      return;
    }
    await _db
        .into(_db.thoughtCheckIns)
        .insertOnConflictUpdate(
          ThoughtCheckInsCompanion.insert(
            date: checkIn.date.toIso(),
            slot: checkIn.slot.name,
            pace: Value(checkIn.pace?.name),
            senses: Value(checkIn.senses?.name),
            thought: Value(checkIn.thought),
            reframe: Value(checkIn.reframe),
          ),
        );
  }

  @override
  Future<void> delete(DiaryDate date, CheckInSlot slot) async {
    await (_db.delete(
          _db.thoughtCheckIns,
        )..where((t) => t.date.equals(date.toIso()) & t.slot.equals(slot.name)))
        .go();
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete(_db.thoughtCheckIns).go();
  }

  /// 읽을 수 없는 날짜·칸이면 null(건너뜀). 모르는 답 값은 답하지 않은 것으로 본다.
  static ThoughtCheckIn? _toCheckIn(CheckInRow row) {
    final date = DiaryDate.tryParseIso(row.date);
    final slot = CheckInSlot.tryParse(row.slot);
    if (date == null || slot == null) {
      return null;
    }
    return ThoughtCheckIn(
      date: date,
      slot: slot,
      pace: _byName(MindPace.values, row.pace),
      senses: _byName(SenseShift.values, row.senses),
      thought: row.thought,
      reframe: row.reframe,
    );
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
