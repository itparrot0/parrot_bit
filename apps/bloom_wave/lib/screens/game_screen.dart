// 게임 화면. 상단 바 / 보드 / 활성 슬롯 / 대기열 / 하단 버튼(힌트·재시작).
// 완성하면 Full Bloom 연출 + 골드 지급, 완성 화면에는 [홈] [다음 스테이지]만 있다 (2026-11-04).
// 실패하면 [다시 하기] [홈]. 일시정지 메뉴에서 설정을 연다 (홈에는 시작 버튼만 있으므로).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../domain/engine.dart' as e;
import '../economy/gold.dart';
import '../game/colors.dart';
import '../game/game_controller.dart';
import '../game/game_fx.dart';
import '../game/game_layout.dart';
import '../game/game_painter.dart';
import '../ui/shapes.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_panel.dart';

const _tutorial = ['wave', 'lanes', 'realtime', 'waiting', 'slots'];

/// 시작 전에 경고창을 띄우는 난이도
const Map<e.Difficulty, (String, Color)> difficultyAlert = {
  e.Difficulty.hard: ('diffHard', Color(0xFFF08C00)),
  e.Difficulty.superHard: ('diffSuperHard', Color(0xFFE5484D)),
  e.Difficulty.megaHard: ('diffMegaHard', Color(0xFF8E4EC6)),
};

