// 게임 화면 (2026-11-04 피드백 반영 배치, 위에서 아래로)
//  상단 바 / 보드(가로 최대 1000) / 활성 슬롯 4칸 한 줄(보드와 겹치지 않음) / 대기열 세로 줄들 / 하단 버튼
import { Container, Sprite, Text } from "pixi.js";
import type { Difficulty, Level } from "@bloom-wave/core/engine";
import type { Ctx, Scene } from "../app";
import { GameController, TICK_MS } from "../game/GameController";
import { BoardView } from "../game/BoardView";
import { DropView, type DropLayout } from "../game/DropView";
import { WavePlayer } from "../game/WavePlayer";
import { C, W, H } from "../ui/theme";
import { Button, Overlay, iconButton, label } from "../ui/widgets";
import { tweens, ease } from "../ui/tween";
import { TEX } from "../ui/textures";
import { artGraphic } from "../ui/art";
import { t, hasKey, getLang, type Key } from "../i18n/i18n";
import { afterClearAd } from "../monetize/ads";
import { sfx } from "../audio/audio";
import { hapticFail, hapticSuccess } from "../platform";
import { StageMapScene } from "./StageMapScene";

const TUTORIAL = ["wave", "lanes", "realtime", "waiting", "slots"];

/** 시작 전에 경고창을 띄우는 난이도 */
export const DIFFICULTY_ALERT: Partial<Record<Difficulty, { key: Key; color: number }>> = {
  hard: { key: "diffHard", color: 0xf08c00 },
  superHard: { key: "diffSuperHard", color: 0xe5484d },
  megaHard: { key: "diffMegaHard", color: 0x8e4ec6 },
};

export class GameScene implements Scene {
  readonly name = "game";
  readonly view = new Container();
  readonly controller: GameController;
  private board: BoardView;
  private drops: DropView;
  private wave: WavePlayer;
  private msg: Text;
  private undoBtn: Button;
  private overlay: Container | null = null;
  private ended = false;
  private leaving = false;
  private intro: string[] = [];
  readonly level: Level;

  constructor(private ctx: Ctx, readonly levelNo: number) {
    this.level = ctx.levels[levelNo - 1];
    const settings = ctx.save.data.settings;
    this.controller = new GameController(this.level, {
      tickMs: TICK_MS[settings.tickSpeed],
      manual: ctx.params.get("manualTick") === "1",
    });
    const top = ctx.safeTop;
    const bottom = H - ctx.safeBottom;

    // 상단 바
    const back = iconButton("‹", 120);
    back.label = "btn-back";
    back.position.set(100, top + 110);
    back.onTap = () => this.toMap();
    const pause = iconButton("Ⅱ", 120);
    pause.label = "btn-pause";
    pause.position.set(W - 100, top + 110);
    pause.onTap = () => this.showPause();
    const title = label(t("stage", { n: levelNo }), 56);
    title.position.set(W / 2, top + 88);
    const name = label(this.level.meta?.name?.[getLang()] ?? this.level.id, 36, C.inkSoft, { fontWeight: "500" });
    name.position.set(W / 2, top + 150);
    this.view.addChild(back, pause, title, name);

    // 보드: 화면 위쪽, 가로 최대 1000
    const boardTop = top + 210;
    const laneBottom = bottom - 230;
    const boardMax = Math.max(500, Math.min(1000, laneBottom - boardTop - 820));
    this.board = new BoardView(this.level, 1040, boardMax);
    const boardY = boardTop + this.board.outerH / 2;
    this.board.position.set(W / 2, boardY);
    const boardBottom = boardTop + this.board.outerH;

    // 활성 슬롯: 보드 바로 아래 가로 한 줄 (보드 영역을 침범하지 않음)
    const slotR = 78;
    const slotY = boardBottom + 40 + slotR;
    const slots = Array.from({ length: this.level.slotCount }, (_, i) => ({ x: W / 2 + (i - (this.level.slotCount - 1) / 2) * 210, y: slotY }));

    // 대기열: 세로 줄 여러 개. 줄마다 맨 위가 탭할 물방울
    const n = this.level.lanes.length;
    const laneW = Math.min(240, (W - 120) / n - 24);
    const gap = Math.min(270, (W - 120) / n);
    const layout: DropLayout = {
      slots, slotR,
      laneTop: slotY + slotR + 210,
      laneBottom,
      laneXs: Array.from({ length: n }, (_, i) => W / 2 + (i - (n - 1) / 2) * gap),
      laneW,
    };
    this.drops = new DropView(this.level, layout, this.controller.options.visible);
    this.drops.onTap = (lane) => this.tap(lane);
    this.wave = new WavePlayer(this.level, this.board, this.drops);
    this.wave.fast = settings.fastFx;
    this.view.addChild(this.board, this.drops, this.wave.fx);

    this.msg = label("", 40, C.inkSoft, { fontWeight: "600" });
    this.msg.position.set(W / 2, slotY + slotR + 60);
    this.view.addChild(this.msg);

    // 하단 버튼
    const by = bottom - 110;
    this.undoBtn = new Button(t("undo"), { w: 300, h: 120, color: C.panel, textColor: C.ink, size: 42, id: "btn-undo" });
    this.undoBtn.position.set(W / 2 - 330, by);
    this.undoBtn.onTap = () => this.undo();
    const hint = new Button(t("hint"), { w: 300, h: 120, color: C.panel, textColor: C.ink, size: 42, id: "btn-hint" });
    hint.position.set(W / 2, by);
    hint.onTap = () => this.hint();
    const restart = new Button(t("restart"), { w: 300, h: 120, color: C.panel, textColor: C.ink, size: 42, id: "btn-restart" });
    restart.position.set(W / 2 + 330, by);
    restart.onTap = () => this.restart();
    this.view.addChild(this.undoBtn, hint, restart);

    this.controller.listen({
      tick: (ev, c) => { this.wave.play(ev, c.tickMs); this.drops.sync(c.state); this.refresh(); },
      deploy: (slot, _d, lane, c) => { sfx.tap(); this.drops.fly(slot, lane, c.state); this.refresh(); },
      idle: () => { sfx.resetPitch(); this.drops.bounceFront(); this.refresh(); },
      reset: (c) => { this.wave.clear(); this.board.sync(c.state); this.board.dim(false); this.drops.sync(c.state); this.closeOverlay(); this.ended = false; this.refresh(); },
      status: (s) => { if (s !== "playing") this.onEnd(s); },
    });
    this.board.sync(this.controller.state);
    this.drops.sync(this.controller.state);
    this.refresh();

    // 시작 전 안내: 어려운 스테이지 경고 → 튜토리얼 순서로 하나씩
    const diff = this.level.meta?.difficulty;
    if (diff && DIFFICULTY_ALERT[diff]) this.intro.push(`diff:${diff}`);
    const tut = TUTORIAL[levelNo - 1];
    if (tut && hasKey(`tutorial_${tut}`)) this.intro.push(`tut:${tut}`);
    this.nextIntro();
  }

