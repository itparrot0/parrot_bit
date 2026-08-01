import 'package:flutter/material.dart';

/// 간격 토큰 (4pt 그리드).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 모서리 반경 토큰.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}

/// 애니메이션 길이 토큰.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
}

/// 색 토큰.
abstract final class AppColors {
  /// 브랜드 시드 컬러 — ColorScheme 생성의 기준값. 브랜드 확정 시 교체한다.
  static const Color seed = Color(0xFF2E7D32);
}
