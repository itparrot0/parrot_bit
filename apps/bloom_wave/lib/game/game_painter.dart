// 게임 화면의 보드·슬롯·대기열을 한 캔버스에 그린다 (논리 좌표). 입력은 화면 위젯이 받는다.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/engine.dart' as e;
import '../ui/cell_sprites.dart';
import '../ui/shapes.dart';
import '../ui/skin_art.dart';
import '../ui/theme.dart';
import 'game_controller.dart';
import 'game_fx.dart';
import 'game_layout.dart';

/// 색 미리보기에서 또렷하게 보일 칸인가: 누른 물방울 색의 "지금 발아한 칸"만 (2026-11-04).
/// 씨앗·이미 핀 칸·다른 색은 흐리게. 그 색 발아 칸이 없으면 전부 흐려져 "지금은 퍼질 곳이 없다"가 보인다
bool previewLit(int? preview, int colorIndex, int cellState) =>
    preview != null && preview == colorIndex && cellState == e.sprout;

/// "?" 물방울을 숨긴 채 그리나: 숨김 물방울이 맨 위(k = 0, 탭할 자리)가 아닐 때. 맨 위에 오면 색·크기가 드러난다
bool showsAsMystery(e.Drop d, int k) => d.hidden && k > 0;

const mysteryColor = Color(0xFF9CA3AF);

/// set 테두리 색 (set 번호 순으로 돌려 쓴다)
const setColors = [Color(0xFF8E4EC6), Color(0xFF12A594), Color(0xFFF76B15)];
Color setColor(int id) => setColors[id % setColors.length];

/// set 표시: 물방울 둘레 고리 + 오른쪽 위 고리 배지
void drawSetMark(Canvas canvas, Offset at, double r, Color color) {
  canvas.drawCircle(
    at,
    r * 1.12,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(4, r * 0.12),
  );
  final b = at + Offset(r * 0.82, -r * 0.82);
  final br = math.max(12.0, r * 0.32);
  canvas.drawCircle(b, br, Paint()..color = color);
  final link = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(2.5, br * 0.18);
  for (final dx in [-0.22, 0.22]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: b + Offset(br * dx, 0),
          width: br * 0.85,
          height: br * 0.5,
        ),
        Radius.circular(br * 0.25),
      ),
      link,
    );
  }
}

class GamePainter extends CustomPainter {
  GamePainter(
    this.c,
    this.fx,
    this.L, {
    this.skinId = 'basic',
    CellSprites? sprites,
  }) : sprites = sprites ?? CellSprites.instance,
       super(repaint: fx);
  final GameController c;
  final GameFx fx;
  final GameLayout L;

  /// 개화 칸의 꽃 모양 (장착한 스킨)
  final String skinId;

  /// 칸 애니메이션 시트. 아직 안 불러왔으면 코드 그리기로 그린다
  final CellSprites sprites;

  late final List<Color> _colors = [
    for (final h in c.level.palette) hexColor(h),
  ];
  final Map<String, TextPainter> _texts = {};

