/// 이벤트 로깅의 추상 인터페이스와 구현.
///
/// 어떤 구현을 쓸지는 각 앱의 main()에서 결정한다.
/// 프로토타입 앱은 [ConsoleAnalytics], 테스트는 [NoopAnalytics]로 충분하다.
library;

export 'src/analytics.dart';
export 'src/console_analytics.dart';
export 'src/noop_analytics.dart';
