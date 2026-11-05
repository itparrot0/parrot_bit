// 골드 구매 상품 (2026-11-05): 소모성 인앱 상품 4개. 조절 지점은 이 파일 한 곳.
//
// 기본 양은 500 골드의 1·2·5·10배, 큰 상품일수록 보너스를 더 준다 (0 · 10 · 20 · 30%).
// 상품 id 는 Play Console(관리형 상품, 소모성으로 처리) / App Store Connect(소모성)에 같은 이름으로 만든다.
// 가격은 스토어에서 정하고, 상점은 스토어가 알려 준 현지 가격을 그대로 보여 준다.
// 참고 가격(원): 1,200 · 2,400 · 5,900 · 11,000 — 기본 양 500골드 ≈ 1,200원 기준.

class GoldPack {
  const GoldPack(this.id, this.base, this.bonusPercent);

  /// 스토어 상품 id
  final String id;

  /// 기본 양
  final int base;

  /// 보너스 비율 (%)
  final int bonusPercent;

  int get bonus => base * bonusPercent ~/ 100;

  /// 실제로 받는 골드
  int get total => base + bonus;
}

const List<GoldPack> goldPacks = [
  GoldPack('gold_500', 500, 0),
  GoldPack('gold_1100', 1000, 10),
  GoldPack('gold_3000', 2500, 20),
  GoldPack('gold_6500', 5000, 30),
];

GoldPack? goldPackById(String id) {
  for (final p in goldPacks) {
    if (p.id == id) return p;
  }
  return null;
}

/// 1234567 → "1,234,567"
String withCommas(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
