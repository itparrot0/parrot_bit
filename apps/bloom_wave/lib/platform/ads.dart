// 광고: 스테이지 완성 후 전면 광고 1회(실패 시에는 없음) + 스테이지 플레이 화면 아래 배너(2026-11-04).
// 광고 제거 구매자는 둘 다 없다.
// 모바일은 AdMob(google_mobile_ads), 웹·데스크톱(개발용)은 화면 안의 가짜 광고로 흐름만 확인한다.
//
// 출시 전 할 일: AdMob 콘솔에서 앱/광고 단위를 만들고 아래 ID 와
// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 실제 값으로 바꾼다.
// 지금 값은 Google이 공개한 테스트 ID 라서 실제 수익이 나지 않는다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConfig {
  /// Google 테스트 전면 광고 단위 (Android)
  static const interstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';

  /// Google 테스트 전면 광고 단위 (iOS)
  static const interstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  /// Google 테스트 적응형 배너 단위 (Android / iOS)
  static const bannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const bannerIos = 'ca-app-pub-3940256099942544/2435281174';

  /// 배너를 받기 전·받지 못했을 때 자리를 비워 두는 높이(dp). 배너가 들어와도 판이 밀리지 않게 한다
  static const bannerReserve = 50.0;

  /// 몇 스테이지마다 광고를 보여 줄지 (1 = 매 스테이지)
  static const every = 1;
}

abstract class AdProvider {
  Future<void> init();

  /// 전면 광고를 보여 주고 닫히면 끝난다. 실패해도 게임은 계속된다
  Future<void> showInterstitial();

  /// 게임 화면 아래 배너 위젯 (광고를 붙일 수 없으면 null)
  Widget? banner();
}

class AdMobProvider implements AdProvider {
  InterstitialAd? _ad;

  @override
  Widget? banner() => AdMobBanner(
    unitId: defaultTargetPlatform == TargetPlatform.iOS
        ? AdConfig.bannerIos
        : AdConfig.bannerAndroid,
  );

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
  Widget? banner() => const MockBanner();
  @override
  Future<void> showInterstitial() {
    shown++;
    return show();
  }
}

/// 스테이지 완성 뒤 광고 주기 관리 + 배너
class Ads {
  Ads(this.provider);
  final AdProvider provider;
  int _counter = 0;

  /// 스테이지 플레이 화면 아래 배너. 광고 제거 구매자는 null
  Widget? banner({required bool noAds}) => noAds ? null : provider.banner();

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

/// AdMob 적응형 고정 배너. 화면 너비에 맞는 크기를 먼저 정해 자리를 잡아 두고, 광고가 들어오면 그 자리에 띄운다.
/// 받지 못해도 자리는 그대로 둔다 (게임 판이 위아래로 흔들리지 않게).
class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key, required this.unitId});
  final String unitId;

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(MediaQuery.sizeOf(context).width.truncate());
  }

  Future<void> _load(int width) async {
    try {
      final size =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ??
          AdSize.banner;
      if (!mounted) return;
      setState(() => _size = size);
      final ad = BannerAd(
        adUnitId: widget.unitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (mounted) setState(() => _ad = null);
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      // 광고 실패는 게임에 영향을 주지 않는다
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final ad = _ad;
    return SizedBox(
      key: const ValueKey('banner-ad'),
      width: double.infinity,
      height: size?.height.toDouble() ?? AdConfig.bannerReserve,
      child: _loaded && ad != null && size != null
          ? Center(
              child: SizedBox(
                width: size.width.toDouble(),
                height: size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            )
          : null,
    );
  }
}

/// 웹·데스크톱(개발용) 가짜 배너: 같은 자리에 회색 띠
class MockBanner extends StatelessWidget {
  const MockBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('banner-ad'),
    height: AdConfig.bannerReserve,
    width: double.infinity,
    alignment: Alignment.center,
    color: const Color(0xFFDDD6C8),
    child: const Text(
      '배너 광고 (테스트)',
      style: TextStyle(fontSize: 14, color: Color(0xFF7A736A)),
    ),
  );
}
