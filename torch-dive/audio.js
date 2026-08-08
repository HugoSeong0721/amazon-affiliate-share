// WebAudio 신시사이저 — 오디오 파일 없이 코드로만 효과음을 만든다.
// 형제들의 Sound와 같은 뼈대지만 소리의 결이 또 다르다:
// 장난감의 딸깍도, 속도의 휘익도 아닌 **지하의 소리** — 동전의 쨍그랑, 낮은 북, 심장 박동.

const STORAGE_MUTED = 'tdv.muted';

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

  // 삐걱 — 문이 돌아간다
  creak() {
    this._tone(180, { type: 'triangle', dur: 0.09, gain: 0.05, slide: -60 });
  }

  // 쨍그랑 — 동전
  coin() {
    this._tone(1180, { type: 'triangle', dur: 0.1, gain: 0.11 });
    this._tone(1570, { type: 'triangle', dur: 0.14, gain: 0.08, delay: 0.05 });
  }

  // 반짝 — 보석 (동전보다 높고 길게)
  gem() {
    this._tone(1245, { type: 'sine', dur: 0.16, gain: 0.1 });
    this._tone(1661, { type: 'sine', dur: 0.18, gain: 0.09, delay: 0.07 });
    this._tone(2093, { type: 'sine', dur: 0.22, gain: 0.07, delay: 0.14 });
  }

  // 화르륵 — 등불을 줍거나 켠다
  lantern() {
    this._tone(520, { type: 'sine', dur: 0.14, gain: 0.09, slide: 260 });
  }

  // 쿵 — 한 층 내려간다
  step() {
    this._tone(105, { type: 'sine', dur: 0.13, gain: 0.12, slide: -35 });
  }

  // 두둥 — 해골. 낮고 길게, 심장이 한 번 멎는 소리
  skull() {
    this._tone(72, { type: 'sawtooth', dur: 0.5, gain: 0.14, slide: -30 });
    this._tone(54, { type: 'sine', dur: 0.65, gain: 0.16, delay: 0.05, slide: -18 });
  }

  // 좌르륵 — 챙겨 나가기. 동전 폭포는 올라가는 아르페지오
  bank() {
    [660, 880, 1100, 1320, 1570].forEach((f, i) =>
      this._tone(f, { type: 'triangle', dur: 0.12, gain: 0.1, delay: i * 0.07 })
    );
  }

  // 틱 — 소소한 UI
  ui() {
    this._tone(440, { type: 'sine', dur: 0.05, gain: 0.05 });
  }
}
