// 연출 상태: 보드 칸의 "보이는" 상태(엔진보다 조금 늦게 바뀜), 개화·발아 애니메이션, 물줄기, 비행, 꽃잎 등.
// TickEvent → 연출 타임라인. 각 틱의 연출은 다음 틱 전에 끝나도록 틱 간격 안에 맞춘다. 입력은 잠그지 않는다.
// 시간은 화면의 Ticker 가 update(dt) 로 밀어 준다 (테스트에서는 pump 로 결정적으로 진행).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../domain/engine.dart';
import 'game_layout.dart';

class WaterStream {
  WaterStream(this.start, this.from, this.to, this.color);
  final double start;
  final Offset from, to;
  final Color color;
}

class Fly {
  Fly(this.start, this.from, this.k0);
  final double start;
  final Offset from;
  final double k0;
}

class Petal {
  Petal(this.start, this.from, this.dx, this.dy, this.rot, this.color, this.k);
  final double start;
  final Offset from;
  final double dx, dy, rot;
  final Color color;
  final int k;
}

class _Pending {
  _Pending(this.at, this.run);
  final double at;
  final VoidCallback run;
}

class GameFx extends ChangeNotifier {
  GameFx(this.level, this.layout)
    : vis = Int8List(level.cells.length),
      animStart = Float64List(level.cells.length)
        ..fillRange(0, level.cells.length, -1e9),
      slotPulse = List.filled(level.slotCount, -1e9),
      flying = List.filled(level.slotCount, null);

  final Level level;
  final GameLayout layout;

  /// 지금 시각 (ms)
  double now = 0;

  /// 보이는 칸 상태 (엔진 상태를 연출 시차만큼 늦게 따라간다)
  final Int8List vis;

  /// 칸별 마지막 변화(개화·발아) 시작 시각
  final Float64List animStart;
  final List<double> slotPulse;
  final List<Fly?> flying;
  final List<WaterStream> streams = [];
  final List<Petal> petals = [];
  final List<_Pending> _pending = [];
  final List<_Pending> _timers = [];

  double bounceStart = -1e9;
  List<int> bounceLanes = const [];
  double shakeStart = -1e9;
  double celebrateStart = -1e9;
  bool dim = false;
  bool failGray = false;

  /// 누르고 있는 물방울의 색 (보드 미리보기), 누르고 있는 줄
  int? previewColor;
  int? pressedLane;

  /// 메시지 한 줄 (힌트 등)
  String msg = '';
  Color msgColor = const Color(0xFF7A736A);
  double msgStart = -1e9;

  bool fast = false;

  void update(double dt) {
    now += dt;
    if (_pending.isNotEmpty) {
      final due = _pending.where((p) => p.at <= now).toList();
      _pending.removeWhere((p) => p.at <= now);
      for (final p in due) {
        p.run();
      }
    }
    if (_timers.isNotEmpty) {
      final due = _timers.where((p) => p.at <= now).toList();
      _timers.removeWhere((p) => p.at <= now);
      for (final p in due) {
        p.run();
      }
    }
    streams.removeWhere((s) => now - s.start > 320);
    petals.removeWhere((p) => now - p.start > 1400);
    notifyListeners();
  }

  /// ms 뒤에 한 번 (연출 시계 기준)
  void after(double ms, VoidCallback run) =>
      _timers.add(_Pending(now + ms, run));

  /// 진행 중인 칸 연출은 버리고 상태를 그대로 그린다 (재시작)
  void syncBoard(State s) {
    _pending.clear();
    for (var i = 0; i < vis.length; i++) {
      vis[i] = s.cell[i];
      animStart[i] = -1e9;
    }
    streams.clear();
    petals.clear();
    for (var i = 0; i < flying.length; i++) {
      flying[i] = null;
    }
    dim = false;
    failGray = false;
    celebrateStart = -1e9;
    notifyListeners();
  }

  void _setCell(int i, int st) {
    vis[i] = st;
    animStart[i] = now;
  }

  void onTick(TickEvent ev, int tickMs) {
    final budget = tickMs * 0.8;
    for (final b in ev.blooms) {
      final stagger = fast
          ? 0.0
          : math.min(40.0, budget / math.max(1, b.cells.length));
      final from = layout.slots[b.slot];
      final color = Color(
        0xFF000000 | int.parse(level.palette[b.color].substring(1), radix: 16),
      );
      for (var k = 0; k < b.cells.length; k++) {
        final i = b.cells[k];
        _pending.add(
          _Pending(now + k * stagger + 70, () => _setCell(i, bloom)),
        );
        if (!fast) {
          streams.add(
            WaterStream(now + k * stagger, from, layout.cellCenter(i), color),
          );
        }
      }
      slotPulse[b.slot] = now;
    }
    // 전염: 개화와 같은 프레임 (조금 늦게 돋아 보이도록)
    final sStagger = fast
        ? 0.0
        : math.min(24.0, budget / math.max(1, ev.sprouted.length));
    for (var k = 0; k < ev.sprouted.length; k++) {
      final i = ev.sprouted[k];
      _pending.add(
        _Pending(now + 80 + k * sStagger + 60, () => _setCell(i, sprout)),
      );
    }
  }

