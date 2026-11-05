// 칸 애니메이션의 임시 프레임 (디자이너 아트가 오기 전까지 쓰는 코드 그림).
// 한 프레임 = 128×128 상자 한 칸. 레이어 두 장:
//   tint  — 회색조. 게임이 칸 색을 곱해 입힌다 (흰색 = 칸 색 그대로, 검정 = 검정)
//   light — 색을 입히지 않고 그대로 위에 얹는다 (반투명 흰색 하이라이트 등)
// tool/anim_export_test.dart 가 이 그림을 assets/anim/*.png 로 내보낸다 (디자이너용 견본).
// 앱은 PNG 를 먼저 읽고, 파일이 없을 때만 이 코드로 만든다.
import 'dart:math' as math;
import 'dart:ui';

import 'shapes.dart';
import 'skin_art.dart';

const double cellPx = 128;

/// 시트 이름별 기본 프레임 수
const int sproutFrames = 8;
const int bloomFrames = 8;

const int fullFrames = 10;

int defaultFrames(String sheet) => sheet.startsWith('full_')
    ? fullFrames
    : sheet == 'seed'
    ? 1
    : sheet == 'sprout'
    ? sproutFrames
    : bloomFrames;

Color _grey(double v) {
  final c = (v.clamp(0.0, 1.0) * 255).round();
  return Color.fromARGB(255, c, c, c);
}

Color _white(double a) =>
    Color.fromARGB((a.clamp(0.0, 1.0) * 255).round(), 255, 255, 255);

double _outBack(double t) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
}

double _outCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

const Offset _mid = Offset(64, 64);

/// 시트 [sheet]('seed' | 'sprout' | 'bloom_<스킨>')의 [frame]번째 프레임을 (0,0)-(128,128) 에 그린다
void paintCellFrame(
  Canvas canvas,
  String sheet,
  int frame,
  int frames, {
  required bool light,
}) {
  final t = frames <= 1 ? 1.0 : frame / (frames - 1);
  if (sheet == 'seed') {
    if (light) return;
    drawTile(canvas, _mid, cellPx, _grey(0.32));
    drawSeedGlyph(canvas, _mid, cellPx * 0.9, _grey(0.62));
    return;
  }
  if (sheet == 'sprout') {
    // 씨앗이 작아지며 사라지고, 싹이 아래에서 위로 돋는다(살짝 튐). 바탕은 0.32 → 0.7
    if (!light) {
      drawTile(canvas, _mid, cellPx, _grey(0.32 + 0.38 * _outCubic(t)));
      final a = (1 - t * 2.2).clamp(0.0, 1.0);
      if (a > 0) {
        drawSeedGlyph(
          canvas,
          _mid,
          cellPx * 0.9 * (1 - 0.4 * t),
          _grey(0.62).withValues(alpha: a),
        );
      }
    } else {
      final sy = math.max(0.02, _outBack(t));
      drawSproutGlyph(
        canvas,
        _mid + const Offset(0, 30) * (1 - sy).clamp(0.0, 1.0),
        cellPx * 0.95,
        _white(0.75 * math.min(1, t * 3)),
        sy: sy,
      );
    }
    return;
  }
  if (sheet.startsWith('full_')) {
    // full_<스킨> (완성 마무리 연출): 핀 꽃에서 만개로 — 꽃이 1.18배로 커지며 밝아지고,
    // 둘레에 작은 꽃잎 고리가 돋고, 마지막에 반짝임 네 점이 남는다. 바탕은 그대로(1.0)
    final skin = sheet.substring(5);
    if (!light) {
      drawTile(canvas, _mid, cellPx, _grey(1));
      return;
    }
    final grow = _outBack(t);
    canvas.save();
    canvas.translate(64, 64);
    canvas.scale(1 + 0.18 * grow);
    drawSkinGlyph(
      canvas,
      Offset.zero,
      cellPx * 0.85,
      _white(0.5 + 0.2 * t),
      skin,
    );
    canvas.restore();
    if (t > 0.3) {
      final u = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 + math.pi / 8;
        canvas.drawCircle(
          _mid + Offset(math.cos(a), math.sin(a)) * (44 + 6 * (1 - u)),
          7 * u,
          Paint()..color = _white(0.65),
        );
      }
    }
    if (t > 0.6) {
      final u = (t - 0.6) / 0.4;
      for (final o in const [
        Offset(-40, -40),
        Offset(40, -40),
        Offset(40, 40),
        Offset(-40, 40),
      ]) {
        canvas.drawCircle(_mid + o, 3 + 3 * u, Paint()..color = _white(0.9));
      }
    }
    return;
  }
  // bloom_<스킨>: 싹이 사라지며 꽃이 돌면서 커졌다(1.15) 제자리로. 빛 고리가 퍼진다. 바탕은 0.7 → 1
  final skin = sheet.startsWith('bloom_') ? sheet.substring(6) : 'basic';
  if (!light) {
    drawTile(canvas, _mid, cellPx, _grey(0.7 + 0.3 * _outCubic(t)));
    return;
  }
  final fade = (1 - t * 2.5).clamp(0.0, 1.0);
  if (fade > 0) {
    drawSproutGlyph(canvas, _mid, cellPx * 0.95, _white(0.75 * fade));
  }
  final s = t < 0.6
      ? 1.15 * _outCubic(t / 0.6)
      : 1.15 - 0.15 * ((t - 0.6) / 0.4);
  if (s > 0.01) {
    canvas.save();
    canvas.translate(64, 64);
    canvas.rotate((1 - t) * 0.7);
    canvas.scale(s);
    drawSkinGlyph(canvas, Offset.zero, cellPx * 0.85, _white(0.5), skin);
    canvas.restore();
  }
  if (t > 0.25 && t < 1) {
    final u = (t - 0.25) / 0.75;
    canvas.drawCircle(
      _mid,
      30 + 30 * u,
      Paint()
        ..color = _white(0.55 * (1 - u))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * (1 - u) + 1,
    );
  }
}

/// 가로로 프레임을 이어 붙인 시트 한 장 (128·frames × 128)
Future<Image> renderSheet(String sheet, int frames, {required bool light}) {
  final rec = PictureRecorder();
  final canvas = Canvas(rec);
  for (var f = 0; f < frames; f++) {
    canvas.save();
    canvas.translate(f * cellPx, 0);
    canvas.clipRect(const Rect.fromLTWH(0, 0, cellPx, cellPx));
    paintCellFrame(canvas, sheet, f, frames, light: light);
    canvas.restore();
  }
  return rec.endRecording().toImage((cellPx * frames).round(), cellPx.round());
}
