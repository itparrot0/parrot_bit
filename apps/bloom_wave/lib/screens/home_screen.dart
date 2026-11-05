// 홈: 스테이지 시작 버튼 + 상점·스킨 뽑기 버튼 (2026-11-04). 지난 스테이지를 고르는 메뉴는 없다.
// 위쪽에는 햇빛(라이프, 왼쪽)과 골드 잔액(오른쪽), 가운데에는 가장 최근에 완성한 그림(없으면 첫 그림의 실루엣).
// 뒤로 가기는 종료 확인.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../game/game_painter.dart';
import '../ui/sun.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'gacha_screen.dart';
import 'lives_panel.dart';
import 'game_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  bool _exitDialog = false;

  /// 햇빛 패널 (배지를 누르거나 햇빛 없이 시작하려 할 때)
  bool _lives = false;
  bool _livesEmpty = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMilliseconds.toDouble())
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _start(AppServices app, int n) {
    // 햇빛이 없으면 시작하지 않고 채우기 패널 (시작할 때 1개를 쓰는 것은 게임 화면이 한다)
    final lives = app.save.data.lives..settle(app.clock());
    if (lives.count <= 0) {
      setState(() {
        _lives = true;
        _livesEmpty = true;
      });
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GameScreen(levelNo: n),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final next = app.nextStage;
    final cleared = [
      for (final l in app.levels)
        if (app.save.data.cleared.contains(l.id)) l,
    ];
    final art = cleared.isNotEmpty ? cleared.last : app.levels.first;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (_lives) {
            _lives = false;
          } else {
            _exitDialog = !_exitDialog;
          }
        });
      },
      child: Scaffold(
        body: LogicalCanvas(
          builder: (context, top, bottom) => Stack(
            clipBehavior: Clip.none,
            children: [
              // 햇빛 (왼쪽 위): 누르면 햇빛 패널
              Positioned(
                left: 50,
                top: top + 60,
                child: LivesBadge(
                  key: const ValueKey('home-lives'),
                  lives: app.save.data.lives,
                  now: app.clock,
                  fullText: app.t('livesFull'),
                  nextText: app.t('livesNext'),
                  onTap: () => setState(() {
                    _lives = true;
                    _livesEmpty = false;
                  }),
                ),
              ),
              // 골드 잔액 (오른쪽 위)
              Positioned(
                right: 50,
                top: top + 60,
                child: GoldBadge(
                  key: const ValueKey('home-gold'),
                  gold: app.save.data.gold,
                ),
              ),
              At(
                x: kW / 2,
                y: top + 380,
                child: Label(
                  app.t('title'),
                  size: 130,
                  color: C.accentDark,
                  weight: FontWeight.w800,
                ),
              ),
              At(
                x: kW / 2,
                y: top + 500,
                child: Label(
                  app.t('subtitle'),
                  size: 46,
                  color: C.inkSoft,
                  weight: FontWeight.w500,
                ),
              ),
              // 그림이 위아래로 천천히 떠 있다
              ValueListenableBuilder<double>(
                valueListenable: _time,
                builder: (context, t, _) => Positioned(
                  left: kW / 2 - 260,
                  top: top + 940 - 260 + math.sin(t / 900) * 14,
                  width: 520,
                  height: 520,
                  child: CustomPaint(
                    painter: ArtPainter(art, silhouette: cleared.isEmpty),
                  ),
                ),
              ),
              if (next != null)
                At(
                  x: kW / 2,
                  y: kH - bottom - 590,
                  w: 800,
                  h: 200,
                  child: PillButton(
                    app.t('startStage', {'n': next}),
                    key: const ValueKey('btn-start'),
                    w: 720,
                    h: 170,
                    size: 58,
                    onClick: app.sfx.click,
                    onTap: () => _start(app, next),
                  ),
                )
              else ...[
                At(
                  x: kW / 2,
                  y: kH - bottom - 630,
                  w: 1000,
                  h: 120,
                  child: Label(
                    app.t('allCleared'),
                    key: const ValueKey('all-cleared'),
                    size: 64,
                    color: C.accentDark,
                  ),
                ),
                At(
                  x: kW / 2,
                  y: kH - bottom - 530,
                  w: 1000,
                  h: 100,
                  child: Label(
                    app.t('allClearedSub'),
                    size: 40,
                    color: C.inkSoft,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
              // 상점 · 스킨 뽑기 (2026-11-04)
              At(
                x: kW / 2 - 185,
                y: kH - bottom - 360,
                w: 380,
                h: 170,
                child: PillButton(
                  app.t('openShop'),
                  key: const ValueKey('btn-shop'),
                  w: 350,
                  h: 140,
                  color: C.panel,
                  textColor: C.ink,
                  leading: const Icon(
                    Icons.storefront_rounded,
                    size: 56,
                    color: C.accentDark,
                  ),
                  onClick: app.sfx.click,
                  onTap: () => _open(const ShopScreen()),
                ),
              ),
              At(
                x: kW / 2 + 185,
                y: kH - bottom - 360,
                w: 380,
                h: 170,
                child: PillButton(
                  app.t('skinGacha'),
                  key: const ValueKey('btn-gacha'),
                  w: 350,
                  h: 140,
                  color: C.gold,
                  textColor: C.ink,
                  leading: const Icon(
                    Icons.local_florist_rounded,
                    size: 56,
                    color: C.ink,
                  ),
                  onClick: app.sfx.click,
                  onTap: () => _open(const GachaScreen()),
                ),
              ),
              if (_lives)
                LivesPanel(
                  app: app,
                  empty: _livesEmpty,
                  onClose: () => setState(() => _lives = false),
                ),
              if (_exitDialog)
                OverlayPanel(
                  key: const ValueKey('overlay-exit'),
                  w: 760,
                  h: 520,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Label(app.t('exitTitle'), size: 52),
                      const SizedBox(height: 90),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PillButton(
                            app.t('exitYes'),
                            key: const ValueKey('btn-exit-yes'),
                            w: 300,
                            color: C.warn,
                            onClick: app.sfx.click,
                            onTap: () => SystemNavigator.pop(),
                          ),
                          const SizedBox(width: 30),
                          PillButton(
                            app.t('exitNo'),
                            key: const ValueKey('btn-exit-no'),
                            w: 300,
                            color: C.panel,
                            textColor: C.ink,
                            onClick: app.sfx.click,
                            onTap: () => setState(() => _exitDialog = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
