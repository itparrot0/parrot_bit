// 햇빛(라이프) 아이콘과 배지. 아이콘은 코드로 그린 해 (디자인 교체 대상).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../economy/lives.dart';
import 'theme.dart';
import 'widgets.dart';

const sunColor = Color(0xFFFFB224);
const sunDark = Color(0xFFE08A00);

/// 해 모양 (빛살 8개 + 둥근 해). [on] 이 false 면 빈 칸(회색)
class SunIcon extends StatelessWidget {
  const SunIcon({super.key, this.size = 64, this.on = true});
  final double size;
  final bool on;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SunPainter(on)),
  );
}

class _SunPainter extends CustomPainter {
  _SunPainter(this.on);
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ray = Paint()
      ..color = on ? sunColor : C.locked
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.68, c + d * r * 0.92, ray);
    }
    canvas.drawCircle(
      c,
      r * 0.5,
      Paint()..color = on ? sunDark : mix(C.locked, C.ink, 0.15),
    );
    canvas.drawCircle(c, r * 0.42, Paint()..color = on ? sunColor : C.locked);
    if (on) {
      canvas.drawCircle(
        c + Offset(-r * 0.14, -r * 0.14),
        r * 0.12,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SunPainter old) => old.on != on;
}

/// 1초마다 다시 그린다 (남은 시간 표시용). 타이머는 화면을 떠나면 멈춘다
class EverySecond extends StatefulWidget {
  const EverySecond({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// 홈 왼쪽 위: 해 + 개수, 아래에 다음 회복까지 남은 시간(가득이면 "가득")
class LivesBadge extends StatelessWidget {
  const LivesBadge({
    super.key,
    required this.lives,
    required this.now,
    required this.fullText,
    required this.nextText,
    this.onTap,
    this.size = 46,
  });
  final Lives lives;
  final DateTime Function() now;
  final String fullText;

  /// '{t}' 자리에 남은 시간이 들어간다
  final String nextText;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: EverySecond(
      builder: (context) {
        final left = lives.untilNext(now());
        return Container(
          padding: EdgeInsets.fromLTRB(
            size * 0.3,
            size * 0.2,
            size * 0.6,
            size * 0.2,
          ),
          decoration: BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.circular(size),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SunIcon(size: size * 1.5),
              SizedBox(width: size * 0.25),
              Text(
                '${lives.count}',
                key: const ValueKey('lives-count'),
                style: textStyle(size),
              ),
              SizedBox(width: size * 0.35),
              Text(
                left == null
                    ? fullText
                    : nextText.replaceAll('{t}', formatLeft(left)),
                key: const ValueKey('lives-timer'),
                style: textStyle(size * 0.7, color: C.inkSoft),
              ),
            ],
          ),
        );
      },
    ),
  );
}
