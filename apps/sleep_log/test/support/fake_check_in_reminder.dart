import 'package:sleep_log/data/check_in_reminder.dart';
import 'package:sleep_log/domain/domain.dart';

/// 알림을 실제로 잡지 않고 호출만 기록한다.
final class FakeCheckInReminder implements CheckInReminder {
  FakeCheckInReminder({this.permissionGranted = true});

  bool permissionGranted;
  final List<({CheckInSettings settings, bool askPermission})> calls = [];

  @override
  Future<bool> apply(
    CheckInSettings settings, {
    bool askPermission = false,
  }) async {
    calls.add((settings: settings, askPermission: askPermission));
    return !settings.enabled || !askPermission || permissionGranted;
  }
}
