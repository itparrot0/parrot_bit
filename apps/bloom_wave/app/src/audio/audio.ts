// Web Audio로 만드는 짧은 효과음 (리소스 파일 없음). 개화음은 웨이브의 틱마다 반음씩 올라간다.
export class Sfx {
  enabled = true;
  private ctx: AudioContext | null = null;
  private step = 0; // 이번 웨이브에서 몇 번째 틱인가

  private ac(): AudioContext | null {
    if (!this.enabled) return null;
    if (!this.ctx) {
      const C = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!C) return null;
      this.ctx = new C();
    }
    if (this.ctx.state === "suspended") void this.ctx.resume();
    return this.ctx;
  }

  private tone(freq: number, dur: number, type: OscillatorType = "sine", gain = 0.12, delay = 0) {
    const ac = this.ac();
    if (!ac) return;
    const t0 = ac.currentTime + delay;
    const o = ac.createOscillator();
    const g = ac.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t0);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain, t0 + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(ac.destination);
    o.start(t0);
    o.stop(t0 + dur + 0.02);
  }

  /** 웨이브가 멈추면 음 높이를 처음으로 */
  resetPitch() { this.step = 0; }

  bloom() {
    const base = 523.25; // C5
    const f = base * Math.pow(2, Math.min(this.step, 24) / 12);
    this.step++;
    this.tone(f, 0.18, "triangle", 0.09);
  }
  tap() { this.tone(330, 0.08, "sine", 0.08); }
  deny() { this.tone(160, 0.12, "square", 0.05); }
  clear() { [0, 4, 7, 12].forEach((s, i) => this.tone(523.25 * Math.pow(2, s / 12), 0.35, "triangle", 0.1, i * 0.09)); }
  fail() { [0, -3, -7].forEach((s, i) => this.tone(220 * Math.pow(2, s / 12), 0.3, "sawtooth", 0.05, i * 0.12)); }
  click() { this.tone(660, 0.05, "sine", 0.05); }
}

export const sfx = new Sfx();
