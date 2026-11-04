// 타이틀: 이어하기 / 스테이지 / 정원 / 설정. 뒤로 가기는 종료 확인
import { Container } from "pixi.js";
import type { Ctx, Scene } from "../app";
import { C, W, H } from "../ui/theme";
import { Button, Overlay, label } from "../ui/widgets";
import { artGraphic } from "../ui/art";
import { t } from "../i18n/i18n";
import { exitApp } from "../platform";
import { StageMapScene } from "./StageMapScene";
import { GameScene } from "./GameScene";
import { GardenScene } from "./GardenScene";
import { SettingsScene } from "./SettingsScene";

export class TitleScene implements Scene {
  readonly name = "title";
  readonly view = new Container();
  private exitDlg: Overlay | null = null;
  private art = new Container();
  private time = 0;

  constructor(private ctx: Ctx) {
    const top = ctx.safeTop;
    const title = label(t("title"), 130, C.accentDark, { fontWeight: "800" });
    title.position.set(W / 2, top + 380);
    const sub = label(t("subtitle"), 46, C.inkSoft, { fontWeight: "500" });
    sub.position.set(W / 2, top + 500);
    this.art.position.set(W / 2, top + 940);
    this.view.addChild(title, sub, this.art);
    this.drawArt();

    const lvl = Math.min(ctx.save.data.unlocked, ctx.levels.length);
    const play = new Button(lvl > 1 ? `${t("continue")} · ${lvl}` : t("play"), { w: 680, h: 160, size: 56, id: "btn-play" });
    play.position.set(W / 2, H - ctx.safeBottom - 720);
    play.onTap = () => { ctx.push(new StageMapScene(ctx)); ctx.push(new GameScene(ctx, lvl)); };
    const map = new Button(t("stages"), { w: 680, color: C.panel, textColor: C.ink, id: "btn-stages" });
    map.position.set(W / 2, H - ctx.safeBottom - 520);
    map.onTap = () => ctx.push(new StageMapScene(ctx));
    const garden = new Button(t("garden"), { w: 330, color: C.panel, textColor: C.ink, id: "btn-garden" });
    garden.position.set(W / 2 - 175, H - ctx.safeBottom - 360);
    garden.onTap = () => ctx.push(new GardenScene(ctx));
    const settings = new Button(t("settings"), { w: 330, color: C.panel, textColor: C.ink, id: "btn-settings" });
    settings.position.set(W / 2 + 175, H - ctx.safeBottom - 360);
    settings.onTap = () => ctx.push(new SettingsScene(ctx));
    this.view.addChild(play, map, garden, settings);
  }

  /** 가장 최근에 깬 그림(없으면 첫 그림의 실루엣) */
  private drawArt() {
    this.art.removeChildren().forEach((c) => c.destroy());
    const { cleared } = this.ctx.save.data;
    const done = this.ctx.levels.filter((l) => cleared[l.id]);
    const lv = done[done.length - 1] ?? this.ctx.levels.find((l) => l.id === "tulip") ?? this.ctx.levels[0];
    this.art.addChild(artGraphic(lv, 480, { silhouette: !done.length }));
  }

  enter() { this.view.visible = true; this.drawArt(); }

  update(dt: number) {
    this.time += dt;
    this.art.y = this.ctx.safeTop + 940 + Math.sin(this.time / 900) * 14;
  }

  back() {
    if (this.exitDlg) { this.exitDlg.destroy({ children: true }); this.exitDlg = null; return true; }
    const o = new Overlay(W, H, 760, 520, "overlay-exit");
    const q = label(t("exitTitle"), 52);
    q.y = -120;
    const yes = new Button(t("exitYes"), { w: 300, color: C.warn, id: "btn-exit-yes" });
    yes.position.set(-165, 100);
    yes.onTap = () => exitApp();
    const no = new Button(t("exitNo"), { w: 300, color: C.panel, textColor: C.ink, id: "btn-exit-no" });
    no.position.set(165, 100);
    no.onTap = () => { o.destroy({ children: true }); this.exitDlg = null; };
    o.box.addChild(q, yes, no);
    this.view.addChild(o);
    this.exitDlg = o;
    return true;
  }
}
