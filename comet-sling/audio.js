// 신시사이저 효과음 — 오디오 파일 없이 코드로만 만든다.
// 형제 게임들의 Sound와 같은 뼈대지만, 소리의 결이 다르다:
// 딸깍·퐁 같은 '장난감' 소리 대신 휘익·지잉·쿵 같은 '속도'의 소리다.
//
// 효과음은 전부 WebAudio 한 경로다 — 지연이 가장 짧고, 재생이 메인 스레드를
// 건드리지 않는다. (한때 iOS에서 효과음마다 <audio>를 재생하는 경로를 뒀는데,
// 사파리의 미디어 파이프라인이 재생마다 메인 스레드를 잡아 미세한 끊김을 만들었다.)
//
// 아이폰 무음 스위치는 WebAudio를 통째로 죽이는데, 해법은 재생 경로를 바꾸는 게
// 아니라 오디오 세션을 바꾸는 것이다: 첫 제스처에서 '무음 루프' <audio>를 하나
// 틀어 두면 사파리가 미디어 재생 모드로 전환되고, 그 뒤로는 WebAudio도 무음
// 스위치를 무시하고 들린다. (unmute.js 등이 쓰는 널리 알려진 기법)

const STORAGE_MUTED = 'cms.muted';
const MASTER = 2.4; // 전체 음량 — 개별 레시피는 그대로 두고 여기서 키운다

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

// 잡음원(1초)은 컨텍스트당 한 번만 만들어 돌려 쓴다.
// 소리마다 새로 채우면 재생 순간에 난수 1만5천 개를 만드느라 프레임이 튄다.
const noiseCache = new WeakMap();
function sharedNoise(ctx) {
  let buf = noiseCache.get(ctx);
  if (buf) return buf;
  const len = Math.ceil(ctx.sampleRate);
  buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
  noiseCache.set(ctx, buf);
  return buf;
}

// 컨텍스트에 레시피를 그리는 붓
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
      const buf = sharedNoise(ctx);
      const src = ctx.createBufferSource();
      src.buffer = buf;
      // 같은 잡음원을 임의 지점부터 잘라 쓰므로 매번 다르게 들린다
      const offset = Math.random() * Math.max(0, buf.duration - dur);
      const filt = ctx.createBiquadFilter();
      filt.type = 'bandpass';
      filt.frequency.setValueAtTime(freq, t);
      filt.Q.value = q;
      const g = ctx.createGain();
      g.gain.setValueAtTime(gain, t);
      g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
      src.connect(filt).connect(g).connect(destination);
      src.start(t, offset, dur);
    },
  };
}

// 무음 루프용 WAV data URI — 헤더 + 0으로 채운 표본. 코드로 만들면 파일이 필요 없다.
function silentWavUri(seconds = 0.2, rate = 8000) {
  const n = Math.ceil(seconds * rate);
  const bytes = new Uint8Array(44 + n * 2); // data 구간은 0(무음)으로 남는다
  const view = new DataView(bytes.buffer);
  const str = (off, s) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)); };
  str(0, 'RIFF');
  view.setUint32(4, 36 + n * 2, true);
  str(8, 'WAVEfmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  str(36, 'data');
  view.setUint32(40, n * 2, true);
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
    this._warmed = false;
    // iOS: 무음 스위치가 WebAudio를 죽인다 → 무음 루프로 세션을 미디어 모드로 바꾼다.
    // (?html5audio 는 이 우회를 아무 데서나 켜 보는 테스트 스위치로 남겨 둔다)
    this._needKeepAlive = forceHtml5 || isIOS();
    this._keepAliveEl = null;
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

  // 오디오 장치를 미리 연다 — 이게 이 파일에서 가장 비싼 한 번(폰에서 100ms 이상)이다.
  // 누르는 순간에 열면 그게 곧 "홀드할 때 처음 끊김"이 되므로, 로딩 직후에 열어 둔다.
  // 컨텍스트 '생성'은 제스처가 필요 없고, '재생'만 제스처가 필요하다.
  prime() {
    const ctx = this.ctx;
    if (ctx) try { sharedNoise(ctx); } catch {} // 잡음원도 지금 만들어 둔다
  }

  // 첫 제스처에서 딱 한 번:
  //  - WebAudio 재생 허가(resume)
  //  - iOS면 무음 루프를 시작해 무음 스위치를 우회
  warm() {
    if (this._warmed) return;
    this._warmed = true;
    this.ctx; // getter가 resume까지 처리한다
    if (this._needKeepAlive) {
      try {
        const el = new Audio(silentWavUri());
        el.loop = true;
        el.play().catch(() => {});
        this._keepAliveEl = el;
      } catch {}
    }
  }

  _play(name) {
    if (this.muted) return;
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
}
