// 신시사이저 효과음 — 오디오 파일 없이 코드로만 만든다.
// 형제 게임들의 Sound와 같은 뼈대지만, 소리의 결이 다르다:
// 딸깍·퐁 같은 '장난감' 소리 대신 휘익·지잉·쿵 같은 '속도'의 소리다.
//
// 재생 경로가 둘이다:
//   1) WebAudio (기본) — 지연이 가장 짧다
//   2) HTML5 <audio> (iOS) — **아이폰 무음 스위치가 WebAudio를 통째로 죽이기 때문에**
//      같은 레시피를 OfflineAudioContext로 미리 WAV로 구워 두고 <audio>로 튼다.
//      <audio>는 미디어 채널이라 무음 스위치에 막히지 않는다.
// 레시피는 한 벌만 쓴다 — 두 경로가 같은 소리를 낸다.

const STORAGE_MUTED = 'cms.muted';
const MASTER = 2.4;   // 전체 음량 — 개별 레시피는 그대로 두고 여기서 키운다
const POOL = 3;       // 효과음당 <audio> 개수 (겹쳐 울릴 수 있게)

const isIOS = () =>
  typeof navigator !== 'undefined' &&
  (/iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1));

// 레시피 — voice(v)는 컨텍스트에 독립적인 두 가지 붓만 쓴다.
// v.tone(주파수, 옵션) · v.noise(옵션). 시간은 항상 t0 기준 상대값.
const RECIPES = {
  // 출발 — 낮은 곳에서 치솟는 휘익
  launch: (v) => {
    v.noise({ dur: 0.35, gain: 0.1, freq: 500, q: 0.8 });
    v.tone(160, { type: 'sawtooth', dur: 0.32, gain: 0.05, slide: 420 });
  },
  // 앵커에 딱 붙는 순간 — 짧고 단단한 저음 + 자기장 울림
  latch: (v) => {
    v.tone(110, { type: 'square', dur: 0.06, gain: 0.1 });
    v.tone(330, { type: 'sine', dur: 0.18, gain: 0.05, delay: 0.02 });
  },
  // 놓는 순간 — 위로 감기는 지잉
  release: (v) => {
    v.tone(220, { type: 'sawtooth', dur: 0.16, gain: 0.06, slide: 500 });
    v.noise({ dur: 0.14, gain: 0.05, freq: 1800, q: 1.5 });
  },
  // 니어미스 — 밝은 반짝
  spark: (v) => {
    v.tone(1500, { type: 'sine', dur: 0.09, gain: 0.09 });
    v.tone(2100, { type: 'sine', dur: 0.1, gain: 0.06, delay: 0.045 });
  },
  // 죽음 — 부딪힘은 묵직하게
  crashHard: (v) => {
    v.noise({ dur: 0.4, gain: 0.22, freq: 220, q: 0.7 });
    v.tone(70, { type: 'square', dur: 0.3, gain: 0.12 });
  },
  // 죽음 — 추락은 아래로 흘러내리게
  crashFall: (v) => {
    v.tone(500, { type: 'sine', dur: 0.5, gain: 0.09, slide: -420 });
  },
  // 최고 기록 갱신
  fanfare: (v) => {
    [523, 659, 784, 1047].forEach((f, i) =>
      v.tone(f, { type: 'triangle', dur: 0.16, gain: 0.09, delay: i * 0.09 })
    );
  },
};

// 레시피가 차지하는 최대 길이(초) — 오프라인 렌더 버퍼 크기용
const RECIPE_SECONDS = 0.75;

// 컨텍스트(라이브/오프라인 공용)에 레시피를 그리는 붓
function makeVoice(ctx, destination, t0) {
  return {
    tone(freq, { type = 'sine', dur = 0.12, gain = 0.1, delay = 0, slide = 0 } = {}) {
      const t = t0 + delay;
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, t);
      if (slide) osc.frequency.exponentialRampToValueAtTime(Math.max(40, freq + slide), t + dur);
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(gain, t + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
      osc.connect(g).connect(destination);
      osc.start(t);
      osc.stop(t + dur + 0.05);
    },
    noise({ dur = 0.3, gain = 0.18, freq = 800, delay = 0, q = 1 } = {}) {
      const t = t0 + delay;
      const len = Math.ceil(ctx.sampleRate * dur);
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const filt = ctx.createBiquadFilter();
      filt.type = 'bandpass';
      filt.frequency.setValueAtTime(freq, t);
      filt.Q.value = q;
      const g = ctx.createGain();
      g.gain.setValueAtTime(gain, t);
      g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
      src.connect(filt).connect(g).connect(destination);
      src.start(t);
    },
  };
}

