// 골드: 스테이지를 완성하면 무작위 양을 지급한다 (2026-11-04 추가).
// 지급량은 플레이해 보고 조절한다 — 이 파일의 [goldReward] 범위만 바꾸면 된다.
import 'dart:math' as math;

class GoldReward {
  const GoldReward({required this.min, required this.max})
    : assert(min >= 0 && max >= min);

  /// 한 번에 지급하는 최소·최대 골드 (양 끝 포함)
  final int min;
  final int max;

  int roll(math.Random rng) => min + rng.nextInt(max - min + 1);
}

/// 스테이지 완성 보상 범위. 조절 지점은 여기 한 곳이다.
const goldReward = GoldReward(min: 10, max: 30);