  enter() { this.board.sync(this.controller.state); }

  update(dt: number) {
    this.controller.update(dt);
    this.board.update(dt);
    this.drops.update(dt);
  }

  back() {
    if (this.overlay && !this.ended) { this.resume(); return true; }
    this.toMap();
    return true;
  }

  pause() { if (!this.ended && !this.overlay) this.showPause(); }

  // ---------- 입력 ----------
  tap(lane: number) {
    if (this.overlay) return;
    const r = this.controller.tap(lane);
    if (!r.ok) {
      if (r.reason === "full") { this.drops.shake(); sfx.deny(); }
      if (r.reason === "wait") sfx.deny();
    }
  }

  undo() {
    if (!this.controller.undo()) return;
    this.closeOverlay();
    this.showPause(); // 되돌리면 일시정지 상태로 시작
  }

  restart() { this.controller.restart(); }

  hint() {
    if (this.ended) return;
    const h = this.controller.hint();
    const text = h.action === "tap" ? t("hintTap") : h.action === "wait" ? t("hintWait")
      : h.result.solvable === false ? t("hintNone") : t("hintSlow");
    this.flash(text, h.action === "tap" ? C.accentDark : C.ink);
    if (h.action === "tap") this.drops.bounceLane(h.lane);
  }

  // ---------- 표시 ----------
  private refresh() {
    const c = this.controller;
    this.undoBtn.enabled = c.canUndo;
  }

  private flash(text: string, color: number) {
    this.msg.text = text;
    this.msg.style.fill = color;
    tweens.cancel(this.msg);
    tweens.add(2200, (k) => { this.msg.alpha = k < 0.8 ? 1 : 1 - (k - 0.8) / 0.2; }, { ease: ease.linear, owner: this.msg });
  }

  private closeOverlay() {
    if (!this.overlay) return;
    this.overlay.destroy({ children: true });
    this.overlay = null;
  }

  private openOverlay(o: Overlay) {
    this.closeOverlay();
    this.overlay = o;
    this.view.addChild(o);
  }

  private resume() {
    this.closeOverlay();
    if (this.nextIntro()) return;
    this.controller.resume();
  }

