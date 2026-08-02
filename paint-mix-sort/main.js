// 부트스트랩 — DOM 연결, 입력, 리사이즈, 디버그 API.

import { mixOf } from '../sort-engine/index.js';
import { Renderer, COLOR_HEX } from './render.js';
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
  goalSlots: $('goalSlots'),
  legend: $('legend'),
  hint: $('hint'),
  banner: $('banner'),
  overlay: $('overlay'),
  overlayTitle: $('overlayTitle'),
  overlayInfo: $('overlayInfo'),
};

const renderer = new Renderer(dom.board);
const sound = new Sound();
const game = new Game({ renderer, sound, dom });

// 혼합 공식 범례: R+Y=O, Y+B=G, R+B=P
function buildLegend() {
  const dot = (c) => `<span class="dot" style="--c:${COLOR_HEX[c]}"></span>`;
  const pairs = [
    ['R', 'Y'],
    ['Y', 'B'],
    ['R', 'B'],
  ];
  dom.legend.innerHTML = pairs
    .map(([a, b]) => `<span class="formula">${dot(a)}+${dot(b)}=${dot(mixOf(a, b))}</span>`)
    .join('');
}

function updateMuteIcon() {
  dom.btnMute.textContent = sound.muted ? '🔇' : '🔊';
}

dom.board.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  const r = dom.board.getBoundingClientRect();
  const i = renderer.hitTest(e.clientX - r.left, e.clientY - r.top);
  if (i !== null) game.tap(i);
  else game.deselect();
});
dom.board.addEventListener('contextmenu', (e) => e.preventDefault());

dom.btnUndo.addEventListener('click', () => game.undo());
dom.btnRestart.addEventListener('click', () => game.restart());
dom.btnNext.addEventListener('click', () => game.next());
dom.btnMute.addEventListener('click', () => {
  sound.setMuted(!sound.muted);
  updateMuteIcon();
});

new ResizeObserver(() => renderer.resize()).observe(dom.board);
window.addEventListener('resize', () => renderer.resize());

buildLegend();
updateMuteIcon();
renderer.resize();
game.loadLevel(game.levelIndex);

// ?debug — 자동화 테스트/개발용 훅
if (new URLSearchParams(location.search).has('debug')) {
  window.__pms = {
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
      const c = renderer.bottleCenter(i);
      return c ? { x: r.left + c.x, y: r.top + c.y } : null;
    },
  };
}
