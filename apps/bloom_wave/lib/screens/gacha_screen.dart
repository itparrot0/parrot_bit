// 스킨 뽑기 (2026-11-04): 가챠 머신 애니메이션 → 꽃 스킨 퍼즐 조각.
// 결과(골드 차감·조각·중복 반환)는 애니메이션 전에 바로 저장한다 — 연출 중에 앱이 꺼져도 잃지 않는다.
// 애니메이션은 이 화면에서만 돌고(AnimationController 하나 + CustomPainter), 쉬는 동안에는 프레임을 쓰지 않는다.
// 게임 화면과는 따로라 게임 성능에 영향이 없다. 탭하면 건너뛴다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../economy/gacha.dart';
import '../economy/skins.dart';
import '../ui/skin_card.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 연출 길이와 구간 (0~1 비율)
class GachaTimeline {
  static const total = Duration(milliseconds: 2600);
  static const crankEnd = 0.27; // 손잡이 한 바퀴, 캡슐 흔들림
  static const dropEnd = 0.52; // 캡슐이 떨어져 튀어 오름
  static const wobbleEnd = 0.64; // 캡슐이 들썩임
  static const openEnd = 0.82; // 캡슐이 열리며 빛
}

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => GachaScreenState();
}

class GachaScreenState extends State<GachaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController anim =
      AnimationController(vsync: this, duration: GachaTimeline.total)
        ..addStatusListener((st) {
          if (st == AnimationStatus.completed) _reveal();
        });

  /// 방금 뽑은 결과 (애니메이션이 끝나면 패널로 보여 준다)
  PullResult? result;
  bool revealed = false;
  bool _odds = false;
  String? _msg;

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  Future<void> _pull(AppServices app) async {
    if (anim.isAnimating) return;
    final block = pullBlock(app.save.data);
    if (block != null) {
      app.sfx.deny();
      setState(
        () => _msg = app.t(
          block == PullBlock.allUnlocked ? 'allSkinsUnlocked' : 'notEnoughGold',
        ),
      );
      return;
    }
    final r = await app.save.pullSkin(app.rng);
    if (!mounted) return;
    app.sfx.tap();
    setState(() {
      result = r;
      revealed = false;
      _msg = null;
    });
    anim.forward(from: 0);
  }

  void _reveal() {
    final app = AppServices.of(context);
    final r = result;
    if (r == null || revealed) return;
    setState(() => revealed = true);
    switch (r.outcome) {
      case PullOutcome.unlocked:
        app.sfx.clear();
        app.haptics.success();
      case PullOutcome.newPiece:
        app.sfx.coin();
      case PullOutcome.duplicate:
        app.sfx.coin();
    }
    app.changed();
  }

  void _skip() {
    if (anim.isAnimating) anim.value = 1;
  }

  void _close() => setState(() {
    result = null;
    revealed = false;
  });

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final d = app.save.data;
    final r = result;
    // 연출이 끝나기 전에는 반환 골드를 아직 보여 주지 않는다
    final shownGold = d.gold - (r != null && !revealed ? r.refund : 0);
    final block = pullBlock(d);
    return PopScope(
      canPop: !anim.isAnimating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _skip();
      },
      child: Scaffold(
        body: LogicalCanvas(
          builder: (context, top, bottom) => Stack(
            clipBehavior: Clip.none,
            children: [
              At(
                x: 100,
                y: top + 110,
                w: 140,
                h: 140,
                child: CircleButton(
                  key: const ValueKey('btn-back'),
                  icon: Icons.chevron_left_rounded,
                  tooltip: app.t('home'),
                  onClick: app.sfx.click,
                  onTap: () {
                    if (!anim.isAnimating) Navigator.of(context).pop();
                  },
                ),
              ),
              At(
                x: kW / 2,
                y: top + 110,
                h: 100,
                child: Label(app.t('skinGacha'), size: 60),
              ),
              Positioned(
                right: 50,
                top: top + 70,
                child: GoldBadge(
                  key: const ValueKey('gacha-gold'),
                  gold: shownGold,
                ),
              ),
              // 머신
              Positioned(
                left: kW / 2 - 400,
                top: top + 240,
                width: 800,
                height: 1200,
                child: GestureDetector(
                  key: const ValueKey('gacha-machine'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _skip,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: anim,
                      builder: (context, _) => CustomPaint(
                        painter: GachaMachinePainter(
                          t: anim.value,
                          capsule: r == null
                              ? C.gold
                              : Color(0xFF000000 | r.skin.color),
                          active: anim.isAnimating || (r != null && !revealed),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (anim.isAnimating)
                At(
                  x: kW / 2,
                  y: top + 1490,
                  h: 80,
                  child: Label(
                    app.t('tapToSkip'),
                    size: 36,
                    color: C.inkSoft,
                    weight: FontWeight.w500,
                  ),
                ),
              if (_msg != null)
                At(
                  x: kW / 2,
                  y: kH - bottom - 470,
                  h: 80,
                  child: Label(
                    _msg!,
                    key: const ValueKey('gacha-msg'),
                    size: 42,
                    color: C.warn,
                  ),
                ),
              At(
                x: kW / 2,
                y: kH - bottom - 320,
                w: 900,
                h: 200,
                child: PillButton(
                  block == PullBlock.allUnlocked
                      ? app.t('allSkinsUnlocked')
                      : '${app.t('pull')} · ${app.t('pullCost', {'n': GachaConfig.pullCost})}',
                  key: const ValueKey('btn-pull'),
                  w: 800,
                  h: 170,
                  size: 54,
                  color: C.gold,
                  textColor: C.ink,
                  enabled: block != PullBlock.allUnlocked && !anim.isAnimating,
                  leading: block == PullBlock.allUnlocked
                      ? null
                      : const CoinIcon(size: 64),
                  onClick: app.sfx.click,
                  onTap: () => _pull(app),
                ),
              ),
              At(
                x: kW / 2,
                y: kH - bottom - 150,
                w: 600,
                h: 140,
                child: PillButton(
                  app.t('odds'),
                  key: const ValueKey('btn-odds'),
                  w: 420,
                  h: 110,
                  size: 40,
                  color: C.panel,
                  textColor: C.ink,
                  onClick: app.sfx.click,
                  onTap: () => setState(() => _odds = true),
                ),
              ),
              if (r != null && revealed) _resultPanel(app, r),
              if (_odds) _oddsPanel(app),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultPanel(AppServices app, PullResult r) {
    final d = app.save.data;
    final lang = d.settings.lang;
    final (title, color) = switch (r.outcome) {
      PullOutcome.unlocked => (app.t('skinUnlocked'), C.accentDark),
      PullOutcome.newPiece => (app.t('newPiece'), C.accentDark),
      PullOutcome.duplicate => (app.t('duplicatePiece'), C.inkSoft),
    };
    final unlocked = r.outcome == PullOutcome.unlocked;
    return OverlayPanel(
      key: ValueKey('overlay-gacha-${r.outcome.name}'),
      w: 900,
      h: 1250,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 50),
        child: Column(
          children: [
            Label(
              title,
              key: const ValueKey('gacha-title'),
              size: 72,
              color: color,
              weight: FontWeight.w900,
            ),
            const SizedBox(height: 40),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (context, k, _) => Transform.scale(
                scale: unlocked
                    ? 0.85 + 0.15 * Curves.elasticOut.transform(k)
                    : 1,
                child: SkinCard(
                  skin: r.skin,
                  owned: {...?d.skinPieces[r.skin.id]},
                  size: 460,
                  highlight: unlocked ? null : r.piece,
                  highlightGlow: 0.5 + 0.5 * math.sin(k * math.pi * 3).abs(),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(r.skin.name(lang), style: textStyle(52)),
            const SizedBox(height: 10),
            Text(
              unlocked
                  ? app.t('pieces', {
                      'n': r.skin.pieces,
                      'total': r.skin.pieces,
                    })
                  : app.t('pieces', {
                      'n': d.skinPieces[r.skin.id]?.length ?? 0,
                      'total': r.skin.pieces,
                    }),
              key: const ValueKey('gacha-progress'),
              style: textStyle(38, color: C.inkSoft, weight: FontWeight.w600),
            ),
            if (r.outcome == PullOutcome.duplicate) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 56),
                  const SizedBox(width: 16),
                  Text(
                    app.t('refund', {'n': r.refund}),
                    key: const ValueKey('gacha-refund'),
                    style: textStyle(
                      44,
                      color: C.goldDark,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (unlocked) ...[
                  PillButton(
                    app.t('equipNow'),
                    key: const ValueKey('btn-equip-now'),
                    w: 380,
                    onClick: app.sfx.click,
                    onTap: () async {
                      await app.save.equipSkin(r.skin.id);
                      app.changed();
                      _close();
                    },
                  ),
                  const SizedBox(width: 30),
                ],
                PillButton(
                  app.t('ok'),
                  key: const ValueKey('btn-gacha-ok'),
                  w: unlocked ? 380 : 600,
                  color: unlocked ? C.bgDeep : C.accent,
                  textColor: unlocked ? C.ink : Colors.white,
                  onClick: app.sfx.click,
                  onTap: _close,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 확률 공개: 규칙과 같은 함수(gachaOdds)로 계산한 지금 확률
  Widget _oddsPanel(AppServices app) {
    final d = app.save.data;
    final lang = d.settings.lang;
    String pct(double p) => '${(p * 100).toStringAsFixed(2)}%';
    return OverlayPanel(
      key: const ValueKey('overlay-odds'),
      w: 960,
      h: 1500,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(50, 60, 50, 50),
        child: Column(
          children: [
            Label(app.t('oddsTitle'), size: 60),
            const SizedBox(height: 30),
            Label(
              app.t('oddsNote', {'n': GachaConfig.refund}),
              size: 34,
              color: C.inkSoft,
              weight: FontWeight.w500,
              height: 1.5,
            ),
            const SizedBox(height: 40),
            for (final o in gachaOdds(d))
              Container(
                key: ValueKey('odds-${o.skin.id}'),
                height: 120,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    SkinCard(
                      skin: o.skin,
                      owned: {...?d.skinPieces[o.skin.id]},
                      size: 84,
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      child: Text(o.skin.name(lang), style: textStyle(42)),
                    ),
                    if (d.isUnlocked(o.skin))
                      Text(
                        app.t('oddsExcluded'),
                        style: textStyle(
                          34,
                          color: C.inkSoft,
                          weight: FontWeight.w600,
                        ),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            pct(o.chance),
                            style: textStyle(44, color: C.accentDark),
                          ),
                          Text(
                            app.t('oddsPiece', {'p': pct(o.perPiece)}),
                            style: textStyle(
                              28,
                              color: C.inkSoft,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const Spacer(),
            PillButton(
              app.t('close'),
              key: const ValueKey('btn-odds-close'),
              w: 500,
              onClick: app.sfx.click,
              onTap: () => setState(() => _odds = false),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가챠 머신 한 장면. t = 연출 진행(0~1). active 가 아니면 캡슐이 나오지 않은 쉬는 모습
class GachaMachinePainter extends CustomPainter {
  GachaMachinePainter({
    required this.t,
    required this.capsule,
    required this.active,
  });
  final double t;
  final Color capsule;
  final bool active;

  static final List<(Offset, Color)> _balls = () {
    final rng = math.Random(7);
    final cols = [for (final s in skins) Color(0xFF000000 | s.color)];
    return [
      for (var i = 0; i < 16; i++)
        (
          Offset(
            400 + (rng.nextDouble() - 0.5) * 380,
            400 + rng.nextDouble() * 150 - (i % 3) * 40,
          ),
          cols[i % cols.length],
        ),
    ];
  }();

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  void _capsule(
    Canvas canvas,
    Offset c,
    double r,
    Color col, {
    double open = 0,
    double rot = 0,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    // 아래 반쪽 (흰색)
    canvas.drawArc(rect, 0, math.pi, true, Paint()..color = Colors.white);
    // 위 반쪽 (색) — 열리면 위로 들리며 기운다
    canvas.save();
    canvas.translate(0, -open * r * 1.4);
    canvas.rotate(-open * 0.6);
    canvas.drawArc(rect, math.pi, math.pi, true, Paint()..color = col);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      true,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );
    canvas.restore();
    canvas.drawArc(
      rect,
      0,
      math.pi,
      true,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final crank = active ? _seg(t, 0, GachaTimeline.crankEnd) : 0.0;
    final shake = active && crank > 0 && crank < 1
        ? math.sin(crank * math.pi * 10) * 10
        : 0.0;

    // 받침과 몸통
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(150, 640, 500, 420),
      const Radius.circular(60),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 14)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawRRect(body, Paint()..color = C.warn);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(120, 610, 560, 60),
        const Radius.circular(30),
      ),
      Paint()..color = const Color(0xFFC13B3F),
    );
    // 유리 돔과 캡슐들
    const dome = Offset(400, 360);
    canvas.drawCircle(dome, 290, Paint()..color = const Color(0x33FFFFFF));
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: dome, radius: 284)),
    );
    for (final (i, (p, col)) in _balls.indexed) {
      final dx = shake * (i.isEven ? 1 : -1), dy = shake.abs() * ((i % 3) - 1);
      _capsule(
        canvas,
        p + Offset(dx, dy),
        62,
        col,
        rot: i * 0.7 + shake * 0.02,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      dome,
      290,
      Paint()
        ..color = const Color(0xFFBFD9E6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    canvas.drawArc(
      Rect.fromCircle(center: dome, radius: 240),
      math.pi * 1.1,
      0.7,
      false,
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );
    // 손잡이
    const knob = Offset(400, 800);
    canvas.drawCircle(knob, 78, Paint()..color = C.panel);
    canvas.save();
    canvas.translate(knob.dx, knob.dy);
    canvas.rotate(crank * math.pi * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 130, height: 34),
        const Radius.circular(17),
      ),
      Paint()..color = C.gold,
    );
    canvas.restore();
    // 나오는 구멍
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(310, 930, 180, 110),
        const Radius.circular(30),
      ),
      Paint()..color = const Color(0xFF7A2326),
    );
    if (!active) return;

    // 떨어지는 캡슐: 구멍 → 받침 앞 (튀어 오름)
    final drop = _seg(t, GachaTimeline.crankEnd, GachaTimeline.dropEnd);
    if (drop <= 0) return;
    // 구멍 안(985)에서 나와 머신 앞 받침(1125)으로 떨어진다
    final y = 985 + Curves.bounceOut.transform(drop) * 140;
    final wob = _seg(t, GachaTimeline.dropEnd, GachaTimeline.wobbleEnd);
    final rot = math.sin(wob * math.pi * 4) * 0.25 * (1 - wob);
    final open = Curves.easeOutBack.transform(
      _seg(t, GachaTimeline.wobbleEnd, GachaTimeline.openEnd),
    );
    // 열리면서 빛
    if (open > 0) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            C.gold.withValues(alpha: 0.75 * open),
            C.gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(400, y), radius: 360));
      canvas.drawCircle(Offset(400, y), 360, glow);
      final rays = Paint()
        ..color = Colors.white.withValues(alpha: 0.6 * open)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 12; k++) {
        final a = k * math.pi / 6 + t * 2;
        final r0 = 110 + 40 * open, r1 = 170 + 150 * open;
        canvas.drawLine(
          Offset(400 + math.cos(a) * r0, y + math.sin(a) * r0),
          Offset(400 + math.cos(a) * r1, y + math.sin(a) * r1),
          rays,
        );
      }
    }
    if (open <= 0) {
      // 구멍 밖으로 나오기 전에는 머신 몸통에 가려 보인다 (구멍과 몸통 아래만 그림)
      canvas.save();
      canvas.clipPath(
        Path()
          ..addRect(const Rect.fromLTWH(310, 930, 180, 110))
          ..addRect(const Rect.fromLTWH(0, 1060, 800, 140)),
      );
      _capsule(canvas, Offset(400, y), 70, capsule, rot: rot);
      canvas.restore();
      return;
    }
    _capsule(canvas, Offset(400, y), 70, capsule, open: open, rot: rot);
  }

  @override
  bool shouldRepaint(covariant GachaMachinePainter old) =>
      old.t != t || old.capsule != capsule || old.active != active;
}