  TextPainter _text(String s, double size, Color color) {
    final key = '$s|$size|${color.toARGB32()}';
    return _texts.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  void _centerText(
    Canvas canvas,
    String s,
    Offset at,
    double size,
    Color color, [
    double alpha = 1,
  ]) {
    final tp = _text(s, size, color);
    if (alpha < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// 물방울 + 숫자 (흰색·밝은 물방울에서도 숫자가 보이게)
  /// "?" 물방울: 회색 물방울 + "?" (색·크기 모두 숨김)
  void _mysteryDrop(Canvas canvas, Offset at, double r) {
    drawDrop(canvas, at, r, mysteryColor);
    _centerText(canvas, '?', at + Offset(0, r * 0.12), r * 0.85, Colors.white);
  }

  void _drop(
    Canvas canvas,
    Offset at,
    double r,
    e.Drop d, {
    double alpha = 1,
    bool gray = false,
  }) {
    var col = _colors[d.color];
    if (gray) col = mix(col, const Color(0xFF8A8A8A), 0.7);
    if (alpha < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    drawDrop(canvas, at, r, col);
    _centerText(
      canvas,
      '${d.amount}',
      at + Offset(0, r * 0.12),
      r * 0.78,
      isLight(col) ? C.ink : Colors.white,
    );
    if (alpha < 1) canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 완성 마무리 연출: 보드를 화면 가로에 맞춰 키우고(비율 유지), 슬롯·대기열은 사라진다
    final z = fx.finaleZoom;
    final target = fx.finaleTarget;
    if (z > 0 && target != null) {
      final from = L.boardOuter;
      final s = 1 + (target.width / from.width - 1) * z;
      final c = Offset.lerp(from.center, target.center, z)!;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(s);
      canvas.translate(-from.center.dx, -from.center.dy);
      _board(canvas);
      canvas.restore();
    } else {
      _board(canvas);
    }
    final ui = 1 - z;
    if (ui > 0) {
      if (ui < 1) {
        canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, ui));
      }
      _streams(canvas);
      _slots(canvas);
      _selectRings(canvas);
      _lanes(canvas);
      if (ui < 1) canvas.restore();
    }
    _petals(canvas);
    final a = fx.msgAlpha;
    if (a > 0) {
      _centerText(canvas, fx.msg, Offset(kW / 2, L.msgY), 40, fx.msgColor, a);
    }
  }

  void _board(Canvas canvas) {
    if (fx.dim) {
      canvas.saveLayer(
        null,
        Paint()..color = const Color.fromRGBO(0, 0, 0, 0.55),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(L.boardOuter, const Radius.circular(36)),
      Paint()..color = C.boardBg,
    );
    if (sprites.ready(skinId)) {
      _cellsSprites(canvas);
    } else {
      _cellsCode(canvas);
    }
    if (fx.dim) canvas.restore();
  }

  /// 칸을 스프라이트 시트로: 상태별 시트마다 drawRawAtlas 한 번(+ light 레이어 한 번)
  void _cellsSprites(Canvas canvas) {
    final cs = L.cellSize;
    final preview = fx.previewColor;
    final sheets = [sprites.seed!, sprites.sprout!, sprites.bloomOf(skinId)!];
    final full = sprites.fullOf(skinId)!;
    // 0 씨앗 · 1 발아 · 2 개화 · 3 만개(완성 마무리 연출)
    final batches = [
      for (final sh in [...sheets, full]) _Atlas(sh),
    ];
    final lit = <int>[];
    for (var i = 0; i < c.level.cells.length; i++) {
      final ci = c.level.cells[i];
      if (ci == e.empty) continue;
      final st = fx.vis[i];
      if (st < e.seed || st > e.bloom) continue;
      final isLit = previewLit(preview, ci, st);
      if (isLit) lit.add(i);
      final alpha = preview != null && !isLit ? 0.22 : 1.0;
      final isFull = st == e.bloom && fx.fullStarted(i);
      final sh = isFull ? full : sheets[st];
      final frame = isFull
          ? sh.frameAt(fx.now - fx.fullStart[i])
          : st == e.seed
          ? 0
          : sh.frameAt(fx.now - fx.animStart[i]);
      batches[isFull ? 3 : st].add(
        L.cellCenter(i),
        cs * fx.celebrateScale(i) / sh.size,
        frame,
        _colors[ci],
        alpha,
      );
    }
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final b in batches) {
      b.draw(canvas, paint);
    }
    final glowA = fx.glowAlpha;
    for (final i in lit) {
      drawGlow(
        canvas,
        L.cellCenter(i),
        cs * 1.02 * fx.celebrateScale(i),
        Colors.white.withValues(alpha: glowA),
      );
    }
  }

  /// 시트가 없을 때(불러오는 중·테스트): 예전 코드 그리기
  void _cellsCode(Canvas canvas) {
    final cs = L.cellSize;
    final preview = fx.previewColor;
    final glowA = fx.glowAlpha;
    for (var i = 0; i < c.level.cells.length; i++) {
      final ci = c.level.cells[i];
      if (ci == e.empty) continue;
      final col = _colors[ci];
      final st = fx.vis[i];
      final center = L.cellCenter(i);
      // 미리보기: 그 색의 "지금 발아한 칸"만 또렷하게 (씨앗·개화 칸과 다른 색은 흐리게)
      final lit = previewLit(preview, ci, st);
      final dimmed = preview != null && !lit;
      if (dimmed) {
        canvas.saveLayer(
          null,
          Paint()..color = const Color.fromRGBO(0, 0, 0, 0.22),
        );
      }
      canvas.save();
      final s = fx.cellScale(i);
      canvas.translate(center.dx, center.dy);
      canvas.scale(s);
      if (st == e.seed) {
        drawTile(canvas, Offset.zero, cs, mix(C.boardBg, col, 0.32));
        drawSeedGlyph(canvas, Offset.zero, cs * 0.9, mix(C.boardBg, col, 0.62));
      } else if (st == e.sprout) {
        drawTile(canvas, Offset.zero, cs, mix(C.boardBg, col, 0.7));
        drawSproutGlyph(
          canvas,
          Offset.zero,
          cs * 0.95,
          mix(col, Colors.white, 0.75),
          sy: fx.sproutScaleY(i),
        );
      } else if (st == e.bloom) {
        drawTile(canvas, Offset.zero, cs, col);
        drawSkinGlyph(
          canvas,
          Offset.zero,
          cs * 0.85,
          mix(col, Colors.white, 0.5),
          skinId,
        );
      }
      if (lit) {
        drawGlow(
          canvas,
          Offset.zero,
          cs * 1.02,
          Colors.white.withValues(alpha: glowA),
        );
      }
      canvas.restore();
      if (dimmed) canvas.restore();
    }
  }

  void _streams(Canvas canvas) {
    for (final st in fx.streams) {
      final k = (fx.now - st.start) / 320;
      if (k < 0 || k >= 1) continue;
      final head = math.min(1.0, k * 1.6), tail = math.max(0.0, k * 1.6 - 0.6);
      Offset p(double u) => Offset(
        st.from.dx + (st.to.dx - st.from.dx) * u,
        st.from.dy + (st.to.dy - st.from.dy) * u - math.sin(u * math.pi) * 60,
      );
      final a = p(tail), b = p(head), m = p((tail + head) / 2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = st.color.withValues(alpha: 0.75 * (1 - tail))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _slots(Canvas canvas) {
    final occupied = c.state.occupied;
    final warn = occupied >= 3;
    final sx = fx.slotShakeX();
    for (var i = 0; i < L.slots.length; i++) {
      final p = L.slots[i] + Offset(sx, 0);
      canvas.drawCircle(
        p + const Offset(0, 6),
        L.slotR,
        Paint()..color = const Color(0x14000000),
      );
      canvas.drawCircle(
        p,
        L.slotR,
        Paint()..color = warn ? mix(C.slot, C.warn, 0.18) : C.slot,
      );
      canvas.drawCircle(
        p,
        L.slotR,
        Paint()
          ..color = warn ? C.warn : C.slotEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    }
    for (var i = 0; i < c.state.slots.length; i++) {
      final d = c.state.slots[i];
      if (d == null) continue;
      final (pos, scale) = fx.slotDrop(i);
      _drop(canvas, pos, L.slotR * 0.8 * scale, d, gray: fx.failGray);
    }
  }

  /// 즉시 개화 아이템으로 고를 수 있는 슬롯에 금빛 고리 (깜빡임)
  void _selectRings(Canvas canvas) {
    if (fx.selectable.isEmpty) return;
    final a = 0.55 + 0.45 * math.sin(fx.now / 140);
    for (final i in fx.selectable) {
      if (i >= L.slots.length) continue;
      canvas.drawCircle(
        L.slots[i],
        L.slotR + 12,
        Paint()
          ..color = C.gold.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
    }
  }

  void _lanes(Canvas canvas) {
    final visible = math.max(1, c.options.visible);
    // 준비된 set (묶인 물방울이 모두 맨 앞): 줄 맨 앞 사이를 띠로 잇는다
    final st = c.state;
    for (final li in L.laneIds) {
      final q = li < st.lanes.length ? st.lanes[li] : const <e.Drop>[];
      if (q.isEmpty || q.first.set == null) continue;
      final g = e.frontGroup(st, li);
      if (g == null || g.length < 2 || g.first != li) continue;
      final x0 = fx.laneX(g.first), x1 = fx.laneX(g.last);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x0,
            L.laneTop - L.frontR * 0.35,
            x1,
            L.laneTop + L.frontR * 0.35,
          ),
          Radius.circular(L.frontR * 0.35),
        ),
        Paint()..color = setColor(q.first.set!).withValues(alpha: 0.45),
      );
    }
    for (final li in L.laneIds) {
      final x = fx.laneX(li);
      final h = L.laneBottom - L.laneTop + L.frontR + 30;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - L.laneW / 2, L.laneTop - L.frontR - 30, L.laneW, h),
          const Radius.circular(40),
        ),
        Paint()..color = C.bgDeep.withValues(alpha: 0.6),
      );
      canvas.drawCircle(
        Offset(x, L.laneTop),
        L.frontR + 18,
        Paint()..color = C.panel,
      );
      final q = li < c.state.lanes.length
          ? c.state.lanes[li]
          : const <e.Drop>[];
      for (var k = 0; k < visible && k < q.length; k++) {
        var at = Offset(x, L.laneDrop(li, k).dy);
        var r = k == 0 ? L.frontR : L.nextR;
        if (k == 0) {
          at -= Offset(0, fx.laneBounce(li));
          if (fx.pressedLane == li) r *= 1.1;
        }
        final d = q[k];
        if (showsAsMystery(d, k)) {
          _mysteryDrop(canvas, at, r);
        } else {
          // set 맨 앞인데 짝이 아직 맨 앞이 아니면 흐리게 (지금은 못 누름)
          final waiting =
              k == 0 && d.set != null && e.frontGroup(st, li) == null;
          _drop(canvas, at, r, d, alpha: waiting ? 0.5 : (k == 0 ? 1 : 0.85));
        }
        if (d.set != null) drawSetMark(canvas, at, r, setColor(d.set!));
      }
    }
  }

  void _petals(Canvas canvas) {
    for (final p in fx.petals) {
      final v = (fx.now - p.start) / 1400;
      if (v < 0 || v >= 1) continue;
      final pos = Offset(
        p.from.dx + p.dx * v + math.sin(v * 9 + p.k) * 30,
        p.from.dy + p.dy * v,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rot * v);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 40, height: 22),
        Paint()..color = p.color.withValues(alpha: 1 - v),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter old) =>
      old.c != c || old.fx != fx || old.skinId != skinId;
}

/// 한 시트에 그릴 칸들을 모아 drawRawAtlas 로 한 번에. tint 는 칸 색을 곱하고(modulate), light 는 흰색(투명도만)
class _Atlas {
  _Atlas(this.sheet);
  final SpriteSheet sheet;
  final List<double> _xf = [], _rect = [];
  final List<int> _tint = [], _light = [];

