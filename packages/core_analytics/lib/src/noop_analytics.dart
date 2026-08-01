import 'analytics.dart';

/// 아무것도 하지 않는 구현. 테스트 및 분석 비활성화 시 사용한다.
final class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void logScreenView(String screenName) {}
}
