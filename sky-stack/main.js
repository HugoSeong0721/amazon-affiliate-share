// 부트스트랩 — DOM 연결, 입력(탭 하나), 리사이즈, 가입 게이트, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
import { AdManager, AD_CONFIG, createPlaceholderProvider } from './ads.js';
import { Signup, SIGNUP_CONFIG } from './signup.js';
import { Leaderboard, LEADERBOARD_CONFIG } from './leaderboard.js';
import { share } from './share.js';
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
  btnBoard: $('btnBoard'),
  btnShare: $('btnShare'),
  btnRanks: $('btnRanks'),
  ranks: $('ranks'),
  ranksList: $('ranksList'),
  ranksNote: $('ranksNote'),
  ranksClose: $('ranksClose'),
  toast: $('toast'),
  pause: $('pause'),
  btnPause: $('btnPause'),
  btnResume: $('btnResume'),
  btnRestart: $('btnRestart'),
  btnPauseShare: $('btnPauseShare'),
  btnPauseRanks: $('btnPauseRanks'),
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

// 랭킹 — ?lb= 로 Apps Script 주소를 임시 주입할 수 있다 (개발·테스트용)
const lb = new Leaderboard({
  config: { ...LEADERBOARD_CONFIG, url: params.get('lb') || LEADERBOARD_CONFIG.url },
  getUser: () => signup?.user || null,
});

const game = new Game({
  renderer,
  sound,
  dom,
  // 런이 끝난 전환 순간에: 신기록이면 랭킹에 올리고, 그다음에야 광고 차례
  onRunEnded: async (runSeconds, { score, isBest }) => {
    if (isBest && score > 0) lb.submit(score);
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
  if (e.target.closest('.overlay-btns')) return; // 버튼 탭은 재시작이 아니다
  e.preventDefault();
  game.continueFromOverlay();
});

// ----- 친구 공유 -----

function showToast(msg) {
  dom.toast.textContent = msg;
  dom.toast.classList.remove('hidden');
  dom.toast.style.animation = 'none';
  void dom.toast.offsetWidth;
  dom.toast.style.animation = '';
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => dom.toast.classList.add('hidden'), 1900);
}

async function doShare(e) {
  e.stopPropagation();
  sound.ui();
  game.pause(); // 플레이 중이었다면 공유 시트 뒤에서 블록이 계속 움직이지 않게
  const result = await share(game.lastScore || game.best || 0);
  if (result === 'copied') showToast('Link copied!');
  if (result === 'failed') showToast('Could not share');
}

dom.btnShare.addEventListener('click', doShare);
dom.btnPauseShare.addEventListener('click', doShare);

// ----- 랭킹 보드 -----

function boardRow(rank, score, isMe) {
  const cls = ['ranks-row', rank <= 3 ? `top${rank}` : '', isMe ? 'me' : ''].join(' ').trim();
  return `<div class="${cls}"><span class="rk">${rank}</span><span class="nm"></span><span class="sc">${score}</span></div>`;
}

// 내 기록 — 최고 기록과 진행 중인 런 중 높은 쪽 (플레이 도중에 열어도 내 줄이 보인다)
function myScore() {
  const live = game.state && !game.state.over ? game.state.floors.length - 1 : 0;
  return Math.max(game.best, live);
}

function renderBoard(top) {
  const wrap = dom.ranksList;
  const mine = myScore();
  // 서버 목록에 내가 없으면 내 줄을 끼워 넣는다 — 어디쯤인지 보여야 다시 도전하게 된다
  const rows = [...top];
  if (mine > 0 && !rows.some((r) => r.name === lb.name && r.score === mine)) {
    rows.push({ name: lb.name, score: mine });
    rows.sort((a, b) => b.score - a.score);
  }
  if (!rows.length) {
    wrap.innerHTML = '<div class="ranks-empty">Stack some blocks first! 🧱</div>';
    return;
  }
  wrap.innerHTML = rows
    .map((r, i) => boardRow(i + 1, r.score, r.name === lb.name && r.score === mine))
    .join('');
  // 이름은 textContent 로 넣는다 — 서버발 문자열을 HTML 로 해석하지 않는다
  wrap.querySelectorAll('.ranks-row .nm').forEach((el, i) => {
    el.textContent = rows[i].name;
  });
}

async function openBoard() {
  sound.ui();
  game.pause(); // 랭킹을 보는 동안 탑이 무너지면 안 된다
  dom.ranks.classList.remove('hidden');
  dom.ranksNote.classList.toggle('hidden', lb.online);
  renderBoard(lb.online ? lb.cachedTop() : []); // 캐시 먼저, 새 데이터로 갱신
  if (lb.online) renderBoard(await lb.fetchTop());
}

[dom.btnBoard, dom.btnRanks, dom.btnPauseRanks].forEach((btn) =>
  btn.addEventListener('click', (e) => {
    e.stopPropagation();
    openBoard();
  })
);
dom.ranksClose.addEventListener('click', () => dom.ranks.classList.add('hidden'));
dom.ranks.addEventListener('pointerdown', (e) => {
  if (!e.target.closest('.ranks-card')) dom.ranks.classList.add('hidden'); // 바깥 탭으로 닫기
});

// ----- 일시정지 -----

dom.btnPause.addEventListener('click', (e) => {
  e.stopPropagation();
  sound.ui();
  game.togglePause();
});
dom.btnResume.addEventListener('click', (e) => {
  e.stopPropagation();
  sound.ui();
  game.resume();
});
dom.btnRestart.addEventListener('click', (e) => {
  e.stopPropagation();
  sound.ui();
  game.startRun();
});
// 카드 바깥을 누르면 이어하기 — 실수로 눌렀을 때 빠져나가는 길
dom.pause.addEventListener('pointerdown', (e) => {
  if (!e.target.closest('.pause-card')) game.resume();
});

// 화면을 벗어나면(탭 전환·홈 버튼·전화) 자동으로 멈춘다 — 돌아왔을 때 탑이 무너져 있지 않게
document.addEventListener('visibilitychange', () => {
  if (document.hidden) game.pause();
});
window.addEventListener('blur', () => game.pause());

// 키보드: 스페이스로 쌓고, Esc/P로 일시정지 (데스크톱에서 해 보는 사람들을 위해)
window.addEventListener('keydown', (e) => {
  if (e.key === ' ' || e.key === 'Enter') {
    e.preventDefault();
    if (!dom.overlay.classList.contains('hidden')) game.continueFromOverlay();
    else if (game.paused) game.resume();
    else game.tap();
  } else if (e.key === 'Escape' || e.key.toLowerCase() === 'p') {
    e.preventDefault();
    game.togglePause();
  }
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
window.__sky = { game, ads, signup, lb, engine: { CONFIG, newRun } };
