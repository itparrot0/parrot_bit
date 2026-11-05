import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/domain.dart';

/// 생각 돌아보기 알림 (오전·오후, 매일). 서버가 없으므로 기기 안의 로컬
/// 알림이다 (PRD §9).
abstract interface class CheckInReminder {
  /// [settings]대로 알림을 다시 잡는다. 꺼져 있으면 지운다.
  ///
  /// [askPermission]이 true면 필요할 때 알림 권한을 묻는다 — 사용자가 설정에서
  /// 기능을 켜는 순간에만 쓴다. 앱 시작 때 다시 잡을 때는 묻지 않는다.
  /// 알림을 보낼 수 있으면 true(꺼진 설정이면 항상 true).
  Future<bool> apply(CheckInSettings settings, {bool askPermission = false});
}

/// 알림을 눌렀을 때 열 시간대를 받는다.
typedef CheckInTapHandler = void Function(CheckInSlot slot);

/// flutter_local_notifications 구현.
final class LocalCheckInReminder implements CheckInReminder {
  LocalCheckInReminder({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  /// 알림을 눌렀을 때 부른다. 앱이 꺼져 있다가 알림으로 열린 경우는
  /// [takeLaunchSlot]으로 따로 받는다.
  CheckInTapHandler? onTap;

  static const int _morningId = 101;
  static const int _afternoonId = 102;

  static const _channel = AndroidNotificationDetails(
    'check_in',
    '생각 돌아보기',
    channelDescription: '오전·오후에 잠깐 스스로를 돌아보자는 알림',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// 잠금 화면에도 보이는 문구라 **기록 내용이나 건강 상태를 담지 않는다**
  /// (PRD §9-1). 묻지 않고 권하는 말로 쓴다.
  static const Map<CheckInSlot, ({String title, String body})> messages = {
    CheckInSlot.morning: (
      title: '잠깐, 생각 돌아보기',
      body: '오늘 아침 머릿속은 어떤가요? 1분만 살펴봐요.',
    ),
    CheckInSlot.afternoon: (
      title: '잠깐, 생각 돌아보기',
      body: '오후의 마음은 어떤가요? 잠깐 쉬어 가며 돌아봐요.',
    ),
  };

  Future<void> _ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (error) {
      // 시간대를 못 읽으면 UTC로 잡혀 시각이 어긋난다. 알림 자체는 살린다.
      debugPrint('sleep_log: 시간대를 읽지 못했다: $error');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // 권한은 기능을 켤 때 묻는다 — 앱을 처음 열자마자 묻지 않는다.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final slot = CheckInSlot.tryParse(response.payload ?? '');
        if (slot != null) {
          onTap?.call(slot);
        }
      },
    );
  }

  /// 앱이 이 알림으로 실행됐다면 그 시간대. 한 번만 의미가 있다.
  Future<CheckInSlot?> takeLaunchSlot() async {
    await _ensureReady();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return CheckInSlot.tryParse(details.notificationResponse?.payload ?? '');
  }

  @override
  Future<bool> apply(
    CheckInSettings settings, {
    bool askPermission = false,
  }) async {
    await _ensureReady();
    await _plugin.cancel(id: _morningId);
    await _plugin.cancel(id: _afternoonId);
    if (!settings.enabled) {
      return true;
    }

    final allowed = askPermission ? await _requestPermission() : true;
    for (final slot in CheckInSlot.values) {
      final message = messages[slot]!;
      await _plugin.zonedSchedule(
        id: slot == CheckInSlot.morning ? _morningId : _afternoonId,
        title: message.title,
        body: message.body,
        scheduledDate: _nextInstanceOf(settings.timeOf(slot)),
        notificationDetails: const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(),
        ),
        // 정확한 알람 권한이 필요 없는 방식 — 몇 분 늦어도 괜찮은 알림이다.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: slot.name,
      );
    }
    return allowed;
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  static tz.TZDateTime _nextInstanceOf(ClockTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}