  /** 남은 시작 안내를 하나 띄운다. 띄웠으면 true */
  private nextIntro(): boolean {
    const item = this.intro.shift();
    if (!item) return false;
    const [kind, key] = item.split(":");
    if (kind === "diff") this.showDifficulty(key as Difficulty);
    else this.showTutorial(key);
    return true;
  }

  /** Hard / Super Hard / Mega Hard 스테이지는 시작 전에 난이도 경고창 */
  private showDifficulty(d: Difficulty) {
    const a = DIFFICULTY_ALERT[d];
    if (!a) return;
    this.controller.pause();
    const o = new Overlay(W, H, 860, 700, `overlay-difficulty-${d}`);
    const badge = new Container();
    const name = label(t(a.key), 92, 0xffffff, { fontWeight: "900" });
    const bg = new Button("", { w: Math.max(420, name.width + 120), h: 170, color: a.color, radius: 85 });
    bg.eventMode = "none";
    badge.addChild(bg, name);
    badge.y = -170;
    const sub = label(t("diffSub"), 40, C.inkSoft, { fontWeight: "500", wordWrap: true, wordWrapWidth: 760, lineHeight: 60 });
    sub.y = 20;
    const ok = new Button(t("diffStart"), { w: 520, color: a.color, id: "btn-difficulty-ok" });
    ok.y = 200;
    ok.onTap = () => this.resume();
    o.box.addChild(badge, sub, ok);
    this.openOverlay(o);
    // 배지가 살짝 커졌다 돌아온다
    tweens.add(600, (k) => badge.scale.set(1 + 0.12 * Math.sin(k * Math.PI)), { delay: 150, ease: ease.linear, owner: o });
  }

  private showPause() {
    if (this.ended) return;
    this.controller.pause();
    const o = new Overlay(W, H, 760, 760, "overlay-pause");
    const title = label(t("pause"), 64);
    title.y = -250;
    const b1 = new Button(t("resume"), { w: 560, id: "btn-resume" });
    b1.y = -80;
    b1.onTap = () => this.resume();
    const b2 = new Button(t("restart"), { w: 560, color: C.panel, textColor: C.ink, id: "btn-pause-restart" });
    b2.y = 80;
    b2.onTap = () => this.restart();
    const b3 = new Button(t("map"), { w: 560, color: C.bgDeep, textColor: C.ink, id: "btn-pause-map" });
    b3.y = 240;
    b3.onTap = () => this.toMap();
    o.box.addChild(title, b1, b2, b3);
    this.openOverlay(o);
  }

  private showTutorial(key: string) {
    const k = `tutorial_${key}`;
    if (!hasKey(k)) { this.resume(); return; }
    this.controller.pause();
    const o = new Overlay(W, H, 920, 640, "overlay-tutorial");
    const drop = new Sprite(TEX.drop);
    drop.anchor.set(0.5);
    drop.width = drop.height = 120;
    drop.tint = C.water;
    drop.y = -200;
    const text = label(t(k), 40, C.ink, { fontWeight: "500", wordWrap: true, wordWrapWidth: 820, lineHeight: 62 });
    text.y = -10;
    const ok = new Button(t("tapToStart"), { w: 520, id: "btn-tutorial-ok" });
    ok.y = 220;
    ok.onTap = () => this.resume();
    o.box.addChild(drop, text, ok);
    this.openOverlay(o);
  }

  private async onEnd(status: "cleared" | "failed") {
    if (this.ended) return;
    this.ended = true;
    if (status === "cleared") {
      sfx.clear();
      hapticSuccess();
      this.board.celebrate();
      this.petals();
      await this.ctx.save.recordClear(this.level.id, this.levelNo, this.ctx.levels.length);
      setTimeout(() => { if (this.ended && !this.view.destroyed) this.showClear(); }, this.wave.fast ? 700 : 1800);
    } else {
      sfx.fail();
      hapticFail();
      this.drops.failFx();
      this.board.dim(true);
      setTimeout(() => { if (this.ended && !this.view.destroyed) this.showFail(); }, 800);
    }
  }

