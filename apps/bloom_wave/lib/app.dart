// 앱 공통 서비스(레벨 팩, 저장, 광고, 결제, 소리, 진동)와 루트 위젯.
// 화면 흐름 (2026-11-04): 홈(스테이지 시작 버튼만) → 게임 → 완성 시 [홈] / [다음 스테이지].
// 지난 스테이지를 다시 보는 메뉴(스테이지 맵·정원)는 없다 — 완성한 스테이지는 다시 쓰지 않는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'domain/engine.dart';
import 'economy/gold_packs.dart';
import 'game/colors.dart';
import 'i18n/strings.dart';
import 'platform/ads.dart';
import 'platform/billing.dart';
import 'platform/haptics.dart';
import 'platform/sfx.dart';
import 'save/save_store.dart';
import 'screens/home_screen.dart';
import 'ui/theme.dart';

class AppServices extends ChangeNotifier {
  AppServices({
    required this.levels,
    required this.save,
    required this.ads,
    required this.billing,
    required this.sfx,
    required this.haptics,
    math.Random? rng,
    this.version = '1.0.0',
    this.manualTick = false,
    DateTime Function()? clock,
  }) : rng = rng ?? math.Random(),
       clock = clock ?? DateTime.now,
       firstSimilar = firstSimilarLevel(levels),
       firstMystery =
           levels.indexWhere(
             (l) => l.lanes.any((lane) => lane.any((d) => d.hidden)),
           ) +
           1,
       firstSet =
           levels.indexWhere(
             (l) => l.lanes.any((lane) => lane.any((d) => d.set != null)),
           ) +
           1 {
    // 골드 구매 지급 (결제가 나중에 끝나도 여기로 온다)
    billing.onConsumable = (productId, orderId) async {
      final pack = goldPackById(productId);
      if (pack == null) return;
      if (await save.grantPurchasedGold(orderId, pack.total) > 0) {
        sfx.coin();
        notifyListeners();
      }
    };
  }

  final List<Level> levels;
  final SaveStore save;
  final Ads ads;
  final Billing billing;
  final Sfx sfx;
  final Haptics haptics;

  /// 골드 지급량 같은 무작위 값 (테스트는 시드를 고정한다)
  final math.Random rng;
  final String version;

  /// 지금 시각 (햇빛 회복·광고 충전 날짜). 테스트는 시계를 바꿔 끼운다
  final DateTime Function() clock;

  /// true 면 게임이 타이머로 틱을 돌리지 않는다 (테스트용)
  final bool manualTick;

  /// 비슷한 색이 처음 나오는 스테이지 번호 (도움말용)
  final int firstSimilar;

  /// "?" 물방울이 처음 나오는 스테이지 번호 (도움말용, 없으면 0)
  final int firstMystery;

  /// set(묶인 물방울)이 처음 나오는 스테이지 번호 (도움말용, 없으면 0)
  final int firstSet;

  Strings get strings => Strings(save.data.settings.lang);
  String t(String key, [Map<String, Object> vars = const {}]) =>
      strings.t(key, vars);

  int get total => levels.length;

  /// 다음에 할 스테이지 번호. 모두 완성했으면 null
  int? get nextStage {
    final d = save.data;
    if (d.cleared.contains(levels.last.id) || d.unlocked > total) return null;
    var n = d.unlocked.clamp(1, total);
    // 옛 저장(해금 수가 상한에 묶여 있던 경우)도 완성한 스테이지는 건너뛴다
    while (n <= total && d.cleared.contains(levels[n - 1].id)) {
      n++;
    }
    return n > total ? null : n;
  }

  /// 설정·골드 등 화면에 보이는 값이 바뀌었을 때
  void changed() => notifyListeners();

  Future<void> updateSettings(Settings s) async {
    await save.updateSettings(s);
    sfx.enabled = s.sound;
    haptics.enabled = s.vibration;
    notifyListeners();
  }

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Scope>()!.notifier!;
}

class _Scope extends InheritedNotifier<AppServices> {
  const _Scope({required AppServices services, required super.child})
    : super(notifier: services);
}

class BloomWaveApp extends StatelessWidget {
  const BloomWaveApp({super.key, required this.services, this.navigatorKey});
  final AppServices services;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => _Scope(
    services: services,
    child: MaterialApp(
      title: 'Bloom Wave',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: C.accent),
        scaffoldBackgroundColor: C.bg,
      ),
      home: const HomeScreen(),
    ),
  );
}
