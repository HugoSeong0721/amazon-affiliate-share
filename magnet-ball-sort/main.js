// 부트스트랩 — DOM 연결, 입력, 리사이즈, 디버그 API.

import { Renderer } from './render.js';
import { Sound } from './audio.js';
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
  levelGrid: $('levelGrid'),
  banner: $('banner'),
  overlay: $('overlay'),
  overlayTitle: $('overlayTitle'),
  overlayInfo: $('overlayInfo'),
};

const renderer = new Renderer(dom.board);
const sound = new Sound();
const game = new Game({ renderer, sound, dom });

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
dom.btnNext.addEventListener('click', () => game.next());
dom.btnMute.addEventListener('click', () => {
  sound.setMuted(!sound.muted);
  updateMuteIcon();
});

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
if (new URLSearchParams(location.search).has('debug')) {
  window.__mbs = {
    game,
    renderer,
    sound,
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
