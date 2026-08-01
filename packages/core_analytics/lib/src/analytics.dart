/// 분석 이벤트 발행 인터페이스.
///
/// 이벤트 이름·파라미터의 정의(카탈로그)는 각 앱이 소유하고,
/// 이 패키지는 전달 통로만 제공한다.
abstract interface class Analytics {
  /// 커스텀 이벤트를 기록한다.
  void logEvent(String name, [Map<String, Object?> parameters = const {}]);

  /// 화면 진입을 기록한다.
  void logScreenView(String screenName);
}