enum _Panel { none, intro, pause, settings, clear, fail }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelNo});
  final int levelNo;

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AppServices app;
  late final e.Level level;
  late final GameController controller;
  late GameFx fx;
  GameLayout? _layout;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  _Panel _panel = _Panel.none;
  String _introItem = '';
  final List<String> _intro = [];
  bool _ended = false;
  bool _leaving = false;

  /// 이번 완성으로 받은 골드
  int earned = 0;
  int? _pressPointer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onFrame)..start();
  }

  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    app = AppServices.of(context);
    level = app.levels[widget.levelNo - 1];
    final s = app.save.data.settings;
    controller = GameController(
      level,
      tickMs: tickMs[s.tickSpeed.name],
      manual: app.manualTick,
    );
    controller.listen(
      ControllerEvents(
        onTick: (ev) {
          fx.onTick(ev, controller.tickMs);
          if (ev.blooms.isNotEmpty) {
            app.sfx.bloom();
            app.haptics.light();
          }
        },
        onDeploy: (slot, _, lane) {
          app.sfx.tap();
          fx.fly(slot, lane);
        },
        onIdle: () {
          app.sfx.resetPitch();
          fx.bounceFront();
        },
        onReset: () {
          _cancelPress();
          fx.syncBoard(controller.state);
          setState(() {
            _ended = false;
            if (_panel != _Panel.intro) _panel = _Panel.none;
          });
        },
        onStatus: (st) {
          if (st != e.Status.playing) _onEnd(st);
        },
      ),
    );

    // 시작 전 안내: 어려운 스테이지 경고 → 튜토리얼 순서로 하나씩
    final diff = level.meta?.difficulty;
    if (diff != null && difficultyAlert.containsKey(diff)) {
      _intro.add('diff:${diff.name}');
    }
    final n = widget.levelNo;
    if (n - 1 < _tutorial.length &&
        app.strings.has('tutorial_${_tutorial[n - 1]}')) {
      _intro.add('tut:${_tutorial[n - 1]}');
    }
    // 길게 눌러 색 미리보기: 1스테이지에서 안내, 비슷한 색이 처음 나오는 스테이지에서 한 번 더
    if (n == 1) _intro.add('tut:hold');
    if (n > 1 && n == app.firstSimilar) _intro.add('tut:similar');
    _nextIntro();
  }

  GameLayout _layoutFor(double top, double bottom) {
    final l = _layout;
    if (l != null && l.top == top && l.bottom == kH - bottom) return l;
    final nl = GameLayout(level, safeTop: top, safeBottom: bottom);
    final old = _layout;
    _layout = nl;
    if (old == null) {
      fx = GameFx(level, nl)..fast = app.save.data.settings.fastFx;
      fx.syncBoard(controller.state);
    } else {
      // 화면 크기가 바뀌면 연출 상태는 버리고 다시 그린다
      final now = fx.now;
      fx.dispose();
      fx = GameFx(level, nl)
        ..fast = app.save.data.settings.fastFx
        ..now = now;
      fx.syncBoard(controller.state);
    }
    return nl;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    if (_layout != null) fx.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_ended && _panel == _Panel.none) _showPause();
    }
  }

  void _onFrame(Duration elapsed) {
    final dt = math.min(100.0, (elapsed - _last).inMicroseconds / 1000);
    _last = elapsed;
    if (_layout == null) return;
    // 게임 진행(틱)을 연출보다 먼저
    controller.update(dt);
    fx.update(dt);
  }

  // ---------- 입력 ----------

  /// lane 줄의 맨 앞을 넣는다 (테스트도 부른다)
  void tap(int lane) {
    if (_panel != _Panel.none) return;
    final r = controller.tap(lane);
    if (!r.ok) {
      if (r.fail == TapFail.full) {
        fx.shake();
        app.sfx.deny();
      }
      if (r.fail == TapFail.wait) app.sfx.deny();
    }
  }

  void _pressStart(int lane, int pointer) {
    if (_pressPointer != null) _cancelPress();
    if (_panel != _Panel.none || controller.front(lane) == null) return;
    _pressPointer = pointer;
    fx.pressedLane = lane;
    fx.previewColor = controller.front(lane)!.color;
  }

  void _cancelPress() {
    _pressPointer = null;
    if (_layout == null) return;
    fx.pressedLane = null;
    fx.previewColor = null;
  }

  void _hint() {
    if (_ended || _panel != _Panel.none) return;
    final h = controller.hint();
    final text = switch (h.action) {
      HintAction.tap => app.t('hintTap'),
      HintAction.wait => app.t('hintWait'),
      null =>
        h.result.solvable == false ? app.t('hintNone') : app.t('hintSlow'),
    };
    fx.flash(text, h.action == HintAction.tap ? C.accentDark : C.ink);
    if (h.action == HintAction.tap) fx.bounceLane(h.lane);
  }

  void _restart() {
    controller.restart();
  }

  // ---------- 패널 ----------

  void _resume() {
    setState(() => _panel = _Panel.none);
    if (_nextIntro()) return;
    controller.resume();
  }

  /// 남은 시작 안내를 하나 띄운다. 띄웠으면 true
  bool _nextIntro() {
    if (_intro.isEmpty) return false;
    controller.pause();
    _cancelPress();
    _introItem = _intro.removeAt(0);
    _panel = _Panel.intro;
    if (mounted) setState(() {});
    return true;
  }

  void _showPause() {
    if (_ended) return;
    controller.pause();
    _cancelPress();
    setState(() => _panel = _Panel.pause);
  }

  void _toHome() {
    controller.pause();
    // pop 은 PopScope 를 거치지 않는다 (maybePop 이면 뒤로 가기 처리와 맞물려 되돌아온다)
    Navigator.of(context).pop();
  }

  Future<void> _onEnd(e.Status status) async {
    if (_ended) return;
    _ended = true;
    _cancelPress();
    if (status == e.Status.cleared) {
      app.sfx.clear();
      app.haptics.success();
      fx.celebrate(app.rng);
      final reward = goldReward.roll(app.rng);
      earned = await app.save.recordClear(
        level.id,
        widget.levelNo,
        app.total,
        gold: reward,
      );
      app.changed();
      fx.after(fx.fast ? 700 : 1800, () {
        if (mounted && _ended) {
          setState(() => _panel = _Panel.clear);
          if (earned > 0) app.sfx.coin();
        }
      });
    } else {
      app.sfx.fail();
      app.haptics.fail();
      fx.failFx();
      fx.after(800, () {
        if (mounted && _ended) setState(() => _panel = _Panel.fail);
      });
    }
  }

  /// 완성 화면에서 나갈 때: 광고(광고 제거 구매 시 건너뜀)가 끝난 뒤 이동
  Future<void> _leaveClear(VoidCallback go) async {
    if (_leaving) return;
    _leaving = true;
    await app.ads.afterClear(noAds: app.save.data.noAds);
    _leaving = false;
    if (mounted) go();
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GameScreen(levelNo: widget.levelNo + 1),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _back() {
    switch (_panel) {
      case _Panel.pause:
        _resume();
      case _Panel.settings:
        setState(() => _panel = _Panel.pause);
      case _Panel.intro:
        _resume();
      case _Panel.clear:
        _leaveClear(_toHome);
      case _Panel.fail || _Panel.none:
        _toHome();
    }
  }

  // ---------- 화면 ----------

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: LogicalCanvas(
          builder: (context, top, bottom) {
            final L = _layoutFor(top, bottom);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: GamePainter(controller, fx, L)),
                ),
                // 상단 바
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
                    onTap: _toHome,
                  ),
                ),
                At(
                  x: kW - 100,
                  y: top + 110,
                  w: 140,
                  h: 140,
                  child: CircleButton(
                    key: const ValueKey('btn-pause'),
                    icon: Icons.pause_rounded,
                    tooltip: app.t('pause'),
                    onClick: app.sfx.click,
                    onTap: _showPause,
                  ),
                ),
                At(
                  x: kW / 2,
                  y: top + 88,
                  h: 90,
                  child: Label(app.t('stage', {'n': widget.levelNo}), size: 56),
                ),
                At(
                  x: kW / 2,
                  y: top + 150,
                  h: 60,
                  child: Label(
                    level.meta?.name?.of(app.save.data.settings.lang) ??
                        level.id,
                    size: 36,
                    color: C.inkSoft,
                    weight: FontWeight.w500,
                  ),
                ),
                // 대기열 맨 앞 물방울: 누르고 있으면 보드에 그 색 미리보기,
                // 동그라미 안에서 떼면 넣기, 누른 채 동그라미 밖으로 벗어나면 취소
                for (var li = 0; li < L.laneXs.length; li++)
                  Positioned(
                    key: ValueKey('lane-front-$li'),
                    left: L.laneXs[li] - L.hitR,
                    top: L.laneTop - L.hitR,
                    width: L.hitR * 2,
                    height: L.hitR * 2,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (ev) => _pressStart(li, ev.pointer),
                      onPointerMove: (ev) {
                        if (_pressPointer != ev.pointer) return;
                        final d = ev.localPosition - Offset(L.hitR, L.hitR);
                        if (d.distance > L.hitR) _cancelPress();
                      },
                      onPointerUp: (ev) {
                        if (_pressPointer != ev.pointer) return;
                        _cancelPress();
                        tap(li);
                      },
                      onPointerCancel: (_) => _cancelPress(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                // 하단 버튼 (되돌리기는 2026-11-04 2차 피드백으로 삭제)
                At(
                  x: kW / 2 - 230,
                  y: L.buttonsY,
                  w: 440,
                  h: 140,
                  child: PillButton(
                    app.t('hint'),
                    key: const ValueKey('btn-hint'),
                    w: 420,
                    h: 120,
                    color: C.panel,
                    textColor: C.ink,
                    size: 42,
                    onClick: app.sfx.click,
                    onTap: _hint,
                  ),
                ),
                At(
                  x: kW / 2 + 230,
                  y: L.buttonsY,
                  w: 440,
                  h: 140,
                  child: PillButton(
                    app.t('restart'),
                    key: const ValueKey('btn-restart'),
                    w: 420,
                    h: 120,
                    color: C.panel,
                    textColor: C.ink,
                    size: 42,
                    onClick: app.sfx.click,
                    onTap: _restart,
                  ),
                ),
                ..._panelWidgets(app),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _panelWidgets(AppServices app) => switch (_panel) {
    _Panel.none => const [],
    _Panel.intro => [_introPanel(app)],
    _Panel.pause => [_pausePanel(app)],
    _Panel.settings => [
      Positioned.fill(
        child: SettingsPanel(
          onClose: () {
            fx.fast = app.save.data.settings.fastFx;
            controller.tickMs = tickMs[app.save.data.settings.tickSpeed.name]!;
            setState(() => _panel = _Panel.pause);
          },
        ),
      ),
    ],
    _Panel.clear => [_clearPanel(app)],
    _Panel.fail => [_failPanel(app)],
  };

  Widget _introPanel(AppServices app) {
    final [kind, key] = _introItem.split(':');
    if (kind == 'diff') {
      final (textKey, color) =
          difficultyAlert[e.Difficulty.values.byName(key)]!;
      return OverlayPanel(
        key: ValueKey('overlay-difficulty-$key'),
        w: 860,
        h: 700,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Pulse(
              child: Container(
                height: 170,
                padding: const EdgeInsets.symmetric(horizontal: 70),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(85),
                ),
                alignment: Alignment.center,
                child: Text(
                  app.t(textKey),
                  style: textStyle(
                    92,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 70),
            Label(
              app.t('diffSub'),
              size: 40,
              color: C.inkSoft,
              weight: FontWeight.w500,
              height: 1.5,
            ),
            const SizedBox(height: 70),
            PillButton(
              app.t('diffStart'),
              key: const ValueKey('btn-difficulty-ok'),
              w: 520,
              color: color,
              onClick: app.sfx.click,
              onTap: _resume,
            ),
          ],
        ),
      );
    }
    // 위쪽 그림: 기본은 물방울 하나, 색 안내(hold/similar)는 비슷한 두 색 물방울 견본
    final Widget icon;
    if (key == 'hold' || key == 'similar') {
      final pair = key == 'similar' ? similarPair(level) : null;
      final cols = pair != null
          ? [hexColor(level.palette[pair.$1]), hexColor(level.palette[pair.$2])]
          : const [Color(0xFFE5484D), Color(0xFFA1252A)];
      icon = Container(
        key: ValueKey('tutorial-swatch-$key'),
        width: 460,
        height: 190,
        decoration: BoxDecoration(
          color: C.boardBg,
          borderRadius: BorderRadius.circular(40),
        ),
        child: CustomPaint(painter: _SwatchPainter(cols)),
      );
    } else {
      icon = SizedBox(
        width: 160,
        height: 160,
        child: CustomPaint(painter: _SwatchPainter(const [C.water])),
      );
    }
    return OverlayPanel(
      key: ValueKey('overlay-tutorial-$key'),
      w: 920,
      h: 1000,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 50),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 50),
            Expanded(
              child: Center(
                child: Label(
                  app.t('tutorial_$key'),
                  size: 40,
                  weight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
            ),
            PillButton(
              app.t('tapToStart'),
              key: const ValueKey('btn-tutorial-ok'),
              w: 520,
              onClick: app.sfx.click,
              onTap: _resume,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pausePanel(AppServices app) => OverlayPanel(
    key: const ValueKey('overlay-pause'),
    w: 760,
    h: 960,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Label(app.t('pause'), size: 64),
        const SizedBox(height: 60),
        PillButton(
          app.t('resume'),
          key: const ValueKey('btn-resume'),
          w: 560,
          onClick: app.sfx.click,
          onTap: _resume,
        ),
        const SizedBox(height: 30),
        PillButton(
          app.t('restart'),
          key: const ValueKey('btn-pause-restart'),
          w: 560,
          color: C.bg,
          textColor: C.ink,
          onClick: app.sfx.click,
          onTap: () {
            _restart();
            _resume();
          },
        ),
        const SizedBox(height: 30),
        PillButton(
          app.t('settings'),
          key: const ValueKey('btn-settings'),
          w: 560,
          color: C.bg,
          textColor: C.ink,
          onClick: app.sfx.click,
          onTap: () => setState(() => _panel = _Panel.settings),
        ),
        const SizedBox(height: 30),
        PillButton(
          app.t('home'),
          key: const ValueKey('btn-pause-home'),
          w: 560,
          color: C.bgDeep,
          textColor: C.ink,
          onClick: app.sfx.click,
          onTap: _toHome,
        ),
      ],
    ),
  );

  /// 완성 화면: Full Bloom 연출 + 받은 골드. 버튼은 [홈] [다음 스테이지] (마지막 스테이지는 [홈]만).
  /// 이 화면을 떠날 때 광고 1회 (실패 시에는 없음)
  Widget _clearPanel(AppServices app) {
    final last = widget.levelNo >= app.total;
    return OverlayPanel(
      key: const ValueKey('overlay-clear'),
      w: 900,
      h: 1400,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 60),
        child: Column(
          children: [
            Label(
              app.t('fullBloom'),
              key: const ValueKey('full-bloom'),
              size: 84,
              color: C.accentDark,
              weight: FontWeight.w900,
              letterSpacing: 4,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 460,
              height: 460,
              child: CustomPaint(painter: ArtPainter(level)),
            ),
            const SizedBox(height: 30),
            Label(app.t('cleared'), size: 60),
            Label(
              level.meta?.name?.of(app.save.data.settings.lang) ?? '',
              size: 40,
              color: C.inkSoft,
              weight: FontWeight.w600,
            ),
            const SizedBox(height: 40),
            _GoldEarned(earned: earned, total: app.save.data.gold),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PillButton(
                  app.t('home'),
                  key: const ValueKey('btn-clear-home'),
                  w: last ? 600 : 340,
                  color: last ? C.accent : C.bgDeep,
                  textColor: last ? Colors.white : C.ink,
                  onClick: app.sfx.click,
                  onTap: () => _leaveClear(_toHome),
                ),
                if (!last) ...[
                  const SizedBox(width: 30),
                  PillButton(
                    app.t('next'),
                    key: const ValueKey('btn-next'),
                    w: 440,
                    onClick: app.sfx.click,
                    onTap: () => _leaveClear(_goNext),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _failPanel(AppServices app) => OverlayPanel(
    key: const ValueKey('overlay-fail'),
    w: 860,
    h: 700,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Label(app.t('failed'), size: 64, color: C.warn),
        const SizedBox(height: 20),
        Label(
          app.t('failedSub'),
          size: 36,
          color: C.inkSoft,
          weight: FontWeight.w500,
        ),
        const SizedBox(height: 70),
        PillButton(
          app.t('retry'),
          key: const ValueKey('btn-retry'),
          w: 600,
          onClick: app.sfx.click,
          onTap: _restart,
        ),
        const SizedBox(height: 30),
        PillButton(
          app.t('home'),
          key: const ValueKey('btn-fail-home'),
          w: 600,
          color: C.bgDeep,
          textColor: C.ink,
          onClick: app.sfx.click,
          onTap: _toHome,
        ),
      ],
    ),
  );
}

/// 받은 골드: 0 에서 받은 양까지 올라가는 숫자 + 잔액
class _GoldEarned extends StatelessWidget {
  const _GoldEarned({required this.earned, required this.total});
  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: earned.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 84),
              const SizedBox(width: 24),
              Text(
                app.t('goldEarned', {'n': v.round()}),
                key: const ValueKey('gold-earned'),
                style: textStyle(
                  76,
                  color: C.goldDark,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${app.t('gold')} ${total - earned + v.round()}',
            key: const ValueKey('gold-total'),
            style: textStyle(36, color: C.inkSoft, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 경고 배지가 살짝 커졌다 돌아온다
class _Pulse extends StatelessWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 750),
    builder: (context, k, child) {
      final t = ((k * 750 - 150) / 600).clamp(0.0, 1.0);
      return Transform.scale(
        scale: 1 + 0.12 * math.sin(t * math.pi),
        child: child,
      );
    },
    child: child,
  );
}

/// 튜토리얼 그림: 물방울 견본 1~2개 (두 개면 사이에 ≈)
class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.colors);
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (colors.length == 1) {
      drawDrop(canvas, c, 60, colors.first);
      return;
    }
    drawDrop(canvas, c + const Offset(-110, 0), 60, colors[0]);
    drawDrop(canvas, c + const Offset(110, 0), 60, colors[1]);
    final tp = TextPainter(
      text: const TextSpan(
        text: '≈',
        style: TextStyle(
          fontSize: 72,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2 - 10));
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) => old.colors != colors;
}

/// 테스트에서 화면 상태를 들여다볼 때
extension GameScreenTesting on GameScreenState {
  GameFx get fxForTest => fx;
}
