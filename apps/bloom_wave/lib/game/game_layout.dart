// 게임 화면 배치 (2026-11-04 피드백 반영, 위에서 아래로, 논리 좌표):
//  상단 바 / 보드(가로 최대 1000) / 활성 슬롯 한 줄(보드와 겹치지 않음) / 대기열 세로 줄들 / 하단 버튼
import 'dart:math' as math;
import 'dart:ui';

import '../domain/engine.dart';
import '../ui/theme.dart';

class GameLayout {
  /// slotCount: 지금 활성 슬롯 수 (슬롯 추가 아이템으로 늘어난다, 최대 6)
  factory GameLayout(
    Level level, {
    double safeTop = 0,
    double safeBottom = 0,
    int? slotCount,
  }) {
    final top = safeTop;
    final bottom = kH - safeBottom;
    final boardTop = top + 210;
    final laneBottom = bottom - 230;
    final boardMax = math.max(
      500.0,
      math.min(1000.0, laneBottom - boardTop - 820),
    );
    // 보드: 테두리(여백)까지 포함해 가로 1040 · 세로 boardMax 안
    final cs = math
        .min(1040 / (level.width + 0.7), boardMax / (level.height + 0.7))
        .floorToDouble();
    final boardW = cs * level.width, boardH = cs * level.height;
    final pad = (cs * 0.35).roundToDouble();
    final outerH = boardH + pad * 2;
    final boardCenter = Offset(kW / 2, boardTop + outerH / 2);
    final boardBottom = boardTop + outerH;

    // 슬롯: 4칸이면 간격 210·반지름 78. 아이템으로 늘면 간격을 줄여 한 줄에 맞춘다 (슬롯 줄의 높이는 그대로)
    final n = slotCount ?? level.slotCount;
    final spacing = math.min(210.0, 1000 / n);
    final slotR = math.min(78.0, spacing * 0.44);
    final slotY = boardBottom + 40 + 78;
    final slots = [
      for (var i = 0; i < n; i++)
        Offset(kW / 2 + (i - (n - 1) / 2) * spacing, slotY),
    ];

    final lanesN = level.lanes.length;
    final laneW = math.min(240.0, (kW - 120) / lanesN - 24);
    final gap = math.min(270.0, (kW - 120) / lanesN);
    final laneTop = slotY + 78 + 210;
    final laneXs = [
      for (var i = 0; i < lanesN; i++) kW / 2 + (i - (lanesN - 1) / 2) * gap,
    ];
    final frontR = math.min(84.0, laneW * 0.36);
    return GameLayout._(
      top: top,
      bottom: bottom,
      cellSize: cs,
      boardW: boardW,
      boardH: boardH,
      pad: pad,
      boardCenter: boardCenter,
      boardBottom: boardBottom,
      slotR: slotR,
      slots: slots,
      laneW: laneW,
      laneXs: laneXs,
      laneTop: laneTop,
      laneBottom: laneBottom,
      frontR: frontR,
      nextR: frontR * 0.62,
      hitR: frontR + 24,
      msgY: slotY + 78 + 60,
      buttonsY: bottom - 110,
      width: level.width,
    );
  }

  GameLayout._({
    required this.top,
    required this.bottom,
    required this.cellSize,
    required this.boardW,
    required this.boardH,
    required this.pad,
    required this.boardCenter,
    required this.boardBottom,
    required this.slotR,
    required this.slots,
    required this.laneW,
    required this.laneXs,
    required this.laneTop,
    required this.laneBottom,
    required this.frontR,
    required this.nextR,
    required this.hitR,
    required this.msgY,
    required this.buttonsY,
    required this.width,
  });

  final double top, bottom;
  final double cellSize, boardW, boardH, pad;
  final Offset boardCenter;
  final double boardBottom;
  final double slotR;
  final List<Offset> slots;
  final double laneW;
  final List<double> laneXs;

  /// 줄 맨 앞 물방울 중심 y / 줄 영역 아래 끝
  final double laneTop, laneBottom;
  final double frontR, nextR, hitR;
  final double msgY, buttonsY;
  final int width;

  Rect get boardOuter => Rect.fromCenter(
    center: boardCenter,
    width: boardW + pad * 2,
    height: boardH + pad * 2,
  );

  Offset cellCenter(int i) {
    final x = i % width, y = i ~/ width;
    return Offset(
      boardCenter.dx - boardW / 2 + (x + 0.5) * cellSize,
      boardCenter.dy - boardH / 2 + (y + 0.5) * cellSize,
    );
  }

  Offset laneFront(int lane) => Offset(laneXs[lane], laneTop);

  /// 줄의 k 번째(0 = 맨 앞) 물방울 중심
  Offset laneDrop(int lane, int k) => Offset(
    laneXs[lane],
    k == 0 ? laneTop : laneTop + frontR + 40 + (k - 0.5) * nextR * 2.3,
  );
}
