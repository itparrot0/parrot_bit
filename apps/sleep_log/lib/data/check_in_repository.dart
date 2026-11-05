import '../domain/domain.dart';

/// 생각 돌아보기 체크인의 저장·조회. 화면은 이 인터페이스만 안다.
abstract interface class CheckInRepository {
  /// 모든 체크인을 (날짜, 오전→오후) 순으로. 저장·삭제마다 새 목록이 온다.
  Stream<List<ThoughtCheckIn>> watchAll();

  /// [date]의 [slot] 체크인. 없으면 null.
  Future<ThoughtCheckIn?> find(DiaryDate date, CheckInSlot slot);

  /// 저장한다. 같은 칸이 있으면 바꾼다. 빈 체크인이면 그 칸을 지운다.
  Future<void> save(ThoughtCheckIn checkIn);

  Future<void> delete(DiaryDate date, CheckInSlot slot);

  /// 모든 체크인을 지운다 (설정의 "모든 기록 지우기").
  Future<void> deleteAll();
}
