import 'package:flutter/material.dart';

import '../domain/domain.dart';

/// 색 매핑. 프로토타입이라 값만 모아둔다 — 승격 시 `core_ui` 토큰으로 옮긴다.
abstract final class BloomPalette {
  static const Color background = Color(0xFF14181D);
  static const Color tile = Color(0xFF232B35);

  static const Map<BloomColor, Color> _colors = {
    BloomColor.red: Color(0xFFE5484D),
    BloomColor.blue: Color(0xFF3E9BFF),
    BloomColor.yellow: Color(0xFFF5C33B),
    BloomColor.green: Color(0xFF46C06A),
    BloomColor.purple: Color(0xFFA865E8),
  };

  static Color of(BloomColor color) => _colors[color]!;
}
