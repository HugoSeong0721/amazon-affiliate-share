// 게임 흐름 — 하루(횃불 3개·오늘의 합계·최고 기록)와 다이브 하나하나를 잇는 상태 기계.
// 규칙 판정은 전부 engine.js에 있고, 여기는 타이밍·연출·저장만 오케스트레이션한다.

import { CONFIG, hashSeed, newDive, openDoor, peekDoor, bankOut } from './engine.js';

const STORAGE_DAY = 'tdv.day';
const STORAGE_BEST = 'tdv.best';
const STORAGE_TAUGHT = 'tdv.taught';

const REVEAL_MS = 620; // 문이 돌아가고 내용물을 읽는 시간
const BUST_MS = 1400; // 해골 뒤 나머지 문이 까지는 것을 지켜보는 시간

export class Game {
  constructor({ renderer, sound, dom, dayKey, onDiveEnded }) {
    this.r = renderer;
    this.sound = sound;
    this.dom = dom;
    this.onDiveEnded = onDiveEnded;
    this.torchesPerDay = CONFIG.torchesPerDay;

    this.dayKey = dayKey;
    this.daySeed = hashSeed(dayKey);

    this.best = Number(localStorage.getItem(STORAGE_BEST)) || 0;
    let day = {};
    try {
      day = JSON.parse(localStorage.getItem(STORAGE_DAY) || '{}');
    } catch {}
    // 자정이 지났으면 새 던전, 새 횃불
    this.day = day.key === dayKey ? day : { key: dayKey, used: 0, total: 0 };

    try {
      this.taught = JSON.parse(localStorage.getItem(STORAGE_TAUGHT) || '{}');
    } catch {
      this.taught = {};
    }

    this.state = null;
    this.practice = false; // 횃불을 다 쓴 뒤의 무료 다이브 — 기록에 안 들어간다
    this.peekMode = false;
    this.busy = false; // 연출 중 입력 잠금
    this.diveStartedAt = 0;
    this._forcedSeed = null; // ?seed= 테스트용
  }

  _saveDay() {
    try {
      localStorage.setItem(STORAGE_DAY, JSON.stringify(this.day));
    } catch {}
  }

  _saveTaught() {
    try {
      localStorage.setItem(STORAGE_TAUGHT, JSON.stringify(this.taught));
    } catch {}
  }

  // ----- 다이브 시작/종료 -----

  startDive() {
    this.practice = this.day.used >= this.torchesPerDay;
    if (this._forcedSeed != null) {
      this.state = newDive(this._forcedSeed, 0);
    } else if (this.practice) {
      // 연습은 매번 다른 던전 — 기록에 안 들어가므로 결정론이 필요 없다
      this.state = newDive((Math.random() * 0xffffffff) >>> 0, 0);
    } else {
      this.state = newDive(this.daySeed, this.day.used);
    }
    this.peekMode = false;
    this.busy = false;
    this.diveStartedAt = performance.now();
    this.r.setPeekMode(false);
    this.r.hideOverlay();
    this.r.renderFloor(this);
    if (!this.taught.open) this.r.showFingerHint();
  }

  async _endDive(kind) {
    const s = this.state;
    const floorReached = s.floorNum;
    if (!this.practice) {
      if (kind === 'bank') this.day.total += s.banked;
      this.day.used += 1;
      this._saveDay();
      if (this.day.total > this.best) {
        this.best = this.day.total;
        try {
          localStorage.setItem(STORAGE_BEST, String(this.best));
        } catch {}
      }
    }
    this.r.updateHud(this);

    // 광고는 다이브가 끝난 이 전환 순간에만 — 도중에는 절대 안 뜬다
    const diveSeconds = (performance.now() - this.diveStartedAt) / 1000;
    await this.onDiveEnded?.(diveSeconds);

    const torchesLeft = Math.max(0, this.torchesPerDay - this.day.used);
    const dayOver = !this.practice && torchesLeft === 0;
    const torches = '🔥'.repeat(torchesLeft) + '·'.repeat(this.torchesPerDay - torchesLeft);
    const prefix = this.practice ? 'FREE DIVE — ' : '';

    if (kind === 'bank') {
      this.r.showDiveEnd({
        kicker: `${prefix}BANKED`,
        big: `+${s.banked}`,
        cls: 'ov-good',
        sub: `floor ${floorReached} · today ${this.day.total}${this.best ? ` · best ${this.best}` : ''}`,
        torches,
        note: dayOver ? 'new dungeon at midnight · tap for a free dive' : 'tap to dive again',
      });
    } else {
      this.r.showDiveEnd({
        kicker: `${prefix}LOST`,
        big: `−${s.lost}`,
        cls: 'ov-bad',
        sub: `floor ${floorReached} · today ${this.day.total}${this.best ? ` · best ${this.best}` : ''}`,
        torches,
        note: dayOver ? 'new dungeon at midnight · tap for a free dive' : 'tap to dive again',
      });
    }
    this.busy = false;
  }

  // ----- 입력 -----

  tapDoor(i) {
    const s = this.state;
    if (!s || s.over || this.busy) return;
    if (this.peekMode) {
      this._peek(i);
      return;
    }

    const res = openDoor(s, i);
    if (!res) return;
    if (!this.taught.open) {
      this.taught.open = 1;
      this._saveTaught();
      this.r.hideFingerHint();
    }

    this.busy = true;
    this.peekMode = false;
    this.r.setPeekMode(false);
    this.sound.creak();
    this.r.revealDoor(i, res);

    if (res.type === 'skull') {
      this.sound.skull();
      this.r.shake();
      this.r.revealRest(res.doors, i);
      this.r.updateActions(this);
      setTimeout(() => this._endDive('bust'), BUST_MS);
      return;
    }

    if (res.type === 'coin') this.sound.coin();
    else if (res.type === 'gem') this.sound.gem();
    else if (res.type === 'lantern') this.sound.lantern();
    this.r.updateActions(this);

    setTimeout(() => {
      this.sound.step();
      this.r.renderFloor(this);
      // 3층까지 내려와 주머니가 찼는데 나가 본 적이 없다면 — 나가는 문을 한 번 반짝인다
      if (!this.taught.bank && s.floorNum >= 3 && s.carried > 0) this.r.pulseBank(true);
      this.busy = false;
    }, REVEAL_MS);
  }

  togglePeek() {
    const s = this.state;
    if (!s || s.over || this.busy || s.lanterns <= 0) return;
    this.peekMode = !this.peekMode;
    this.sound.ui();
    this.r.setPeekMode(this.peekMode);
  }

  _peek(i) {
    const t = peekDoor(this.state, i);
    this.peekMode = false;
    this.r.setPeekMode(false);
    if (t == null) return;
    this.sound.lantern();
    this.r.showPeek(i, t);
    this.r.updateActions(this);
  }

  bank() {
    const s = this.state;
    if (!s || s.over || this.busy || s.carried <= 0) return;
    bankOut(s);
    if (!this.taught.bank) {
      this.taught.bank = 1;
      this._saveTaught();
    }
    this.r.pulseBank(false);
    this.busy = true;
    this.sound.bank();
    this._endDive('bank');
  }

  // 오버레이 탭 — 다음 다이브로
  continueFromOverlay() {
    if (this.dom.overlay.classList.contains('hidden')) return;
    this.startDive();
  }
}
