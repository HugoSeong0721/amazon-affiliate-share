// WebAudio 신시사이저 — 오디오 파일 없이 코드로만 효과음을 만든다.
// 형제 게임들의 Sound와 같은 뼈대지만, 소리의 결이 다르다:
// 딸깍·퐁 같은 '장난감' 소리 대신 휘익·지잉·쿵 같은 '속도'의 소리다.

const STORAGE_MUTED = 'cms.muted';

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

  _noise({ dur = 0.3, gain = 0.18, freq = 800, delay = 0, q = 1 } = {}) {
    if (this.muted) return;
    const ctx = this.ctx;
    if (!ctx) return;
    try {
      const t0 = ctx.currentTime + delay;
      const len = Math.ceil(ctx.sampleRate * dur);
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const filt = ctx.createBiquadFilter();
      filt.type = 'bandpass';
      filt.frequency.setValueAtTime(freq, t0);
      filt.Q.value = q;
      const g = ctx.createGain();
      g.gain.setValueAtTime(gain, t0);
      g.gain.exponentialRampToValueAtTime(0.0008, t0 + dur);
      src.connect(filt).connect(g).connect(ctx.destination);
      src.start(t0);
    } catch {}
  }

  // 출발 — 낮은 곳에서 치솟는 휘익
  launch() {
    this._noise({ dur: 0.35, gain: 0.1, freq: 500, q: 0.8 });
    this._tone(160, { type: 'sawtooth', dur: 0.32, gain: 0.05, slide: 420 });
  }

  // 앵커에 딱 붙는 순간 — 짧고 단단한 저음 + 자기장 울림
  latch() {
    this._tone(110, { type: 'square', dur: 0.06, gain: 0.1 });
    this._tone(330, { type: 'sine', dur: 0.18, gain: 0.05, delay: 0.02 });
  }

  // 놓는 순간 — 위로 감기는 지잉
  release() {
    this._tone(220, { type: 'sawtooth', dur: 0.16, gain: 0.06, slide: 500 });
    this._noise({ dur: 0.14, gain: 0.05, freq: 1800, q: 1.5 });
  }

  // 니어미스 — 밝은 반짝
  spark() {
    this._tone(1500, { type: 'sine', dur: 0.09, gain: 0.09 });
    this._tone(2100, { type: 'sine', dur: 0.1, gain: 0.06, delay: 0.045 });
  }

  // 죽음 — 원인별로 무게가 다르다
  crash(cause) {
    if (cause === 'fell') {
      this._tone(500, { type: 'sine', dur: 0.5, gain: 0.09, slide: -420 });
    } else {
      this._noise({ dur: 0.4, gain: 0.22, freq: 220, q: 0.7 });
      this._tone(70, { type: 'square', dur: 0.3, gain: 0.12 });
    }
  }

  // 최고 기록 갱신
  fanfare() {
    const notes = [523, 659, 784, 1047];
    notes.forEach((f, i) => this._tone(f, { type: 'triangle', dur: 0.16, gain: 0.09, delay: i * 0.09 }));
  }
}
