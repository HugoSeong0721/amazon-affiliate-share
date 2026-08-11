// 게임 컨트롤러 — 렌더러의 드래그 콜백을 규칙 판단으로 바꾸고, HUD/오버레이/여정을 관리한다.
//
// 규칙은 언블록 클래식이다: 차는 자기 축을 따라서만 미끄러지고, 택시가 출구로 나가면 끝.
// 목표는 화면만 봐도 안다 — 꽉 막힌 주차장, 벽에 뚫린 구멍, 깜빡이는 택시. 그래서 설명 문구가 없다.
//
// 소트 퍼즐과 달리 모든 수가 되돌릴 수 있어 막다른 길이 없다.
// 되돌리기는 오직 별점(수 아끼기) 재도전을 위해 있다.

import {
  W,
  PLAYER,
  moveVehicle,
  coordOf,
  rangeOf,
  isWin,
  solve,
  decodeVehicles,
  decodeMoves,
} from './engine.js';
import { LEVEL_DATA } from './levels-data.js';
import { TAXI_HEX, CAR_HEX } from './render.js';

const STORAGE_LEVEL = 'pke.level';
const STORAGE_CLEARED = 'pke.cleared'; // 레벨당 '0'/'1' 한 글자
const STORAGE_STARS = 'pke.stars'; // 레벨당 '0'~'3' 한 글자

// 첫 판만 손가락으로 짚어준다. "차를 끌 수 있다"는 것만 손이 배우면 끝이다.
const GUIDED_LEVELS = new Set([0]);

// 여정: 5레벨마다 승객 한 명이 집에 도착한다. 마지막 승객은 왕관을 쓰고 있다.
const CHAPTER = 5;
const PASSENGER_HEX = [CAR_HEX[0], CAR_HEX[2], CAR_HEX[3], CAR_HEX[4], CAR_HEX[5], CAR_HEX[1], CAR_HEX[6], TAXI_HEX];

// 별점 기준. 참고 답안(솔버가 찾은 최소 수) 안에 풀면 3개.
function starsFor(moves, par) {
  if (moves <= par) return 3;
  if (moves <= Math.round(par * 1.4)) return 2;
  return 1;
}

export class Game {
  // onCleared: 레벨을 깰 때마다 불린다. 광고 빈도 계산 같은 게임 밖 관심사를 여기로 뺀다.
  constructor({ renderer, sound, dom, onCleared }) {
    this.renderer = renderer;
    this.sound = sound;
    this.dom = dom;
    this.onCleared = onCleared;

    const saved = parseInt(localStorage.getItem(STORAGE_LEVEL) || '0', 10);
    this.levelIndex = Number.isFinite(saved) ? Math.min(Math.max(saved, 0), LEVEL_DATA.length - 1) : 0;
    const marks = localStorage.getItem(STORAGE_CLEARED) || '';
    this.cleared = LEVEL_DATA.map((_, i) => marks[i] === '1');
    const starMarks = localStorage.getItem(STORAGE_STARS) || '';
    this.stars = LEVEL_DATA.map((_, i) => {
      const n = parseInt(starMarks[i] || '0', 10);
      return Number.isFinite(n) ? Math.min(Math.max(n, 0), 3) : 0;
    });
    this.won = false;

    // 렌더러의 손끝 이벤트 → 규칙과 소리
    renderer.handlers = {
      canDrag: (v) => this.canDrag(v),
      onPick: () => this.sound.pick(),
      onDetent: (v, pos) => this.sound.detent(pos),
      onBump: (v, speed) => this.sound.bump(speed),
      onStuck: () => this.sound.stuck(),
      onThunk: (v, impact) => {
        if (impact > 0.12) this.sound.thunk(impact);
      },
      // 출구까지 길이 뻥 뚫리는 순간 — 게이트가 밝아지며 "딩"
      onExitOpen: () => {
        if (!this.won) this.sound.exitOpen();
      },
      onCommit: (v, to) => this.commitMove(v, to),
    };
  }

