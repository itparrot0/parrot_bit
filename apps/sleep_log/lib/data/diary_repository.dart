import '../domain/domain.dart';

/// 하루 기록의 저장·조회.
///
/// 화면은 이 인터페이스만 알고 저장 방식(drift)을 보지 않는다
/// (docs/03-architecture.md §4). 앱은 `DriftDiaryRepository`를 쓰고, 위젯
/// 테스트는 메모리 구현으로 바꿔 끼운다.
abstract interface class DiaryRepository {
  /// 모든 기록을 날짜 오름차순으로. 처음에 현재 목록이 오고, 저장·삭제가
  /// 일어날 때마다 새 목록이 온다.
  Stream<List<DiaryEntry>> watchAll();

  /// [date]의 기록. 없으면 null.
  Future<DiaryEntry?> find(DiaryDate date);

  /// 기록을 저장한다. 같은 날짜가 있으면 통째로 바꾼다(편집).
  ///
  /// 빈 기록(수면도 태그도 없음)은 저장하지 않고 그날 기록을 지운다 — 빈 줄이
  /// 남으면 달력에 "기록 있음"으로 찍힌다.
  Future<void> save(DiaryEntry entry);

  /// [date]의 기록을 지운다. 없으면 아무 일도 없다.
  Future<void> delete(DiaryDate date);

  /// 모든 기록을 지운다. 건강 데이터이므로 전체 삭제 수단이 반드시 있어야 한다
  /// (docs/screen-flow/sleep_log.md §5 `settings`).
  Future<void> deleteAll();
}
