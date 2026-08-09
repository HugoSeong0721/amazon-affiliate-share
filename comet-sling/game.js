// 게임 껍데기 — 엔진(순수 물리)을 화면·소리·저장과 잇는다.
// 모드: ready(출발대) → running(런) → dead(결과) → ready…

import { DT, WORLD, newRun, step, score, drainEvents, aim } from './engine.js';
import { submitScore } from './signup.js';

const STORE = {
  best: 'cms.best',
  runs: 'cms.runs',
  taught: 'cms.taught', // 성공한 릴리즈 누적 수 — 0이면 유령 시범, 3 미만이면 코치 손가락
};

const COACH_UNTIL_RELEASES = 3;

export class Game {
  constructor({ renderer, sound, dom, onRunEnded, challengeScore = null }) {
    this.renderer = renderer;
    this.sound = sound;
    this.dom = dom;
    this.onRunEnded = onRunEnded || (() => {});

    // 도전장: 공유 링크(?beat=N)로 들어오면 친구 기록이 결승선으로 그려진다
    this.challenge = challengeScore > 0
      ? { score: challengeScore, height: challengeScore * 4, beaten: false }
      : null;

    this.dom.btnShare.addEventListener('click', (e) => {
      e.stopPropagation();
      this._share();
    });

    this.best = Number(localStorage.getItem(STORE.best) || 0);
    this.runs = Number(localStorage.getItem(STORE.runs) || 0);
    this.releases = Number(localStorage.getItem(STORE.taught) || 0);

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
      this._checkChallenge();
      this._syncHud();
    }
    this.renderer.draw(this.state, {
      mode: this.mode,
      holding: this.holding,
      demo: this.releases === 0,
      coach: this._coach(),
      challenge: this.challenge,
    });
  }

  // 결승선(친구 기록 높이)을 넘는 순간 한 번 축하한다
  _checkChallenge() {
    const c = this.challenge;
    if (!c || c.beaten || this.state.height < c.height) return;
    c.beaten = true;
    this.sound.fanfare();
    this.renderer.burst(this.state.x, this.state.y);
  }

  // 결과 공유 — 공유 시트가 있으면 그걸로, 없으면 클립보드 복사
  async _share() {
    const s = Math.max(score(this.state), this.best);
    const url = new URL(location.href);
    url.search = `?beat=${s}`;
    const text = `☄️ I scored ${s} in Comet Sling — can you beat me?`;
    try {
      if (navigator.share) {
        await navigator.share({ text, url: url.toString() });
        return;
      }
    } catch {
      return; // 사용자가 공유 시트를 닫음 — 조용히
    }
    try {
      await navigator.clipboard.writeText(`${text} ${url}`);
      this._toast('Link copied!');
    } catch {
      this._toast(url.toString());
    }
  }

  _toast(msg) {
    const t = this.dom.toast;
    t.textContent = msg;
    t.classList.remove('hidden');
    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(() => t.classList.add('hidden'), 1800);
  }

  // 아직 손에 익기 전(릴리즈 3회 미만)에는 지금 뭘 해야 하는지 손가락이 짚어준다
  _coach() {
    if (this.releases >= COACH_UNTIL_RELEASES) return null;
    if (this.mode !== 'running' || this.state.dead) return null;
    const s = this.state;
    if (s.mode === 'orbit') {
      // 릴리즈 타이밍: 조준이 앵커에 잠겼거나 접선이 위를 향할 때
      const o = s.orbit;
      const upness = Math.cos(o.theta) * o.dir;
      return aim(s).snapped !== null || upness > 0.45 ? 'release' : null;
    }
    if (!this.holding) {
      // 잡을 수 있는 앵커가 사거리 안에 있는데 안 누르고 있다
      const near = s.anchors.some(
        (a) => a.y >= s.y - WORLD.captureR && Math.hypot(a.x - s.x, a.y - s.y) < WORLD.captureR * 1.2
      );
      if (near) return 'hold';
    }
    return null;
  }

  _handleEvents() {
    for (const ev of drainEvents(this.state)) {
      if (ev.type === 'latch') this.sound.latch();
      if (ev.type === 'release') {
        this.sound.release();
        if (this.releases < COACH_UNTIL_RELEASES) {
          this.releases += 1;
          localStorage.setItem(STORE.taught, String(this.releases));
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
      submitScore(s); // 랭킹 시트로 (endpoint 설정 시) — 신기록만 보낸다
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
      const c = this.challenge;
      this.dom.overlayChallenge.classList.toggle('hidden', !c);
      if (c) {
        this.dom.overlayChallenge.textContent = c.beaten
          ? `🏆 You beat your friend's ${c.score}!`
          : `🏁 ${c.score} to beat`;
      }
      this.dom.overlay.classList.remove('hidden');
      this._syncHud();
    }, 650);
  }

  _syncHud() {
    this.dom.scoreLabel.textContent = String(score(this.state));
    this.dom.bestLabel.textContent = `BEST ${this.best}`;
  }
}
