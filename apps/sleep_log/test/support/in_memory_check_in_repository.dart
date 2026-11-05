import 'dart:async';

import 'package:sleep_log/data/check_in_repository.dart';
import 'package:sleep_log/domain/domain.dart';

/// 위젯 테스트용 [CheckInRepository] (drift 구현은 test/data/에서 검증한다).
final class InMemoryCheckInRepository implements CheckInRepository {
  InMemoryCheckInRepository([Iterable<ThoughtCheckIn> initial = const []]) {
    for (final checkIn in initial) {
      _items[(checkIn.date, checkIn.slot)] = checkIn;
    }
  }

  final Map<(DiaryDate, CheckInSlot), ThoughtCheckIn> _items = {};
  final StreamController<List<ThoughtCheckIn>> _changes =
      StreamController.broadcast();

  List<ThoughtCheckIn> get _sorted => _items.values.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.slot.index.compareTo(b.slot.index);
    });

  @override
  Stream<List<ThoughtCheckIn>> watchAll() async* {
    yield _sorted;
    yield* _changes.stream;
  }

  @override
  Future<ThoughtCheckIn?> find(DiaryDate date, CheckInSlot slot) async =>
      _items[(date, slot)];

  @override
  Future<void> save(ThoughtCheckIn checkIn) async {
    if (checkIn.isEmpty) {
      await delete(checkIn.date, checkIn.slot);
      return;
    }
    _items[(checkIn.date, checkIn.slot)] = checkIn;
    _changes.add(_sorted);
  }

  @override
  Future<void> delete(DiaryDate date, CheckInSlot slot) async {
    _items.remove((date, slot));
    _changes.add(_sorted);
  }

  @override
  Future<void> deleteAll() async {
    _items.clear();
    _changes.add(_sorted);
  }
}