  get level() {
    return LEVEL_DATA[this.levelIndex];
  }

  saveProgress() {
    localStorage.setItem(STORAGE_CLEARED, this.cleared.map((c) => (c ? '1' : '0')).join(''));
    localStorage.setItem(STORAGE_STARS, this.stars.join(''));
  }

  get totalStars() {
    return this.stars.reduce((a, b) => a + b, 0);
  }

  // 승객 여정 — 챕터(5레벨)를 다 깨면 그 승객이 집에 도착한다.
  passengerHome(chapterIndex) {
    const last = (chapterIndex + 1) * CHAPTER - 1;
    for (let i = chapterIndex * CHAPTER; i <= Math.min(last, LEVEL_DATA.length - 1); i++) {
      if (!this.cleared[i]) return false;
    }
    return true;
  }

  get chapterCount() {
    return Math.ceil(LEVEL_DATA.length / CHAPTER);
  }

  get homeCount() {
    let n = 0;
    for (let c = 0; c < this.chapterCount; c++) if (this.passengerHome(c)) n++;
    return n;
  }

  // 이번 챕터의 승객 — 택시 뒷좌석에 타고 있고, 챕터를 다 깨면 집에 내린다
  get passengerHex() {
    return PASSENGER_HEX[Math.floor(this.levelIndex / CHAPTER) % PASSENGER_HEX.length];
  }

