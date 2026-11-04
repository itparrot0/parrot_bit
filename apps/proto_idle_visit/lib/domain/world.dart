import 'dart:math';

import 'catalog.dart';

/// 방문 규칙의 숫자들. 재미 판정 중에 가장 자주 바뀔 곳이라 한데 모았다.
final class VisitRules {
  const VisitRules({
    this.rollInterval = const Duration(minutes: 5),
    this.visitChance = 0.5,
  }) : assert(visitChance >= 0 && visitChance <= 1);

  /// 빈 아이템이 "누가 올까" 추첨을 하는 간격. 놓은 직후와 손님이 떠난 직후에도
  /// 이만큼 기다린 뒤 첫 추첨을 한다 — "일정 시간이 지나면 찾아온다".
  final Duration rollInterval;

  /// 한 번의 추첨에서 누군가 찾아올 확률. 후보가 없으면 이 확률과 무관하게
  /// 아무도 오지 않는다.
  final double visitChance;

  static const VisitRules standard = VisitRules();
}

/// 아이템에 머무는 중인 캐릭터.
final class Visit {
  const Visit({
    required this.characterId,
    required this.arrivedAt,
    required this.leavesAt,
  });

  final String characterId;
  final DateTime arrivedAt;
  final DateTime leavesAt;
}

/// 장소의 한 자리. 비어 있거나, 아이템이 놓여 있거나, 아이템에 손님이 있다.
final class Slot {
  Slot._(this.placeId, this.index);

  final String placeId;
  final int index;

  String? _itemId;
  DateTime? _nextRollAt;
  Visit? _visit;

  String? get itemId => _itemId;
  Visit? get visit => _visit;

  /// 다음 추첨 시각. 아이템이 없거나 손님이 있으면 null이다.
  DateTime? get nextRollAt => _nextRollAt;

  bool get isEmpty => _itemId == null;
}

/// 도감 한 칸.
final class CollectionEntry {
  const CollectionEntry({required this.firstSeenAt, required this.visitCount});

  final DateTime firstSeenAt;
  final int visitCount;
}

/// [World.advance]가 돌려주는 도착 기록. UI가 "누가 왔어요" 알림에 쓴다.
final class Arrival {
  const Arrival({
    required this.characterId,
    required this.placeId,
    required this.slotIndex,
    required this.at,
    required this.isFirstVisit,
  });

  final String characterId;
  final String placeId;
  final int slotIndex;
  final DateTime at;

  /// 도감에 처음 올라간 방문인가.
  final bool isFirstVisit;
}

/// 게임 세계 전체 상태 — 순수 Dart, 시계를 직접 읽지 않는다.
///
/// 시간은 언제나 [advance]로만 흐른다. 앱이 켜져 있을 때 1초마다 부르든, 사흘
/// 만에 열어서 한 번 부르든 결과가 같다 — 방치형의 오프라인 진행이 별도 코드
/// 없이 같은 규칙으로 처리된다.
///
/// 무작위는 [seed]와 지금까지의 추첨 횟수로만 정해진다. 같은 시드에 같은 조작을
/// 같은 시각에 하면 같은 손님이 온다 — 테스트와 버그 재현을 위해서다.
final class World {
  World({
    required this.catalog,
    required this.seed,
    required this._now,
    this.rules = VisitRules.standard,
  }) : _slots = {
         for (final place in catalog.places)
           place.id: [
             for (var i = 0; i < place.slotCount; i++) Slot._(place.id, i),
           ],
       };

  final Catalog catalog;
  final VisitRules rules;
  final int seed;

  final Map<String, List<Slot>> _slots;
  final Map<String, CollectionEntry> _collection = {};
  int _rollCount = 0;
  DateTime _now;

  /// 세계가 마지막으로 진행된 시각.
  DateTime get now => _now;

  /// 지금까지 한 추첨 횟수. 무작위 상태 그 자체다.
  int get rollCount => _rollCount;

  List<Slot> slotsOf(String placeId) =>
      List.unmodifiable(_slots[placeId] ?? (throw ArgumentError(placeId)));

  Slot slot(String placeId, int index) => slotsOf(placeId)[index];

  Map<String, CollectionEntry> get collection => Map.unmodifiable(_collection);

