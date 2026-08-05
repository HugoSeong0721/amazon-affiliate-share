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

const STORAGE_LEVEL = 'mbs.level';
const STORAGE_CLEARED = 'mbs.cleared'; // 레벨당 '0'/'1' 한 글자

// 첫 판만 손가락으로 짚어준다. 두 번 누르면 옮겨진다는 것만 알면 끝이다.
const GUIDED_LEVELS = new Set([0]);

export class Game {
  constructor({ renderer, sound, dom }) {
    this.renderer = renderer;
    this.sound = sound;
    this.dom = dom;
    const saved = parseInt(localStorage.getItem(STORAGE_LEVEL) || '0', 10);
    this.levelIndex = Number.isFinite(saved) ? Math.min(Math.max(saved, 0), LEVEL_DATA.length - 1) : 0;
    const marks = localStorage.getItem(STORAGE_CLEARED) || '';
    this.cleared = LEVEL_DATA.map((_, i) => marks[i] === '1');
    this.busy = false;
    this.won = false;
    this.selected = null;
  }

  get level() {
    return LEVEL_DATA[this.levelIndex];
  }

  saveCleared() {
    localStorage.setItem(STORAGE_CLEARED, this.cleared.map((c) => (c ? '1' : '0')).join(''));
  }

  loadLevel(i) {
    this.levelIndex = Math.min(Math.max(i, 0), LEVEL_DATA.length - 1);
    localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex));
    const lv = this.level;
    this.state = { capacity: lv.capacity, bottles: lv.tubes.map((t) => t.slice()) };
    this.targets = lv.targets.slice();
    this.history = [];
    this.selected = null;
    this.won = false;
    this.busy = false;
    this.guided = GUIDED_LEVELS.has(this.levelIndex);
    clearTimeout(this._deadT);
    clearTimeout(this._bannerT);
    clearTimeout(this._winT);

    this.renderer.clearEffects();
    this.renderer.setState(this.state);
    this.dom.overlay.classList.add('hidden');
    this.closeLevels();
    this.hideBanner();
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
    return this.level.solution[this.history.length] || null;
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
    this.selected = null;
    this.busy = true;
    this.hideBanner();
    this.updateHud();
    this.renderer.setGuide(null);

    const completedNow = isComplete(this.state, to) && !isComplete(prev, to);

    this.renderer.animateMove({
      result: res,
      heldCount,
      onDone: () => {
        this.busy = false;
        this.renderer.setState(this.state);
        this.updateHud();
        if (completedNow) {
          this.renderer.burstAtTube(to, COLOR_HEX[res.color]);
          this.sound.complete();
        }
        if (isWin(this.state, this.targets)) this.win();
        else {
          this.updateGuide();
          this.scheduleDeadCheck();
        }
      },
    });
    // 구슬이 착지하는 타이밍에 맞춰 소리
    setTimeout(() => this.sound.drop(res.amount), 210);
  }

  undo() {
    if (this.busy || this.won || !this.history.length) return;
    this.state = this.history.pop();
    this.release();
    this.renderer.setState(this.state);
    this.hideBanner();
    this.updateHud();
    this.updateGuide();
    this.sound.pick(1);
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
      if (!r.solved && r.exhausted) {
        this.showBanner('🚫 더 이상 풀 수 없어요 — 되돌리기(↩︎)를 눌러보세요', true);
      }
    }, 160);
  }

  win() {
    this.won = true;
    this.release();
    this.sound.win();
    this.renderer.setGuide(null);
    this.renderer.celebrate();
    this.cleared[this.levelIndex] = true;
    this.saveCleared();
    if (this.levelIndex + 1 < LEVEL_DATA.length) {
      localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex + 1));
    }
    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.dom.overlayTitle.textContent = last ? '🎉 전 레벨 클리어!' : `레벨 ${this.levelIndex + 1} 클리어!`;
    this.dom.overlayInfo.textContent = `${this.history.length}수 · 참고 답안 ${this.level.solutionLength}수`;
    this.dom.btnNext.textContent = last ? '처음부터 다시 ↻' : '다음 레벨 ▶';
    this._winT = setTimeout(() => this.dom.overlay.classList.remove('hidden'), 800);
  }

  updateHud() {
    const done = this.state.bottles.filter((_, i) => isComplete(this.state, i)).length;
    this.dom.levelLabel.textContent = `레벨 ${this.levelIndex + 1}`;
    this.dom.moveLabel.textContent = `완성 ${done}/${this.targets.length} · ${this.history.length}수`;
    this.dom.btnUndo.disabled = !this.history.length;
  }

  // --- 레벨 목차 ---
  // 프로토타입이라 전부 열어둔다. 실제 출시 때는 클리어한 다음 레벨까지만 여는 게 맞다.
  openLevels() {
    this.buildLevelGrid();
    this.dom.levelSelect.classList.remove('hidden');
  }

  closeLevels() {
    this.dom.levelSelect.classList.add('hidden');
  }

  toggleLevels() {
    if (this.dom.levelSelect.classList.contains('hidden')) this.openLevels();
    else this.closeLevels();
  }

  buildLevelGrid() {
    const grid = this.dom.levelGrid;
    grid.innerHTML = '';
    LEVEL_DATA.forEach((lv, i) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className =
        'lv' + (this.cleared[i] ? ' cleared' : '') + (i === this.levelIndex ? ' current' : '');
      btn.setAttribute(
        'aria-label',
        `레벨 ${i + 1}${this.cleared[i] ? ' (클리어함)' : ''} — 색 ${lv.targets.length}가지`
      );

      const num = document.createElement('span');
      num.textContent = String(i + 1);

      const dots = document.createElement('span');
      dots.className = 'dots';
      for (const t of lv.targets) {
        const d = document.createElement('i');
        d.style.setProperty('--c', COLOR_HEX[t]);
        dots.appendChild(d);
      }

      btn.append(num, dots);
      btn.addEventListener('click', () => this.loadLevel(i));
      grid.appendChild(btn);
    });
  }

  showBanner(text, sticky = false) {
    clearTimeout(this._bannerT);
    this.dom.banner.textContent = text;
    this.dom.banner.classList.remove('hidden');
    if (!sticky) this._bannerT = setTimeout(() => this.hideBanner(), 2300);
  }

  hideBanner() {
    this.dom.banner.classList.add('hidden');
  }

  // 디버그/검증용
  autoWin() {
    if (this.won) return true;
    let moves;
    if (this.history.length === 0) {
      moves = this.level.solution;
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