  /** 완성 화면: Full Bloom 연출 + 완성 여부만 (별점 없음). 이 화면을 떠날 때 광고 1회 (실패 시에는 없음) */
  private showClear() {
    const o = new Overlay(W, H, 860, 1180, "overlay-clear");
    const glow = new Container();
    glow.y = -230;
    const rays = new Sprite(TEX.glow);
    rays.anchor.set(0.5);
    rays.width = rays.height = 700;
    rays.tint = C.gold;
    rays.alpha = 0.55;
    glow.addChild(rays);
    const fb = label(t("fullBloom"), 84, C.accentDark, { fontWeight: "900", letterSpacing: 4 });
    fb.y = -500;
    fb.label = "full-bloom";
    const art = artGraphic(this.level, 440);
    art.y = -230;
    const done = label(t("cleared"), 60, C.ink);
    done.y = 50;
    const name = label(this.level.meta?.name?.[getLang()] ?? "", 40, C.inkSoft, { fontWeight: "600" });
    name.y = 125;
    o.box.addChild(glow, fb, art, done, name);
    tweens.add(2400, (k) => { rays.rotation = k * Math.PI; rays.alpha = 0.35 + 0.25 * Math.sin(k * Math.PI * 2); }, { ease: ease.linear, owner: o });
    tweens.add(500, (k) => fb.scale.set(0.6 + 0.4 * k), { delay: 100, ease: ease.outBack, owner: o });
    let y = 280;
    if (this.levelNo < this.ctx.levels.length) {
      const next = new Button(t("next"), { w: 600, id: "btn-next" });
      next.y = y;
      next.onTap = () => this.leaveClear(() => this.ctx.replace(new GameScene(this.ctx, this.levelNo + 1)));
      o.box.addChild(next);
      y += 160;
    }
    const retry = new Button(t("retry"), { w: 290, color: C.panel, textColor: C.ink, size: 40, id: "btn-retry" });
    retry.position.set(-155, y);
    retry.onTap = () => this.leaveClear(() => this.restart());
    const map = new Button(t("map"), { w: 290, color: C.bgDeep, textColor: C.ink, size: 40, id: "btn-map" });
    map.position.set(155, y);
    map.onTap = () => this.leaveClear(() => this.toMap());
    o.box.addChild(retry, map);
    this.openOverlay(o);
  }

  /** 완성 화면에서 나갈 때: 광고(광고 제거 구매 시 건너뜀)가 끝난 뒤 이동 */
  private async leaveClear(go: () => void) {
    if (this.leaving) return;
    this.leaving = true;
    try { await afterClearAd(this.ctx.save.data.noAds); } catch { /* 광고 실패는 무시 */ }
    this.leaving = false;
    if (!this.view.destroyed) go();
  }

  private showFail() {
    const o = new Overlay(W, H, 860, 820, "overlay-fail");
    const title = label(t("failed"), 64, C.warn);
    title.y = -280;
    const sub = label(t("failedSub"), 36, C.inkSoft, { fontWeight: "500", wordWrap: true, wordWrapWidth: 760 });
    sub.y = -190;
    const retry = new Button(t("retry"), { w: 600, id: "btn-retry" });
    retry.y = -40;
    retry.onTap = () => this.restart();
    const undo = new Button(t("undo"), { w: 600, color: C.panel, textColor: C.ink, id: "btn-fail-undo" });
    undo.y = 120;
    undo.enabled = this.controller.canUndo;
    undo.onTap = () => this.undo();
    const map = new Button(t("map"), { w: 600, color: C.bgDeep, textColor: C.ink, id: "btn-map" });
    map.y = 280;
    map.onTap = () => this.toMap();
    o.box.addChild(title, sub, retry, undo, map);
    this.openOverlay(o);
  }

  private petals() {
    if (this.wave.fast) return;
    const colors = this.level.palette.map((p) => parseInt(p.slice(1), 16));
    for (let k = 0; k < 40; k++) {
      const s = new Sprite(TEX.petal);
      s.anchor.set(0.5);
      s.width = 40; s.height = 22;
      s.tint = colors[k % colors.length];
      const x0 = this.board.x + (Math.random() - 0.5) * this.board.boardW;
      const y0 = this.board.y - this.board.boardH / 2 - 40;
      s.position.set(x0, y0);
      this.view.addChild(s);
      const dx = (Math.random() - 0.5) * 400, dy = 500 + Math.random() * 500, rot = (Math.random() - 0.5) * 8;
      tweens.add(1400, (v) => { s.position.set(x0 + dx * v + Math.sin(v * 9 + k) * 30, y0 + dy * v); s.rotation = rot * v; s.alpha = 1 - v; },
        { delay: k * 18, ease: ease.linear, done: () => s.destroy() });
    }
  }

  private toMap() {
    this.controller.pause();
    // 맵이 스택 아래에 있으면 돌아가고, 아니면 맵으로 교체
    if (this.ctx.current === this && !this.ctx.pop()) this.ctx.replace(new StageMapScene(this.ctx));
  }
}

