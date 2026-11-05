import 'package:core_analytics/core_analytics.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_model.dart';
import '../platform/ads.dart';
import '../save/save_repository.dart';
import 'ad_rewards.dart';
import 'economy.dart';

/// 앱 전체 Navigator. 가짜 광고가 이 위에 창을 띄운다.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 지금 테마. 테마가 늘면 진행 상태에서 고른다.
final groveThemeProvider = Provider<GroveTheme>((ref) => forestCaveTheme);

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPrefsKeyValueStore(),
);

final analyticsProvider = Provider<Analytics>(
  (ref) => const ConsoleAnalytics(),
);

/// 방치 산출 계산에 쓰는 시계. 테스트에서 바꿔 끼운다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => SaveRepository(ref.watch(keyValueStoreProvider)),
);

/// 앱 시작 시 한 번 불러온 저장 (오프라인 산출 반영 완료).
final loadedGroveProvider = FutureProvider<LoadedGrove>(
  (ref) => ref
      .watch(saveRepositoryProvider)
      .load(ref.watch(groveThemeProvider), now: ref.watch(clockProvider)()),
);

/// 창고·테마 완주 (아웃게임 상태, `docs/03-architecture.md` §3).
///
/// [loadedGroveProvider]가 끝난 뒤에만 읽는다 — 보드 화면이 그 순서를 지킨다.
final economyProvider = NotifierProvider<EconomyNotifier, Economy>(
  EconomyNotifier.new,
);

class EconomyNotifier extends Notifier<Economy> {
  @override
  Economy build() => ref.watch(loadedGroveProvider).requireValue.economy;

  /// 창고에 넣고 실제로 들어간 양을 돌려준다.
  int deposit(Resource resource, int amount) {
    final (next, accepted) = state.add(resource, amount);
    state = next;
    return accepted;
  }

  Map<Resource, int> depositAll(Map<Resource, int> gains) {
    final (next, accepted) = state.addAll(gains);
    state = next;
    return accepted;
  }

  void pay(Cost cost) => state = state.pay(cost);

  void upgradeStorage() => state = state.upgradeStorage();

  void markCleared() => state = state.markCleared();
}

/// 보상형 광고 재생기. 테스트에서 바꿔 끼운다.
final rewardedAdsProvider = Provider<RewardedAds>(
  (ref) => platformRewardedAds(rootNavigatorKey),
);

/// 광고 시청 기록·산출 가속 (아웃게임 상태). [economyProvider]와 같은 순서로 읽는다.
final adRewardsProvider = NotifierProvider<AdRewardsNotifier, AdRewards>(
  AdRewardsNotifier.new,
);

class AdRewardsNotifier extends Notifier<AdRewards> {
  @override
  AdRewards build() => ref.watch(loadedGroveProvider).requireValue.ads;

  void recordWatch(DateTime now) => state = state.recordWatch(now);

  void startBoost(DateTime now) => state = state.startBoost(now);
}
