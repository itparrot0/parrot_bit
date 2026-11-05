import 'package:core_storage/core_storage.dart';

import '../domain/domain.dart';

/// 설정값 저장. 도메인 없는 단순 값이라 `core_storage`(key-value)를 쓴다
/// (docs/prd/sleep_log.md §9-3). 키 이름은 이 앱이 소유한다.
final class SettingsRepository {
  SettingsRepository(this._store);

  static const String targetMinutesKey = 'sleep_log.target_minutes';
  static const String safetyNoticeKey = 'sleep_log.safety_notice_enabled';

  final KeyValueStore _store;

  /// 사용자가 정한 목표 수면시간. **설정한 적이 없으면 null** — 기본값을 채워
  /// 돌려주지 않는다. "아직 안 정했다"는 온보딩으로 보낼 근거라서
  /// (docs/screen-flow/sleep_log.md §2) 기본값과 구분돼야 한다.
  ///
  /// 저장값이 허용 범위를 벗어나면(손상·이전 버전) 설정하지 않은 것으로 본다.
  Future<SleepTarget?> loadTarget() async {
    final minutes = await _store.getInt(targetMinutesKey);
    if (minutes == null) {
      return null;
    }
    final duration = Duration(minutes: minutes);
    if (duration < SleepTarget.minDuration ||
        duration > SleepTarget.maxDuration) {
      return null;
    }
    return SleepTarget(duration);
  }

  Future<void> saveTarget(SleepTarget target) =>
      _store.setInt(targetMinutesKey, target.duration.inMinutes);

  /// 안전 안내 배너를 띄울지 (PRD §9-2). **기본 켜짐** — 정한 적이 없으면 true.
  Future<bool> loadSafetyNoticeEnabled() async =>
      await _store.getBool(safetyNoticeKey) ?? true;

  Future<void> saveSafetyNoticeEnabled(bool enabled) =>
      _store.setBool(safetyNoticeKey, enabled);
}
