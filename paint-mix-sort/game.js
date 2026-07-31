// 게임 컨트롤러 — 입력을 엔진 호출로 바꾸고, HUD/오버레이/배너를 관리한다.

import {
  canPour,
  pour,
  isWin,
  isComplete,
  solve,
  MIX_RULES,
} from '../sort-engine/index.js';
import { LEVEL_DATA, CAPACITY } from './levels-data.js';
import { COLOR_HEX } from './render.js';

const STORAGE_LEVEL = 'pms.level';

const HINTS = {
  0: '병을 눌러 선택하고, 부을 병을 누르세요.\n🔴 빨강 + 🟡 노랑을 섞으면 🟠 주황!',
  6: '⚠️ 이번엔 빨강 병 자체가 목표예요. 빨강을 다 섞어버리면 안 됩니다!',
};

export class Game {
  constructor({ renderer, sound, dom }) {
    this.renderer = renderer;
    this.sound = sound;
    this.dom = dom;
    const saved = parseInt(localStorage.getItem(STORAGE_LEVEL) || '0', 10);
    this.levelIndex = Number.isFinite(saved) ? Math.min(Math.max(saved, 0), LEVEL_DATA.length - 1) : 0;
    this.busy = false;
    this.won = false;
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
    clearTimeout(this._deadT);
    clearTimeout(this._bannerT);

    this.renderer.clearEffects();
    this.renderer.setState(this.state);
    this.renderer.setSelected(null);
    this.dom.overlay.classList.add('hidden');
    this.hideBanner();
    this.updateHud();
    this.updateTargets();

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

  tap(i) {
    if (this.busy || this.won) return;
    if (!this.state.bottles[i]) return;

    if (this.selected === null) {
      if (this.state.bottles[i].length) {
        this.selected = i;
        this.renderer.setSelected(i);
        this.sound.select();
      } else {
        this.renderer.shakeBottle(i);
      }
      return;
    }

    if (i === this.selected) {
      this.deselect();
      return;
    }

    if (canPour(this.state, this.selected, i, MIX_RULES)) {
      this.doPour(this.selected, i);
    } else if (this.state.bottles[i].length) {
      // 부을 수 없는 곳이면 선택을 옮겨준다 (연타 조작감)
      this.selected = i;
      this.renderer.setSelected(i);
      this.sound.select();
    } else {
      this.renderer.shakeBottle(i);
      this.sound.error();
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

    const completedNow = isComplete(this.state, to) && !isComplete(prev, to);

    this.renderer.animatePour({
      prevState: prev,
      result: res,
      onMix: () => this.sound.mix(),
      onDone: () => {
        this.busy = false;
        this.renderer.setState(this.state);
        this.updateTargets();
        if (completedNow) {
          this.renderer.burstAtBottle(to, COLOR_HEX[res.color]);
          this.sound.complete();
        }
        if (isWin(this.state, this.targets)) this.win();
        else this.scheduleDeadCheck();
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
    this.updateTargets();
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
    this.renderer.celebrate();
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

  updateTargets() {
    // 완성된 병 색 개수를 세서 목표 칩에 체크 표시
    const doneCount = {};
    this.state.bottles.forEach((b, i) => {
      if (isComplete(this.state, i)) doneCount[b[0]] = (doneCount[b[0]] || 0) + 1;
    });
    const bar = this.dom.targetsBar;
    bar.innerHTML = '';
    const remaining = { ...doneCount };
    for (const t of this.targets) {
      const chip = document.createElement('span');
      chip.className = 'chip';
      chip.style.setProperty('--c', COLOR_HEX[t]);
      if (remaining[t] > 0) {
        chip.classList.add('done');
        remaining[t]--;
      }
      bar.appendChild(chip);
    }
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
    this.updateHud();
    this.updateTargets();
    if (isWin(this.state, this.targets)) {
      this.win();
      return true;
    }
    return false;
  }
}

export { LEVEL_DATA };
