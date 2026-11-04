// 칸·물방울 모양. TS 버전의 128×128 흰색 텍스처를 같은 비율로 캔버스에 직접 그린다.
// 디자이너 아트가 오면 이 함수들만 이미지 그리기로 바꾸면 된다.
import 'dart:math' as math;
import 'dart:ui';

import '../domain/engine.dart';
import 'theme.dart';

const double _s = 128;

/// 128 상자 좌표를 (중심 c, 한 변 size) 로 옮기는 변환을 걸고 draw 를 부른다
void inBox(Canvas canvas, Offset c, double size, void Function() draw) {
  canvas.save();
  canvas.translate(c.dx - size / 2, c.dy - size / 2);
  canvas.scale(size / _s);
  draw();
  canvas.restore();
}

final Path _dropPath = () {
  final p = Path()
    ..moveTo(64, 6)
    ..cubicTo(64 + 18, 40, _s - 14, 62, _s - 14, 82)
    ..arcTo(
      Rect.fromCircle(center: const Offset(64, 82), radius: 50),
      0,
      math.pi,
      false,
    )
    ..cubicTo(14, 62, 64 - 18, 40, 64, 6)
    ..close();
  return p;
}();

/// 물방울: 몸통 중심이 (anchor 0.5, 0.58) 에 오도록 c 에 그린다. r 은 반지름(상자 한 변 = 2r)
void drawDrop(Canvas canvas, Offset c, double r, Color color) {
  final size = r * 2;
  final top = Offset(c.dx, c.dy - size * (0.58 - 0.5));
  inBox(
    canvas,
    top,
    size,
    () => canvas.drawPath(_dropPath, Paint()..color = color),
  );
}

void drawTile(Canvas canvas, Offset c, double size, Color color) {
  inBox(canvas, c, size, () {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, _s - 8, _s - 8),
        const Radius.circular(26),
      ),
      Paint()..color = color,
    );
  });
}

void drawGlow(Canvas canvas, Offset c, double size, Color color) {
  inBox(canvas, c, size, () {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, _s - 12, _s - 12),
        const Radius.circular(26),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
  });
}

void drawSeedGlyph(Canvas canvas, Offset c, double size, Color color) {
  final p = Paint()..color = color;
  inBox(canvas, c, size, () {
    canvas.drawCircle(const Offset(64, 70), 15, p);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(64, 60), width: 18, height: 26),
      p,
    );
  });
}

/// 싹: sy 로 세로 방향만 늘였다 줄였다 (돋는 연출)
void drawSproutGlyph(
  Canvas canvas,
  Offset c,
  double size,
  Color color, {
  double sy = 1,
}) {
  final p = Paint()..color = color;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, sy);
  inBox(canvas, Offset.zero, size, () {
    canvas.drawRect(const Rect.fromLTWH(59, 58, 10, 40), p);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(44, 50), width: 44, height: 24),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(84, 42), width: 44, height: 24),
      p,
    );
  });
  canvas.restore();
}

void drawBloomGlyph(Canvas canvas, Offset c, double size, Color color) {
  final p = Paint()..color = color;
  inBox(canvas, c, size, () {
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(
        Offset(64 + math.cos(a) * 26, 64 + math.sin(a) * 26),
        22,
        p,
      );
    }
    canvas.drawCircle(const Offset(64, 64), 16, p);
  });
}

/// 레벨 그림을 완성된(모두 개화한) 픽셀 아트로 그린다. silhouette 면 회색 실루엣
void drawArt(
  Canvas canvas,
  Offset c,
  Level level,
  double maxSize, {
  bool silhouette = false,
}) {
  final px = math
      .max(1, (maxSize / math.max(level.width, level.height)).floor())
      .toDouble();
  final ox = c.dx - level.width * px / 2, oy = c.dy - level.height * px / 2;
  final gap = px >= 8 ? 1.0 : 0.0;
  final paints = [
    for (final h in level.palette)
      Paint()..color = silhouette ? C.locked : hexColor(h),
  ];
  for (var i = 0; i < level.cells.length; i++) {
    final ci = level.cells[i];
    if (ci == empty) continue;
    final x = i % level.width, y = i ~/ level.width;
    canvas.drawRect(
      Rect.fromLTWH(
        ox + x * px + gap,
        oy + y * px + gap,
        px - gap * 2,
        px - gap * 2,
      ),
      paints[ci],
    );
  }
}
