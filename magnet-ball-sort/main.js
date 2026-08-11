// 부트스트랩 — DOM 연결, 입력, 리사이즈, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
import { AdManager, AD_CONFIG, createPlaceholderProvider } from './ads.js';
import {
  AuthManager,
  AUTH_CONFIG,
  createFakeAuthProvider,
  createCapacitorFirebaseProvider,
} from './auth.js';
import { DailyState, dateKey, levelForDate, monthGrid, streakFrom, MONTHS } from './daily.js';
import { Game, LEVEL_DATA } from './game.js';

const $ = (id) => document.getElementById(id);
const dom = {
  board: $('board'),
  levelLabel: $('levelLabel'),
  moveLabel: $('moveLabel'),
  btnUndo: $('btnUndo'),
  btnRestart: $('btnRestart'),
  btnMute: $('btnMute'),
  btnNext: $('btnNext'),
  btnLevelsFromWin: $('btnLevelsFromWin'),
  levelSelect: $('levelSelect'),
  journey: $('journey'),
  journeyTotal: $('journeyTotal'),
  deadEnd: $('deadEnd'),
  overlay: $('overlay'),
  overlayTitle: $('overlayTitle'),
  overlayInfo: $('overlayInfo'),
  overlayRescue: $('overlayRescue'),
  starRow: $('starRow'),
  accountRow: $('accountRow'),
  acctSignIn: $('acctSignIn'),
  acctInfo: $('acctInfo'),
  acctEmail: $('acctEmail'),
  authDialog: $('authDialog'),
  authGoogle: $('authGoogle'),
  authLater: $('authLater'),
  authError: $('authError'),
  deleteConfirm: $('deleteConfirm'),
  delError: $('delError'),
  dailyPanel: $('dailyPanel'),
  dailyDot: $('dailyDot'),
  dailyStreak: $('dailyStreak'),
  dailyMonth: $('dailyMonth'),
  dailyGrid: $('dailyGrid'),
  btnPlayDaily: $('btnPlayDaily'),
  overlayDaily: $('overlayDaily'),
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

// 로그인 provider: 네이티브 앱이면 Firebase, 웹은 없음(UI가 숨는다).
// ?debug 에서는 가짜 provider 로 가입 흐름을 미리 볼 수 있다.
const authProvider =
  createCapacitorFirebaseProvider() || (params.has('debug') ? createFakeAuthProvider() : null);
const auth = new AuthManager({ provider: authProvider });

const daily = new DailyState();

const game = new Game({
  renderer,
  sound,
  dom,
  onCleared: () => {
    ads.noteLevelCleared();
    // 로그인돼 있으면 깰 때마다 클라우드에 진행을 민다 (실패해도 조용히 넘어간다)
    auth.push(game.getProgressData());
    // 승리 화면에 "오늘의 퍼즐" 리마인더 — 캠페인에서, 아직 안 했을 때만
    dom.overlayDaily.classList.toggle(
      'hidden',
      game.mode !== 'campaign' || daily.isDone(dateKey())
    );
  },
});

// --- 데일리 챌린지 (돌아올 이유) ---

const MONTHS_SHORT = MONTHS.map((m) => m.slice(0, 3));
const dailyLabel = (key) => {
  const [, m, d] = key.split('-').map(Number);
  return `${MONTHS_SHORT[m - 1]} ${d}`;
};

function renderDaily() {
  const today = dateKey();
  const n = daily.streak(today);
  dom.dailyDot.classList.toggle('hidden', daily.isDone(today));
  dom.dailyStreak.innerHTML =
    (n === 0 ? '🔥 Start your streak today!' : `🔥 ${n} day${n === 1 ? '' : 's'} streak`) +
    (daily.best > 1 ? ` <span class="best">· Best ${daily.best}</span>` : '');

  const now = new Date();
  const grid = monthGrid(now.getFullYear(), now.getMonth());
  dom.dailyMonth.textContent = grid.label;
  dom.dailyGrid.innerHTML = '';
  for (let i = 0; i < grid.firstDow; i++) {
    const pad = document.createElement('div');
    pad.className = 'dc-day empty';
    dom.dailyGrid.appendChild(pad);
  }
  grid.keys.forEach((key, i) => {
    const cell = document.createElement('div');
    const future = key > today;
    cell.className =
      'dc-day' +
      (daily.isDone(key) ? ' done' : '') +
      (key === today ? ' today' : '') +
      (future ? ' future' : '');
    cell.textContent = String(i + 1);
    cell.setAttribute(
      'aria-label',
      `${key} — ${daily.isDone(key) ? 'cleared' : future ? 'upcoming' : 'not played'}`
    );
    dom.dailyGrid.appendChild(cell);
  });

  const done = daily.isDone(today);
  dom.btnPlayDaily.textContent = done ? '✓ Cleared today — play again' : "Play today's puzzle ▶";
  dom.btnPlayDaily.classList.toggle('done-today', done);
}

function openDaily() {
  game.closeLevels();
  renderDaily();
  dom.dailyPanel.classList.remove('hidden');
}

function closeDaily() {
  dom.dailyPanel.classList.add('hidden');
}

function playDaily(key = dateKey()) {
  closeDaily();
  game.loadDaily(key, levelForDate(key), dailyLabel(key));
}

// 데일리 승리 → 도장 + 스트릭. 승리 카드에 띄울 한 줄을 돌려준다.
game.onDailyCleared = (key, stars) => {
  daily.markDone(key, stars);
  renderDaily();
  const n = daily.streak(key);
  return {
    note: n >= 2 ? `🔥 ${n}-day streak!` : '🔥 Streak started — come back tomorrow!',
  };
};

function updateMuteIcon() {
  dom.btnMute.textContent = sound.muted ? '🔇' : '🔊';
}

dom.board.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  const r = dom.board.getBoundingClientRect();
  const i = renderer.hitTest(e.clientX - r.left, e.clientY - r.top);
  if (i !== null) game.tap(i);
  else game.release();
});
dom.board.addEventListener('contextmenu', (e) => e.preventDefault());

