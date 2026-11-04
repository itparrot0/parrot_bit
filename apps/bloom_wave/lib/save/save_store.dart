// 진행도·설정·골드 저장. 키 하나에 JSON 한 덩어리로 둔다 (shared_preferences, 테스트는 메모리).
// schema 필드는 업데이트 때 마이그레이션을 위해 꼭 유지한다.
//  - schema 1: stars(레벨별 별점)
//  - schema 2 (2026-11-04): 별점 폐지 → cleared(완성 여부), noAds(광고 제거 구매)
//  - schema 3 (2026-11-04, Flutter 전환): gold(골드 잔액). 지난 스테이지 다시 하기 없음 → unlocked 가 곧 다음 스테이지
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const saveKey = 'bloomwave.save';
const saveSchema = 3;

enum TickSpeed { normal, slow }

class Settings {
  const Settings({
    this.sound = true,
    this.vibration = true,
    this.tickSpeed = TickSpeed.normal,
    this.fastFx = false,
    this.lang = 'ko',
  });
  final bool sound;
  final bool vibration;
  final TickSpeed tickSpeed;

  /// 빠른 연출 (애니메이션 축약)
  final bool fastFx;

  /// 'ko' | 'en'
  final String lang;

  Settings copyWith({
    bool? sound,
    bool? vibration,
    TickSpeed? tickSpeed,
    bool? fastFx,
    String? lang,
  }) => Settings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    tickSpeed: tickSpeed ?? this.tickSpeed,
    fastFx: fastFx ?? this.fastFx,
    lang: lang ?? this.lang,
  );

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'tickSpeed': tickSpeed.name,
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
  }) : cleared = cleared ?? <String>{};

  /// 다음에 할 스테이지 번호 (1부터). 완성한 스테이지는 다시 열지 않는다
  int unlocked;

  /// 완성한 레벨 id
  final Set<String> cleared;

  /// 광고 제거 구매 여부 (스토어 복원으로도 다시 켜진다)
  bool noAds;

  /// 골드 잔액
  int gold;
  Settings settings;

  Map<String, dynamic> toJson() => {
    'schema': saveSchema,
    'unlocked': unlocked,
    'cleared': {for (final id in cleared) id: true},
    'noAds': noAds,
    'gold': gold,
    'settings': settings.toJson(),
  };
}

/// 어떤 값이 들어와도 유효한 SaveData 로 만든다 (깨진 저장, 옛 스키마 대비)
SaveData migrate(Object? raw, {String lang = 'ko'}) {
  final d = SaveData(settings: Settings(lang: lang));
  if (raw is! Map) return d;
  final s = raw['settings'];
  if (s is Map) {
    final ts = s['tickSpeed'];
    final l = s['lang'];
    d.settings = Settings(
      sound: s['sound'] is bool ? s['sound'] as bool : true,
      vibration: s['vibration'] is bool ? s['vibration'] as bool : true,
      tickSpeed: ts == 'slow' ? TickSpeed.slow : TickSpeed.normal,
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

  Future<void> setNoAds(bool v) async {
    data.noAds = v;
    await save();
  }

  Future<void> updateSettings(Settings s) async {
    data.settings = s;
    await save();
  }
}
