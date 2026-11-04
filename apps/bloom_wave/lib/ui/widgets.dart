// 버튼·패널·토글 같은 공통 UI. 모든 크기는 논리 좌표(1080×2340) 기준이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// 화면 전체에 배경을 깔고, 논리 해상도 캔버스를 비율 유지로 가운데 맞춘다.
/// builder 는 노치·내비게이션 바를 논리 좌표로 환산한 여백을 받는다.
class LogicalCanvas extends StatelessWidget {
  const LogicalCanvas({super.key, required this.builder});
  final Widget Function(BuildContext context, double safeTop, double safeBottom)
  builder;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: C.bg,
      child: LayoutBuilder(
        builder: (context, box) {
          final s = math.min(box.maxWidth / kW, box.maxHeight / kH);
          // 화면이 논리 해상도보다 길면 남는 여백이 이미 안전 영역 역할을 한다
          final spareY = (box.maxHeight - kH * s) / 2;
          final top = math.max(0.0, mq.padding.top - spareY) / s;
          final bottom = math.max(0.0, mq.padding.bottom - spareY) / s;
          return Center(
            child: SizedBox(
              width: kW * s,
              height: kH * s,
              child: FittedBox(
                child: SizedBox(
                  width: kW,
                  height: kH,
                  child: MediaQuery(
                    // 글자 크기는 논리 좌표로 정한다 (기기 글꼴 배율은 화면 배율에 이미 반영)
                    data: mq.copyWith(textScaler: TextScaler.noScaling),
                    child: builder(context, top, bottom),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

TextStyle textStyle(
  double size, {
  Color color = C.ink,
  FontWeight weight = FontWeight.w700,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  letterSpacing: letterSpacing,
  decoration: TextDecoration.none,
);

/// 가운데 정렬 글자
class Label extends StatelessWidget {
  const Label(
    this.text, {
    super.key,
    this.size = 44,
    this.color = C.ink,
    this.weight = FontWeight.w700,
    this.height,
    this.letterSpacing,
  });
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final double? height;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: textStyle(
      size,
      color: color,
      weight: weight,
      height: height,
      letterSpacing: letterSpacing,
    ),
  );
}

/// 논리 좌표 (x, y) 를 가운데로 하는 자식
class At extends StatelessWidget {
  const At({
    super.key,
    required this.x,
    required this.y,
    required this.child,
    this.w = 1000,
    this.h = 400,
  });
  final double x, y, w, h;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: x - w / 2,
    top: y - h / 2,
    width: w,
    height: h,
    child: Center(child: child),
  );
}

class PillButton extends StatefulWidget {
  const PillButton(
    this.text, {
    super.key,
    required this.onTap,
    this.w = 420,
    this.h = 130,
    this.color = C.accent,
    this.textColor = Colors.white,
    this.size = 46,
    this.radius = 40,
    this.enabled = true,
    this.leading,
    this.onClick,
  });
  final String text;
  final VoidCallback onTap;
  final double w, h, size, radius;
  final Color color, textColor;
  final bool enabled;
  final Widget? leading;

  /// 누를 때 효과음 (화면이 넘겨준다)
  final VoidCallback? onClick;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Semantics(
      button: true,
      enabled: w.enabled,
      label: w.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: w.enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: w.enabled
            ? () {
                w.onClick?.call();
                w.onTap();
              }
            : null,
        child: Opacity(
          opacity: w.enabled ? 1 : 0.4,
          child: AnimatedScale(
            scale: _down ? 0.96 : 1,
            duration: const Duration(milliseconds: 80),
            child: SizedBox(
              width: w.w,
              height: w.h + 8,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 8,
                    height: w.h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x1F000000),
                        borderRadius: BorderRadius.circular(w.radius),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: w.h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: w.color,
                        borderRadius: BorderRadius.circular(w.radius),
                      ),
                      // 긴 문구(영어 등)는 버튼 안에 맞게 줄인다
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: math.min(30, w.radius),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (w.leading != null) ...[
                                w.leading!,
                                SizedBox(width: w.size * 0.3),
                              ],
                              Text(
                                w.text,
                                style: textStyle(w.size, color: w.textColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 동그란 아이콘 버튼 (뒤로, 일시정지)
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 120,
    this.tooltip,
    this.onClick,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final VoidCallback? onClick;

  @override
  Widget build(BuildContext context) => PillButton(
    '',
    onTap: onTap,
    onClick: onClick,
    w: size,
    h: size,
    radius: size / 2,
    color: C.panel,
    leading: Icon(icon, size: size * 0.5, color: C.ink, semanticLabel: tooltip),
  );
}

/// 화면 전체를 덮는 반투명 막 + 가운데 패널. 막을 탭해도 아래로 입력이 가지 않는다
class OverlayPanel extends StatefulWidget {
  const OverlayPanel({
    super.key,
    required this.w,
    required this.h,
    required this.child,
  });
  final double w, h;
  final Widget child;

  @override
  State<OverlayPanel> createState() => _OverlayPanelState();
}

class _OverlayPanelState extends State<OverlayPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) {
          final v = Curves.easeOutBack.transform(_a.value);
          return Opacity(
            opacity: _a.value,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 화면 비율이 달라 생기는 위아래(좌우) 여백까지 덮는다
                const Positioned(
                  left: -kW,
                  right: -kW,
                  top: -kH,
                  bottom: -kH,
                  child: ModalBarrier(color: C.dim, dismissible: false),
                ),
                Center(
                  child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: widget.w,
          height: widget.h,
          decoration: BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.circular(48),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), offset: Offset(0, 10)),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 140,
        height: 88,
        decoration: BoxDecoration(
          color: value ? C.accent : C.locked,
          borderRadius: BorderRadius.circular(44),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

/// 선택지 두 개짜리 세그먼트 버튼 (틱 속도, 언어)
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.w = 200,
  });
  final List<(String key, String text)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final double w;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, o) in options.indexed) ...[
        if (i > 0) const SizedBox(width: 12),
        GestureDetector(
          key: ValueKey('seg-${o.$1}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(o.$1),
          child: Container(
            width: w,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: o.$1 == value ? C.accent : C.bgDeep,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              o.$2,
              style: textStyle(38, color: o.$1 == value ? Colors.white : C.ink),
            ),
          ),
        ),
      ],
    ],
  );
}

/// 골드 동전 아이콘
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: C.gold,
      border: Border.all(color: C.goldDark, width: size * 0.09),
    ),
    alignment: Alignment.center,
    child: Container(
      width: size * 0.42,
      height: size * 0.42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE08A), width: size * 0.07),
      ),
    ),
  );
}

/// 골드 잔액 표시 (동전 + 숫자)
class GoldBadge extends StatelessWidget {
  const GoldBadge({super.key, required this.gold, this.size = 46});
  final int gold;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      size * 0.35,
      size * 0.25,
      size * 0.7,
      size * 0.25,
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
        CoinIcon(size: size * 1.3),
        SizedBox(width: size * 0.35),
        Text(
          '$gold',
          key: const ValueKey('gold-amount'),
          style: textStyle(size),
        ),
      ],
    ),
  );
}
