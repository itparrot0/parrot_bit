// 진행도·설정·골드 저장. 키 하나에 JSON 한 덩어리로 둔다 (shared_preferences, 테스트는 메모리).
// schema 필드는 업데이트 때 마이그레이션을 위해 꼭 유지한다.
//  - schema 1: stars(레벨별 별점)
//  - schema 2 (2026-11-04): 별점 폐지 → cleared(완성 여부), noAds(광고 제거 구매)
//  - schema 3 (2026-11-04, Flutter 전환): gold(골드 잔액). 지난 스테이지 다시 하기 없음 → unlocked 가 곧 다음 스테이지
//  - schema 4 (2026-11-04): skins — 스킨별 모은 퍼즐 조각(pieces), 장착한 스킨(equipped).
//    해금 여부는 따로 저장하지 않고 "조각을 모두 모았나"로 계산한다 (economy/skins.dart)
//  - schema 5 (2026-11-04): items(아이템 개수·해금·튜토리얼 완료), x2(남은 시간·켜짐). 설정의 웨이브 속도는 x2 로 바뀌어 없앤다
//  - schema 6 (2026-11-05): lives — 햇빛 개수·회복 기준 시각·광고 충전한 날 (economy/lives.dart). 옛 저장은 가득 찬 상태로 시작
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../economy/gacha.dart';
import '../economy/items.dart';
import '../economy/lives.dart';
import '../economy/skins.dart';

const saveKey = 'bloomwave.save';
const saveSchema = 6;

class Settings {
  const Settings({
    this.sound = true,
    this.vibration = true,
    this.fastFx = false,
    this.lang = 'ko',
  });
  final bool sound;
  final bool vibration;

  /// 빠른 연출 (애니메이션 축약)
  final bool fastFx;

  /// 'ko' | 'en'
  final String lang;

  Settings copyWith({
    bool? sound,
    bool? vibration,
    bool? fastFx,
    String? lang,
  }) => Settings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    fastFx: fastFx ?? this.fastFx,
    lang: lang ?? this.lang,
  );

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'fastFx': fastFx,
    'lang': lang,
  };
}

class SaveData {
  SaveData({
    this.unlocked = 1,
    Set<String>? cleared,
    this.noAds = false,
    this.gold = 0,
    this.settings = const Settings(),
    Map<String, Set<int>>? skinPieces,
    this.equippedSkin = defaultSkinId,
    Map<ItemKind, int>? items,
    Set<ItemKind>? itemsUnlocked,
    Set<ItemKind>? itemTutorialDone,
    this.x2Ms = x2InitialMs,
    this.x2On = false,
    Lives? lives,
  }) : lives = lives ?? Lives(),
       cleared = cleared ?? <String>{},
       skinPieces = skinPieces ?? <String, Set<int>>{},
       items = items ?? {for (final k in ItemKind.values) k: 0},
       itemsUnlocked = itemsUnlocked ?? <ItemKind>{},
       itemTutorialDone = itemTutorialDone ?? <ItemKind>{};

  /// 다음에 할 스테이지 번호 (1부터). 완성한 스테이지는 다시 열지 않는다
  int unlocked;

  /// 완성한 레벨 id
  final Set<String> cleared;

  /// 광고 제거 구매 여부 (스토어 복원으로도 다시 켜진다)
  bool noAds;

  /// 골드 잔액
  int gold;
  Settings settings;

  /// 스킨별로 모은 퍼즐 조각 번호
  final Map<String, Set<int>> skinPieces;

  /// 게임에서 쓰는 꽃 스킨
  String equippedSkin;

  /// 아이템별 남은 개수
  final Map<ItemKind, int> items;

  /// 해금된 아이템 (해금 스테이지에서 처음 받음)
  final Set<ItemKind> itemsUnlocked;

  /// 튜토리얼에서 한 번 써 본 아이템
  final Set<ItemKind> itemTutorialDone;

  /// x2 남은 시간(ms) / 켜 둠
  int x2Ms;
  bool x2On;

  /// 햇빛 (라이프)
  final Lives lives;

  int itemCount(ItemKind k) => items[k] ?? 0;

  /// 해금된 스킨인가 (기본 스킨이거나 조각을 모두 모음)
  bool isUnlocked(SkinDef s) =>
      s.isDefault || (skinPieces[s.id]?.length ?? 0) >= s.pieces;

  /// 장착한 스킨 (해금 안 된 값이 들어 있으면 기본 스킨)
  SkinDef get skin {
    final s = skinById(equippedSkin);
    return s != null && isUnlocked(s) ? s : skins.first;
  }

