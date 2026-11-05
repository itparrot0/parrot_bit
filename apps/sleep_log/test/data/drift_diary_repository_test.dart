import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/database.dart';
import 'package:sleep_log/data/drift_diary_repository.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late DriftDiaryRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftDiaryRepository(database);
  });

  tearDown(() => database.close());

  const day = DiaryDate(2026, 11, 5);
  final overnight = SleepSession(
    bedTime: ClockTime(23, 30),
    wakeTime: ClockTime(7, 0),
  );

  group('save / find', () {
    test('수면과 태그를 저장하고 그대로 읽는다', () async {
      final entry = DiaryEntry(
        date: day,
        sleep: overnight,
        tags: {DefaultMoodTags.calm, DefaultMoodTags.tired},
      );

      await repository.save(entry);
      final loaded = await repository.find(day);

      expect(loaded, isNotNull);
      expect(loaded!.date, day);
      expect(loaded.sleep, overnight);
      expect(loaded.sleepDuration, const Duration(hours: 7, minutes: 30));
      expect(loaded.tags, {DefaultMoodTags.calm, DefaultMoodTags.tired});
    });

    test('기록이 없는 날은 null', () async {
      expect(await repository.find(day), isNull);
    });

    test('태그만 있는 기록 — 수면은 null로 읽힌다', () async {
      await repository.save(
        DiaryEntry(date: day, tags: {DefaultMoodTags.anxious}),
      );

      final loaded = await repository.find(day);
      expect(loaded!.sleep, isNull);
      expect(loaded.tags, {DefaultMoodTags.anxious});
    });

    test('수면만 있는 기록 — 태그는 비어 있다', () async {
      await repository.save(DiaryEntry(date: day, sleep: overnight));

      final loaded = await repository.find(day);
      expect(loaded!.sleep, overnight);
      expect(loaded.tags, isEmpty);
    });

    test('같은 날짜를 다시 저장하면 통째로 바뀐다 (편집)', () async {
      await repository.save(
        DiaryEntry(
          date: day,
          sleep: overnight,
          tags: {DefaultMoodTags.calm, DefaultMoodTags.joyful},
        ),
      );
      await repository.save(
        DiaryEntry(date: day, tags: {DefaultMoodTags.irritated}),
      );

      final loaded = await repository.find(day);
      expect(loaded!.sleep, isNull, reason: '수면을 지운 편집이 반영돼야 한다');
      expect(loaded.tags, {DefaultMoodTags.irritated});
    });

    test('빈 기록을 저장하면 그날 기록이 지워진다', () async {
      await repository.save(DiaryEntry(date: day, sleep: overnight));
      await repository.save(DiaryEntry(date: day));

      expect(await repository.find(day), isNull);
    });
  });

  group('delete', () {
    test('그날 기록과 태그가 함께 지워진다', () async {
      await repository.save(
        DiaryEntry(date: day, sleep: overnight, tags: {DefaultMoodTags.calm}),
      );

      await repository.delete(day);

      expect(await repository.find(day), isNull);
      final orphanTags = await database.select(database.entryTags).get();
      expect(orphanTags, isEmpty, reason: '외래 키 CASCADE가 켜져 있어야 한다');
    });

    test('없는 날을 지워도 오류가 없다', () async {
      await repository.delete(day);
    });

    test('deleteAll은 모든 기록을 지운다', () async {
      await repository.save(DiaryEntry(date: day, sleep: overnight));
      await repository.save(
        DiaryEntry(date: day.previous, tags: {DefaultMoodTags.calm}),
      );

      await repository.deleteAll();

      expect(await repository.watchAll().first, isEmpty);
      expect(await database.select(database.entryTags).get(), isEmpty);
    });
  });

  group('watchAll', () {
    test('날짜 오름차순으로, 태그 수와 관계없이 하루 한 번씩 온다', () async {
      await repository.save(
        DiaryEntry(
          date: day,
          tags: {
            DefaultMoodTags.calm,
            DefaultMoodTags.joyful,
            DefaultMoodTags.tired,
          },
        ),
      );
      await repository.save(
        DiaryEntry(date: day.addDays(-40), sleep: overnight),
      );
      await repository.save(
        DiaryEntry(date: day.previous, tags: {DefaultMoodTags.down}),
      );

      final entries = await repository.watchAll().first;

      expect(entries.map((e) => e.date), [day.addDays(-40), day.previous, day]);
      expect(entries.last.tags, hasLength(3));
      expect(entries.first.tags, isEmpty);
    });

    test('저장하면 새 목록이 흘러온다', () async {
      final seen = <List<DiaryDate>>[];
      final subscription = repository.watchAll().listen(
        (entries) => seen.add(entries.map((e) => e.date).toList()),
      );
      addTearDown(subscription.cancel);

      // 첫 값(빈 목록)이 온 뒤에 저장해야 "새 값이 온다"를 볼 수 있다.
      await pumpEventQueue();
      expect(seen, [<DiaryDate>[]]);

      await repository.save(DiaryEntry(date: day, sleep: overnight));
      await pumpEventQueue();
      expect(seen.last, [day]);
    });
  });

  group('읽을 수 없는 행은 건너뛰거나 고쳐 읽는다', () {
    test('모르는 태그 id는 버린다', () async {
      await repository.save(
        DiaryEntry(date: day, tags: {DefaultMoodTags.calm}),
      );
      await database
          .into(database.entryTags)
          .insert(
            EntryTagsCompanion.insert(date: day.toIso(), tagId: 'custom_42'),
          );

      final loaded = await repository.find(day);
      expect(loaded!.tags, {DefaultMoodTags.calm});
    });

    test('취침과 기상이 같은 값이면 수면 없이 읽는다', () async {
      await database
          .into(database.diaryEntries)
          .insert(
            DiaryEntriesCompanion.insert(
              date: day.toIso(),
              bedMinute: const Value(420),
              wakeMinute: const Value(420),
            ),
          );

      final loaded = await repository.find(day);
      expect(loaded, isNotNull);
      expect(loaded!.sleep, isNull);
    });

    test('날짜를 읽을 수 없는 행은 목록에서 빠진다', () async {
      await repository.save(DiaryEntry(date: day, sleep: overnight));
      await database
          .into(database.diaryEntries)
          .insert(DiaryEntriesCompanion.insert(date: '2026-02-30'));

      final entries = await repository.watchAll().first;
      expect(entries.map((e) => e.date), [day]);
    });
  });

  test('취침·기상 중 하나만 있는 행은 DB가 거부한다', () async {
    await expectLater(
      database
          .into(database.diaryEntries)
          .insert(
            DiaryEntriesCompanion.insert(
              date: day.toIso(),
              bedMinute: const Value(420),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
