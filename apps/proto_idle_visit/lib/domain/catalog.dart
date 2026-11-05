/// 게임에 등장하는 정적 데이터 — 장소·아이템·캐릭터.
///
/// 규칙은 이 데이터를 읽기만 한다. 밸런스 조정은 [Catalog.standard]의 숫자를
/// 바꾸는 것으로 끝나야 한다.
library;

/// 캐릭터 희귀도. [weight]는 같은 아이템을 좋아하는 후보들 사이의 추첨 가중치다.
enum Rarity {
  common(weight: 60, label: '흔함'),
  rare(weight: 30, label: '드묾'),
  special(weight: 10, label: '특별');

  const Rarity({required this.weight, required this.label});

  final int weight;
  final String label;
}

/// 장소. 아이템을 놓을 수 있는 자리 [slotCount]개를 가진다.
final class PlaceDef {
  const PlaceDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slotCount,
  });

  final String id;
  final String name;
  final String emoji;
  final int slotCount;
}

/// 배치할 수 있는 아이템.
final class ItemDef {
  const ItemDef({required this.id, required this.name, required this.emoji});

  final String id;
  final String name;
  final String emoji;
}

/// 수집 대상 캐릭터. [likes]에 든 아이템에만 찾아온다.
final class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rarity,
    required this.likes,
    required this.stay,
  });

  final String id;
  final String name;
  final String emoji;
  final Rarity rarity;
  final Set<String> likes;

  /// 한 번 찾아오면 머무는 시간.
  final Duration stay;
}

/// 정적 데이터 묶음. 생성자가 참조 무결성을 검사한다 — 없는 아이템을 좋아하는
/// 캐릭터나 아무도 안 찾아오는 아이템은 플레이 중이 아니라 여기서 걸린다.
final class Catalog {
  Catalog({
    required List<PlaceDef> places,
    required List<ItemDef> items,
    required List<CharacterDef> characters,
  }) : places = List.unmodifiable(places),
       items = List.unmodifiable(items),
       characters = List.unmodifiable(characters),
       _places = {for (final p in places) p.id: p},
       _items = {for (final i in items) i.id: i},
       _characters = {for (final c in characters) c.id: c} {
    _requireUnique('place', places.map((p) => p.id));
    _requireUnique('item', items.map((i) => i.id));
    _requireUnique('character', characters.map((c) => c.id));

    for (final place in places) {
      if (place.slotCount < 1) {
        throw ArgumentError('장소 ${place.id}의 자리 수가 1보다 작다');
      }
    }
    for (final character in characters) {
      if (character.likes.isEmpty) {
        throw ArgumentError('캐릭터 ${character.id}가 좋아하는 아이템이 없다');
      }
      for (final itemId in character.likes) {
        if (!_items.containsKey(itemId)) {
          throw ArgumentError('캐릭터 ${character.id}가 없는 아이템 $itemId를 좋아한다');
        }
      }
    }
    for (final item in items) {
      if (visitorsOf(item.id).isEmpty) {
        throw ArgumentError('아이템 ${item.id}에 찾아오는 캐릭터가 없다');
      }
    }
  }

  final List<PlaceDef> places;
  final List<ItemDef> items;
  final List<CharacterDef> characters;

  final Map<String, PlaceDef> _places;
  final Map<String, ItemDef> _items;
  final Map<String, CharacterDef> _characters;

  PlaceDef place(String id) => _places[id] ?? (throw ArgumentError(id));
  ItemDef item(String id) => _items[id] ?? (throw ArgumentError(id));
  CharacterDef character(String id) =>
      _characters[id] ?? (throw ArgumentError(id));

  bool hasPlace(String id) => _places.containsKey(id);
  bool hasItem(String id) => _items.containsKey(id);
  bool hasCharacter(String id) => _characters.containsKey(id);

  /// [itemId]를 좋아하는 캐릭터들. 카탈로그 순서를 유지한다.
  List<CharacterDef> visitorsOf(String itemId) => [
    for (final c in characters)
      if (c.likes.contains(itemId)) c,
  ];

  static void _requireUnique(String kind, Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw ArgumentError('$kind id 중복: $id');
    }
  }

  /// 프로토타입 기본 데이터 — 장소 2곳, 아이템 6개, 새 8마리.
  static final Catalog standard = Catalog(
    places: const [
      PlaceDef(id: 'yard', name: '마당', emoji: '🌳', slotCount: 4),
      PlaceDef(id: 'window', name: '창가', emoji: '🪟', slotCount: 3),
    ],
    items: const [
      ItemDef(id: 'seeds', name: '해바라기씨', emoji: '🌻'),
      ItemDef(id: 'berry', name: '딸기', emoji: '🍓'),
      ItemDef(id: 'water', name: '물그릇', emoji: '💧'),
      ItemDef(id: 'perch', name: '횃대', emoji: '🪵'),
      ItemDef(id: 'nest', name: '둥지', emoji: '🪺'),
      ItemDef(id: 'bell', name: '방울', emoji: '🔔'),
    ],
    characters: const [
      CharacterDef(
        id: 'sparrow',
        name: '참새',
        emoji: '🐦',
        rarity: Rarity.common,
        likes: {'seeds', 'water'},
        stay: Duration(minutes: 20),
      ),
      CharacterDef(
        id: 'chick',
        name: '병아리',
        emoji: '🐤',
        rarity: Rarity.common,
        likes: {'seeds', 'nest'},
        stay: Duration(minutes: 25),
      ),
      CharacterDef(
        id: 'dove',
        name: '비둘기',
        emoji: '🕊️',
        rarity: Rarity.common,
        likes: {'water', 'perch'},
        stay: Duration(minutes: 30),
      ),
      CharacterDef(
        id: 'parrot',
        name: '앵무새',
        emoji: '🦜',
        rarity: Rarity.rare,
        likes: {'berry', 'bell'},
        stay: Duration(minutes: 40),
      ),
      CharacterDef(
        id: 'owl',
        name: '부엉이',
        emoji: '🦉',
        rarity: Rarity.rare,
        likes: {'perch', 'nest'},
        stay: Duration(minutes: 45),
      ),
      CharacterDef(
        id: 'swan',
        name: '백조',
        emoji: '🦢',
        rarity: Rarity.rare,
        likes: {'water'},
        stay: Duration(minutes: 40),
      ),
      CharacterDef(
        id: 'flamingo',
        name: '플라밍고',
        emoji: '🦩',
        rarity: Rarity.special,
        likes: {'berry', 'water'},
        stay: Duration(minutes: 60),
      ),
      CharacterDef(
        id: 'peacock',
        name: '공작',
        emoji: '🦚',
        rarity: Rarity.special,
        likes: {'bell'},
        stay: Duration(minutes: 60),
      ),
    ],
  );
}
