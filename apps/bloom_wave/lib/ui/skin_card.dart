// 스킨 카드: 꽃 그림 한 장을 2×2 퍼즐 조각으로 나눠 보여 준다. 없는 조각은 "?" 로 가린다.
// 해금되면 이음매 없이 한 장으로 그린다.
import 'package:flutter/material.dart';

import '../economy/skins.dart';
import 'skin_art.dart';
import 'theme.dart';

class SkinCardPainter extends CustomPainter {
  SkinCardPainter(
    this.skin, {
    required this.owned,
    this.highlight,
    this.highlightGlow = 0,
  });
  final SkinDef skin;

  /// 가진 조각 번호 (0 왼쪽 위, 1 오른쪽 위, 2 왼쪽 아래, 3 오른쪽 아래)
  final Set<int> owned;

  /// 방금 뽑은 조각 (테두리로 강조)
  final int? highlight;
  final double highlightGlow;

  bool get complete => skin.isDefault || owned.length >= skin.pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final color = Color(0xFF000000 | skin.color);
    final radius = Radius.circular(size.width * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()..color = color,
    );
    drawSkinGlyph(
      canvas,
      r.center,
      size.width * 1.05, // 조각마다 꽃의 일부가 보이도록 카드 가득
      mix(color, Colors.white, 0.72),
      skin.id,
    );
    if (complete) return;
    // 조각 (2×2)
    const cols = 2;
    final rows = (skin.pieces / cols).ceil();
    final w = size.width / cols, h = size.height / rows;
    final gap = size.width * 0.012;
    final cover = Paint()..color = C.locked;
    for (var i = 0; i < skin.pieces; i++) {
      final cell = Rect.fromLTWH((i % cols) * w, (i ~/ cols) * h, w, h);
      if (!owned.contains(i)) {
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(r, radius));
        canvas.drawRect(cell, cover);
        canvas.restore();
        final tp = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              fontSize: w * 0.45,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, cell.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // 이음매
    final seam = Paint()
      ..color = C.panel
      ..strokeWidth = gap * 2;
    for (var k = 1; k < cols; k++) {
      canvas.drawLine(Offset(k * w, 0), Offset(k * w, size.height), seam);
    }
    for (var k = 1; k < rows; k++) {
      canvas.drawLine(Offset(0, k * h), Offset(size.width, k * h), seam);
    }
    final hi = highlight;
    if (hi != null && highlightGlow > 0) {
      final cell = Rect.fromLTWH(
        (hi % cols) * w,
        (hi ~/ cols) * h,
        w,
        h,
      ).deflate(gap * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell, Radius.circular(size.width * 0.06)),
        Paint()
          ..color = C.gold.withValues(alpha: highlightGlow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.03,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SkinCardPainter old) =>
      old.skin != skin ||
      old.owned.length != owned.length ||
      old.highlight != highlight ||
      old.highlightGlow != highlightGlow;
}

class SkinCard extends StatelessWidget {
  const SkinCard({
    super.key,
    required this.skin,
    required this.owned,
    this.size = 260,
    this.highlight,
    this.highlightGlow = 0,
  });
  final SkinDef skin;
  final Set<int> owned;
  final double size;
  final int? highlight;
  final double highlightGlow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: SkinCardPainter(
        skin,
        owned: owned,
        highlight: highlight,
        highlightGlow: highlightGlow,
      ),
    ),
  );
}
