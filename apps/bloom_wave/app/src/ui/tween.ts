// 아주 작은 트윈 엔진. Pixi Ticker 의 deltaMS 로 돈다.
export type Ease = (t: number) => number;
export const ease = {
  linear: (t: number) => t,
  outCubic: (t: number) => 1 - Math.pow(1 - t, 3),
  inOutSine: (t: number) => -(Math.cos(Math.PI * t) - 1) / 2,
  outBack: (t: number) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
};

type Tween = { delay: number; dur: number; t: number; ease: Ease; update: (v: number) => void; done?: () => void; owner?: object };

export class Tweens {
  private list: Tween[] = [];
  /** 빠른 연출: 모든 트윈 시간을 이 배율로 줄인다 */
  speed = 1;

  add(dur: number, update: (v: number) => void, opts: { delay?: number; ease?: Ease; done?: () => void; owner?: object } = {}) {
    const tw: Tween = { delay: (opts.delay ?? 0) * this.speed, dur: Math.max(1, dur * this.speed), t: 0, ease: opts.ease ?? ease.outCubic, update, done: opts.done, owner: opts.owner };
    this.list.push(tw);
    if (tw.delay <= 0) update(tw.ease(0));
    return tw;
  }

  /** owner 로 묶인 트윈을 끝까지 건너뛰거나 버린다 */
  cancel(owner: object, finish = false) {
    this.list = this.list.filter((tw) => {
      if (tw.owner !== owner) return true;
      if (finish) { tw.update(tw.ease(1)); tw.done?.(); }
      return false;
    });
  }

  clear() { this.list = []; }

  update(dt: number) {
    if (!this.list.length) return;
    const keep: Tween[] = [];
    const finished: Tween[] = [];
    for (const tw of this.list) {
      if (tw.delay > 0) { tw.delay -= dt; if (tw.delay > 0) { keep.push(tw); continue; } }
      tw.t = Math.min(1, tw.t + dt / tw.dur);
      tw.update(tw.ease(tw.t));
      if (tw.t >= 1) finished.push(tw); else keep.push(tw);
    }
    this.list = keep;
    for (const tw of finished) tw.done?.();
  }
}

export const tweens = new Tweens();
