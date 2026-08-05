// 게임 컨트롤러 — 입력을 엔진 호출로 바꾸고, HUD/오버레이/목차를 관리한다.
//
// 규칙은 클래식 소트다: 같은 색 위 또는 빈 튜브에만 옮길 수 있다.
// 목표는 화면만 봐도 안다 — 튜브마다 한 색으로 모으기. 그래서 설명 문구가 없다.

import {
  canPour,
  pour,
  topRun,
  isWin,
  isComplete,
  isLocked,
  solve,
  CLASSIC_RULES,
} from '../sort-engine/index.js';
import { LEVEL_DATA } from './levels-data.js';
import { COLOR_HEX } from './render.js';

// 압축 저장된 레벨 데이터를 푼다 (형식 설명은 levels-data.js 머리말 참고)
const decodeTubes = (tubes) => tubes.map((s) => s.split(''));
function decodeSolution(sol) {
  const moves = [];
  for (let i = 0; i + 1 < sol.length; i += 2) {
    moves.push({ from: Number(sol[i]), to: Number(sol[i + 1]) });
  }
  return moves;
}
const colorsOf = (tubes) => [...new Set(tubes.join(''))];

const STORAGE_LEVEL = 'mbs.level';
const STORAGE_CLEARED = 'mbs.cleared'; // 레벨당 '0'/'1' 한 글자
const STORAGE_STARS = 'mbs.stars'; // 레벨당 '0'~'3' 한 글자

// 첫 판만 손가락으로 짚어준다. 두 번 누르면 옮겨진다는 것만 알면 끝이다.
const GUIDED_LEVELS = new Set([0]);

// 여정: 5레벨마다 갇힌 친구 하나를 구한다. 마지막 친구는 왕관을 쓴다.
const CHAPTER = 5;
const FRIEND_COLORS = ['C', 'G', 'K', 'Y', 'B', 'P', 'O', 'R'];

