// 부트스트랩 — DOM 연결, 입력, 리사이즈, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
import { AdManager, AD_CONFIG, createPlaceholderProvider } from './ads.js';
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
  levelSelect: $('levelSelect'),
  journey: $('journey'),
  journeyTotal: $('journeyTotal'),
  deadEnd: $('deadEnd'),
  overlay: $('overlay'),
  overlayTitle: $('overlayTitle'),
  overlayInfo: $('overlayInfo'),
  overlayRescue: $('overlayRescue'),
  starRow: $('starRow'),
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

const game = new Game({
  renderer,
  sound,
  dom,
  onCleared: () => ads.noteLevelCleared(),
});

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
// 광고는 레벨을 깬 뒤 "다음 레벨"을 누를 때만 띄운다.
// 퍼즐 도중이나 다시하기에는 절대 띄우지 않는다.
dom.btnNext.addEventListener('click', async () => {
  dom.btnNext.disabled = true;
  try {
    await ads.maybeShow();
  } finally {
    dom.btnNext.disabled = false;
  }
  game.next();
});
dom.btnMute.addEventListener('click', () => {
  sound.setMuted(!sound.muted);
  updateMuteIcon();
});

$('deUndo').addEventListener('click', () => game.undo());
$('deRestart').addEventListener('click', () => game.restart());
$('btnLevels').addEventListener('click', () => game.toggleLevels());
$('btnCloseLevels').addEventListener('click', () => game.closeLevels());
$('btnLevelsFromWin').addEventListener('click', () => game.openLevels());
dom.levelSelect.addEventListener('click', (e) => {
  if (e.target === dom.levelSelect) game.closeLevels();
});
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') game.closeLevels();
});

new ResizeObserver(() => renderer.resize()).observe(dom.board);
window.addEventListener('resize', () => renderer.resize());

updateMuteIcon();
renderer.resize();
game.loadLevel(game.levelIndex);

// ?debug — 자동화 테스트/개발용 훅
if (params.has('debug')) {
  window.__mbs = {
    game,
    renderer,
    sound,
    ads,
    adsModule: { AdManager, AD_CONFIG },
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
