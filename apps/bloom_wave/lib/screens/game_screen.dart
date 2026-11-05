// 게임 화면. 상단 바(x2 · 일시정지) / 보드 / 활성 슬롯 / 대기열 / 아이템 칸 / 맨 아래 배너 광고.
// 힌트는 없고(2026-11-04 삭제), 재시작은 일시정지 메뉴에 있다.
// 완성하면 Full Bloom 연출 + 골드 지급, 완성 화면에는 [홈] [다음 스테이지]만 있다 (2026-11-04).
// 실패하면 [다시 하기] [홈]. 일시정지 메뉴에서 설정을 연다 (홈에는 시작 버튼만 있으므로).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../domain/engine.dart' as e;
import '../economy/gold.dart';
import '../economy/items.dart';
import '../save/save_store.dart';
import '../game/colors.dart';
import '../game/game_controller.dart';
import '../game/game_fx.dart';
import '../game/game_layout.dart';
import '../game/game_painter.dart';
import '../ui/sun.dart';
import '../ui/cell_sprites.dart';
import '../ui/shapes.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'lives_panel.dart';
import 'settings_panel.dart';

const _tutorial = ['wave', 'lanes', 'realtime', 'waiting', 'slots'];

/// 시작 전에 경고창을 띄우는 난이도
const Map<e.Difficulty, (String, Color)> difficultyAlert = {
  e.Difficulty.hard: ('diffHard', Color(0xFFF08C00)),
  e.Difficulty.superHard: ('diffSuperHard', Color(0xFFE5484D)),
  e.Difficulty.megaHard: ('diffMegaHard', Color(0xFF8E4EC6)),
};