// 별점 기준. 참고 답안(par) 안에 풀면 3개.
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
    this.busy = false;
    this.won = false;
    this.selected = null;
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

  // 몇 번째 친구까지 구했는지. 챕터(4레벨)를 다 깨면 그 친구가 풀려난다.
  friendFreed(chapterIndex) {
    const last = (chapterIndex + 1) * CHAPTER - 1;
    for (let i = chapterIndex * CHAPTER; i <= Math.min(last, LEVEL_DATA.length - 1); i++) {
      if (!this.cleared[i]) return false;
    }
    return true;
  }

  get chapterCount() {
    return Math.ceil(LEVEL_DATA.length / CHAPTER);
  }

  get rescuedCount() {
    let n = 0;
    for (let c = 0; c < this.chapterCount; c++) if (this.friendFreed(c)) n++;
    return n;
  }

  loadLevel(i) {
    this.levelIndex = Math.min(Math.max(i, 0), LEVEL_DATA.length - 1);
    localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex));
    const lv = this.level;
    this.state = { capacity: lv.cap, bottles: decodeTubes(lv.tubes) };
    this.targets = colorsOf(lv.tubes);
    this.solution = decodeSolution(lv.sol);
    this.history = [];
    this.selected = null;
    this.won = false;
    this.busy = false;
    this.guided = GUIDED_LEVELS.has(this.levelIndex);
    clearTimeout(this._deadT);
    clearTimeout(this._winT);

    this.renderer.clearEffects();
    this.renderer.setState(this.state);
    this.dom.overlay.classList.add('hidden');
    this.closeLevels();
    this.hideDeadEnd();
    this.updateHud();
    this.updateGuide();
  }

  release() {
    this.selected = null;
    this.renderer.hold(null);
  }

  // --- 튜토리얼 ---
  nextGuideMove() {
    if (!this.guided || this.won || this.busy) return null;
    return this.solution[this.history.length] || null;
  }

  updateGuide() {
    const g = this.nextGuideMove();
    this.renderer.setGuide(g ? (this.selected === null ? g.from : g.to) : null);
  }

  tap(i) {
    if (this.busy || this.won) return;
    if (!this.state.bottles[i]) return;

    // 집은 걸 다시 놓는 건 안내 중에도 언제나 허용한다 (막으면 답답하다)
    if (i === this.selected) {
      this.release();
      this.updateGuide();
      return;
    }

    const g = this.nextGuideMove();
    if (g) {
      const want = this.selected === null ? g.from : g.to;
      if (i !== want) {
        this.renderer.nudgeTube(i);
        return;
      }
    }

    if (this.selected === null) {
      this.pickUp(i);
      return;
    }

    if (canPour(this.state, this.selected, i, CLASSIC_RULES)) {
      this.doMove(this.selected, i);
    } else {
      // 못 놓는 곳이면 그 튜브를 새로 집어본다. 그것도 안 되면 흔들어 알린다.
      const before = this.selected;
      if (!this.pickUp(i)) {
        this.selected = before;
        this.renderer.nudgeTube(i);
      }
    }
  }

  // 맨 위 같은 색 구슬 묶음을 자석으로 집는다.
  pickUp(i) {
    const balls = this.state.bottles[i];
    if (!balls.length || isLocked(this.state, i, CLASSIC_RULES)) {
      this.renderer.nudgeTube(i);
      this.sound.error();
      return false;
    }
    const run = topRun(balls);
    this.selected = i;
    this.renderer.hold(i, run.color, run.count);
    this.sound.pick(run.count);
    this.updateGuide();
    return true;
  }

  doMove(from, to) {
    const prev = this.state;
    const heldCount = topRun(prev.bottles[from]).count;
    const res = pour(prev, from, to, CLASSIC_RULES);
    if (!res) return;

    this.history.push(prev);
    this.state = res.state;
    // 렌더러도 곧바로 새 상태를 알아야 한다. 옛 상태로 그리면 날아가는 구슬의
    // 목적지 칸 번호가 어긋나 튜브 밖에 그려진다.
    this.renderer.setState(this.state);
    this.selected = null;
    this.busy = true;
    this.hideDeadEnd();
    this.updateHud();
    this.renderer.setGuide(null);

    const completedNow = isComplete(this.state, to) && !isComplete(prev, to);

    this.renderer.animateMove({
      result: res,
      heldCount,
      // 구슬 하나하나가 실제로 닿는 순간에 소리를 낸다 (칸이 높을수록 음이 올라간다)
      onLand: (slotIndex) => this.sound.land(slotIndex),
      onDone: () => {
        this.busy = false;
        this.renderer.setState(this.state);
        this.updateHud();
        if (completedNow) {
          this.renderer.completeTube(to, COLOR_HEX[res.color]);
          this.sound.complete();
        }
        if (isWin(this.state, this.targets)) this.win();
        else {
          this.updateGuide();
          this.scheduleDeadCheck();
        }
      },
    });
  }

  undo() {
    if (this.busy || this.won || !this.history.length) return;
    this.state = this.history.pop();
    this.release();
    this.renderer.setState(this.state);
    this.hideDeadEnd();
    this.updateHud();
    this.updateGuide();
    this.sound.pick(1);
    // 되돌린 상태도 여전히 막혔으면 패널이 다시 떠야 한다.
    // 이게 없으면 한 수 무른 뒤 "이제 됐나?" 하고 헤매게 된다 (실플레이에서 나온 문제).
    this.scheduleDeadCheck();
  }

  restart() {
    if (this.busy) return;
    this.loadLevel(this.levelIndex);
  }

  next() {
    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.loadLevel(last ? 0 : this.levelIndex + 1);
  }

  scheduleDeadCheck() {
    clearTimeout(this._deadT);
    this._deadT = setTimeout(() => {
      if (this.won || this.busy) return;
      const r = solve(this.state, this.targets, CLASSIC_RULES, { maxNodes: 25000 });
      if (!r.solved && r.exhausted) this.showDeadEnd();
    }, 160);
  }

  win() {
    this.won = true;
    this.release();
    this.sound.win();
    this.renderer.setGuide(null);
    this.renderer.celebrate();

    const chapter = Math.floor(this.levelIndex / CHAPTER);
    const wasFreed = this.friendFreed(chapter);
    const earned = starsFor(this.history.length, this.level.par);
    this.cleared[this.levelIndex] = true;
    this.stars[this.levelIndex] = Math.max(this.stars[this.levelIndex], earned);
    this.saveProgress();
    const nowFreed = this.friendFreed(chapter);

    if (this.levelIndex + 1 < LEVEL_DATA.length) {
      localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex + 1));
    }

    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.dom.overlayTitle.textContent = last ? '🎉 Everyone rescued!' : `Level ${this.levelIndex + 1} Clear!`;
    this.dom.overlayInfo.textContent = `${this.history.length} moves · Par ${this.level.par}`;
    this.dom.btnNext.textContent = last ? 'Play Again ↻' : 'Next Level ▶';

    // 별은 오버레이가 뜰 때 하나씩 튀어나오게 (클래스를 다시 붙여 애니메이션 재생)
    [...this.dom.starRow.children].forEach((el, i) => {
      el.classList.remove('on');
      if (i < earned) void el.offsetWidth, el.classList.add('on');
    });

    // 챕터를 막 끝냈다면 친구 한 명이 풀려난다 — 이게 이 여정의 보상이다
    if (nowFreed && !wasFreed) {
      this.dom.overlayRescue.textContent = `You rescued a friend! (${this.rescuedCount}/${this.chapterCount})`;
      this.dom.overlayRescue.classList.remove('hidden');
    } else {
      this.dom.overlayRescue.classList.add('hidden');
    }

    this._winT = setTimeout(() => this.dom.overlay.classList.remove('hidden'), 800);
    this.onCleared?.(this.levelIndex);
  }

  updateHud() {
    const done = this.state.bottles.filter((_, i) => isComplete(this.state, i)).length;
    this.dom.levelLabel.textContent = `Level ${this.levelIndex + 1}`;
    this.dom.moveLabel.textContent = `${done}/${this.targets.length} sorted · ${this.history.length} moves`;
    this.dom.btnUndo.disabled = !this.history.length;
  }

  // --- 여정 지도 ---
  // 프로토타입이라 전부 열어둔다. 실제 출시 때는 클리어한 다음 레벨까지만 여는 게 맞다.
  openLevels() {
    this.buildJourney();
    this.dom.levelSelect.classList.remove('hidden');
    // 현재 레벨이 보이도록 스크롤
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

  // 길을 따라 늘어선 레벨들과, 4레벨마다 놓인 갇힌 친구.
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
        `Level ${i + 1} — ${colorsOf(lv.tubes).length} colors, ${this.stars[i]} stars`
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

      // 챕터의 마지막 레벨 다음에 친구를 놓는다
      const chapter = Math.floor(i / CHAPTER);
      const isChapterEnd = (i + 1) % CHAPTER === 0 || i === LEVEL_DATA.length - 1;
      if (!isChapterEnd) return;

      const freed = this.friendFreed(chapter);
      const isLast = chapter === this.chapterCount - 1;
      const friend = document.createElement('div');
      friend.className = 'jf' + (freed ? ' freed' : '');
      friend.style.setProperty('--c', COLOR_HEX[FRIEND_COLORS[chapter % FRIEND_COLORS.length]]);
      friend.setAttribute(
        'aria-label',
        `${isLast ? 'Final friend' : `Friend ${chapter + 1}`} — ${freed ? 'rescued' : 'still trapped'}`
      );
      friend.innerHTML =
        (isLast ? '<span class="crown"></span>' : '') +
        '<span class="eye l"></span><span class="eye r"></span><span class="mouth"></span>';
      road.appendChild(friend);

      const label = document.createElement('div');
      label.className = 'jf-label';
      label.textContent = freed ? 'Rescued' : isLast ? 'Final friend' : 'Trapped';
      road.appendChild(label);
    });
  }

  // 막다른 길 패널. 버튼(되돌리기/처음부터)이 패널 안에 직접 들어 있어
  // 아이콘을 찾아 헤맬 필요가 없다.
  showDeadEnd() {
    this.dom.deadEnd.classList.remove('hidden');
  }

  hideDeadEnd() {
    this.dom.deadEnd.classList.add('hidden');
  }

  // 디버그/검증용
  autoWin() {
    if (this.won) return true;
    let moves;
    if (this.history.length === 0) {
      moves = this.solution;
    } else {
      const r = solve(this.state, this.targets, CLASSIC_RULES, { maxNodes: 800000 });
      if (!r.solved) return false;
      moves = r.moves;
    }
    for (const mv of moves) {
      const res = pour(this.state, mv.from, mv.to, CLASSIC_RULES);
      if (!res) return false;
      this.history.push(this.state);
      this.state = res.state;
    }
    this.release();
    this.renderer.setState(this.state);
    this.renderer.setGuide(null);
    this.updateHud();
    if (isWin(this.state, this.targets)) {
      this.win();
      return true;
    }
    return false;
  }
}

export { LEVEL_DATA };
