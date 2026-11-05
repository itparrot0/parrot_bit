import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bloom_wave/app.dart';
import 'package:bloom_wave/domain/engine.dart';
import 'package:bloom_wave/platform/ads.dart';
import 'package:bloom_wave/platform/billing.dart';
import 'package:bloom_wave/platform/haptics.dart';
import 'package:bloom_wave/platform/sfx.dart';
import 'package:bloom_wave/save/save_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<Level> loadPackFile() => [
  for (final j
      in jsonDecode(File('assets/levels/pack-01.json').readAsStringSync())
          as List)
    Level.fromJson(j as Map<String, dynamic>),
];

final List<Level> pack = loadPackFile();

class FakeAds implements AdProvider {
  int shown = 0;
  int rewardedShown = 0;

  /// 보상형 광고를 끝까지 봤다고 할지
  bool rewardOk = true;
  @override
  Future<bool> showRewarded() async {
    rewardedShown++;
    return rewardOk;
  }

  @override
  Future<void> init() async {}
  @override
  Future<void> showInterstitial() async => shown++;
  @override
  Widget? banner() => const SizedBox(
    key: ValueKey('banner-ad'),
    width: double.infinity,
    height: 50,
  );
}

class Harness {
  Harness({SaveData? data, List<Level>? levels, int seed = 1, DateTime? now})
    : ads = FakeAds(),
      billing = DevBilling(),
      sfx = SilentSfx(),
      store = MemoryStore() {
    save = SaveStore(store);
    if (data != null) save.data = data;
    services = AppServices(
      levels: levels ?? pack,
      save: save,
      ads: Ads(ads),
      billing: billing,
      sfx: sfx,
      haptics: Haptics()..enabled = false,
      rng: math.Random(seed),
      manualTick: true,
      clock: () => this.now,
    );
    if (now != null) this.now = now;
  }

  /// 테스트 시계 (바꾸면 햇빛 회복이 그만큼 진행된다)
  DateTime now = DateTime(2026, 11, 5, 12);

  final FakeAds ads;
  final DevBilling billing;
  final SilentSfx sfx;
  final MemoryStore store;
  late final SaveStore save;
  late final AppServices services;

  Widget get app => BloomWaveApp(services: services);
}

/// 논리 해상도(1080×2340)와 같은 비율의 화면
Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 연출 시계는 한 프레임에 최대 100ms 만 간다 — 잘게 나눠 진행
Future<void> advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder byKey(String k) => find.byKey(ValueKey(k));
