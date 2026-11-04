// 광고: 스테이지 완성 후 전면 광고 1회. 실패 시에는 광고 없음. 광고 제거 구매자는 건너뛴다.
// 모바일은 AdMob(google_mobile_ads), 웹·데스크톱(개발용)은 화면 안의 가짜 광고로 흐름만 확인한다.
//
// 출시 전 할 일: AdMob 콘솔에서 앱/광고 단위를 만들고 아래 ID 와
// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 실제 값으로 바꾼다.
// 지금 값은 Google이 공개한 테스트 ID 라서 실제 수익이 나지 않는다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConfig {
  /// Google 테스트 전면 광고 단위 (Android)
  static const interstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';

  /// Google 테스트 전면 광고 단위 (iOS)
  static const interstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  /// 몇 스테이지마다 광고를 보여 줄지 (1 = 매 스테이지)
  static const every = 1;
}

abstract class AdProvider {
  Future<void> init();

  /// 전면 광고를 보여 주고 닫히면 끝난다. 실패해도 게임은 계속된다
  Future<void> showInterstitial();
}

class AdMobProvider implements AdProvider {
  InterstitialAd? _ad;

  String get _unit => defaultTargetPlatform == TargetPlatform.iOS
      ? AdConfig.interstitialIos
      : AdConfig.interstitialAndroid;

  @override
  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      unawaited(_prepare());
    } catch (_) {
      // 광고 SDK 실패는 게임에 영향을 주지 않는다
    }
  }

  Future<void> _prepare() {
    final done = Completer<void>();
    try {
      InterstitialAd.load(
        adUnitId: _unit,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            if (!done.isCompleted) done.complete();
          },
          onAdFailedToLoad: (_) {
            _ad = null;
            if (!done.isCompleted) done.complete();
          },
        ),
      );
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  @override
  Future<void> showInterstitial() async {
    if (_ad == null) await _prepare();
    final ad = _ad;
    if (ad == null) return;
    _ad = null;
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
      await ad.show();
    } catch (_) {
      finish();
    }
    await closed.future.timeout(const Duration(seconds: 60), onTimeout: () {});
    unawaited(_prepare()); // 다음 광고 미리 받기
  }
}

/// 개발용 가짜 광고: 화면을 덮는 패널을 띄운다 (show 는 화면 쪽이 넘겨준다)
class MockAdProvider implements AdProvider {
  MockAdProvider(this.show);
  final Future<void> Function() show;
  int shown = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> showInterstitial() {
    shown++;
    return show();
  }
}

/// 스테이지 완성 뒤 광고 주기 관리
class Ads {
  Ads(this.provider);
  final AdProvider provider;
  int _counter = 0;

  /// 광고 제거 구매자이거나 주기가 아니면 바로 끝난다. 보여 줬으면 true
  Future<bool> afterClear({required bool noAds}) async {
    if (noAds) return false;
    _counter++;
    if (_counter % AdConfig.every != 0) return false;
    try {
      await provider.showInterstitial();
    } catch (_) {
      // 광고 실패는 무시
    }
    return true;
  }
}