dom.btnUndo.addEventListener('click', () => game.undo());
dom.btnRestart.addEventListener('click', () => game.restart());

// --- 선택적 로그인 (이메일 수집 + 진행 저장) ---

// 로그인하고, 클라우드와 로컬 진행을 병합한다.
// 다른 기기가 더 멀리 갔으면 그 레벨로 점프하고 true 를 돌려준다.
async function doSignIn() {
  await auth.signIn();
  const merged = await auth.sync(game.getProgressData());
  return merged ? game.applyProgressData(merged) : false;
}

function renderAccount() {
  dom.accountRow.classList.toggle('hidden', !auth.available);
  if (!auth.available) return;
  const u = auth.user;
  dom.acctSignIn.classList.toggle('hidden', !!u);
  dom.acctInfo.classList.toggle('hidden', !u);
  if (u) dom.acctEmail.textContent = u.email || u.name || 'Signed in';
}

// 가입 권유 대화상자. 어느 버튼으로 닫혀도 게임은 계속된다 —
// 로그인 실패조차 흐름을 막지 않는다(에러 한 줄 보여주고 "나중에"가 남는다).
function showAuthDialog() {
  return new Promise((resolve) => {
    dom.authError.classList.add('hidden');
    dom.authDialog.classList.remove('hidden');
    const finish = (jumped) => {
      dom.authDialog.classList.add('hidden');
      dom.authGoogle.removeEventListener('click', onGoogle);
      dom.authLater.removeEventListener('click', onLater);
      resolve(jumped);
    };
    const onLater = () => finish(false);
    const onGoogle = async () => {
      dom.authGoogle.disabled = true;
      try {
        finish(await doSignIn());
      } catch {
        dom.authError.classList.remove('hidden');
      } finally {
        dom.authGoogle.disabled = false;
      }
    };
    dom.authGoogle.addEventListener('click', onGoogle);
    dom.authLater.addEventListener('click', onLater);
  });
}

