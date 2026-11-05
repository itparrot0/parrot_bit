import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'backup_codec.dart';

/// 가져오기 결과 — 화면이 "몇 개를 옮겼는지" 알려 줄 때 쓴다.
typedef RestoreSummary = ({int entries, int checkIns});

/// 백업 만들기·가져오기 (PRD §9-4). 파일을 고르고 보내는 일은
/// [BackupFileGateway]가, 암호화는 [BackupCodec]이 한다.
final class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  /// 지금 기기의 기록·설정 전부.
  Future<BackupContents> collect() async {
    final settings = _ref.read(settingsRepositoryProvider);
    return BackupContents(
      createdAt: _ref.read(clockProvider)(),
      entries: await _ref.read(diaryRepositoryProvider).watchAll().first,
      checkIns: await _ref.read(checkInRepositoryProvider).watchAll().first,
      target: _ref.read(savedSleepTargetProvider),
      safetyNoticeEnabled: await settings.loadSafetyNoticeEnabled(),
      checkInSettings: await settings.loadCheckInSettings(),
    );
  }

  Future<Uint8List> export(String password) async => BackupCodec.encode(
    await collect(),
    password,
    iterations: _ref.read(backupIterationsProvider),
  );

  /// 백업을 지금 기기에 **합친다.**
  ///
  /// - 같은 날짜(체크인은 같은 날짜·시간대)는 백업 내용으로 바뀐다.
  /// - 백업에 없는 날짜의 기록은 그대로 남는다 — 새 기기에서 며칠 쓰다가
  ///   옮겨 와도 그 며칠을 잃지 않는다.
  /// - 설정(목표 수면시간, 안전 안내, 생각 돌아보기와 알림 시각)은 백업을 따른다.
  Future<RestoreSummary> restore(BackupContents contents) async {
    final diary = _ref.read(diaryRepositoryProvider);
    for (final entry in contents.entries) {
      await diary.save(entry);
    }
    final checkIns = _ref.read(checkInRepositoryProvider);
    for (final checkIn in contents.checkIns) {
      await checkIns.save(checkIn);
    }
    if (contents.target case final target?) {
      await _ref.read(savedSleepTargetProvider.notifier).set(target);
    }
    await _ref
        .read(safetyNoticeEnabledProvider.notifier)
        .set(contents.safetyNoticeEnabled);
    // 알림도 새 기기에서 다시 잡힌다. 권한은 여기서 묻지 않는다 — 켜져 있던
    // 기능이면 설정 화면에서 다시 켤 때 묻는다.
    await _ref
        .read(checkInSettingsProvider.notifier)
        .set(contents.checkInSettings, askPermission: false);
    return (
      entries: contents.entries.length,
      checkIns: contents.checkIns.length,
    );
  }
}