  void add(Offset center, double scale, int frame, Color color, double alpha) {
    final half = sheet.size / 2 * scale;
    _xf.addAll([scale, 0, center.dx - half, center.dy - half]);
    final x = frame * sheet.size;
    _rect.addAll([x, 0, x + sheet.size, sheet.size]);
    final a = (alpha * 255).round();
    _tint.add(color.withAlpha(a).toARGB32());
    _light.add(Color.fromARGB(a, 255, 255, 255).toARGB32());
  }

  void draw(Canvas canvas, Paint paint) {
    if (_tint.isEmpty) return;
    final xf = Float32List.fromList(_xf), rect = Float32List.fromList(_rect);
    canvas.drawRawAtlas(
      sheet.tint,
      xf,
      rect,
      Int32List.fromList(_tint),
      BlendMode.modulate,
      null,
      paint,
    );
    final light = sheet.light;
    if (light != null) {
      canvas.drawRawAtlas(
        light,
        xf,
        rect,
        Int32List.fromList(_light),
        BlendMode.modulate,
        null,
        paint,
      );
    }
  }
}

/// 레벨 그림(완성 모습) 한 장
class ArtPainter extends CustomPainter {
  ArtPainter(this.level, {this.silhouette = false});
  final e.Level level;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) => drawArt(
    canvas,
    size.center(Offset.zero),
    level,
    math.min(size.width, size.height),
    silhouette: silhouette,
  );

  @override
  bool shouldRepaint(covariant ArtPainter old) =>
      old.level != level || old.silhouette != silhouette;
}
