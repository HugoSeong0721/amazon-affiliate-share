// 게임 흐름 — 고정 스텝 루프, 입력, 점수/최고 기록, 런 종료 오버레이.
// 규칙 판정은 전부 engine.js에 있고, 여기는 루프·연출·저장만 오케스트레이션한다.

import { DT, newRun, step, drop, score } from './engine.js';

const STORAGE_BEST = 'sky.best';
const STORAGE_RUNS = 'sky.runs';

export class Game {
  constructor({ renderer, sound, dom, onRunEnded }) {
    this.r = renderer;
    this.sound = sound;
    this.dom = dom;
    this.onRunEnded = onRunEnded;

    this.best = Number(localStorage.getItem(STORAGE_BEST)) || 0;
    this.runs = Number(localStorage.getItem(STORAGE_RUNS)) || 0;
    this.state = null;
    this.acc = 0;
    this.last = 0;
    this.runStartedAt = 0;
    this.pausedAt = 0; // 일시정지 중에는 런 시간이 흐르지 않는다 (광고 판정이 왜곡되지 않게)
    this.paused = false;
    this.lastScore = 0;
    this._ending = false;
    this._forcedSeed = null; // ?seed= 테스트용

    requestAnimationFrame((t) => this._loop(t));
  }

  startRun() {
    const seed = this._forcedSeed != null ? this._forcedSeed : (Math.random() * 0xffffffff) >>> 0;
    this.state = newRun(seed);
    this.r.reset(this.state);
    this._ending = false;
    this.paused = false;
    this.acc = 0;
    this.runStartedAt = performance.now();
    this.dom.pause.classList.add('hidden');
    this.dom.btnPause.textContent = '⏸';
    this.dom.overlay.classList.add('hidden');
    this._updateHud();
  }

  _updateHud() {
    this.dom.scoreLabel.textContent = String(score(this.state));
    this.dom.bestLabel.textContent = `BEST ${this.best}`;
  }

  // ----- 일시정지 -----
  // 블록이 멈춘다. 화면 밖으로 나가거나(탭 전환·홈 버튼) 랭킹·공유를 열 때도 자동으로 멈춘다.

  pause() {
    if (this.paused || !this.state || this.state.over || this._ending) return false;
    this.paused = true;
    this.pausedAt = performance.now();
    this.dom.pause.classList.remove('hidden');
    this.dom.btnPause.textContent = '▶';
    return true;
  }

  resume() {
    if (!this.paused) return;
    this.paused = false;
    // 멈춰 있던 시간만큼 시작 시각을 밀어 준다 — 런 길이는 실제 플레이 시간만 센다
    this.runStartedAt += performance.now() - this.pausedAt;
    this.acc = 0; // 밀린 물리 스텝을 몰아서 실행하지 않는다
    this.dom.pause.classList.add('hidden');
    this.dom.btnPause.textContent = '⏸';
  }

  togglePause() {
    if (this.paused) this.resume();
    else this.pause();
  }

  // 탭 — 이 게임의 유일한 입력
  tap() {
    const s = this.state;
    if (!s || s.over || this._ending || this.paused) return;
    const res = drop(s);
    if (!res) return;

    if (res.type === 'perfect') {
      this.sound.perfect(res.floor, res.combo);
      this.r.notePerfect();
      this._popCombo(res.combo);
    } else if (res.type === 'cut') {
      this.sound.place(res.floor);
      this.sound.cut();
      this.r.addDebris(s, res.cut, res.floor);
    } else {
      this._endRun();
      return;
    }
    this._updateHud();
  }

  _popCombo(combo) {
    if (combo < 2) return;
    const el = this.dom.comboPop;
    el.textContent = `PERFECT ×${combo}`;
    el.classList.remove('show');
    void el.offsetWidth;
    el.classList.add('show');
  }

  async _endRun() {
    const s = this.state;
    this._ending = true;
    this.sound.over();
    const sc = score(s);
    const isBest = sc > this.best;
    if (isBest) {
      this.best = sc;
      try {
        localStorage.setItem(STORAGE_BEST, String(this.best));
      } catch {}
      setTimeout(() => this.sound.best(), 500);
    }
    this.runs += 1;
    this.lastScore = sc;
    try {
      localStorage.setItem(STORAGE_RUNS, String(this.runs));
    } catch {}

    // 광고는 런이 끝난 이 전환 순간에만 — 플레이 도중에는 절대 안 뜬다
    const runSeconds = (performance.now() - this.runStartedAt) / 1000;
    await this.onRunEnded?.(runSeconds, { score: sc, isBest });

    this.dom.overlayScore.textContent = String(sc);
    this.dom.overlayBest.textContent = isBest ? 'NEW BEST!' : `BEST ${this.best}`;
    this.dom.overlayBest.classList.toggle('new-best', isBest);
    this.dom.overlay.classList.remove('hidden');
  }

  continueFromOverlay() {
    if (this.dom.overlay.classList.contains('hidden')) return;
    this.startRun();
  }

  _loop(t) {
    requestAnimationFrame((t2) => this._loop(t2));
    if (!this.state) return;
    const dtMs = Math.min(100, t - (this.last || t));
    this.last = t;
    // 일시정지 중에도 그리기는 계속한다 (멈춘 화면이 보여야 하니까) — 물리만 멈춘다
    if (!this.paused) {
      this.acc += dtMs / 1000;
      while (this.acc >= DT) {
        step(this.state);
        this.acc -= DT;
      }
      this.r.tick(this.state, dtMs / 1000);
    }
    this.r.draw(this.state);
  }
}
