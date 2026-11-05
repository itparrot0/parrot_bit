import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/database.dart';
import 'package:sleep_log/data/drift_check_in_repository.dart';
import 'package:sleep_log/data/drift_diary_repository.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late DriftCheckInRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftCheckInRepository(database);
  });

  tearDown(() => database.close());

  const day = DiaryDate(2026, 11, 5);

  test('모든 항목을 저장하고 그대로 읽는다', () async {
    final checkIn = ThoughtCheckIn(
      date: day,
      slot: CheckInSlot.morning,
      pace: MindPace.busy,
      senses: SenseShift.some,
      thought: '다들 나를 싫어하는 것 같다',
      reframe: '어제 연락 온 친구도 있었다',
    );

    await repository.save(checkIn);

    expect(await repository.find(day, CheckInSlot.morning), checkIn);
    expect(await repository.find(day, CheckInSlot.afternoon), isNull);
  });

  test('하루에 오전·오후 두 칸이 따로 있다', () async {
    await repository.save(
      ThoughtCheckIn(
        date: day,
        slot: CheckInSlot.afternoon,
        pace: MindPace.slow,
      ),
    );
    await repository.save(
      ThoughtCheckIn(date: day, slot: CheckInSlot.morning, pace: MindPace.busy),
    );
    await repository.save(
      ThoughtCheckIn(
        date: day.previous,
        slot: CheckInSlot.afternoon,
        pace: MindPace.usual,
      ),
    );

    final all = await repository.watchAll().first;
    expect(all.map((c) => (c.date, c.slot)), [
      (day.previous, CheckInSlot.afternoon),
      (day, CheckInSlot.morning),
      (day, CheckInSlot.afternoon),
    ]);
  });

  test('같은 칸을 다시 저장하면 바뀌고, 빈 체크인이면 지워진다', () async {
    await repository.save(
      ThoughtCheckIn(date: day, slot: CheckInSlot.morning, pace: MindPace.busy),
    );
    await repository.save(
      ThoughtCheckIn(
        date: day,
        slot: CheckInSlot.morning,
        senses: SenseShift.none,
      ),
    );

    final edited = await repository.find(day, CheckInSlot.morning);
    expect(edited!.pace, isNull);
    expect(edited.senses, SenseShift.none);

    await repository.save(ThoughtCheckIn(date: day, slot: CheckInSlot.morning));
    expect(await repository.find(day, CheckInSlot.morning), isNull);
  });

  test('deleteAll은 체크인만 지우고 수면 기록은 건드리지 않는다', () async {
    final diary = DriftDiaryRepository(database);
    await diary.save(DiaryEntry(date: day, tags: {DefaultMoodTags.calm}));
    await repository.save(
      ThoughtCheckIn(date: day, slot: CheckInSlot.morning, pace: MindPace.busy),
    );

    await repository.deleteAll();

    expect(await repository.watchAll().first, isEmpty);
    expect(await diary.find(day), isNotNull);
  });

  test('공백만 적은 생각은 적지 않은 것으로 본다', () {
    final checkIn = ThoughtCheckIn(
      date: day,
      slot: CheckInSlot.morning,
      thought: '   ',
    );
    expect(checkIn.thought, isNull);
    expect(checkIn.isEmpty, isTrue);
  });

  test('CheckInSlot.at — 14시 전은 오전', () {
    expect(CheckInSlot.at(DateTime(2026, 11, 5, 13, 59)), CheckInSlot.morning);
    expect(CheckInSlot.at(DateTime(2026, 11, 5, 14)), CheckInSlot.afternoon);
  });

  test('schema 1 DB를 열면 체크인 표가 생기고 기존 기록은 남는다', () async {
    final legacy = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE diary_entries (date TEXT NOT NULL PRIMARY KEY, '
              'bed_minute INTEGER NULL, wake_minute INTEGER NULL, '
              'CHECK ((bed_minute IS NULL) = (wake_minute IS NULL)))',
            )
            ..execute(
              'CREATE TABLE entry_tags (date TEXT NOT NULL REFERENCES '
              'diary_entries (date) ON DELETE CASCADE, tag_id TEXT NOT NULL, '
              'PRIMARY KEY (date, tag_id))',
            )
            ..execute(
              "INSERT INTO diary_entries (date, bed_minute, wake_minute) "
              "VALUES ('2026-11-04', 0, 420)",
            )
            ..execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(legacy.close);

    final checkIns = DriftCheckInRepository(legacy);
    await checkIns.save(
      ThoughtCheckIn(
        date: day,
        slot: CheckInSlot.morning,
        pace: MindPace.usual,
      ),
    );

    expect(await checkIns.find(day, CheckInSlot.morning), isNotNull);
    expect(
      await DriftDiaryRepository(legacy).find(day.previous),
      isNotNull,
      reason: '기존 기록이 보존돼야 한다',
    );
  });
}