  bool isCollected(String characterId) => _collection.containsKey(characterId);

  /// 지금 어딘가에 머무는 캐릭터들. 한 캐릭터는 한 번에 한 곳에만 있다.
  Set<String> get visitingCharacters => {
    for (final slots in _slots.values)
      for (final slot in slots)
        if (slot.visit case final visit?) visit.characterId,
  };

  /// [itemId]를 자리에 놓는다. 이미 놓인 아이템은 바꿔 놓이고, 머물던 손님은
  /// 떠난다. 첫 추첨은 [VisitRules.rollInterval] 뒤다.
  void placeItem(String placeId, int index, String itemId) {
    if (!catalog.hasItem(itemId)) throw ArgumentError(itemId);
    final target = slot(placeId, index);
    target
      .._itemId = itemId
      .._visit = null
      .._nextRollAt = _now.add(rules.rollInterval);
  }

  /// 자리를 비운다. 머물던 손님도 떠난다.
  void removeItem(String placeId, int index) {
    slot(placeId, index)
      .._itemId = null
      .._visit = null
      .._nextRollAt = null;
  }

  /// [to]까지 시간을 흘린다. 그 사이의 떠남·추첨을 시각 순서대로 처리하고,
  /// 그동안 도착한 손님을 순서대로 돌려준다.
  ///
  /// [to]가 과거면(기기 시계를 되돌린 경우) 아무 일도 일어나지 않는다.
  List<Arrival> advance(DateTime to) {
    final arrivals = <Arrival>[];
    if (!to.isAfter(_now)) return arrivals;

    while (true) {
      final next = _nextEvent(to);
      if (next == null) break;
      final (slot, at) = next;
      _now = at;
      if (slot._visit case final visit?) {
        // 떠남: 비운 직후부터 다시 기다린다.
        slot
          .._visit = null
          .._nextRollAt = visit.leavesAt.add(rules.rollInterval);
      } else {
        final arrival = _roll(slot, at);
        if (arrival != null) arrivals.add(arrival);
      }
    }

    _now = to;
    return arrivals;
  }

  /// [to] 이하인 가장 이른 사건. 같은 시각이면 떠남이 먼저(떠난 캐릭터가 같은
  /// 순간 다른 자리의 후보가 될 수 있도록), 그다음 장소·자리 순서다.
  (Slot, DateTime)? _nextEvent(DateTime to) {
    (Slot, DateTime, bool)? best;
    for (final place in catalog.places) {
      for (final slot in _slots[place.id]!) {
        final DateTime at;
        final bool isLeave;
        if (slot._visit case final visit?) {
          at = visit.leavesAt;
          isLeave = true;
        } else if (slot._nextRollAt case final rollAt?) {
          at = rollAt;
          isLeave = false;
        } else {
          continue;
        }
        if (at.isAfter(to)) continue;
        if (best == null ||
            at.isBefore(best.$2) ||
            (at.isAtSameMomentAs(best.$2) && isLeave && !best.$3)) {
          best = (slot, at, isLeave);
        }
      }
    }
    return best == null ? null : (best.$1, best.$2);
  }

  Arrival? _roll(Slot slot, DateTime at) {
    final random = Random(_mix(seed, _rollCount++));
    slot._nextRollAt = at.add(rules.rollInterval);

    final visiting = visitingCharacters;
    final candidates = [
      for (final c in catalog.visitorsOf(slot._itemId!))
        if (!visiting.contains(c.id)) c,
    ];
    // 후보 유무와 무관하게 난수를 같은 개수만큼 쓴다 — 다른 자리 상황이
    // 이 자리의 운을 바꾸지 않게.
    final chanceRoll = random.nextDouble();
    final pickRoll = random.nextDouble();
    if (candidates.isEmpty || chanceRoll >= rules.visitChance) return null;

    final totalWeight = candidates.fold<int>(
      0,
      (sum, c) => sum + c.rarity.weight,
    );
    var pick = pickRoll * totalWeight;
    var chosen = candidates.last;
    for (final c in candidates) {
      pick -= c.rarity.weight;
      if (pick < 0) {
        chosen = c;
        break;
      }
    }

    slot
      .._nextRollAt = null
      .._visit = Visit(
        characterId: chosen.id,
        arrivedAt: at,
        leavesAt: at.add(chosen.stay),
      );

    final previous = _collection[chosen.id];
    _collection[chosen.id] = CollectionEntry(
      firstSeenAt: previous?.firstSeenAt ?? at,
      visitCount: (previous?.visitCount ?? 0) + 1,
    );
    return Arrival(
      characterId: chosen.id,
      placeId: slot.placeId,
      slotIndex: slot.index,
      at: at,
      isFirstVisit: previous == null,
    );
  }

