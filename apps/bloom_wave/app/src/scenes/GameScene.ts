// 게임 화면: 상단 바 / 좌우 슬롯 + 보드 / 대기열 / 하단 버튼 (01 기획서 3장 화면 배치)
import { Container, Sprite, Text } from "pixi.js";
import type { Level } from "@bloom-wave/core/engine";
import type { Ctx, Scene } from "../app";
import { GameController, TICK_MS } from "../game/GameController";
import { BoardView } from "../game/BoardView";
import { DropView } from "../game/DropView";
import { WavePlayer } from "../game/WavePlayer";
import { C, W, H } from "../ui/theme";
import { Button, Overlay, iconButton, label, stars } from "../ui/widgets";
import { tweens, ease } from "../ui/tween";
import { TEX } from "../ui/textures";
import { artGraphic } from "../ui/art";
import { t, hasKey, getLang } from "../i18n/i18n";
import { sfx } from "../audio/audio";
import { hapticFail, hapticSuccess } from "../platform";
import { StageMapScene } from "./StageMapScene";

const TUTORIAL = ["wave", "colors", "realtime", "waiting", "slots"];

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

    // 보드와 슬롯
    const boardY = top + 760;
    this.board = new BoardView(this.level, 700, 760);
    this.board.position.set(W / 2, boardY);
    const slotPos = [
      { x: 90, y: boardY - 210 }, { x: 90, y: boardY + 210 },
      { x: W - 90, y: boardY - 210 }, { x: W - 90, y: boardY + 210 },
    ];
    const queueY = Math.min(boardY + 700, bottom - 520);
    this.drops = new DropView(this.level, slotPos, queueY, 60, W - 160);
    this.drops.onTapFront = () => this.tapFront();
    this.wave = new WavePlayer(this.level, this.board, this.drops);
    this.wave.fast = settings.fastFx;
    this.view.addChild(this.board, this.drops, this.wave.fx);

    this.msg = label("", 40, C.inkSoft, { fontWeight: "600" });
    this.msg.position.set(W / 2, queueY - 175);
    this.view.addChild(this.msg);

    // 하단 버튼
    const by = Math.min(queueY + 330, bottom - 130);
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
      deploy: (slot, _d, c) => { sfx.tap(); this.drops.fly(slot, c.state); this.refresh(); },
      idle: () => { sfx.resetPitch(); this.drops.bounceFront(); this.refresh(); },
      reset: (c) => { this.wave.clear(); this.board.sync(c.state); this.board.dim(false); this.drops.sync(c.state); this.closeOverlay(); this.ended = false; this.refresh(); },
      status: (s) => { if (s !== "playing") this.onEnd(s); },
    });
    this.board.sync(this.controller.state);
    this.drops.sync(this.controller.state);
    this.refresh();

    const tut = TUTORIAL[levelNo - 1];
    if (tut) this.showTutorial(tut);
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
  tapFront() {
    if (this.overlay) return;
    const r = this.controller.tapFront();
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
    if (h.action === "tap") this.drops.bounceFront();
  }

  // ---------- 표시 ----------
  private refresh() {
    const c = this.controller;
    this.undoBtn.enabled = c.canUndo;
    if (c.status !== "playing") { this.board.highlight(null); return; }
    const f = c.front;
    this.board.highlight(f && c.frontUsable() ? f.color : null);
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

  private resume() { this.closeOverlay(); this.controller.resume(); }

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
    if (!hasKey(k)) return;
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
    this.board.highlight(null);
    const n = this.controller.stars();
    if (status === "cleared") {
      sfx.clear();
      hapticSuccess();
      this.board.celebrate();
      this.petals();
      await this.ctx.save.recordClear(this.level.id, this.levelNo, n, this.ctx.levels.length);
      setTimeout(() => { if (this.ended && !this.view.destroyed) this.showClear(n); }, this.wave.fast ? 500 : 1500);
    } else {
      sfx.fail();
      hapticFail();
      this.drops.failFx();
      this.board.dim(true);
      setTimeout(() => { if (this.ended && !this.view.destroyed) this.showFail(); }, 800);
    }
  }

  private showClear(n: number) {
    const o = new Overlay(W, H, 860, 1240, "overlay-clear");
    const title = label(t("cleared"), 76, C.accentDark);
    title.y = -520;
    const art = artGraphic(this.level, 420);
    art.y = -230;
    const name = label(this.level.meta?.name?.[getLang()] ?? "", 44, C.inkSoft);
    name.y = 20;
    const st = stars(n, 100, 24);
    st.y = 140;
    st.label = `stars-${n}`;
    o.box.addChild(title, art, name, st);
    let y = 300;
    if (this.levelNo < this.ctx.levels.length) {
      const next = new Button(t("next"), { w: 600, id: "btn-next" });
      next.y = y;
      next.onTap = () => this.ctx.replace(new GameScene(this.ctx, this.levelNo + 1));
      o.box.addChild(next);
      y += 160;
    }
    const retry = new Button(t("retry"), { w: 290, color: C.panel, textColor: C.ink, size: 40, id: "btn-retry" });
    retry.position.set(-155, y);
    retry.onTap = () => this.restart();
    const map = new Button(t("map"), { w: 290, color: C.bgDeep, textColor: C.ink, size: 40, id: "btn-map" });
    map.position.set(155, y);
    map.onTap = () => this.toMap();
    o.box.addChild(retry, map);
    this.openOverlay(o);
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

