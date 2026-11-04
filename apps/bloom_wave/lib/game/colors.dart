// 색 구분 도우미: 팔레트에서 서로 비슷한 색(명도·채도가 가까운 색) 찾기.
// 2026-11-04 2차 피드백: 비슷한 색이 많은 그림은 구분이 어려워, 처음 나오는 낮은 스테이지에서 도움말을 띄운다.
import 'dart:math' as math;

import '../domain/engine.dart';

/// CIE Lab 거리(ΔE76) 가 이보다 작으면 "비슷한 색"
const double similarDeltaE = 25;

int hexToInt(String hex) => int.parse(hex.replaceFirst('#', ''), radix: 16);

List<double> _lab(String hex) {
  final n = hexToInt(hex);
  double lin(int c) {
    final v = c / 255;
    return v > 0.04045
        ? math.pow((v + 0.055) / 1.055, 2.4).toDouble()
        : v / 12.92;
  }

  final r = lin((n >> 16) & 255), g = lin((n >> 8) & 255), b = lin(n & 255);
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

double colorDistance(String a, String b) {
  final p = _lab(a), q = _lab(b);
  final d0 = p[0] - q[0], d1 = p[1] - q[1], d2 = p[2] - q[2];
  return math.sqrt(d0 * d0 + d1 * d1 + d2 * d2);
}

/// 레벨 팔레트에서 가장 비슷한 두 색 (인덱스). 기준보다 멀면 null
(int, int)? similarPair(Level level, [double maxDe = similarDeltaE]) {
  (int, int)? best;
  var bestD = maxDe;
  for (var a = 0; a < level.palette.length; a++) {
    for (var b = a + 1; b < level.palette.length; b++) {
      final d = colorDistance(level.palette[a], level.palette[b]);
      if (d < bestD) {
        bestD = d;
        best = (a, b);
      }
    }
  }
  return best;
}

/// 비슷한 색이 처음 나오는 레벨 번호 (1부터). 없으면 0
int firstSimilarLevel(List<Level> levels) =>
    levels.indexWhere((l) => similarPair(l) != null) + 1;
