// 게임 컨트롤러 — 입력을 엔진 호출로 바꾸고, HUD/오버레이/배너를 관리한다.

import {
  canPour,
  pour,
  canShake,
  shake,
  shakePreview,
  isWin,
  isComplete,
  isLocked,
  solve,
  SHAKE_RULES,
} from '../sort-engine/index.js';
import { LEVEL_DATA, CAPACITY } from './levels-data.js';
import { COLOR_HEX, COLOR_NAME } from './render.js';

const STORAGE_LEVEL = 'pms.level';
const STORAGE_CLEARED = 'pms.cleared'; // 레벨당 '0'/'1' 한 글자

// 손가락이 직접 짚어주는 레벨. 1은 흔들기를, 2는 붓기를 가르친다.
const GUIDED_LEVELS = new Set([0, 1]);

const HINTS = {
  5: '🔴 빨강도 목표예요. 빨강 4칸을 그대로 남겨야 합니다.',
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
    // 승리 오버레이는 지연 후 뜨므로, 그 사이 레벨을 옮기면 취소해야 한다.
    // (안 그러면 새 레벨 위에 이전 레벨의 클리어 화면이 튀어나온다)
    clearTimeout(this._winT);

    this.renderer.clearEffects();
    this.renderer.setState(this.state);
    this.renderer.setSelected(null);
    this.dom.overlay.classList.add('hidden');
    this.closeLevels();
    this.hideBanner();
    this.updateHud();
    this.updateGoals();
    this.updateShakeButton();
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
    this.updateShakeButton();
  }

  // --- 튜토리얼 안내 ---
  // 안내 레벨에서 지금 둬야 할 수. 입력을 이 수로만 제한한다.
  nextGuideMove() {
    if (!this.guided || this.won || this.busy) return null;
    return this.level.solution[this.history.length] || null;
  }

  updateGuide() {
    const g = this.nextGuideMove();
    if (!g) {
      this.renderer.setGuide(null);
      this.dom.btnShake.classList.remove('pulse');
      return;
    }
    if (g.type === 'shake') {
      // 병을 먼저 고르게 하고, 고른 뒤에는 흔들기 버튼을 강조한다
      const picked = this.selected === g.at;
      this.renderer.setGuide(picked ? null : g.at);
      this.dom.btnShake.classList.toggle('pulse', picked);
    } else {
      this.renderer.setGuide(this.selected === null ? g.from : g.to);
      this.dom.btnShake.classList.remove('pulse');
    }
  }

  // 선택 시도. 비었거나 완성돼 잠긴 병이면 거절한다.
  trySelect(i) {
    if (!this.state.bottles[i].length || isLocked(this.state, i, SHAKE_RULES)) {
      this.renderer.shakeBottle(i);
      this.sound.error();
      return false;
    }
    this.selected = i;
    this.renderer.setSelected(i);
    this.sound.select();
    this.updateShakeButton();
    this.updateGuide();
    return true;
  }

  tap(i) {
    if (this.busy || this.won) return;
    if (!this.state.bottles[i]) return;

    // 안내 중에는 짚어준 병만 반응한다
    const g = this.nextGuideMove();
    if (g) {
      const want = g.type === 'shake' ? g.at : this.selected === null ? g.from : g.to;
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

    if (canPour(this.state, this.selected, i, SHAKE_RULES)) {
      this.doPour(this.selected, i);
    } else {
      // 부을 수 없는 곳이면 선택을 옮겨준다. 옮길 수 없으면 기존 선택을 유지한다.
      this.trySelect(i);
    }
  }

  doPour(from, to) {
    const prev = this.state;
    const res = pour(prev, from, to, SHAKE_RULES);
    if (!res) return;

    this.history.push(prev);
    this.state = res.state;
    this.deselect();
    this.busy = true;
    this.hideBanner();
    this.sound.pour(res.amount);
    this.updateHud();
    this.renderer.setGuide(null);
    this.dom.btnShake.classList.remove('pulse');

    const completedNow = isComplete(this.state, to) && !isComplete(prev, to);

    this.renderer.animatePour({
      prevState: prev,
      result: res,
      onDone: () => this.afterMove(completedNow ? { at: to, color: res.color } : null),
    });
  }

  doShake() {
    if (this.busy || this.won || this.selected === null) return;
    const at = this.selected;
    const prev = this.state;
    const res = shake(prev, at, SHAKE_RULES);
    if (!res) {
      this.renderer.shakeBottle(at);
      this.sound.error();
      return;
    }

    const g = this.nextGuideMove();
    if (g && !(g.type === 'shake' && g.at === at)) {
      this.renderer.shakeBottle(at);
      return;
    }

    this.history.push(prev);
    this.state = res.state;
    this.deselect();
    this.busy = true;
    this.hideBanner();
    this.sound.mix();
    this.updateHud();
    this.renderer.setGuide(null);
    this.dom.btnShake.classList.remove('pulse');

    this.renderer.animateShake({
      prevState: prev,
      result: res,
      onDone: () => this.afterMove({ at, color: res.color }),
    });
  }

  // 한 수가 끝난 뒤 공통 처리
  afterMove(completed) {
    this.busy = false;
    this.renderer.setState(this.state);
    this.updateGoals();
    this.updateShakeButton();
    if (completed) {
      this.renderer.burstAtBottle(completed.at, COLOR_HEX[completed.color]);
      this.sound.complete();
    }
    if (isWin(this.state, this.targets)) this.win();
    else {
      this.updateGuide();
      this.scheduleDeadCheck();
    }
  }

  undo() {
    if (this.busy || this.won || !this.history.length) return;
    this.state = this.history.pop();
    this.deselect();
    this.renderer.setState(this.state);
    this.hideBanner();
    this.updateHud();
    this.updateGoals();
    this.updateShakeButton();
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
      const r = solve(this.state, this.targets, SHAKE_RULES, { maxNodes: 25000 });
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
    this.dom.btnShake.classList.add('hidden');
    this.cleared[this.levelIndex] = true;
    this.saveCleared();
    if (this.levelIndex + 1 < LEVEL_DATA.length) {
      localStorage.setItem(STORAGE_LEVEL, String(this.levelIndex + 1));
    }
    const last = this.levelIndex >= LEVEL_DATA.length - 1;
    this.dom.overlayTitle.textContent = last ? '🎉 전 레벨 클리어!' : `레벨 ${this.levelIndex + 1} 클리어!`;
    this.dom.overlayInfo.textContent = `${this.history.length}수 · 참고 답안 ${this.level.solutionLength}수`;
    this.dom.btnNext.textContent = last ? '처음부터 다시 ↻' : '다음 레벨 ▶';
    this._winT = setTimeout(() => this.dom.overlay.classList.remove('hidden'), 850);
  }

  updateHud() {
    this.dom.levelLabel.textContent = `레벨 ${this.levelIndex + 1}`;
    this.dom.moveLabel.textContent = `${this.history.length}수 · 총 ${LEVEL_DATA.length}레벨`;
    this.dom.btnUndo.disabled = !this.history.length;
  }

  // 고른 병을 흔들 수 있으면 버튼을 띄우고, 나올 색을 미리 보여준다.
  updateShakeButton() {
    const btn = this.dom.btnShake;
    const at = this.selected;
    const color = at === null || this.won ? null : shakePreview(this.state, at, SHAKE_RULES);
    if (!color) {
      btn.classList.add('hidden');
      btn.classList.remove('pulse');
      return;
    }
    btn.classList.remove('hidden');
    btn.style.setProperty('--c', COLOR_HEX[color]);
    btn.innerHTML = `흔들어 섞기 <span class="swatch"></span>`;
    btn.setAttribute('aria-label', `흔들어 ${COLOR_NAME[color]} 만들기`);
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
      const r = solve(this.state, this.targets, SHAKE_RULES, { maxNodes: 600000 });
      if (!r.solved) return false;
      moves = r.moves;
    }
    for (const mv of moves) {
      const res =
        mv.type === 'shake'
          ? shake(this.state, mv.at, SHAKE_RULES)
          : pour(this.state, mv.from, mv.to, SHAKE_RULES);
      if (!res) return false;
      this.history.push(this.state);
      this.state = res.state;
    }
    this.renderer.setState(this.state);
    this.renderer.setGuide(null);
    this.deselect();
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