// 광고는 레벨을 깬 뒤 "다음 레벨"을 누를 때만 띄운다.
// 퍼즐 도중이나 다시하기에는 절대 띄우지 않는다.
// 첫 친구를 구한 직후에는 광고 대신 가입 권유가 딱 한 번 나온다 —
// 한 화면 전환에 끊김은 한 번만이다.
dom.btnNext.addEventListener('click', async () => {
  dom.btnNext.disabled = true;
  let jumped = false;
  try {
    if (game.mode === 'campaign' && auth.shouldPrompt(game.levelIndex)) {
      auth.markPrompted();
      ads.noteInterruption();
      jumped = await showAuthDialog();
    } else {
      await ads.maybeShow();
    }
  } finally {
    dom.btnNext.disabled = false;
  }
  // 클라우드 진행으로 이미 점프했다면 next()가 그 위를 덮어쓰면 안 된다
  if (!jumped) game.next();
});

dom.acctSignIn.addEventListener('click', async () => {
  dom.acctSignIn.disabled = true;
  try {
    await doSignIn();
  } catch {
    // 실패해도 버튼은 남는다 — 언제든 다시 시도할 수 있다
  } finally {
    dom.acctSignIn.disabled = false;
  }
});
$('acctSignOut').addEventListener('click', () => auth.signOut());
$('acctDelete').addEventListener('click', () => {
  dom.delError.classList.add('hidden');
  dom.deleteConfirm.classList.remove('hidden');
});
$('delCancel').addEventListener('click', () => dom.deleteConfirm.classList.add('hidden'));
$('delConfirm').addEventListener('click', async () => {
  const btn = $('delConfirm');
  btn.disabled = true;
  try {
    await auth.deleteAccount();
    dom.deleteConfirm.classList.add('hidden');
  } catch {
    dom.delError.classList.remove('hidden');
  } finally {
    btn.disabled = false;
  }
});

auth.onChange = renderAccount;
renderAccount();
auth.init();
dom.btnMute.addEventListener('click', () => {
  sound.setMuted(!sound.muted);
  updateMuteIcon();
});

$('deUndo').addEventListener('click', () => game.undo());
$('deRestart').addEventListener('click', () => game.restart());
$('btnLevels').addEventListener('click', () => {
  closeDaily();
  game.toggleLevels();
});
$('btnCloseLevels').addEventListener('click', () => game.closeLevels());
$('btnLevelsFromWin').addEventListener('click', () => game.openLevels());
dom.levelSelect.addEventListener('click', (e) => {
  if (e.target === dom.levelSelect) game.closeLevels();
});
$('btnDaily').addEventListener('click', () => {
  if (dom.dailyPanel.classList.contains('hidden')) openDaily();
  else closeDaily();
});
$('btnCloseDaily').addEventListener('click', closeDaily);
dom.btnPlayDaily.addEventListener('click', () => playDaily());
dom.overlayDaily.addEventListener('click', () => playDaily());
dom.dailyPanel.addEventListener('click', (e) => {
  if (e.target === dom.dailyPanel) closeDaily();
});
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    game.closeLevels();
    closeDaily();
  }
});

new ResizeObserver(() => renderer.resize()).observe(dom.board);
window.addEventListener('resize', () => renderer.resize());

updateMuteIcon();
renderer.resize();
renderDaily(); // 부팅 때 오늘 미완료 점(📅)을 맞춰둔다
game.loadLevel(game.levelIndex);

// ?debug — 자동화 테스트/개발용 훅
if (params.has('debug')) {
  window.__mbs = {
    game,
    renderer,
    sound,
    ads,
    adsModule: { AdManager, AD_CONFIG },
    auth,
    authProvider,
    authConfig: AUTH_CONFIG,
    daily,
    dailyModule: { dateKey, levelForDate, streakFrom, monthGrid },
    playDaily,
    openDaily,
    levelCount: LEVEL_DATA.length,
    tap: (i) => game.tap(i),
    state: () => game.state,
    loadLevel: (i) => game.loadLevel(i),
    autoWin: () => game.autoWin(),
    center: (i) => {
      const r = dom.board.getBoundingClientRect();
      const c = renderer.tubeCenter(i);
      return c ? { x: r.left + c.x, y: r.top + c.y } : null;
    },
  };
}
