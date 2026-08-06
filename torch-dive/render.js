// DOM 렌더러 — 캔버스 없이 문 카드와 CSS 전환만으로 그린다.
// 엔진 상태를 읽기만 하고, 게임 규칙은 전혀 모른다.

export const ICONS = { coin: '🪙', gem: '💎', lantern: '🏮', skull: '💀' };

// 구성 pips 표시 순서 — 좋은 것부터, 위협은 마지막에
const PIP_ORDER = ['coin', 'gem', 'lantern', 'skull'];

export class Renderer {
  constructor(dom) {
    this.dom = dom;
    this.doorEls = [];
  }

  // ----- HUD -----

  updateHud(game) {
    const { dom } = this;
    const s = game.state;
    if (game.practice) {
      dom.torchRow.textContent = 'FREE DIVE';
      dom.torchRow.classList.add('free');
    } else {
      dom.torchRow.classList.remove('free');
      dom.torchRow.replaceChildren(
        ...Array.from({ length: game.torchesPerDay }, (_, i) => {
          const el = document.createElement('span');
          el.className = 'torch' + (i < game.day.used ? ' spent' : '');
          el.textContent = '🔥';
          return el;
        })
      );
    }
    dom.depthLabel.textContent = s ? `FLOOR ${s.floorNum}` : '';
    dom.todayLabel.textContent = `TODAY ${game.day.total}`;
    this.updateActions(game);
  }

  updateActions(game) {
    const s = game.state;
    const carried = s && !s.over ? s.carried : 0;
    this.dom.bankLabel.textContent = carried > 0 ? `CLIMB OUT +${carried}` : 'CLIMB OUT';
    this.dom.btnBank.disabled = carried <= 0;
    const lanterns = s && !s.over ? s.lanterns : 0;
    this.dom.btnLantern.textContent = `🏮 ×${lanterns}`;
    this.dom.btnLantern.disabled = lanterns <= 0;
  }

  pulseBank(on) {
    this.dom.btnBank.classList.toggle('pulse', on);
  }

  // ----- 층 -----

  renderFloor(game, { animate = true } = {}) {
    const s = game.state;
    this.renderComp(s.floor.comp);
    const wrap = this.dom.doors;
    wrap.replaceChildren();
    this.doorEls = s.floor.doors.map((_, i) => {
      const door = document.createElement('div');
      door.className = 'door';
      door.dataset.i = String(i);
      if (animate) door.style.animationDelay = `${i * 55}ms`;
      door.innerHTML = `
        <div class="door-inner">
          <div class="door-face door-front"></div>
          <div class="door-face door-back"><span class="loot"></span><span class="gain"></span></div>
        </div>
        <div class="peek-tag hidden"></div>`;
      if (animate) door.classList.add('drop-in');
      wrap.appendChild(door);
      return door;
    });
    this.updateHud(game);
  }

  renderComp(comp) {
    const row = this.dom.compRow;
    row.replaceChildren();
    for (const t of PIP_ORDER) {
      for (let k = 0; k < comp[t]; k++) {
        const pip = document.createElement('span');
        pip.className = `pip pip-${t}`;
        pip.textContent = ICONS[t];
        row.appendChild(pip);
      }
    }
  }

  _fillBack(el, type, gain) {
    el.querySelector('.loot').textContent = ICONS[type];
    el.querySelector('.gain').textContent = type === 'skull' ? '' : gain > 0 ? `+${gain}` : '';
  }

  // 문 하나를 연다 — 결과에 따라 좋은/나쁜 잔광
  revealDoor(i, res) {
    const el = this.doorEls[i];
    if (!el) return;
    this._fillBack(el, res.type, res.gain);
    el.classList.add('open', res.type === 'skull' ? 'bad' : 'good');
  }

  // 해골을 밟았다 — 나머지 문도 전부 까서 무엇을 놓쳤는지 보여준다
  revealRest(doors, openedIdx) {
    doors.forEach((type, i) => {
      if (i === openedIdx) return;
      const el = this.doorEls[i];
      if (!el) return;
      this._fillBack(el, type, 0);
      el.style.transitionDelay = `${120 + i * 90}ms`;
      el.classList.add('open', 'ghost');
    });
  }

  // 등불로 미리 보기 — 문은 닫힌 채, 내용물의 그림자만 문틈으로 비친다
  showPeek(i, type) {
    const el = this.doorEls[i];
    if (!el) return;
    const tag = el.querySelector('.peek-tag');
    tag.textContent = ICONS[type];
    tag.classList.remove('hidden');
    el.classList.add('peeked', type === 'skull' ? 'peek-bad' : 'peek-good');
  }

  setPeekMode(on) {
    this.dom.app.classList.toggle('peek-mode', on);
    this.dom.btnLantern.classList.toggle('active', on);
  }

  // ----- 가르침 (문구 없이 손가락 하나로) -----

  showFingerHint() {
    const first = this.doorEls[0];
    if (!first) return;
    const hint = document.createElement('div');
    hint.className = 'finger-hint';
    hint.textContent = '👆';
    first.appendChild(hint);
  }

  hideFingerHint() {
    this.dom.doors.querySelector('.finger-hint')?.remove();
  }

  // ----- 다이브 종료 오버레이 -----

  showDiveEnd({ kicker, big, cls, sub, torches, note }) {
    const { dom } = this;
    dom.ovKicker.textContent = kicker;
    dom.ovBig.textContent = big;
    dom.ovBig.className = cls;
    dom.ovSub.textContent = sub;
    dom.ovTorches.textContent = torches;
    dom.ovNote.textContent = note;
    dom.overlay.classList.remove('hidden');
  }

  hideOverlay() {
    this.dom.overlay.classList.add('hidden');
  }

  shake() {
    this.dom.app.classList.remove('shake');
    void this.dom.app.offsetWidth; // 리플로우로 애니메이션 재시작
    this.dom.app.classList.add('shake');
  }
}
