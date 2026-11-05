import 'package:drift/drift.dart';

part 'database.g.dart';

/// 하루 기록 한 줄. 키는 날짜(`yyyy-MM-dd`)다.
///
/// 날짜를 ISO 문자열로 두는 이유: 문자열 정렬이 곧 날짜 정렬이라 범위 조회가
/// 그대로 되고, [DiaryDate]가 타임존 없이 날짜만 갖는다는 성질이 저장에서도
/// 유지된다 (DateTime 정수로 두면 시·분·타임존이 다시 섞여 들어온다).
@DataClassName('DiaryEntryRow')
class DiaryEntries extends Table {
  TextColumn get date => text()();

  /// 취침·기상 시각 (자정부터 분). 둘 다 있거나 둘 다 없다 — 수면 없이 태그만
  /// 남긴 날이 있기 때문이다 (docs/screen-flow/sleep_log.md §5).
  IntColumn get bedMinute => integer().nullable()();
  IntColumn get wakeMinute => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {date};

  @override
  List<String> get customConstraints => [
    'CHECK ((bed_minute IS NULL) = (wake_minute IS NULL))',
  ];
}

/// 기록에 붙은 감정 태그. 한 날짜에 여러 개.
///
/// 열 하나에 목록으로 넣지 않고 표로 나눈 이유: 태그별 집계(리포트)와 최근 사용
/// 태그 조회를 SQL로 할 수 있어야 한다 (PRD §9-3).
@DataClassName('EntryTagRow')
class EntryTags extends Table {
  TextColumn get date =>
      text().references(DiaryEntries, #date, onDelete: KeyAction.cascade)();

  /// [MoodTag.id]. 표시 문구가 아니라 id를 저장해, 문구를 고쳐도 기록이
  /// 고아가 되지 않는다.
  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => {date, tagId};
}

/// 생각 돌아보기 체크인 (PRD §3-3). 하루 두 칸 — 오전·오후.
///
/// 하루 기록(`diary_entries`)과 묶지 않는다. 체크인은 선택 기능이라, 수면 기록
/// 없이도 있고 체크인 없이도 기록은 완결된다.
@DataClassName('CheckInRow')
class ThoughtCheckIns extends Table {
  TextColumn get date => text()();

  /// `CheckInSlot.name` (`morning` / `afternoon`).
  TextColumn get slot => text()();

  /// `MindPace.name`. 답하지 않았으면 null.
  TextColumn get pace => text().nullable()();

  /// `SenseShift.name`. 답하지 않았으면 null.
  TextColumn get senses => text().nullable()();

  TextColumn get thought => text().nullable()();
  TextColumn get reframe => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {date, slot};
}

/// 슬립로그 로컬 DB (drift / SQLite).
///
/// 스키마는 도메인 지식이므로 `core_storage`가 아니라 앱 안에 둔다
/// (docs/prd/sleep_log.md §9-3). 기기 밖으로 나가는 경로는 없다 (§9-1).
@DriftDatabase(tables: [DiaryEntries, EntryTags, ThoughtCheckIns])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 1: 기록·태그. 2: 생각 돌아보기 체크인 표 추가.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(thoughtCheckIns);
      }
    },
    beforeOpen: (details) async {
      // SQLite는 외래 키를 기본으로 검사하지 않는다. 이걸 켜야 기록을 지울 때
      // 태그도 같이 지워진다(ON DELETE CASCADE).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
