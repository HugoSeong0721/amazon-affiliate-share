// 게임 컨트롤러 — 입력을 엔진 호출로 바꾸고, HUD/오버레이/배너를 관리한다.

import {
  canPour,
  pour,
  isWin,
  isComplete,
  isLocked,
  solve,
  MIX_RULES,
} from '../sort-engine/index.js';
import { LEVEL_DATA, CAPACITY } from './levels-data.js';
import { COLOR_HEX } from './render.js';

const STORAGE_LEVEL = 'pms.level';
const STORAGE_CLEARED = 'pms.cleared'; // 레벨당 '0'/'1' 한 글자

// 손가락이 첫 판을 끝까지 안내하는 레벨 (설명 문구 대신 직접 짚어준다)
const GUIDED_LEVELS = new Set([0]);

const HINTS = {
  6: '🔴 빨강도 목표예요. 전부 섞어버리면 못 만듭니다.',
};

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
  }

  saveCleared() {
    localStorage.setItem(STORAGE_CLEARED, this.cleared.map((c) => (c ? '1' : '0')).join(''));
  }

  get level() {
    return LEVEL_DATA[this.levelIndex];
  }

  loadLevel(i) {
    this.levelIndex = Math.min(Math.max(i, 0), LEVEL_DATA.length - 1);
    localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex));
    const lv = this.level;
    this.state = { capacity: CAPACITY, bottles: lv.bottles.map((b) => b.slice()) };
    this.targets = lv.targets.slice();
    this.history = [];
    this.selected = null;
    this.won = false;
    this.busy = false;
    this.guided = GUIDED_LEVELS.has(this.levelIndex);
    this._goalFlags = null;
    clearTimeout(this._deadT);
    clearTimeout(this._bannerT);

    this.renderer.clearEffects();
    this.renderer.setState(this.state);
    this.renderer.setSelected(null);
    this.dom.overlay.classList.add('hidden');
    this.closeLevels();
    this.hideBanner();
    this.updateHud();
    this.updateGoals();
    this.updateGuide();

    const hint = HINTS[this.levelIndex];
    if (hint) {
      this.dom.hint.textContent = hint;
      this.dom.hint.classList.remove('hidden');
    } else {
      this.dom.hint.classList.add('hidden');
    }
  }

  deselect() {
    this.selected = null;
    this.renderer.setSelected(null);
  }

  // 안내 레벨에서 지금 눌러야 할 수. 입력을 이 수로만 제한한다.
  nextGuideMove() {
    if (!this.guided || this.won || this.busy) return null;
    return this.level.solution[this.history.length] || null;
  }

  updateGuide() {
    const g = this.nextGuideMove();
    this.renderer.setGuide(g ? (this.selected === null ? g.from : g.to) : null);
  }

  // 선택 시도. 비었거나 완성돼 잠긴 병이면 거절한다.
  trySelect(i) {
    if (!this.state.bottles[i].length || isLocked(this.state, i, MIX_RULES)) {
      this.renderer.shakeBottle(i);
      this.sound.error();
      return false;
    }
    this.selected = i;
    this.renderer.setSelected(i);
    this.sound.select();
    this.updateGuide();
    return true;
  }

  tap(i) {
    if (this.busy || this.won) return;
    if (!this.state.bottles[i]) return;

    // 안내 중에는 짚어준 병만 반응한다
    const g = this.nextGuideMove();
    if (g) {
      const want = this.selected === null ? g.from : g.to;
      if (i !== want) {
        this.renderer.shakeBottle(i);
        return;
      }
    }

    if (this.selected === null) {
      this.trySelect(i);
      return;
    }

    if (i === this.selected) {
      this.deselect();
      this.updateGuide();
      return;
    }

    if (canPour(this.state, this.selected, i, MIX_RULES)) {
      this.doPour(this.selected, i);
    } else {
      // 부을 수 없는 곳이면 선택을 옮겨준다 (연타 조작감).
      // 옮길 수 없는 병이면 기존 선택을 유지한다.
      this.trySelect(i);
    }
  }

  doPour(from, to) {
    const prev = this.state;
    const res = pour(prev, from, to, MIX_RULES);
    if (!res) return;

    this.history.push(prev);
    this.state = res.state;
    this.deselect();
    this.busy = true;
    this.hideBanner();
    this.sound.pour(res.amount);
    this.updateHud();
    this.renderer.setGuide(null); // 붓는 동안에는 손가락을 치운다

    const completedNow = isComplete(this.state, to) && !isComplete(prev, to);

    this.renderer.animatePour({
      prevState: prev,
      result: res,
      onMix: () => this.sound.mix(),
      onDone: () => {
        this.busy = false;
        this.renderer.setState(this.state);
        this.updateGoals();
        if (completedNow) {
          this.renderer.burstAtBottle(to, COLOR_HEX[res.color]);
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
    this.deselect();
    this.renderer.setState(this.state);
    this.hideBanner();
    this.updateHud();
    this.updateGoals();
    this.updateGuide();
    this.sound.select();
  }

  restart() {
    if (this.busy) return;
    this.loadLevel(this.levelIndex);
  }

  next() {
    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.loadLevel(last ? 0 : this.levelIndex + 1);
  }

  // 매 수 이후, 현재 상태가 확실히 못 푸는 상태인지 백그라운드로 확인
  scheduleDeadCheck() {
    clearTimeout(this._deadT);
    this._deadT = setTimeout(() => {
      if (this.won || this.busy) return;
      const r = solve(this.state, this.targets, MIX_RULES, { maxNodes: 25000 });
      if (!r.solved && r.exhausted) {
        this.showBanner('🚫 더 이상 풀 수 없어요 — 되돌리기(↩︎)로 살려보세요!', true);
      }
    }, 160);
  }

  win() {
    this.won = true;
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
    setTimeout(() => this.dom.overlay.classList.remove('hidden'), 850);
  }

  updateHud() {
    this.dom.levelLabel.textContent = `레벨 ${this.levelIndex + 1}`;
    this.dom.moveLabel.textContent = `${this.history.length}수 · 총 ${LEVEL_DATA.length}레벨`;
    this.dom.btnUndo.disabled = !this.history.length;
  }

  // 하단 목표 선반: 빈 병 실루엣이 "만들어야 할 병", 완성되면 색이 찬다.
  updateGoals() {
    const remaining = {};
    this.state.bottles.forEach((b, i) => {
      if (isComplete(this.state, i)) remaining[b[0]] = (remaining[b[0]] || 0) + 1;
    });
    const flags = this.targets.map((t) => {
      if (remaining[t] > 0) {
        remaining[t]--;
        return true;
      }
      return false;
    });

    const slots = this.dom.goalSlots;
    slots.innerHTML = '';
    flags.forEach((done, idx) => {
      const el = document.createElement('span');
      el.className = 'goal' + (done ? ' done' : '');
      el.style.setProperty('--c', COLOR_HEX[this.targets[idx]]);
      // 이번에 새로 완성된 칸만 튀어오르게
      if (done && this._goalFlags && !this._goalFlags[idx]) el.classList.add('pop');
      slots.appendChild(el);
    });
    this._goalFlags = flags;
  }

  // --- 레벨 목차 ---
  // 프로토타입이라 전부 열어둔다. 난이도 곡선을 아무 데나 찍어보며 확인할 수 있어야 하므로.
  // 실제 출시 때는 클리어한 다음 레벨까지만 여는 게 맞다.
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
        `레벨 ${i + 1}${this.cleared[i] ? ' (클리어함)' : ''} — 목표 ${lv.targets.length}개`
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
    if (!sticky) {
      this._bannerT = setTimeout(() => this.hideBanner(), 2300);
    }
  }

  hideBanner() {
    this.dom.banner.classList.add('hidden');
  }

  // 디버그/검증용: 현재 상태를 즉시 클리어 상태로 만든다
  autoWin() {
    if (this.won) return true;
    let moves;
    if (this.history.length === 0) {
      moves = this.level.solution;
    } else {
      const r = solve(this.state, this.targets, MIX_RULES, { maxNodes: 600000 });
      if (!r.solved) return false;
      moves = r.moves;
    }
    for (const mv of moves) {
      const res = pour(this.state, mv.from, mv.to, MIX_RULES);
      if (!res) return false;
      this.history.push(this.state);
      this.state = res.state;
    }
    this.renderer.setState(this.state);
    this.renderer.setGuide(null);
    this.updateHud();
    this.updateGoals();
    if (isWin(this.state, this.targets)) {
      this.win();
      return true;
    }
    return false;
  }
}

export { LEVEL_DATA };
