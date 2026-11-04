// 진행도·설정 저장. @capacitor/preferences (웹에서는 localStorage) 에 JSON 한 덩어리로 둔다.
// schema 필드는 업데이트 때 마이그레이션을 위해 꼭 유지한다.
export const SAVE_KEY = "bloomwave.save";
export const SCHEMA = 1;

export type Lang = "ko" | "en";
export type Settings = {
  sound: boolean;
  vibration: boolean;
  tickSpeed: "normal" | "slow";
  fastFx: boolean; // 빠른 연출 (애니메이션 축약)
  lang: Lang;
};

export type SaveData = {
  schema: number;
  unlocked: number; // 열린 레벨 수 (1 = 첫 레벨만)
  stars: Record<string, number>; // levelId -> 최고 별점
  settings: Settings;
};

export interface KeyValueStore {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

export function defaultSave(lang: Lang = "ko"): SaveData {
  return {
    schema: SCHEMA, unlocked: 1, stars: {},
    settings: { sound: true, vibration: true, tickSpeed: "normal", fastFx: false, lang },
  };
}

/** 어떤 값이 들어와도 유효한 SaveData 로 만든다 (깨진 저장, 옛 스키마 대비) */
export function migrate(raw: unknown, lang: Lang = "ko"): SaveData {
  const d = defaultSave(lang);
  if (!raw || typeof raw !== "object") return d;
  const r = raw as Partial<SaveData>;
  // schema 1 이 첫 버전. 이후 버전이 생기면 여기서 단계별로 올린다.
  const s = { ...d.settings, ...(typeof r.settings === "object" && r.settings ? r.settings : {}) };
  if (s.tickSpeed !== "normal" && s.tickSpeed !== "slow") s.tickSpeed = "normal";
  if (s.lang !== "ko" && s.lang !== "en") s.lang = lang;
  const stars: Record<string, number> = {};
  if (r.stars && typeof r.stars === "object") {
    for (const [k, v] of Object.entries(r.stars)) if (typeof v === "number" && v >= 1 && v <= 3) stars[k] = Math.floor(v);
  }
  const unlocked = typeof r.unlocked === "number" && r.unlocked >= 1 ? Math.floor(r.unlocked) : 1;
  return { schema: SCHEMA, unlocked, stars, settings: s };
}

export class SaveStore {
  data: SaveData;
  constructor(private kv: KeyValueStore, lang: Lang = "ko") { this.data = defaultSave(lang); }

  async load(lang: Lang = "ko"): Promise<SaveData> {
    try {
      const raw = await this.kv.get(SAVE_KEY);
      this.data = migrate(raw ? JSON.parse(raw) : null, lang);
    } catch {
      this.data = defaultSave(lang);
    }
    return this.data;
  }

  async save() {
    try { await this.kv.set(SAVE_KEY, JSON.stringify(this.data)); } catch { /* 저장 실패는 다음 저장 때 다시 시도 */ }
  }

  /** 레벨을 끝낼 때 호출. 별점은 최고 기록만 남기고, 클리어하면 다음 레벨을 연다 */
  async recordClear(levelId: string, levelNo: number, stars: number, total: number) {
    const prev = this.data.stars[levelId] ?? 0;
    if (stars > prev) this.data.stars[levelId] = stars;
    this.data.unlocked = Math.min(total, Math.max(this.data.unlocked, levelNo + 1));
    await this.save();
  }

  async updateSettings(patch: Partial<Settings>) {
    this.data.settings = { ...this.data.settings, ...patch };
    await this.save();
  }
}

export function memoryStore(init: Record<string, string> = {}): KeyValueStore & { map: Map<string, string> } {
  const map = new Map(Object.entries(init));
  return { map, async get(k) { return map.get(k) ?? null; }, async set(k, v) { map.set(k, v); } };
}
