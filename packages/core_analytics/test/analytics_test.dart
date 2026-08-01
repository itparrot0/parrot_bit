import 'package:core_analytics/core_analytics.dart';
import 'package:test/test.dart';

final class RecordingAnalytics implements Analytics {
  final List<String> events = [];

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {
    events.add(name);
  }

  @override
  void logScreenView(String screenName) {
    events.add('screen_view:$screenName');
  }
}

void main() {
  test('Analytics 인터페이스는 임의 구현으로 대체 가능하다', () {
    final analytics = RecordingAnalytics();

    analytics.logEvent('game_start', {'level': 1});
    analytics.logScreenView('home');

    expect(analytics.events, ['game_start', 'screen_view:home']);
  });

  test('제공되는 구현들은 예외 없이 동작한다', () {
    for (final Analytics analytics in [
      const ConsoleAnalytics(),
      const NoopAnalytics(),
    ]) {
      expect(() => analytics.logEvent('event', {'k': 'v'}), returnsNormally);
      expect(() => analytics.logScreenView('screen'), returnsNormally);
    }
  });
}
