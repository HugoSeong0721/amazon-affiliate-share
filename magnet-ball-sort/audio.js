// WebAudio 신시사이저 — 오디오 파일 없이 코드로만 효과음을 만든다.
// 모바일 정책상 첫 사용자 제스처에서 컨텍스트가 열린다.

const STORAGE_MUTED = 'mbs.muted';

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
      g.gain.linearRampToValueAtTime(gain, t0 + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0008, t0 + dur);
      osc.connect(g).connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + dur + 0.05);
    } catch {}
  }

  _click({ dur = 0.05, freq = 2200, gain = 0.13, delay = 0 } = {}) {
    if (this.muted) return;
    const ctx = this.ctx;
    if (!ctx) return;
    try {
      const t0 = ctx.currentTime + delay;
      const len = Math.max(1, Math.floor(ctx.sampleRate * dur));
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.frequency.value = freq;
      filter.Q.value = 1.4;
      const g = ctx.createGain();
      g.gain.setValueAtTime(gain, t0);
      g.gain.exponentialRampToValueAtTime(0.0008, t0 + dur);
      src.connect(filter).connect(g).connect(ctx.destination);
      src.start(t0);
    } catch {}
  }

  // 진동. 안드로이드 크롬은 지원하고 iOS 사파리는 무시한다 — 있으면 손맛이 확 올라간다.
  buzz(pattern) {
    if (this.muted) return;
    try {
      navigator.vibrate?.(pattern);
    } catch {}
  }

  // 자석에 붙는 소리: 짧은 저음 툭 + 금속성 딸깍
  pick(count) {
    this._tone(180, { type: 'sine', dur: 0.09, gain: 0.08, slide: 90 });
    for (let i = 0; i < Math.min(count, 4); i++) {
      this._click({ freq: 2600 + i * 220, gain: 0.06, delay: 0.02 * i });
    }
    this.buzz(9);
  }

  // 구슬 하나가 착지하는 소리. 튜브가 찰수록 음이 올라간다 — 쌓이는 쾌감의 핵심.
  land(slotIndex) {
    const scale = [523, 587, 659, 784, 880, 988];
    const pitch = scale[Math.min(slotIndex, scale.length - 1)];
    this._click({ freq: 1900 + slotIndex * 260, gain: 0.1, dur: 0.035 });
    this._tone(pitch, { type: 'triangle', dur: 0.08, gain: 0.07 });
    this._tone(pitch / 2, { type: 'sine', dur: 0.06, gain: 0.05 });
    this.buzz(12);
  }

  complete() {
    this._tone(880, { type: 'triangle', dur: 0.13, gain: 0.09 });
    this._tone(1320, { type: 'triangle', dur: 0.2, gain: 0.08, delay: 0.07 });
    this.buzz([0, 26, 40, 26]);
  }

  win() {
    [523, 659, 784, 1047].forEach((f, i) =>
      this._tone(f, { type: 'triangle', dur: 0.26, gain: 0.11, delay: i * 0.09 })
    );
    this.buzz([0, 40, 60, 40, 60, 70]);
  }

  error() {
    this._tone(140, { type: 'square', dur: 0.09, gain: 0.05 });
    this.buzz(24);
  }
}
