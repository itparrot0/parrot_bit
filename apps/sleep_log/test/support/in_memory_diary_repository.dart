import 'dart:async';

import 'package:sleep_log/data/diary_repository.dart';
import 'package:sleep_log/domain/domain.dart';

/// 위젯 테스트용 [DiaryRepository]. drift 쿼리는 테스트의 가짜 시간 안에서
/// 끝나지 않아서, 화면 테스트는 이걸 쓴다. drift 구현 자체는
/// `test/data/drift_diary_repository_test.dart`가 검증한다.
final class InMemoryDiaryRepository implements DiaryRepository {
  InMemoryDiaryRepository([Iterable<DiaryEntry> initial = const []]) {
    for (final entry in initial) {
      _entries[entry.date] = entry;
    }
  }

  final Map<DiaryDate, DiaryEntry> _entries = {};
  final StreamController<List<DiaryEntry>> _changes =
      StreamController.broadcast();

  List<DiaryEntry> get _sorted =>
      _entries.values.toList()..sort((a, b) => a.date.compareTo(b.date));

  @override
  Stream<List<DiaryEntry>> watchAll() async* {
    yield _sorted;
    yield* _changes.stream;
  }

  @override
  Future<DiaryEntry?> find(DiaryDate date) async => _entries[date];

  @override
  Future<void> save(DiaryEntry entry) async {
    if (entry.isEmpty) {
      await delete(entry.date);
      return;
    }
    _entries[entry.date] = entry;
    _changes.add(_sorted);
  }

  @override
  Future<void> delete(DiaryDate date) async {
    _entries.remove(date);
    _changes.add(_sorted);
  }

  @override
  Future<void> deleteAll() async {
    _entries.clear();
    _changes.add(_sorted);
  }
}