  /// 줄 맨 앞 → 슬롯 곡선 비행 (엔진 상태는 이미 슬롯에 있음)
  void fly(int slot, int lane) {
    flying[slot] = Fly(
      now,
      layout.laneFront(lane),
      layout.frontR / (layout.slotR * 0.8),
    );
  }

  void bounceFront() {
    bounceLanes = [for (var i = 0; i < layout.laneXs.length; i++) i];
    bounceStart = now;
  }

  void bounceLane(int lane) {
    bounceLanes = [lane];
    bounceStart = now;
  }

  void shake() => shakeStart = now;

  void failFx() {
    shake();
    failGray = true;
    dim = true;
  }

  void celebrate(math.Random rng) {
    celebrateStart = now;
    if (fast) return;
    final colors = [
      for (final h in level.palette)
        Color(0xFF000000 | int.parse(h.substring(1), radix: 16)),
    ];
    final o = layout.boardOuter;
    for (var k = 0; k < 40; k++) {
      petals.add(
        Petal(
          now + k * 18,
          Offset(
            o.center.dx + (rng.nextDouble() - 0.5) * layout.boardW,
            o.center.dy - layout.boardH / 2 - 40,
          ),
          (rng.nextDouble() - 0.5) * 400,
          500 + rng.nextDouble() * 500,
          (rng.nextDouble() - 0.5) * 8,
          colors[k % colors.length],
          k,
        ),
      );
    }
  }

  void flash(String text, Color color) {
    msg = text;
    msgColor = color;
    msgStart = now;
  }

  // ---------- 그리기용 계산 ----------

  /// 칸의 크기 배율 (개화 0.6→1.15→1, 클리어 반짝)
  double cellScale(int i) {
    var s = 1.0;
    if (vis[i] == bloom) {
      final t = (now - animStart[i]) / 260;
      if (t >= 0 && t < 1) {
        s = t < 0.5 ? 0.6 + 0.55 * (t / 0.5) : 1.15 - 0.15 * ((t - 0.5) / 0.5);
      }
    }
    final x = i % level.width, y = i ~/ level.width;
    final c = (now - celebrateStart - (x + y) * 35) / 520;
    if (c >= 0 && c < 1) s *= 1 + 0.18 * math.sin(c * math.pi);
    return s;
  }

  /// 싹 글자의 세로 배율 (돋는 연출)
  double sproutScaleY(int i) {
    if (vis[i] != sprout) return 1;
    final t = (now - animStart[i]) / 260;
    if (t < 0 || t >= 1) return 1;
    return 0.3 + 0.7 * _outBack(t);
  }

  double get glowAlpha => 0.35 + 0.35 * (0.5 + 0.5 * math.sin(now / 180));

  /// 슬롯 물방울 위치·배율 (비행 중이면 곡선 위)
  (Offset, double) slotDrop(int slot) {
    final to = layout.slots[slot];
    final f = flying[slot];
    var scale = 1.0;
    var pos = to;
    if (f != null) {
      final k0 = (now - f.start) / 380;
      if (k0 >= 1) {
        flying[slot] = null;
      } else {
        final k = _inOutSine(math.max(0, k0));
        final mx = (f.from.dx + to.dx) / 2,
            my = math.min(f.from.dy, to.dy) - 160;
        final a = (1 - k) * (1 - k), b = 2 * (1 - k) * k, c = k * k;
        pos = Offset(
          a * f.from.dx + b * mx + c * to.dx,
          a * f.from.dy + b * my + c * to.dy,
        );
        scale = f.k0 + (1 - f.k0) * k;
      }
    }
    final p = (now - slotPulse[slot]) / 220;
    if (p >= 0 && p < 1) scale *= 1 + 0.12 * math.sin(p * math.pi);
    return (pos, scale);
  }

  double slotShakeX() {
    final k = (now - shakeStart) / 320;
    if (k < 0 || k >= 1) return 0;
    return math.sin(k * math.pi * 6) * 14 * (1 - k);
  }

  double laneBounce(int lane) {
    final k = (now - bounceStart) / 900;
    if (k < 0 || k >= 1 || !bounceLanes.contains(lane)) return 0;
    return (math.sin(k * math.pi * 2)).abs() * 22 * math.max(0, 1 - k);
  }

  double get msgAlpha {
    final k = (now - msgStart) / 2200;
    if (k < 0 || k >= 1) return 0;
    return k < 0.8 ? 1 : 1 - (k - 0.8) / 0.2;
  }
}

double _outBack(double t) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
}

double _inOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;
