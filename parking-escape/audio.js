// WebAudio 신시사이저 — 오디오 파일 없이 코드로만 효과음을 만든다.
// 모바일 정책상 첫 사용자 제스처에서 컨텍스트가 열린다.

const STORAGE_MUTED = 'pke.muted';

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

  // 차를 잡는 소리 — 낮게 툭
  pick() {
    this._tone(150, { type: 'sine', dur: 0.07, gain: 0.07, slide: 60 });
    this._click({ freq: 1600, gain: 0.05, dur: 0.03 });
    this.buzz(8);
  }

  // 드래그 중 칸 경계를 지날 때의 딸깍 — 손가락에 눈금이 생긴다
  detent(pos) {
    this._click({ freq: 2100 + pos * 160, gain: 0.045, dur: 0.025 });
    this.buzz(5);
  }

  // 자리에 딱 붙는 소리. 세게 던질수록 굵어진다.
  thunk(impact = 0.5) {
    const p = Math.min(1, impact);
    this._tone(120 + p * 40, { type: 'sine', dur: 0.09, gain: 0.05 + p * 0.06, slide: -50 });
    this._click({ freq: 900, gain: 0.04 + p * 0.05, dur: 0.04 });
    this.buzz(Math.round(8 + p * 10));
  }

  // 벽·차에 쿵 부딪히는 소리
  bump(speed = 0.5) {
    const p = Math.min(1, speed);
    this._tone(75, { type: 'sine', dur: 0.12, gain: 0.07 + p * 0.07, slide: -30 });
    this._click({ freq: 480, gain: 0.09, dur: 0.06 });
    this.buzz([0, 18]);
  }

  // 아예 못 움직이는 차를 밀었을 때
  stuck() {
    this._tone(140, { type: 'square', dur: 0.08, gain: 0.04 });
    this._tone(110, { type: 'square', dur: 0.1, gain: 0.04, delay: 0.09 });
    this.buzz(24);
  }

  // 출구까지 길이 뚫렸다 — 밝게 딩동. "지금 나가면 된다"는 신호.
  exitOpen() {
    this._tone(1047, { type: 'triangle', dur: 0.12, gain: 0.09 });
    this._tone(1568, { type: 'triangle', dur: 0.18, gain: 0.08, delay: 0.09 });
    this.buzz([0, 20, 30, 20]);
  }

  // 탈출! 빵빵 + 부릉
  win() {
    this._tone(440, { type: 'square', dur: 0.13, gain: 0.06 });
    this._tone(440, { type: 'square', dur: 0.2, gain: 0.07, delay: 0.18 });
    this._tone(90, { type: 'sawtooth', dur: 0.7, gain: 0.05, slide: 160, delay: 0.1 });
    [523, 659, 784, 1047].forEach((f, i) =>
      this._tone(f, { type: 'triangle', dur: 0.24, gain: 0.1, delay: 0.45 + i * 0.09 })
    );
    this.buzz([0, 40, 60, 40, 60, 70]);
  }
}