enum _Panel { none, intro, pause, settings, clear, fail, lives }

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

  /// 이번 도전에 햇빛을 냈나 (완성하면 돌려받는다)
  bool _paid = false;

  /// 햇빛 패널을 닫으면 돌아갈 패널 (실패 / 일시정지)
  _Panel _livesBack = _Panel.fail;

  /// 이번 완성으로 받은 골드
  int earned = 0;
  int? _pressPointer;

  /// 튜토리얼에서 꼭 한 번 써야 하는 아이템 (쓰기 전까지 대기열 입력을 막는다)
  ItemKind? forced;

  /// 즉시 개화: 슬롯을 고르는 중
  bool picking = false;

  /// x2 남은 시간을 몇 ms마다 저장하나
  double _x2SaveAcc = 0;

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
    // 햇빛 1개를 내고 시작 (홈에서 0개면 들어오지 않는다. 혹시 없으면 내지 않고 그냥 한다)
    _paid = app.save.spendLife(app.clock());
    // 칸 애니메이션 시트 (보통 앱 시작 때 이미 불러 둠). 준비 전에는 코드 그리기로 그린다
    CellSprites.instance.ensure(app.save.data.skin.id);
    controller = GameController(
      level,
      tickMs: app.save.data.x2On ? x2TickMs : baseTickMs,
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
          // 줄의 마지막 물방울을 넣었으면 그 줄 영역을 없애고 남은 줄을 가운데로 (다시 배치)
          if (controller.state.lanes[lane].isEmpty) setState(() {});
        },
        onIdle: () {
          app.sfx.resetPitch();
          fx.bounceFront();
        },
        onReset: () {
          _cancelPress();
          picking = false;
          fx.selectable = const [];
          fx.syncBoard(controller.state);
          setState(() {
            _ended = false;
            if (_panel != _Panel.intro) _panel = _Panel.none;
          });
          if (forced == ItemKind.bloom) _prepBloomTutorial();
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
    if (n == app.firstMystery) _intro.add('tut:mystery');
    if (n == app.firstSet) _intro.add('tut:sets');
    // 아이템 해금 스테이지: 처음이면 3개 지급, 튜토리얼(1개 쓰기)을 아직 안 했으면 안내 → 꼭 한 번 쓰게 한다
    for (final def in itemDefs) {
      if (def.unlockStage != n) continue;
      app.save.unlockItem(def.kind);
      if (!app.save.data.itemTutorialDone.contains(def.kind)) {
        _intro.add('item:${def.kind.name}');
      }
    }
    _nextIntro();
  }

  GameLayout _layoutFor(double top, double bottom) {
    final l = _layout;
    final slots = controller.state.slots.length;
    final lanes = [
      for (var i = 0; i < controller.state.lanes.length; i++)
        if (controller.state.lanes[i].isNotEmpty) i,
    ];
    if (l != null &&
        l.top == top &&
        l.bottom == kH - bottom &&
        l.slots.length == slots &&
        listEquals(l.laneIds, lanes)) {
      return l;
    }
    final nl = GameLayout(
      level,
      safeTop: top,
      safeBottom: bottom,
      slotCount: slots,
      laneIds: lanes,
    );
    final old = _layout;
    _layout = nl;
    if (old != null && old.top == top && old.bottom == kH - bottom) {
      // 슬롯 수만 바뀜 (슬롯 추가 아이템·재시작): 연출은 그대로 두고 배치만 바꾼다
      fx.relayout(nl);
      return nl;
    }
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
    app.save.setX2(ms: app.save.data.x2Ms); // x2 남은 시간 저장
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
    _spendX2(dt);
    fx.update(dt);
  }

  // ---------- x2 ----------

  /// x2 를 켜 둔 동안 웨이브가 실제로 진행될 때만 남은 시간을 쓴다
  void _spendX2(double dt) {
    final d = app.save.data;
    if (!d.x2On ||
        _ended ||
        _panel != _Panel.none ||
        controller.paused ||
        !controller.active) {
      return;
    }
    d.x2Ms -= dt.round();
    _x2SaveAcc += dt;
    if (d.x2Ms <= 0) {
      d.x2Ms = 0;
      setX2(false);
      fx.flash(app.t('x2Empty'), C.warn);
    } else if (_x2SaveAcc >= 5000) {
      _x2SaveAcc = 0;
      app.save.setX2(ms: d.x2Ms);
    }
  }

  /// x2 켜기/끄기 (테스트도 부른다)
  void setX2(bool on) {
    final d = app.save.data;
    if (on && d.x2Ms <= 0) {
      app.sfx.deny();
      fx.flash(app.t('x2Empty'), C.warn);
      return;
    }
    app.save.setX2(ms: d.x2Ms, on: on);
    controller.tickMs = d.x2On ? x2TickMs : baseTickMs;
    if (mounted) setState(() {});
  }

  // ---------- 아이템 ----------

  bool _usable(ItemKind k) => switch (k) {
    ItemKind.slot => controller.canAddSlot,
    ItemKind.shuffle => controller.canShuffle,
    ItemKind.bloom => controller.stuck.isNotEmpty,
  };

  /// 튜토리얼 아이템을 지금 쓸 수 있으면 대기열은 잠근다 (그 아이템을 먼저 써야 함)
  bool get lanesLocked => picking || (forced != null && _usable(forced!));

  /// 아이템 칸을 눌렀을 때 (테스트도 부른다)
  Future<void> useItem(ItemKind k) async {
    if (_ended || _panel != _Panel.none) return;
    final d = app.save.data;
    if (!d.itemsUnlocked.contains(k)) {
      app.sfx.deny();
      fx.flash(app.t('itemLocked', {'n': itemDef(k).unlockStage}), C.inkSoft);
      return;
    }
    if (forced != null && forced != k) {
      app.sfx.deny();
      return;
    }
    if (picking) {
      // 다시 누르면 고르기 취소
      setState(() {
        picking = false;
        fx.selectable = const [];
      });
      return;
    }
    if (d.itemCount(k) <= 0) {
      app.sfx.deny();
      fx.flash(app.t('itemEmpty'), C.warn);
      return;
    }
    switch (k) {
      case ItemKind.slot:
        if (!controller.addSlotItem()) {
          app.sfx.deny();
          fx.flash(app.t('itemSlotMax'), C.warn);
          return;
        }
        _cancelPress();
        setState(() {}); // 새 배치 (슬롯 한 칸 더)
        await _consume(k);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) fx.slotPulse[controller.state.slots.length - 1] = fx.now;
        });
      case ItemKind.shuffle:
        if (!controller.shuffleItem(app.rng.nextInt)) {
          app.sfx.deny();
          fx.flash(app.t('itemShuffleFail'), C.warn);
          return;
        }
        fx.bounceFront();
        fx.flash(app.t('itemShuffleDone'), C.accentDark);
        await _consume(k);
      case ItemKind.bloom:
        final stuck = controller.stuck;
        if (stuck.isEmpty) {
          app.sfx.deny();
          fx.flash(app.t('itemBloomNone'), C.warn);
          return;
        }
        _cancelPress();
        setState(() {
          picking = true;
          fx.selectable = stuck;
        });
    }
  }

  /// 즉시 개화: 고른 슬롯 (테스트도 부른다)
  Future<void> pickSlot(int slot) async {
    if (!picking) return;
    final ev = controller.bloomItem(slot, app.rng.nextInt);
    if (ev == null) return;
    setState(() {
      picking = false;
      fx.selectable = const [];
    });
    fx.onTick(ev, controller.tickMs);
    app.sfx.bloom();
    app.haptics.light();
    await _consume(ItemKind.bloom);
  }

  Future<void> _consume(ItemKind k) async {
    app.sfx.coin();
    final tutorial = forced == k;
    await app.save.useItem(k, tutorial: tutorial);
    if (tutorial) forced = null;
    app.changed();
    if (mounted) setState(() {});
  }

  /// 튜토리얼 안내창을 닫은 뒤: 그 아이템을 한 번 쓰게 한다
  void _beginForced(ItemKind k) {
    forced = k;
    if (k == ItemKind.bloom) _prepBloomTutorial();
  }

  /// 즉시 개화 튜토리얼: 묶인 물방울이 아직 없으면, 지금 퍼질 수 없는 맨 앞 물방울을 하나 슬롯에 넣어 준다
  void _prepBloomTutorial() {
    if (controller.stuck.isNotEmpty) return;
    final s = controller.state;
    for (var li = 0; li < s.lanes.length; li++) {
      final f = controller.front(li);
      if (f != null && s.sproutCount[f.color] == 0 && s.slots.contains(null)) {
        controller.tap(li);
        return;
      }
    }
    // 없으면 플레이하다 묶인 물방울이 생길 때 잠긴다 (lanesLocked)
  }

  // ---------- 입력 ----------

  /// lane 줄의 맨 앞을 넣는다 (테스트도 부른다)
  void tap(int lane) {
    if (_panel != _Panel.none) return;
    if (lanesLocked) {
      app.sfx.deny();
      return;
    }
    final r = controller.tap(lane);
    if (!r.ok) {
      if (r.fail == TapFail.full) {
        fx.shake();
        app.sfx.deny();
        final need = e.frontGroup(controller.state, lane)?.length ?? 1;
        if (need > 1) fx.flash(app.t('setNeedSlots', {'n': need}), C.warn);
      }
      if (r.fail == TapFail.wait) app.sfx.deny();
      if (r.fail == TapFail.set) {
        app.sfx.deny();
        fx.bounceLane(lane);
        fx.flash(app.t('setWaiting'), C.warn);
      }
    }
  }

  void _pressStart(int lane, int pointer) {
    if (_pressPointer != null) _cancelPress();
    if (_panel != _Panel.none ||
        lanesLocked ||
        controller.front(lane) == null) {
      return;
    }
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

  /// 다시 하기 = 새 도전: 햇빛 1개를 낸다. 없으면 햇빛 패널을 띄우고 false
  bool _restart() {
    if (!app.save.spendLife(app.clock())) {
      _cancelPress();
      controller.pause();
      setState(() {
        _livesBack = _panel == _Panel.pause ? _Panel.pause : _Panel.fail;
        _panel = _Panel.lives;
      });
      return false;
    }
    _paid = true;
    app.changed();
    controller.restart();
    return true;
  }

  // ---------- 패널 ----------

  void _resume() {
    final closing = _panel == _Panel.intro ? _introItem : '';
    setState(() => _panel = _Panel.none);
    if (closing.startsWith('item:')) {
      _beginForced(ItemKind.values.byName(closing.substring(5)));
    }
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
    app.save.setX2(ms: app.save.data.x2Ms);
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
      if (_paid) {
        _paid = false;
        app.save.refundLife(app.clock());
      }
      app.sfx.clear();
      app.haptics.success();
      _startFinale();
      final reward = goldReward.roll(app.rng);
      earned = await app.save.recordClear(
        level.id,
        widget.levelNo,
        app.total,
        gold: reward,
      );
      app.changed();
    } else {
      app.sfx.fail();
      app.haptics.fail();
      fx.failFx();
      fx.after(800, () {
        if (mounted && _ended) setState(() => _panel = _Panel.fail);
      });
    }
  }

  // ───── 완성 마무리 연출 (2026-11-05) ─────
  // 보드와 배너만 남기고 나머지는 사라진다 → 보드를 화면 가로에 맞춰 키운다(비율 유지) →
  // 위에서 아래로 한 줄씩 다시 개화 → 만개 → FULL BLOOM 글자와 꽃잎 → 완성 패널. 탭하면 바로 패널로.

  /// 마무리 연출 중 (화면 위젯이 사라진다)
  bool finale = false;

  /// FULL BLOOM 글자를 보여 줌
  bool finaleTitle = false;

  void _startFinale() {
    final L = _layout;
    if (L == null) return;
    final from = L.boardOuter;
    final area = Rect.fromLTRB(30, L.top + 40, kW - 30, L.bottom - 40);
    final k = math.min(area.width / from.width, area.height / from.height);
    final target = Rect.fromCenter(
      center: area.center,
      width: from.width * k,
      height: from.height * k,
    );
    final sheet = CellSprites.instance.bloomOf(app.save.data.skin.id);
    fx.startFinale(target, bloomMs: sheet?.durationMs ?? 330);
    setState(() => finale = true);
    final titleAt = fx.finaleSweepAt + fx.finaleSweepMs + fx.finaleBloomMs;
    fx.after(titleAt, _showFinaleTitle);
    fx.after(titleAt + (fx.fast ? 700 : 1600), _showClearPanel);
  }

  void _showFinaleTitle() {
    if (!mounted || !_ended || finaleTitle) return;
    setState(() => finaleTitle = true);
    fx.celebrate(app.rng); // 꽃잎
    app.haptics.light();
  }

  void _showClearPanel() {
    if (!mounted || !_ended || _panel != _Panel.none) return;
    _showFinaleTitle();
    setState(() => _panel = _Panel.clear);
    if (earned > 0) app.sfx.coin();
  }

  /// 연출 중 탭: 바로 완성 패널로
  void _skipFinale() => _showClearPanel();

  /// 마무리 연출 때 사라지는 화면 위젯
  Widget _fadeOut(Widget child) => IgnorePointer(
    ignoring: finale,
    child: AnimatedOpacity(
      opacity: finale ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: child,
    ),
  );

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
      case _Panel.none:
        // 화면의 뒤로 버튼은 x2 로 바뀌었다: 시스템 뒤로 가기는 일시정지 메뉴(홈은 거기서)
        _showPause();
      case _Panel.fail:
        _toHome();
      case _Panel.lives:
        setState(() => _panel = _livesBack);
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
        body: _withBanner(
          app,
          LogicalCanvas(
            builder: (context, top, bottom) {
              final L = _layoutFor(top, bottom);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GamePainter(
                        controller,
                        fx,
                        L,
                        skinId: app.save.data.skin.id,
                      ),
                    ),
                  ),
                  // 상단 바: 왼쪽 x2(남은 시간), 오른쪽 일시정지
                  At(
                    x: 150,
                    y: top + 110,
                    w: 280,
                    h: 140,
                    child: _fadeOut(
                      _X2Button(
                        fx: fx,
                        data: app.save.data,
                        onTap: () {
                          app.sfx.click();
                          setX2(!app.save.data.x2On);
                        },
                      ),
                    ),
                  ),
                  At(
                    x: kW - 100,
                    y: top + 110,
                    w: 140,
                    h: 140,
                    child: _fadeOut(
                      CircleButton(
                        key: const ValueKey('btn-pause'),
                        icon: Icons.pause_rounded,
                        tooltip: app.t('pause'),
                        onClick: app.sfx.click,
                        onTap: _showPause,
                      ),
                    ),
                  ),
                  At(
                    x: kW / 2,
                    y: top + 88,
                    h: 90,
                    child: _fadeOut(
                      Label(app.t('stage', {'n': widget.levelNo}), size: 56),
                    ),
                  ),
                  At(
                    x: kW / 2,
                    y: top + 150,
                    h: 60,
                    child: _fadeOut(
                      Label(
                        level.meta?.name?.of(app.save.data.settings.lang) ??
                            level.id,
                        size: 36,
                        color: C.inkSoft,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // 대기열 맨 앞 물방울: 누르고 있으면 보드에 그 색 미리보기,
                  // 동그라미 안에서 떼면 넣기, 누른 채 동그라미 밖으로 벗어나면 취소
                  for (final li in finale ? const <int>[] : L.laneIds)
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
                  // 즉시 개화: 고를 수 있는 슬롯 (금빛 고리)
                  if (picking)
                    for (final i in fx.selectable)
                      Positioned(
                        key: ValueKey('slot-$i'),
                        left: L.slots[i].dx - L.slotR - 16,
                        top: L.slots[i].dy - L.slotR - 16,
                        width: (L.slotR + 16) * 2,
                        height: (L.slotR + 16) * 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => pickSlot(i),
                        ),
                      ),
                  // 튜토리얼·고르기 안내 (슬롯과 대기열 사이)
                  if (picking || lanesLocked)
                    At(
                      x: kW / 2,
                      y: L.msgY,
                      h: 70,
                      child: Label(
                        app.t(picking ? 'itemBloomPick' : 'itemUseNow'),
                        key: const ValueKey('item-prompt'),
                        size: 40,
                        color: C.accentDark,
                      ),
                    ),
                  // 하단 아이템 칸 (힌트·재시작 자리, 2026-11-04). 재시작은 일시정지 메뉴에
                  for (final (i, def) in itemDefs.indexed)
                    At(
                      x: kW / 2 + (i - 1) * 330,
                      y: L.buttonsY,
                      w: 320,
                      h: 170,
                      child: _fadeOut(
                        _ItemButton(
                          key: ValueKey('item-${def.kind.name}'),
                          def: def,
                          label: app.t('item_${def.kind.name}'),
                          lockedLabel: app.t('itemLocked', {
                            'n': def.unlockStage,
                          }),
                          unlocked: app.save.data.itemsUnlocked.contains(
                            def.kind,
                          ),
                          count: app.save.data.itemCount(def.kind),
                          highlight:
                              forced == def.kind ||
                              (picking && def.kind == ItemKind.bloom),
                          dim: forced != null && forced != def.kind,
                          onTap: () => useItem(def.kind),
                          fx: fx,
                        ),
                      ),
                    ),
                  // 완성 마무리 연출: 탭하면 건너뛰기, FULL BLOOM 글자
                  if (finale && _panel == _Panel.none)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('finale-skip'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _skipFinale,
                      ),
                    ),
                  if (finaleTitle)
                    At(
                      x: kW / 2,
                      y: fx.finaleTarget?.center.dy ?? kH / 2,
                      w: kW,
                      h: 360,
                      child: IgnorePointer(
                        child: _FinaleTitle(text: app.t('fullBloom')),
                      ),
                    ),
                  ..._panelWidgets(app),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 스테이지 플레이 화면 아래 배너 광고 (2026-11-04). 게임 캔버스와 겹치지 않게 아래 띠를 따로 잡고,
  /// 캔버스는 남은 높이에 맞춘다. 광고 제거 구매자는 배너 없이 전체 화면.
  Widget _withBanner(AppServices app, Widget canvas) {
    final banner = app.ads.banner(noAds: app.save.data.noAds);
    if (banner == null) return canvas;
    return ColoredBox(
      color: C.bg,
      child: Column(
        children: [
          Expanded(
            // 아래 시스템 여백은 배너가 맡는다 (캔버스가 한 번 더 비키지 않게)
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: canvas,
            ),
          ),
          // 버튼과 배너 사이를 조금 띄운다 (잘못 누르기 방지)
          const SizedBox(height: 8),
          SafeArea(top: false, child: banner),
        ],
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
            setState(() => _panel = _Panel.pause);
          },
        ),
      ),
    ],
    _Panel.clear => [_clearPanel(app)],
    _Panel.fail => [_failPanel(app)],
    _Panel.lives => [
      LivesPanel(
        app: app,
        empty: true,
        onClose: () => setState(() => _panel = _livesBack),
      ),
    ],
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
            // 배지 폭을 패널 안으로 묶는다 (두근거림 1.12배까지 넘치지 않게)
            _Pulse(
              child: Container(
                width: 640,
                height: 170,
                padding: const EdgeInsets.symmetric(horizontal: 50),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(85),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
    if (kind == 'item') {
      final k = ItemKind.values.byName(key);
      return OverlayPanel(
        key: ValueKey('overlay-item-$key'),
        w: 920,
        h: 1000,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 70, 40, 50),
          child: Column(
            children: [
              _ItemIcon(kind: k, size: 170, color: C.accentDark),
              const SizedBox(height: 30),
              Label(
                app.t('itemGot', {'name': app.t('item_$key')}),
                size: 48,
                color: C.accentDark,
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Center(
                  child: Label(
                    app.t('itemTut_$key'),
                    size: 40,
                    weight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ),
              PillButton(
                app.t('itemTutorialOk'),
                key: const ValueKey('btn-item-tutorial-ok'),
                w: 520,
                onClick: app.sfx.click,
                onTap: _resume,
              ),
            ],
          ),
        ),
      );
    }
    // 위쪽 그림: 기본은 물방울 하나, 색 안내(hold/similar)는 비슷한 두 색 물방울 견본
    final Widget icon;
    if (key == 'sets') {
      icon = Container(
        key: const ValueKey('tutorial-sets-icon'),
        width: 460,
        height: 190,
        decoration: BoxDecoration(
          color: C.bgDeep,
          borderRadius: BorderRadius.circular(40),
        ),
        child: CustomPaint(painter: _SetPainter()),
      );
    } else if (key == 'mystery') {
      icon = SizedBox(
        key: const ValueKey('tutorial-mystery-icon'),
        width: 160,
        height: 160,
        child: CustomPaint(painter: _MysteryPainter()),
      );
    } else if (key == 'hold' || key == 'similar') {
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
            if (_restart()) _resume();
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
    h: 820,
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
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SunIcon(size: 64),
            const SizedBox(width: 12),
            Label(
              app.t('livesLeft', {'n': app.save.data.lives.count}),
              key: const ValueKey('fail-lives'),
              size: 38,
              color: C.inkSoft,
            ),
          ],
        ),
        const SizedBox(height: 40),
        PillButton(
          app.t('retry'),
          key: const ValueKey('btn-retry'),
          w: 600,
          onClick: app.sfx.click,
          onTap: () => _restart(),
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

/// 왼쪽 위 x2 버튼: 켜짐/꺼짐과 남은 시간(분:초). 연출 시계(fx)가 갈 때마다 다시 그린다
class _X2Button extends StatelessWidget {
  const _X2Button({required this.fx, required this.data, required this.onTap});
  final GameFx fx;
  final SaveData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: fx,
    builder: (context, _) {
      final on = data.x2On, empty = data.x2Ms <= 0;
      final sec = (data.x2Ms / 1000).ceil();
      final time = '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
      return GestureDetector(
        key: const ValueKey('btn-x2'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 250,
          height: 120,
          decoration: BoxDecoration(
            color: empty ? C.bgDeep : (on ? C.gold : C.panel),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(color: on ? C.goldDark : C.slotEdge, width: 5),
            boxShadow: const [
              BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'x2',
                  style: textStyle(
                    54,
                    color: empty ? C.inkSoft : C.ink,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  time,
                  key: const ValueKey('x2-time'),
                  style: textStyle(
                    36,
                    color: empty ? C.inkSoft : C.ink,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({
    required this.kind,
    required this.size,
    required this.color,
  });
  final ItemKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(
    switch (kind) {
      ItemKind.slot => Icons.add_circle_outline_rounded,
      ItemKind.shuffle => Icons.shuffle_rounded,
      ItemKind.bloom => Icons.local_florist_rounded,
    },
    size: size,
    color: color,
  );
}

/// 하단 아이템 칸 하나: 아이콘·이름·남은 개수. 잠겨 있으면 자물쇠와 해금 스테이지
class _ItemButton extends StatelessWidget {
  const _ItemButton({
    super.key,
    required this.def,
    required this.label,
    required this.lockedLabel,
    required this.unlocked,
    required this.count,
    required this.highlight,
    required this.dim,
    required this.onTap,
    required this.fx,
  });
  final GameFx fx;
  final ItemDef def;
  final String label, lockedLabel;
  final bool unlocked, highlight, dim;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = unlocked && count > 0 && !dim;
    final card = Container(
      width: 300,
      height: 150,
      decoration: BoxDecoration(
        color: unlocked ? C.panel : C.bgDeep,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: highlight ? C.gold : C.slotEdge,
          width: highlight ? 9 : 4,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                unlocked
                    ? _ItemIcon(
                        kind: def.kind,
                        size: 64,
                        color: active ? C.accentDark : C.locked,
                      )
                    : const Icon(Icons.lock_rounded, size: 56, color: C.locked),
                const SizedBox(height: 6),
                Text(
                  unlocked ? label : lockedLabel,
                  style: textStyle(
                    32,
                    color: active ? C.ink : C.inkSoft,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Positioned(
              right: 14,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: count > 0 ? C.accent : C.locked,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '$count',
                  key: ValueKey('item-count-${def.kind.name}'),
                  style: textStyle(
                    32,
                    color: Colors.white,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.45 : 1,
        // 튜토리얼·고르기 중인 아이템은 계속 두근거린다 (연출 시계 fx 를 따라)
        child: highlight
            ? AnimatedBuilder(
                animation: fx,
                builder: (context, child) => Transform.scale(
                  scale: 1 + 0.05 * math.sin(fx.now / 160),
                  child: child,
                ),
                child: card,
              )
            : card,
      ),
    );
  }
}

/// 안내창 그림: 띠로 이어진 set 물방울 두 개
class _SetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final a = Offset(size.width * 0.3, y), b = Offset(size.width * 0.7, y);
    final col = setColor(0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(a.dx, y - 22, b.dx, y + 22),
        const Radius.circular(22),
      ),
      Paint()..color = col.withValues(alpha: 0.45),
    );
    for (final (p, c) in [(a, const Color(0xFFE5484D)), (b, C.water)]) {
      drawDrop(canvas, p, 56, c);
      drawSetMark(canvas, p, 56, col);
    }
  }

  @override
  bool shouldRepaint(covariant _SetPainter old) => false;
}

/// 안내창 그림: 회색 "?" 물방울
class _MysteryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    drawDrop(canvas, c, 64, mysteryColor);
    final tp = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 56,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -tp.height / 2 + 8));
  }

  @override
  bool shouldRepaint(covariant _MysteryPainter old) => false;
}

/// 완성 마무리 연출의 FULL BLOOM 글자: 튀어나오며 커졌다 자리 잡는다
class _FinaleTitle extends StatefulWidget {
  const _FinaleTitle({required this.text});
  final String text;

  @override
  State<_FinaleTitle> createState() => _FinaleTitleState();
}

class _FinaleTitleState extends State<_FinaleTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (context, child) {
      final t = _a.value;
      final scale = Curves.elasticOut.transform(t) * 0.6 + 0.4;
      return Opacity(
        opacity: (t * 3).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      );
    },
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        widget.text,
        key: const ValueKey('full-bloom'),
        style: const TextStyle(
          fontSize: 150,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          color: Colors.white,
          shadows: [
            Shadow(color: C.accentDark, blurRadius: 0, offset: Offset(0, 8)),
            Shadow(color: Color(0xAA2A7E3B), blurRadius: 40),
          ],
        ),
      ),
    ),
  );
}
