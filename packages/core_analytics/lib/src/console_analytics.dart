import 'dart:developer' as developer;

import 'analytics.dart';

/// 개발/프로토타입용: 이벤트를 콘솔 로그로만 출력한다.
final class ConsoleAnalytics implements Analytics {
  const ConsoleAnalytics();

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {
    developer.log(
      parameters.isEmpty ? name : '$name $parameters',
      name: 'analytics',
    );
  }

  @override
  void logScreenView(String screenName) {
    developer.log('screen_view: $screenName', name: 'analytics');
  }
}
