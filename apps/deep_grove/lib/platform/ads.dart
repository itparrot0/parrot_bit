// 보상형 광고 (PRD §6). 플레이어가 버튼을 누를 때만 재생한다. 배너·전면 광고는 없다.
// 모바일은 AdMob(google_mobile_ads), 웹·데스크톱(개발용)은 화면 안 가짜 광고로 흐름만 확인한다.
//
// 출시 전 할 일: AdMob 콘솔에서 앱/광고 단위를 만들고 아래 ID 와
// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID,
// ios/Runner/Info.plist 의 GADApplicationIdentifier 를 실제 값으로 바꾼다.
// 지금 값은 Google이 공개한 테스트 ID 라서 실제 수익이 나지 않는다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract final class AdConfig {
  /// Google 테스트 보상형 광고 단위 (Android / iOS)
  static const rewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const rewardedIos = 'ca-app-pub-3940256099942544/1712485313';
}

/// 보상형 광고 한 편 재생.
abstract interface class RewardedAds {
  Future<void> init();

  /// 광고를 보여 준다. 끝까지 봐서 보상을 받으면 true, 못 받거나 실패하면 false.
  /// 어떤 실패도 던지지 않는다 — 광고는 게임을 멈추지 않는다.
  Future<bool> show();
}

/// 이 기기에서 쓸 광고. AdMob 은 Android·iOS 에서만 돈다.
RewardedAds platformRewardedAds(GlobalKey<NavigatorState> navigatorKey) =>
    !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)
    ? AdMobRewardedAds()
    : MockRewardedAds(navigatorKey);

class AdMobRewardedAds implements RewardedAds {
  RewardedAd? _ready;

  String get _unit => defaultTargetPlatform == TargetPlatform.iOS
      ? AdConfig.rewardedIos
      : AdConfig.rewardedAndroid;

  @override
  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      unawaited(_load());
    } catch (_) {
      // 광고 SDK 실패는 게임에 영향을 주지 않는다
    }
  }

  /// 한 편을 미리 받아 둔다 — 버튼을 누른 뒤 기다리는 시간을 줄인다.
  Future<RewardedAd?> _load() {
    final loaded = Completer<RewardedAd?>();
    try {
      RewardedAd.load(
        adUnitId: _unit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ready = ad;
            if (!loaded.isCompleted) loaded.complete(ad);
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
    } catch (_) {
      if (!loaded.isCompleted) loaded.complete(null);
    }
    return loaded.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  @override
  Future<bool> show() async {
    final ad = _ready ?? await _load();
    _ready = null;
    if (ad == null) return false;
    var earned = false;
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        finish();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (_) {
      finish();
    }
    await closed.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    unawaited(_load()); // 다음 광고 미리 받기
    return earned;
  }
}

/// 개발용 가짜 광고: 끝까지 볼지 닫을지 고르는 창을 띄운다 (실패 흐름도 손으로 확인).
class MockRewardedAds implements RewardedAds {
  MockRewardedAds(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<void> init() async {}

  @override
  Future<bool> show() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final earned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('보상형 광고 (테스트)'),
        content: const Text('실제 기기에서는 여기서 광고가 재생돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('중간에 닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('끝까지 봄'),
          ),
        ],
      ),
    );
    return earned ?? false;
  }
}
