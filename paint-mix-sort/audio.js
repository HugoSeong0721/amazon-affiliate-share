// WebAudio 신시사이저 — 오디오 파일 없이 코드로만 효과음을 만든다.
// 모바일 정책상 첫 사용자 제스처에서 컨텍스트가 열린다.

const STORAGE_MUTED = 'pms.muted';

export class Sound {
  constructor() {
    this.muted = localStorage.getItem(STORAGE_MUTED) === '1';
    this._ctx = null;
  }

  get ctx() {
    if (typeof AudioContext === 'undefined' && typeof webkitAudioContext === 'undefined') return null;
    if (!this._ctx) {
      try {
        this._ctx = new (window.AudioContext || window.webkitAudioContext)();
      } catch {
        return null;
      }
    }
    if (this._ctx.state === 'suspended') this._ctx.resume().catch(() => {});
    return this._ctx;
  }

  setMuted(m) {
    this.muted = m;
    localStorage.setItem(STORAGE_MUTED, m ? '1' : '0');
  }

  _tone(freq, { type = 'sine', dur = 0.12, gain = 0.1, delay = 0, slide = 0 } = {}) {
    if (this.muted) return;
    const ctx = this.ctx;
    if (!ctx) return;
    try {
      const t0 = ctx.currentTime + delay;
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, t0);
      if (slide) osc.frequency.exponentialRampToValueAtTime(Math.max(40, freq + slide), t0 + dur);
      g.gain.setValueAtTime(0, t0);
      g.gain.linearRampToValueAtTime(gain, t0 + 0.012);
      g.gain.exponentialRampToValueAtTime(0.0008, t0 + dur);
      osc.connect(g).connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + dur + 0.05);
    } catch {}
  }

  _noise({ dur = 0.25, from = 900, to = 300, gain = 0.16, delay = 0 } = {}) {
    if (this.muted) return;
    const ctx = this.ctx;
    if (!ctx) return;
    try {
      const t0 = ctx.currentTime + delay;
      const len = Math.max(1, Math.floor(ctx.sampleRate * dur));
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(from, t0);
      filter.frequency.exponentialRampToValueAtTime(Math.max(60, to), t0 + dur);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0, t0);
      g.gain.linearRampToValueAtTime(gain, t0 + 0.03);
      g.gain.exponentialRampToValueAtTime(0.0008, t0 + dur);
      src.connect(filter).connect(g).connect(ctx.destination);
      src.start(t0);
    } catch {}
  }

  select() {
    this._tone(540, { type: 'triangle', dur: 0.07, gain: 0.07 });
  }

  pour(amount) {
    this._noise({ dur: 0.2 + 0.08 * amount, from: 950, to: 280, gain: 0.15 });
  }

  mix() {
    this._tone(523, { type: 'triangle', dur: 0.14, gain: 0.1 });
    this._tone(659, { type: 'triangle', dur: 0.14, gain: 0.1, delay: 0.06 });
    this._tone(784, { type: 'triangle', dur: 0.22, gain: 0.12, delay: 0.12 });
  }

  complete() {
    this._tone(880, { type: 'triangle', dur: 0.13, gain: 0.09 });
    this._tone(1175, { type: 'triangle', dur: 0.2, gain: 0.08, delay: 0.07 });
  }

  win() {
    [523, 659, 784, 1047].forEach((f, i) =>
      this._tone(f, { type: 'triangle', dur: 0.26, gain: 0.11, delay: i * 0.09 })
    );
  }

  error() {
    this._tone(150, { type: 'square', dur: 0.09, gain: 0.05 });
  }
}
