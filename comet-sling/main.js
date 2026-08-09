// 부트스트랩 — DOM 연결, 입력(홀드/릴리즈), 루프, 리사이즈, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
import { AdManager, AD_CONFIG, createPlaceholderProvider } from './ads.js';
import { createDemoPayProvider } from './payments.js';
import { Game } from './game.js';
import { SignupGate, SIGNUP_CONFIG } from './signup.js';
import { newRun, step, WORLD, paramsAt, aim } from './engine.js';

const $ = (id) => document.getElementById(id);
const dom = {
  board: $('board'),
  scoreLabel: $('scoreLabel'),
  bestLabel: $('bestLabel'),
  btnMute: $('btnMute'),
  overlay: $('overlay'),
  overlayScore: $('overlayScore'),
  overlayBest: $('overlayBest'),
  overlayChallenge: $('overlayChallenge'),
  btnShare: $('btnShare'),
  toast: $('toast'),
  revive: $('revive'),
  reviveCount: $('reviveCount'),
  btnRevive: $('btnRevive'),
  btnNoRevive: $('btnNoRevive'),
  signup: $('signup'),
  emailForm: $('emailForm'),
  emailInput: $('emailInput'),
  skipBtn: $('skipBtn'),
  googleBtn: $('googleBtn'),
  orDivider: $('orDivider'),
};

const params = new URLSearchParams(location.search);

const renderer = new Renderer(dom.board);
const sound = new Sound();

// ?noads 로 광고를 끌 수 있다 (개발·자동화 테스트용)
const ads = new AdManager({
  enabled: !params.has('noads'),
  provider: createPlaceholderProvider({
    root: $('adSlot'),
    closeBtn: $('adClose'),
    config: AD_CONFIG,
  }),
});

// 회생 결제 — 데모 제공자 (TEST MODE 라벨, 실제 과금 없음). ?nopay 로 끈다.
const payments = params.has('nopay')
  ? null
  : createDemoPayProvider({
      root: $('paySheet'),
      titleEl: $('payTitle'),
      priceEl: $('payPrice'),
      payBtn: $('btnPay'),
      cancelBtn: $('btnPayCancel'),
    });

const game = new Game({
  renderer,
  sound,
  dom,
  payments,
  // 도전장 링크(?beat=N) — 친구 기록이 결승선으로 그려진다
  challengeScore: Number(params.get('beat')) || null,
  // 광고는 죽은 뒤 "다시" 전환 순간에만. 런 도중에는 절대 안 뜬다.
  onRunEnded: async (runSeconds) => {
    ads.noteRunEnded();
    await ads.maybeShow(runSeconds);
  },
});

// 첫 실행 이메일 게이트 — 가입/건너뛰기 전에는 키 입력을 게임에 흘리지 않는다
// (포인터는 게이트가 화면을 덮고 있어 자동으로 막힌다)
let gateOpen = true;
new SignupGate({
  dom,
  config: SIGNUP_CONFIG,
  onDone: () => {
    gateOpen = false;
    sound.warm(); // 게이트 버튼 클릭이 제스처이므로 여기서 오디오를 미리 깨운다
  },
});

// ?seed=123 으로 트랙을 고정할 수 있다 (리플레이/테스트용)
if (params.has('seed')) {
  game._forcedSeed = Number(params.get('seed')) >>> 0;
  game.state = newRun(game._forcedSeed);
  renderer.reset(game.state);
}

function updateMuteIcon() {
  dom.btnMute.textContent = sound.muted ? '🔇' : '🔊';
}

// 입력 — 화면 아무 데나 누르면 잡고, 떼면 놓는다. 한 손가락이 전부다.
dom.board.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  sound.warm(); // 첫 제스처에서 오디오를 미리 깨워 런 시작 프레임이 끊기지 않게
  game.press();
});
window.addEventListener('pointerup', () => game.releasePress());
window.addEventListener('pointercancel', () => game.releasePress());
window.addEventListener('blur', () => game.releasePress());
dom.board.addEventListener('contextmenu', (e) => e.preventDefault());

// 데스크톱 테스트용: 스페이스/아무 키나 홀드
window.addEventListener('keydown', (e) => {
  if (e.repeat || gateOpen) return;
  if (e.key === ' ' || e.key === 'ArrowUp') game.press();
});
window.addEventListener('keyup', (e) => {
  if (e.key === ' ' || e.key === 'ArrowUp') game.releasePress();
});

dom.btnMute.addEventListener('click', (e) => {
  e.stopPropagation();
  sound.setMuted(!sound.muted);
  updateMuteIcon();
});

new ResizeObserver(() => renderer.resize()).observe(dom.board);
window.addEventListener('resize', () => renderer.resize());

updateMuteIcon();
renderer.resize();

// 물리 워밍업 — 버려지는 시뮬레이션을 미리 돌려 JIT을 데운다 (첫 런 끊김 방지)
{
  const warm = newRun(1);
  for (let i = 0; i < 900; i++) step(warm, { hold: i % 300 < 200 });
}

// 메인 루프 — 렌더는 rAF, 물리는 game.frame 안에서 고정 스텝으로 돈다
let last = performance.now();
function loop(now) {
  const dtMs = now - last;
  last = now;
  game.frame(dtMs);
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

// ?debug — 자동화 테스트/개발용 훅
if (params.has('debug')) {
  window.__cms = {
    game,
    renderer,
    sound,
    ads,
    adsModule: { AdManager, AD_CONFIG },
    engine: { newRun, WORLD, paramsAt, aim },
    state: () => game.state,
    press: () => game.press(),
    release: () => game.releasePress(),
    kill: () => {
      game.state.dead = false;
      game.state.events.push({ type: 'death', cause: 'debug' });
      game._handleEvents();
    },
    newRun: (seed) => {
      game.state = newRun(seed >>> 0);
      game.mode = 'ready';
      renderer.reset(game.state);
      dom.overlay.classList.add('hidden');
    },
  };
}