  loadLevel(i) {
    this.levelIndex = Math.min(Math.max(i, 0), LEVEL_DATA.length - 1);
    localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex));
    const lv = this.level;
    this.state = decodeVehicles(lv.v);
    this.renderer.setPassenger(this.passengerHex);
    this.solution = decodeMoves(lv.sol);
    this.history = [];
    this.won = false;
    this.guided = GUIDED_LEVELS.has(this.levelIndex);
    this.helperShown = false;
    clearTimeout(this._winT);

    this.renderer.reset(this.state);
    this.dom.overlay.classList.add('hidden');
    this.closeLevels();
    this.hideHelper();
    this.updateHud();
    this.updateGuide();
  }

  // --- 튜토리얼 ---
  nextGuideMove() {
    if (!this.guided || this.won) return null;
    return this.solution[this.history.length] || null;
  }

  // 힌트: 지금 상태에서 솔버가 찾은 다음 최적 수를 손끝으로 짚어준다.
  // 막다른 길이 없는 게임이라 힌트는 언제나 존재한다. 다음 수를 두면 저절로 사라진다.
  hint() {
    if (this.won) return;
    this.hideHelper();
    const g = this.nextGuideMove();
    if (g) {
      this.renderer.setGuide(g);
      return;
    }
    const r = solve(this.state);
    if (!r.solved || !r.moves.length) return; // 이론상 불가능하지만 방어
    this.renderer.setGuide(r.moves[0]);
    this.sound.pick();
  }

  // 오래 헤매면 먼저 손을 내민다 — 참고 답안의 두 배(최소 +6수)를 넘기면 한 번만.
  maybeOfferHelp() {
    if (this.helperShown || this.won || this.guided) return;
    const threshold = Math.max(this.level.par * 2, this.level.par + 6);
    if (this.history.length >= threshold) {
      this.helperShown = true;
      this.dom.helper.classList.remove('hidden');
    }
  }

  hideHelper() {
    this.dom.helper.classList.add('hidden');
  }

  updateGuide() {
    this.renderer.setGuide(this.nextGuideMove());
  }

  // 안내 중에는 짚어준 차만 잡을 수 있다 (다른 차를 잡으면 도리도리)
  canDrag(v) {
    if (this.won) return false;
    const g = this.nextGuideMove();
    return !g || g.v === v;
  }

  // 렌더러가 "이 차를 여기 놓았다"고 알려온다. 합법성은 rangeOf가 이미 보장했다.
  commitMove(v, to) {
    if (this.won) return;
    const from = coordOf(this.state[v]);
    if (to === from) return;
    // 드래그 범위는 잡는 순간 계산되므로, 그 사이 상태가 바뀌었을 수 있다 — 한 번 더 확인
    const { min, max } = rangeOf(this.state, v);
    if (to < min || to > max) return;

    this.history.push(this.state);
    this.state = moveVehicle(this.state, v, to);
    this.renderer.setState(this.state);
    this.updateHud();
    this.updateGuide();

    if (isWin(this.state)) this.win();
    else this.maybeOfferHelp();
  }

  undo() {
    if (this.won || !this.history.length) return;
    this.state = this.history.pop();
    this.renderer.setState(this.state);
    this.updateHud();
    this.updateGuide();
    this.sound.pick();
  }

  restart() {
    if (this.won && this.renderer.exitAnim) return;
    this.loadLevel(this.levelIndex);
  }

  next() {
    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.loadLevel(last ? 0 : this.levelIndex + 1);
  }

  win() {
    this.won = true;
    this.sound.win();
    this.renderer.setGuide(null);
    this.hideHelper();

    const chapter = Math.floor(this.levelIndex / CHAPTER);
    const wasHome = this.passengerHome(chapter);
    const earned = starsFor(this.history.length, this.level.par);
    this.cleared[this.levelIndex] = true;
    this.stars[this.levelIndex] = Math.max(this.stars[this.levelIndex], earned);
    this.saveProgress();
    const nowHome = this.passengerHome(chapter);

    if (this.levelIndex + 1 < LEVEL_DATA.length) {
      localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex + 1));
    }

    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.dom.overlayTitle.textContent = last
      ? '🎉 Everyone got home!'
      : earned === 3
        ? '✨ Perfect!'
        : `Level ${this.levelIndex + 1} Clear!`;
    this.dom.overlayInfo.textContent = `${this.history.length} moves · Par ${this.level.par}`;
    this.dom.btnNext.textContent = last ? 'Play Again ↻' : 'Next Level ▶';
    this.updateHud();

    // 별은 오버레이가 뜰 때 하나씩 튀어나오게 (클래스를 다시 붙여 애니메이션 재생)
    [...this.dom.starRow.children].forEach((el, i) => {
      el.classList.remove('on');
      if (i < earned) void el.offsetWidth, el.classList.add('on');
    });

    // 승객 진행 — "왜 깨는지"가 매 판 눈에 보여야 다음 판을 누른다.
    // 챕터의 남은 판 수를 점으로, 끝에 이번 승객 얼굴을 놓는다.
    const start = chapter * CHAPTER;
    const slots = Math.min(CHAPTER, LEVEL_DATA.length - start);
    let dots = '';
    let left = 0;
    for (let k = 0; k < slots; k++) {
      const done = this.cleared[start + k];
      if (!done) left++;
      dots += `<span class="ride-dot${done ? ' on' : ''}"></span>`;
    }
    const gotHome = nowHome && !wasHome;
    this.dom.rideRow.innerHTML =
      dots +
      `<span class="ride-arrow">›</span>` +
      `<span class="ride-face${nowHome ? ' home' : ''}" style="--c:${this.passengerHex}">` +
      '<span class="eye l"></span><span class="eye r"></span><span class="mouth"></span></span>';
    this.dom.overlayRescue.textContent = gotHome
      ? `Passenger dropped off! (${this.homeCount}/${this.chapterCount})`
      : nowHome
        ? ''
        : `${left} ride${left > 1 ? 's' : ''} until drop-off`;
    this.dom.overlayRescue.classList.toggle('hidden', nowHome && !gotHome);

    // 택시가 실제로 달려 나간 뒤에 카드가 뜬다 — 연출이 보상보다 먼저
    this.renderer.driveOut(() => {
      this._winT = setTimeout(() => this.dom.overlay.classList.remove('hidden'), 350);
    });
    this.onCleared?.(this.levelIndex);
  }

  updateHud() {
    // 모은 별을 늘 보이게 — 수집이 눈에 보여야 수집욕이 생긴다
    this.dom.levelLabel.textContent = `Level ${this.levelIndex + 1} · ⭐ ${this.totalStars}`;
    this.dom.moveLabel.textContent = `${this.history.length} moves · Par ${this.level.par}`;
    this.dom.btnUndo.disabled = !this.history.length;
  }

  // --- 여정 지도 ---
  // 프로토타입이라 전부 열어둔다. 실제 출시 때는 클리어한 다음 레벨까지만 여는 게 맞다.
  openLevels() {
    this.buildJourney();
    this.dom.levelSelect.classList.remove('hidden');
    const cur = this.dom.journey.querySelector('.jn.current');
    if (cur) cur.scrollIntoView({ block: 'center' });
  }

  closeLevels() {
    this.dom.levelSelect.classList.add('hidden');
  }

  toggleLevels() {
    if (this.dom.levelSelect.classList.contains('hidden')) this.openLevels();
    else this.closeLevels();
  }

  // 길을 따라 늘어선 레벨들과, 5레벨마다 내려주는 승객.
  // 목표가 지도에 그려져 있으니 "왜 하는지"를 글로 설명할 필요가 없다.
  buildJourney() {
    const road = this.dom.journey;
    road.innerHTML = '';

    this.dom.journeyTotal.innerHTML = `<span class="star on"></span>${this.totalStars} / ${
      LEVEL_DATA.length * 3
    }`;

    LEVEL_DATA.forEach((lv, i) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className =
        'jn' + (this.cleared[i] ? ' cleared' : '') + (i === this.levelIndex ? ' current' : '');
      btn.textContent = String(i + 1);
      btn.setAttribute(
        'aria-label',
        `Level ${i + 1} — ${decodeVehicles(lv.v).length} cars, par ${lv.par}, ${this.stars[i]} stars`
      );

      if (this.stars[i] > 0) {
        const row = document.createElement('span');
        row.className = 'jstars';
        for (let s = 0; s < 3; s++) {
          const st = document.createElement('span');
          st.className = 'star' + (s < this.stars[i] ? ' on' : '');
          row.appendChild(st);
        }
        btn.appendChild(row);
      }

      btn.addEventListener('click', () => this.loadLevel(i));
      road.appendChild(btn);

      const chapter = Math.floor(i / CHAPTER);
      const isChapterEnd = (i + 1) % CHAPTER === 0 || i === LEVEL_DATA.length - 1;
      if (!isChapterEnd) return;

      const home = this.passengerHome(chapter);
      const isLast = chapter === this.chapterCount - 1;
      const rider = document.createElement('div');
      rider.className = 'jf' + (home ? ' freed' : '');
      rider.style.setProperty('--c', PASSENGER_HEX[chapter % PASSENGER_HEX.length]);
      rider.setAttribute(
        'aria-label',
        `${isLast ? 'Final passenger' : `Passenger ${chapter + 1}`} — ${home ? 'home' : 'still riding'}`
      );
      rider.innerHTML =
        (isLast ? '<span class="crown"></span>' : '') +
        '<span class="eye l"></span><span class="eye r"></span><span class="mouth"></span>';
      road.appendChild(rider);

      const label = document.createElement('div');
      label.className = 'jf-label';
      label.textContent = home ? 'Home!' : isLast ? 'Final passenger' : 'Riding along';
      road.appendChild(label);
    });
  }

  // 디버그/검증용: 즉석 솔버로 현재 상태에서 끝까지 민다
  autoWin() {
    if (this.won) return true;
    const r = solve(this.state);
    if (!r.solved) return false;
    for (const mv of r.moves) {
      if (isWin(this.state)) break;
      this.history.push(this.state);
      this.state = moveVehicle(this.state, mv.v, mv.to);
    }
    this.renderer.setState(this.state);
    this.updateHud();
    if (isWin(this.state)) {
      this.win();
      return true;
    }
    return false;
  }

  // 디버그/검증용: 드래그 없이 수를 둔다
  applyMove(v, to) {
    this.commitMove(v, to);
  }
}

export { LEVEL_DATA };
