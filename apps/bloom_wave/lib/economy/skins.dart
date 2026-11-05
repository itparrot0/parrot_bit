// 꽃 스킨 목록 (2026-11-04). 스킨은 게임 보드에서 "개화한 칸"의 꽃 모양만 바꾼다 — 색은 그림 색 그대로라
// 퍼즐에는 영향이 없다. 모양(경로)은 lib/ui/skin_art.dart 가 스킨 id 로 그린다.
//
// 기본 스킨 말고는 뽑기로 퍼즐 조각을 모아 해금한다. 조각을 모두 모으면 해금.
// 스킨을 늘리려면 여기에 한 줄 + skin_art.dart 에 모양 하나 + 문구(이름은 여기)를 더한다.

class SkinDef {
  const SkinDef({
    required this.id,
    required this.ko,
    required this.en,
    required this.color,
    this.pieces = 4,
    this.isDefault = false,
  });
  final String id;
  final String ko;
  final String en;

  /// 카드·캡슐에 쓰는 대표색 (0xRRGGBB)
  final int color;

  /// 퍼즐 조각 수 (2×2 = 4)
  final int pieces;

  /// 처음부터 가진 스킨 (뽑기에 나오지 않는다)
  final bool isDefault;

  String name(String lang) => lang == 'ko' ? ko : en;
}

const defaultSkinId = 'basic';

const List<SkinDef> skins = [
  SkinDef(
    id: 'basic',
    ko: '기본 꽃',
    en: 'Classic',
    color: 0x46A758,
    isDefault: true,
  ),
  SkinDef(id: 'daisy', ko: '데이지', en: 'Daisy', color: 0xF5D90A),
  SkinDef(id: 'tulip', ko: '튤립', en: 'Tulip', color: 0xE5484D),
  SkinDef(id: 'sakura', ko: '벚꽃', en: 'Cherry Blossom', color: 0xF19CBB),
  SkinDef(id: 'sunflower', ko: '해바라기', en: 'Sunflower', color: 0xF76B15),
  SkinDef(id: 'clover', ko: '네잎클로버', en: 'Four-leaf Clover', color: 0x30A46C),
];

SkinDef? skinById(String id) {
  for (final s in skins) {
    if (s.id == id) return s;
  }
  return null;
}

/// 뽑기에 나올 수 있는 스킨 (기본 스킨 제외)
Iterable<SkinDef> get gachaSkins => skins.where((s) => !s.isDefault);
