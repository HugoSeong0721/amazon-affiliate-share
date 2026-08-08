// WebAudio 신시사이저 — 오디오 파일 없이 코드로만 효과음을 만든다.
// 이 게임의 소리는 '음악'에 가깝다: 쌓을 때마다 펜타토닉 음계를 한 계단씩 올라간다.
// 잘 쌓을수록 멜로디가 높아지고, 퍼펙트는 화음으로 보상한다.

const STORAGE_MUTED = 'sky.muted';

// C 메이저 펜타토닉 — 어떤 순서로 울려도 듣기 좋다
const SCALE = [261.63, 293.66, 329.63, 392.0, 440.0];

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

  _note(floor) {
    const idx = floor % SCALE.length;
    const octave = 1 + Math.floor((floor % (SCALE.length * 3)) / SCALE.length); // 3옥타브 순환
    return SCALE[idx] * octave;
  }

  // 탁 — 블록이 얹힌다. 층수가 올라갈수록 음도 올라간다
  place(floor) {
    this._tone(this._note(floor), { type: 'triangle', dur: 0.14, gain: 0.11 });
  }

  // 반짝 — 퍼펙트. 그 층의 음 위로 장3도·5도 화음
  perfect(floor, combo) {
    const f = this._note(floor);
    this._tone(f, { type: 'triangle', dur: 0.2, gain: 0.12 });
    this._tone(f * 1.26, { type: 'sine', dur: 0.22, gain: 0.09, delay: 0.03 });
    this._tone(f * 1.5, { type: 'sine', dur: 0.26, gain: 0.08, delay: 0.06 });
    if (combo >= 3) this._tone(f * 2, { type: 'sine', dur: 0.3, gain: 0.06, delay: 0.09 });
  }

  // 슥 — 조각이 잘려 떨어진다
  cut() {
    this._tone(520, { type: 'sawtooth', dur: 0.08, gain: 0.04, slide: -220 });
  }

  // 우르르 — 빗나갔다. 내려가는 세 음
  over() {
    this._tone(330, { type: 'triangle', dur: 0.18, gain: 0.11 });
    this._tone(262, { type: 'triangle', dur: 0.2, gain: 0.1, delay: 0.12 });
    this._tone(196, { type: 'triangle', dur: 0.34, gain: 0.1, delay: 0.24 });
  }

  // 좌르륵 — 신기록
  best() {
    [523, 659, 784, 1047].forEach((f, i) =>
      this._tone(f, { type: 'triangle', dur: 0.14, gain: 0.1, delay: i * 0.08 })
    );
  }

  // 틱 — 소소한 UI
  ui() {
    this._tone(440, { type: 'sine', dur: 0.05, gain: 0.05 });
  }

  // 가입 완료 팡파레 (게이트에서 쓴다)
  bank() {
    this.best();
  }
}
