// 부트스트랩 — DOM 연결, 입력(탭 하나), 리사이즈, 가입 게이트, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
import { AdManager, AD_CONFIG, createPlaceholderProvider } from './ads.js';
import { Signup, SIGNUP_CONFIG } from './signup.js';
import { Game } from './game.js';
import { CONFIG, newRun } from './engine.js';

const $ = (id) => document.getElementById(id);
const dom = {
  app: $('app'),
  board: $('board'),
  scoreLabel: $('scoreLabel'),
  bestLabel: $('bestLabel'),
  btnMute: $('btnMute'),
  comboPop: $('comboPop'),
  overlay: $('overlay'),
  overlayScore: $('overlayScore'),
  overlayBest: $('overlayBest'),
  gate: $('gate'),
  googleBtn: $('googleBtn'),
  gateOr: $('gateOr'),
  emailForm: $('emailForm'),
  emailInput: $('emailInput'),
  btnSkip: $('btnSkip'),
  btnSignup: $('btnSignup'),
};

const params = new URLSearchParams(location.search);

function localDayKey() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

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

const game = new Game({
  renderer,
  sound,
  dom,
  // 광고는 런이 끝난 전환 순간에만
  onRunEnded: async (runSeconds) => {
    ads.noteRunEnded();
    await ads.maybeShow(runSeconds);
  },
});

// ?seed=123 으로 색상 시작점을 고정할 수 있다 (스크린샷/테스트용)
if (params.has('seed')) game._forcedSeed = Number(params.get('seed')) >>> 0;

// 가입 게이트 — 게임 위에 얹히는 막. ?gclient= / ?collect= / ?entry= 로 설정 임시 주입
const signupConfig = {
  ...SIGNUP_CONFIG,
  googleClientId: params.get('gclient') || SIGNUP_CONFIG.googleClientId,
  collectUrl: params.get('collect') || SIGNUP_CONFIG.collectUrl,
  formEntry: params.get('entry') || SIGNUP_CONFIG.formEntry,
};
const signup = new Signup({ dom, sound, dayKey: localDayKey(), config: signupConfig });

// ----- 입력 — 탭 하나가 전부 -----

dom.board.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  game.tap();
});

dom.overlay.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  game.continueFromOverlay();
});

function updateMuteIcon() {
  dom.btnMute.textContent = sound.muted ? '🔇' : '🔊';
}
dom.btnMute.addEventListener('click', (e) => {
  e.stopPropagation();
  sound.setMuted(!sound.muted);
  updateMuteIcon();
});
updateMuteIcon();

window.addEventListener('resize', () => renderer.resize());
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('dblclick', (e) => e.preventDefault());

game.startRun();

// 게임이 먼저 그려지고, 그 위에 게이트가 얹힌다.
// 이미 가입했거나 게스트를 택한 사람에게는 다시 묻지 않는다 (?signup 으로 강제 표시)
if (params.has('signup') || signup.needsGate()) signup.show();
else signup._updateBadge();
signup.flushQueue(); // 지난번에 못 보낸 이메일이 있으면 재시도

// 디버그/자동화용
window.__sky = { game, ads, signup, engine: { CONFIG, newRun } };