  /// 시드와 추첨 번호를 섞어 추첨마다 독립된 난수 시드를 만든다.
  static int _mix(int seed, int counter) {
    var x = (seed * 0x9E3779B1 + counter * 0x85EBCA77) & 0x7fffffff;
    x = ((x ^ (x >> 15)) * 0x2C1B3C6D) & 0x7fffffff;
    x = ((x ^ (x >> 12)) * 0x297A2D39) & 0x7fffffff;
    return x ^ (x >> 15);
  }

  // ── 저장 ──────────────────────────────────────────────────────────────

  static const int _schemaVersion = 1;

  Map<String, Object?> toJson() => {
    'version': _schemaVersion,
    'seed': seed,
    'now': _now.millisecondsSinceEpoch,
    'rollCount': _rollCount,
    'slots': [
      for (final slots in _slots.values)
        for (final slot in slots)
          if (!slot.isEmpty)
            {
              'place': slot.placeId,
              'index': slot.index,
              'item': slot._itemId,
              'nextRollAt': slot._nextRollAt?.millisecondsSinceEpoch,
              if (slot._visit case final visit?)
                'visit': {
                  'character': visit.characterId,
                  'arrivedAt': visit.arrivedAt.millisecondsSinceEpoch,
                  'leavesAt': visit.leavesAt.millisecondsSinceEpoch,
                },
            },
    ],
    'collection': {
      for (final MapEntry(:key, :value) in _collection.entries)
        key: {
          'firstSeenAt': value.firstSeenAt.millisecondsSinceEpoch,
          'visitCount': value.visitCount,
        },
    },
  };

  /// 저장본을 되살린다. 카탈로그에서 사라진 장소·자리·아이템·캐릭터는 조용히
  /// 버린다 — 밸런스 조정으로 데이터가 바뀌어도 저장본이 깨지지 않게.
  factory World.fromJson(
    Map<String, Object?> json, {
    required Catalog catalog,
    VisitRules rules = VisitRules.standard,
  }) {
    if (json['version'] != _schemaVersion) {
      throw FormatException('지원하지 않는 저장 버전: ${json['version']}');
    }
    DateTime time(Object? millis) =>
        DateTime.fromMillisecondsSinceEpoch(millis! as int, isUtc: true);

    final world = World(
      catalog: catalog,
      seed: json['seed']! as int,
      now: time(json['now']),
      rules: rules,
    ).._rollCount = json['rollCount']! as int;

    for (final raw in json['slots']! as List<Object?>) {
      final s = raw! as Map<String, Object?>;
      final placeId = s['place']! as String;
      final index = s['index']! as int;
      final itemId = s['item']! as String;
      final slots = world._slots[placeId];
      if (slots == null || index >= slots.length) continue;
      if (!catalog.hasItem(itemId)) continue;

      final slot = slots[index].._itemId = itemId;
      final visit = s['visit'] as Map<String, Object?>?;
      final characterId = visit?['character'] as String?;
      if (visit != null &&
          characterId != null &&
          catalog.hasCharacter(characterId)) {
        slot._visit = Visit(
          characterId: characterId,
          arrivedAt: time(visit['arrivedAt']),
          leavesAt: time(visit['leavesAt']),
        );
      } else {
        slot._nextRollAt = s['nextRollAt'] == null
            ? world._now.add(rules.rollInterval)
            : time(s['nextRollAt']);
      }
    }

    final collection = json['collection']! as Map<String, Object?>;
    for (final MapEntry(:key, :value) in collection.entries) {
      if (!catalog.hasCharacter(key)) continue;
      final e = value! as Map<String, Object?>;
      world._collection[key] = CollectionEntry(
        firstSeenAt: time(e['firstSeenAt']),
        visitCount: e['visitCount']! as int,
      );
    }
    return world;
  }
}
