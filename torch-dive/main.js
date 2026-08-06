// 부트스트랩 — DOM 연결, 입력 위임, 오늘 날짜 → 시드, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
import { AdManager, AD_CONFIG, createPlaceholderProvider } from './ads.js';
import { Game } from './game.js';
import { Signup, SIGNUP_CONFIG } from './signup.js';
import { CONFIG, hashSeed, newDive } from './engine.js';

const $ = (id) => document.getElementById(id);
const dom = {
  app: $('app'),
  torchRow: $('torchRow'),
  depthLabel: $('depthLabel'),
  todayLabel: $('todayLabel'),
  btnMute: $('btnMute'),
  compRow: $('compRow'),
  doors: $('doors'),
  btnLantern: $('btnLantern'),
  btnBank: $('btnBank'),
  bankLabel: $('bankLabel'),
  overlay: $('overlay'),
  ovKicker: $('ovKicker'),
  ovBig: $('ovBig'),
  ovSub: $('ovSub'),
  ovTorches: $('ovTorches'),
  ovNote: $('ovNote'),
  gate: $('gate'),
  googleBtn: $('googleBtn'),
  gateOr: $('gateOr'),
  emailForm: $('emailForm'),
  emailInput: $('emailInput'),
  btnSkip: $('btnSkip'),
  btnSignup: $('btnSignup'),
};

const params = new URLSearchParams(location.search);

// 오늘의 열쇠 — 기기 로컬 자정에 던전이 바뀐다 (?day=2026-08-07 로 흉내낼 수 있다)
function localDayKey() {
  if (params.has('day')) return params.get('day');
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

const renderer = new Renderer(dom);
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
  dayKey: localDayKey(),
  // 광고는 다이브 사이의 전환 순간에만
  onDiveEnded: async (diveSeconds) => {
    ads.noteDiveEnded();
    await ads.maybeShow(diveSeconds);
  },
});

// ?seed=123 으로 던전을 고정할 수 있다 (리플레이/테스트용)
if (params.has('seed')) game._forcedSeed = Number(params.get('seed')) >>> 0;

// 가입 게이트 — 게임 위에 얹히는 막이라 게임 흐름은 전혀 모른다.
// ?gclient= / ?collect= 로 설정을 임시 주입할 수 있다 (개발·테스트용)
const signupConfig = {
  ...SIGNUP_CONFIG,
  googleClientId: params.get('gclient') || SIGNUP_CONFIG.googleClientId,
  collectUrl: params.get('collect') || SIGNUP_CONFIG.collectUrl,
  formEntry: params.get('entry') || SIGNUP_CONFIG.formEntry,
};
const signup = new Signup({ dom, sound, dayKey: localDayKey(), config: signupConfig });

// ----- 입력 -----

// 문 — 손가락이 닿는 순간 반응한다
dom.doors.addEventListener('pointerdown', (e) => {
  const door = e.target.closest('.door');
  if (!door) return;
  e.preventDefault();
  game.tapDoor(Number(door.dataset.i));
});

dom.btnLantern.addEventListener('click', () => game.togglePeek());
dom.btnBank.addEventListener('click', () => game.bank());
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

// 길게 눌러도 컨텍스트 메뉴·더블탭 줌이 끼어들지 않게
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('dblclick', (e) => e.preventDefault());

game.startDive();

// 게임이 먼저 그려지고, 그 위에 게이트가 얹힌다 — 문 너머가 살짝 보여야 가입할 이유가 생긴다.
// 이미 가입했거나 게스트를 택한 사람에게는 다시 묻지 않는다 (?signup 으로 강제 표시)
if (params.has('signup') || signup.needsGate()) signup.show();
else signup._updateBadge();
signup.flushQueue(); // 지난번에 못 보낸 이메일이 있으면 재시도

// 디버그/자동화용 — 콘솔에서 상태를 들여다볼 수 있다
window.__tdv = { game, ads, signup, engine: { CONFIG, hashSeed, newDive } };