  Map<String, dynamic> toJson() => {
    'schema': saveSchema,
    'unlocked': unlocked,
    'cleared': {for (final id in cleared) id: true},
    'noAds': noAds,
    'gold': gold,
    'settings': settings.toJson(),
    'skins': {
      'pieces': {
        for (final e in skinPieces.entries)
          if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
      },
      'equipped': equippedSkin,
    },
    'items': {
      'count': {for (final k in ItemKind.values) k.name: itemCount(k)},
      'unlocked': [
        for (final k in ItemKind.values)
          if (itemsUnlocked.contains(k)) k.name,
      ],
      'tutorialDone': [
        for (final k in ItemKind.values)
          if (itemTutorialDone.contains(k)) k.name,
      ],
    },
    'x2': {'ms': x2Ms, 'on': x2On},
    'lives': lives.toJson(),
  };
}

/// 어떤 값이 들어와도 유효한 SaveData 로 만든다 (깨진 저장, 옛 스키마 대비)
SaveData migrate(Object? raw, {String lang = 'ko'}) {
  final d = SaveData(settings: Settings(lang: lang));
  if (raw is! Map) return d;
  final s = raw['settings'];
  if (s is Map) {
    final l = s['lang'];
    d.settings = Settings(
      sound: s['sound'] is bool ? s['sound'] as bool : true,
      vibration: s['vibration'] is bool ? s['vibration'] as bool : true,
      fastFx: s['fastFx'] == true,
      lang: l == 'ko' || l == 'en' ? l as String : lang,
    );
  }
  // schema 1 → 2: 별이 1개 이상이면 완성
  final stars = raw['stars'];
  if (stars is Map) {
    stars.forEach((k, v) {
      if (v is num && v >= 1) d.cleared.add('$k');
    });
  }
  final cleared = raw['cleared'];
  if (cleared is Map) {
    cleared.forEach((k, v) {
      if (v == true) d.cleared.add('$k');
    });
  }
  final u = raw['unlocked'];
  if (u is num && u >= 1) d.unlocked = u.floor();
  d.noAds = raw['noAds'] == true;
  // schema 2 → 3: 골드는 0에서 시작
  final g = raw['gold'];
  if (g is num && g >= 0) d.gold = g.floor();
  // schema 3 → 4: 스킨 없음 (기본 스킨). 모르는 스킨·범위 밖 조각은 버린다
  final sk = raw['skins'];
  if (sk is Map) {
    final pieces = sk['pieces'];
    if (pieces is Map) {
      pieces.forEach((k, v) {
        final def = skinById('$k');
        if (def == null || def.isDefault || v is! List) return;
        final set = {
          for (final i in v)
            if (i is int && i >= 0 && i < def.pieces) i,
        };
        if (set.isNotEmpty) d.skinPieces[def.id] = set;
      });
    }
    final eq = sk['equipped'];
    if (eq is String && skinById(eq) != null) d.equippedSkin = eq;
  }
  // schema 4 → 5: 아이템·x2. 해금 스테이지를 이미 지난 저장은 튜토리얼을 마친 것으로 치고 2개씩 준다
  ItemKind? kindOf(Object? v) =>
      ItemKind.values.where((k) => k.name == v).firstOrNull;
  final it = raw['items'];
  if (it is Map) {
    final c = it['count'];
    if (c is Map) {
      c.forEach((k, v) {
        final kind = kindOf(k);
        if (kind != null && v is num && v >= 0) d.items[kind] = v.floor();
      });
    }
    for (final (key, set) in [
      ('unlocked', d.itemsUnlocked),
      ('tutorialDone', d.itemTutorialDone),
    ]) {
      final list = it[key];
      if (list is List) {
        for (final v in list) {
          final kind = kindOf(v);
          if (kind != null) set.add(kind);
        }
      }
    }
  }
  for (final def in itemDefs) {
    if (d.unlocked > def.unlockStage && !d.itemsUnlocked.contains(def.kind)) {
      d.itemsUnlocked.add(def.kind);
      d.itemTutorialDone.add(def.kind);
      d.items[def.kind] = itemStartCount - 1;
    }
  }
  final x2 = raw['x2'];
  if (x2 is Map) {
    final ms = x2['ms'];
    if (ms is num && ms >= 0) d.x2Ms = ms.floor();
    d.x2On = x2['on'] == true && d.x2Ms > 0;
  }
  // schema 5 → 6: 햇빛 가득
  final lv = Lives.fromJson(raw['lives']);
  d.lives
    ..count = lv.count
    ..anchorMs = lv.anchorMs
    ..adDay = lv.adDay;
  return d;
}

