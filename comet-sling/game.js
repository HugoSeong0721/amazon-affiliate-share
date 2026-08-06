// 게임 껍데기 — 엔진(순수 물리)을 화면·소리·저장과 잇는다.
// 모드: ready(출발대) → running(런) → dead(결과) → ready…

import { DT, newRun, step, score, drainEvents } from './engine.js';

const STORE = {
  best: 'cms.best',
  runs: 'cms.runs',
  taught: 'cms.taught', // 첫 릴리즈에 성공하면 1 — 이후로 홀드 힌트를 숨긴다
};

export class Game {
  constructor({ renderer, sound, dom, onRunEnded }) {
    this.renderer = renderer;
    this.sound = sound;
    this.dom = dom;
    this.onRunEnded = onRunEnded || (() => {});

    this.best = Number(localStorage.getItem(STORE.best) || 0);
    this.runs = Number(localStorage.getItem(STORE.runs) || 0);
    this.taught = localStorage.getItem(STORE.taught) === '1';

    this.mode = 'ready';
    this.holding = false;
    this._acc = 0;
    this._deadAt = 0;
    this._newBest = false;
    this._runSeconds = 0;
    this.state = newRun(this._seed());

    this._syncHud();
    this.dom.overlay.classList.add('hidden');
  }

  _seed() {
    // 런마다 다른 시드. 디버그에서는 ?seed=로 고정할 수 있다 (main.js).
    return (Date.now() ^ (Math.random() * 0xffffffff)) >>> 0;
  }

  // ----- 입력 -----

  press() {
    this.holding = true;
    if (this.mode === 'ready') {
      this.mode = 'running';
      this._runSeconds = 0;
      this.dom.overlay.classList.add('hidden');
      this.sound.launch();
    } else if (this.mode === 'dead' && performance.now() - this._deadAt > 600) {
      this._retry();
    }
  }

  releasePress() {
    this.holding = false;
  }

  async _retry() {
    this.holding = false;
    await this.onRunEnded(this._runSeconds); // 광고 게이트 — 짧은 런에는 안 뜬다 (ads.js)
    this.state = newRun(this._forcedSeed ?? this._seed());
    this.mode = 'ready';
    this._newBest = false;
    this.renderer.reset(this.state);
    this.dom.overlay.classList.add('hidden');
    this._syncHud();
  }

  // ----- 프레임 -----

  frame(dtMs) {
    if (this.mode === 'running' && !this.state.dead) {
      this._acc += Math.min(dtMs, 100) / 1000;
      this._runSeconds += Math.min(dtMs, 100) / 1000;
      while (this._acc >= DT) {
        step(this.state, { hold: this.holding });
        this._acc -= DT;
      }
      this._handleEvents();
      this._syncHud();
    }
    this.renderer.draw(this.state, {
      mode: this.mode,
      holding: this.holding,
      showHint: !this.taught,
    });
  }

  _handleEvents() {
    for (const ev of drainEvents(this.state)) {
      if (ev.type === 'latch') this.sound.latch();
      if (ev.type === 'release') {
        this.sound.release();
        if (!this.taught) {
          this.taught = true;
          localStorage.setItem(STORE.taught, '1');
        }
      }
      if (ev.type === 'spark') {
        this.sound.spark();
        this.renderer.burst(ev.x, ev.y);
      }
      if (ev.type === 'death') this._onDeath(ev.cause);
    }
  }

  _onDeath(cause) {
    this.mode = 'dead';
    this._deadAt = performance.now();
    this.holding = false;
    this.runs += 1;
    localStorage.setItem(STORE.runs, String(this.runs));

    const s = score(this.state);
    if (s > this.best) {
      this.best = s;
      this._newBest = true;
      localStorage.setItem(STORE.best, String(s));
    }

    this.sound.crash(cause);
    this.renderer.shake(cause === 'wall' ? 10 : 14);
    this.renderer.explode(this.state.x, this.state.y);
    if (this._newBest) setTimeout(() => this.sound.fanfare(), 550);

    // 폭발이 눈에 들어온 다음에 결과 카드를 올린다
    setTimeout(() => {
      this.dom.overlayScore.textContent = String(s);
      this.dom.overlayBest.textContent = this._newBest ? 'NEW BEST!' : `BEST ${this.best}`;
      this.dom.overlayBest.classList.toggle('newbest', this._newBest);
      this.dom.overlay.classList.remove('hidden');
      this._syncHud();
    }, 650);
  }

  _syncHud() {
    this.dom.scoreLabel.textContent = String(score(this.state));
    this.dom.bestLabel.textContent = `BEST ${this.best}`;
  }
}