// AudioBuffer → 16bit PCM WAV data URI
function bufferToWavUri(buf) {
  const ch = buf.getChannelData(0);
  const n = ch.length;
  const bytes = new Uint8Array(44 + n * 2);
  const view = new DataView(bytes.buffer);
  const str = (off, s) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)); };
  str(0, 'RIFF');
  view.setUint32(4, 36 + n * 2, true);
  str(8, 'WAVEfmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);          // PCM
  view.setUint16(22, 1, true);          // mono
  view.setUint32(24, buf.sampleRate, true);
  view.setUint32(28, buf.sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  str(36, 'data');
  view.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) {
    const s = Math.max(-1, Math.min(1, ch[i]));
    view.setInt16(44 + i * 2, s < 0 ? s * 0x8000 : s * 0x7fff, true);
  }
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return 'data:audio/wav;base64,' + btoa(bin);
}

export class Sound {
  constructor({ forceHtml5 = false } = {}) {
    this.muted = localStorage.getItem(STORAGE_MUTED) === '1';
    this._ctx = null;
    // iOS는 무음 스위치가 WebAudio를 죽이므로 <audio> 경로를 쓴다
    this.useHtml5 = forceHtml5 || isIOS();
    this._pools = null;
    if (this.useHtml5) this._prerender();
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

  // 레시피들을 WAV로 미리 구워 <audio> 풀에 담는다 (제스처 없이도 가능)
  async _prerender() {
    const OfflineCtx = window.OfflineAudioContext || window.webkitOfflineAudioContext;
    if (!OfflineCtx) { this.useHtml5 = false; return; }
    const pools = {};
    try {
      for (const [name, recipe] of Object.entries(RECIPES)) {
        const rate = 44100;
        const ctx = new OfflineCtx(1, Math.ceil(rate * RECIPE_SECONDS), rate);
        const master = ctx.createGain();
        master.gain.value = MASTER;
        master.connect(ctx.destination);
        recipe(makeVoice(ctx, master, 0));
        const uri = bufferToWavUri(await ctx.startRendering());
        pools[name] = { i: 0, els: Array.from({ length: POOL }, () => {
          const a = new Audio(uri);
          a.preload = 'auto';
          return a;
        }) };
      }
      this._pools = pools;
    } catch {
      this.useHtml5 = false; // 굽기 실패 — WebAudio로 되돌린다
    }
  }

  _play(name) {
    if (this.muted) return;
    if (this.useHtml5 && this._pools && this._pools[name]) {
      const pool = this._pools[name];
      const el = pool.els[pool.i];
      pool.i = (pool.i + 1) % pool.els.length;
      try {
        el.currentTime = 0;
        el.play().catch(() => {});
      } catch {}
      return;
    }
    const ctx = this.ctx;
    if (!ctx) return;
    try {
      const master = ctx.createGain();
      master.gain.value = MASTER;
      master.connect(ctx.destination);
      RECIPES[name](makeVoice(ctx, master, ctx.currentTime));
    } catch {}
  }

  launch() { this._play('launch'); }
  latch() { this._play('latch'); }
  release() { this._play('release'); }
  spark() { this._play('spark'); }
  fanfare() { this._play('fanfare'); }
  crash(cause) { this._play(cause === 'fell' ? 'crashFall' : 'crashHard'); }

  // 첫 제스처에서 오디오를 미리 깨워 둔다 — 런 시작 프레임의 버벅임 방지.
  // <audio> 경로에서는 이 제스처 안에서 한 번 재생해 둬야 이후 재생이 허용된다.
  warm() {
    if (this.useHtml5) {
      if (!this._pools) return;
      for (const pool of Object.values(this._pools)) {
        const el = pool.els[0];
        try {
          const v = el.volume;
          el.volume = 0;
          el.play().then(() => {
            el.pause();
            el.currentTime = 0;
            el.volume = v;
          }).catch(() => { el.volume = v; });
        } catch {}
      }
      return;
    }
    const ctx = this.ctx;
    if (!ctx) return;
    try {
      const buf = ctx.createBuffer(1, 1, 22050);
      const src = ctx.createBufferSource();
      src.buffer = buf;
      src.connect(ctx.destination);
      src.start(0);
    } catch {}
  }
}