abstract interface class KeyValueStore {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

class PrefsStore implements KeyValueStore {
  @override
  Future<String?> get(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> set(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? init]) : map = {...?init};
  final Map<String, String> map;
  @override
  Future<String?> get(String key) async => map[key];
  @override
  Future<void> set(String key, String value) async => map[key] = value;
}

class SaveStore {
  SaveStore(this._kv);
  final KeyValueStore _kv;
  SaveData data = SaveData();

  Future<SaveData> load({String lang = 'ko'}) async {
    try {
      final raw = await _kv.get(saveKey);
      data = migrate(raw == null ? null : jsonDecode(raw), lang: lang);
    } catch (_) {
      data = SaveData(settings: Settings(lang: lang));
    }
    return data;
  }

  Future<void> save() async {
    try {
      await _kv.set(saveKey, jsonEncode(data.toJson()));
    } catch (_) {
      // 저장 실패는 다음 저장 때 다시 시도
    }
  }

  /// 레벨을 완성했을 때 호출. 다음 레벨을 열고 골드를 더한다.
  /// 같은 레벨을 두 번 기록해도 골드는 한 번만 들어간다. 실제로 더한 골드를 돌려준다.
  Future<int> recordClear(
    String levelId,
    int levelNo,
    int total, {
    int gold = 0,
  }) async {
    final first = data.cleared.add(levelId);
    final added = first ? gold : 0;
    data.gold += added;
    if (levelNo + 1 > data.unlocked) data.unlocked = levelNo + 1;
    if (data.unlocked > total + 1) data.unlocked = total + 1;
    await save();
    return added;
  }

  /// 스킨 뽑기 한 번 (골드 차감·조각 추가·중복 반환을 한 번에 저장). 뽑을 수 없으면 StateError
  Future<PullResult> pullSkin(math.Random rng) async {
    final r = pull(data, rng);
    await save();
    return r;
  }

  /// 해금 스테이지에 처음 들어왔을 때: 아이템 해금 + [itemStartCount]개 지급 (한 번만). 새로 해금했으면 true
  Future<bool> unlockItem(ItemKind k) async {
    if (!data.itemsUnlocked.add(k)) return false;
    data.items[k] = data.itemCount(k) + itemStartCount;
    await save();
    return true;
  }

  /// 아이템 1개 사용. 없으면 false
  Future<bool> useItem(ItemKind k, {bool tutorial = false}) async {
    if (data.itemCount(k) <= 0) return false;
    data.items[k] = data.itemCount(k) - 1;
    if (tutorial) data.itemTutorialDone.add(k);
    await save();
    return true;
  }

  /// x2 남은 시간·켜짐 저장
  Future<void> setX2({int? ms, bool? on}) async {
    if (ms != null) data.x2Ms = ms < 0 ? 0 : ms;
    if (on != null) data.x2On = on && data.x2Ms > 0;
    if (data.x2Ms <= 0) data.x2On = false;
    await save();
  }

  /// 해금된 스킨만 장착할 수 있다
  Future<bool> equipSkin(String id) async {
    final s = skinById(id);
    if (s == null || !data.isUnlocked(s)) return false;
    data.equippedSkin = id;
    await save();
    return true;
  }

  /// 스테이지 시작: 햇빛 1개 쓰기 (바로 반영, 저장은 뒤에서). 없으면 false
  bool spendLife(DateTime now) {
    if (!data.lives.spend(now)) return false;
    save();
    return true;
  }

  /// 스테이지 완성: 시작할 때 쓴 햇빛을 돌려받는다
  Future<void> refundLife(DateTime now) async {
    data.lives.refund(now);
    await save();
  }

  /// 골드로 햇빛 가득 채우기. 이미 가득이거나 골드가 모자라면 false
  Future<bool> refillLivesWithGold(DateTime now) async {
    data.lives.settle(now);
    if (data.lives.full || data.gold < refillGoldCost) return false;
    data.gold -= refillGoldCost;
    data.lives.fill();
    await save();
    return true;
  }

  /// 광고를 끝까지 본 뒤: 햇빛 가득 + 오늘 광고 충전 사용. 오늘 이미 썼으면 false
  Future<bool> refillLivesWithAd(DateTime now) async {
    if (!data.lives.adAvailable(now)) return false;
    data.lives.fill();
    data.lives.adDay = adDayKey(now);
    await save();
    return true;
  }

  Future<void> setNoAds(bool v) async {
    data.noAds = v;
    await save();
  }

  Future<void> updateSettings(Settings s) async {
    data.settings = s;
    await save();
  }
}
