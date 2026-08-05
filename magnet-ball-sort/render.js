// 캔버스 렌더러 — 튜브, 구슬, 자석 집기/날아가기 애니메이션, 충격 연출.
// 게임 로직은 전혀 모르고, 상태와 수(move) 결과만 받아 그린다.
//
// 이 게임의 규칙은 설명 대신 애니메이션으로 전달된다:
// 튜브를 누르면 맨 위 같은 색 구슬들이 자석처럼 딱 붙어 함께 떠오른다.
// 몇 개가 움직일지 손대기 전에 눈으로 보이므로 규칙을 글로 읽을 필요가 없다.
//
// 손맛은 "부딪히는 느낌"에서 나온다. 구슬이 도착만 하지 않고,
// 착지할 때 눌리고 · 아래 구슬들이 밀리고 · 링이 퍼지고 · 화면이 흔들린다.

export const COLOR_HEX = {
  R: '#ff4d5a',
  O: '#ff9838',
  Y: '#ffd93d',
  G: '#35d07f',
  C: '#2fd3d3',
  B: '#4a90ff',
  P: '#a96bff',
  K: '#ff6bd0',
};

export const COLOR_NAME = {
  R: '빨강', O: '주황', Y: '노랑', G: '초록',
  C: '청록', B: '파랑', P: '보라', K: '분홍',
};

const rgbCache = new Map();
function hexToRgb(hex) {
  let c = rgbCache.get(hex);
  if (!c) {
    c = [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
    rgbCache.set(hex, c);
  }
  return c;
}

// amt > 0 이면 흰쪽, < 0 이면 검은쪽으로. 검정을 직접 섞지 않아 색 정체성이 유지된다.
function shade(hex, amt) {
  const [r, g, b] = hexToRgb(hex);
  const t = Math.abs(amt);
  const target = amt > 0 ? 255 : 0;
  return `rgb(${Math.round(r + (target - r) * t)},${Math.round(g + (target - g) * t)},${Math.round(
    b + (target - b) * t
  )})`;
}
function rgba(hex, a) {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r},${g},${b},${a})`;
}

const clamp01 = (t) => Math.max(0, Math.min(1, t));
const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
const easeInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const easeOutBack = (t) => 1 + 2.2 * Math.pow(t - 1, 3) + 1.4 * Math.pow(t - 1, 2);

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  if (ctx.roundRect) {
    ctx.roundRect(x, y, w, h, r);
    return;
  }
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

// 2차 베지어
function qbez(p0, cp, p1, t) {
  const u = 1 - t;
  return {
    x: u * u * p0.x + 2 * u * t * cp.x + t * t * p1.x,
    y: u * u * p0.y + 2 * u * t * cp.y + t * t * p1.y,
  };
}

const LIFT_GAP = 15; // 튜브 입구와 떠오른 구슬 사이 간격
const IMPACT_DUR = 190; // 착지 충격이 잦아드는 시간(ms)

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.cssW = 0;
    this.cssH = 0;
    this.state = null;
    this.capacity = 4;
    this.held = null; // { tube, color, count, t0 }
    this.flight = null;
    this.nudge = null; // 잘못 눌렀을 때 흔들기
    this.guide = null;
    this.impacts = []; // 착지·완성 충격 { tube, index, t0, dur, amp }
    this.rings = []; // 퍼지는 링 { x, y, t0, dur, hex, r0, r1 }
    this.faces = new Map(); // 튜브 → 얼굴이 뜨기 시작한 시각
    this.screenShake = null;
    this.particles = [];
    this.rects = [];
    this._loop = this._loop.bind(this);
    requestAnimationFrame(this._loop);
  }

  resize() {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    if (w < 10 || h < 10) return;
    this.cssW = w;
    this.cssH = h;
    this.canvas.width = Math.round(w * this.dpr);
    this.canvas.height = Math.round(h * this.dpr);
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this._layout();
  }

  setState(state) {
    this.state = state;
    this.capacity = state.capacity;
    this._layout();
  }

  // 맨 위 같은 색 구슬 묶음을 자석처럼 집어 올린다. null이면 놓는다.
  hold(tube, color, count) {
    this.held = tube === null ? null : { tube, color, count, t0: performance.now() };
  }

  setGuide(i) {
    this.guide = i;
  }

  nudgeTube(i) {
    this.nudge = { i, t0: performance.now() };
  }

  clearEffects() {
    this.held = null;
    this.flight = null;
    this.nudge = null;
    this.guide = null;
    this.impacts = [];
    this.rings = [];
    this.faces.clear();
    this.screenShake = null;
    this.particles = [];
  }

  _layout() {
    if (!this.state || this.cssW < 10) {
      this.rects = [];
      return;
    }
    const n = this.state.bottles.length;
    // 한 줄에 최대 5개까지. 튜브가 많아지면 줄을 늘린다.
    const rows = Math.ceil(n / 5);
    const perRow = Math.ceil(n / rows);
    const padX = 14;
    const gap = Math.max(10, Math.min(16, (this.cssW - padX * 2) * 0.035));
    // 구슬이 관 폭을 꽉 채우도록: 한 칸 높이 ≈ 관 내부 폭이 되는 비율
    const ratio = this.capacity * 0.9;
    let tw = Math.min(66, (this.cssW - padX * 2 - gap * (perRow - 1)) / perRow);
    const topPad = 34; // 떠오른 구슬 + 완성 배지 여유
    const bottomPad = 16;
    const rowGap = 52;
    const availH = this.cssH - topPad - bottomPad;
    const thMax = (availH - (rows - 1) * rowGap) / rows;
    const th = Math.min(tw * ratio, thMax);
    tw = th / ratio;

    const contentH = rows * th + (rows - 1) * rowGap;
    const startY = topPad + Math.max(0, (availH - contentH) / 2);
    this.rects = [];
    for (let r = 0; r < rows; r++) {
      const start = r * perRow;
      const count = Math.min(perRow, n - start);
      const totalW = count * tw + (count - 1) * gap;
      const x0 = (this.cssW - totalW) / 2;
      const y = startY + r * (th + rowGap);
      for (let k = 0; k < count; k++) {
        this.rects.push({ x: x0 + k * (tw + gap), y, w: tw, h: th });
      }
    }
  }

  tubeCenter(i) {
    const r = this.rects[i];
    return r ? { x: r.x + r.w / 2, y: r.y + r.h / 2 } : null;
  }

  hitTest(x, y) {
    for (let i = 0; i < this.rects.length; i++) {
      const r = this.rects[i];
      // 위쪽은 떠오른 구슬까지 눌릴 수 있게 넉넉히 잡는다
      if (x >= r.x - 7 && x <= r.x + r.w + 7 && y >= r.y - 46 && y <= r.y + r.h + 10) return i;
    }
    return null;
  }

  _metrics(rect) {
    const pad = 4;
    const slotH = (rect.h - pad * 2) / this.capacity;
    const ballR = Math.min(rect.w - pad * 2, slotH) * 0.46;
    return { pad, slotH, ballR };
  }

  // 튜브 안 k번째 칸(0=바닥) 구슬 중심
  _slotPos(rect, k) {
    const { pad, slotH } = this._metrics(rect);
    return { x: rect.x + rect.w / 2, y: rect.y + rect.h - pad - slotH * (k + 0.5) };
  }

  // 떠오른 묶음의 j번째(0=아래) 구슬 중심. 자석처럼 딱 붙어 있다.
  _heldPos(rect, j) {
    const { ballR } = this._metrics(rect);
    return {
      x: rect.x + rect.w / 2,
      y: rect.y - LIFT_GAP - ballR - j * (ballR * 2 + 0.5),
    };
  }

  // 구슬이 날아가는 애니메이션.
  // amount개는 목적지로, 남은 것(공간 부족)은 원래 튜브로 되돌아간다.
  // onLand(slotIndex)는 구슬 하나가 실제로 착지하는 순간마다 호출된다 — 소리를 여기 맞춘다.
  animateMove({ result, heldCount, onLand, onDone }) {
    const { from, to, amount } = result;
    if (!this.rects[from] || !this.rects[to]) {
      onDone && onDone();
      return;
    }
    this.flight = {
      from,
      to,
      color: result.color,
      amount,
      returning: Math.max(0, heldCount - amount),
      t0: performance.now(),
      TRAVEL: 205, // 빠릿한 게 손맛이 좋다
      STAGGER: 26,
      onLand,
      onDone,
      doneFired: false,
      landedAt: new Map(),
    };
    this.held = null;
  }

  // 착지 충격: 맞은 칸이 눌리고 아래 구슬들이 밀린다.
  addImpact(tube, index, amp = 0.26, dur = IMPACT_DUR) {
    this.impacts.push({ tube, index, t0: performance.now(), dur, amp });
  }

  addRing(x, y, hex, { r0 = 4, r1 = 30, dur = 320 } = {}) {
    this.rings.push({ x, y, hex, r0, r1, dur, t0: performance.now() });
  }

  shakeScreen(mag = 4, dur = 200) {
    this.screenShake = { t0: performance.now(), mag, dur };
  }

  // 튜브 하나가 완성됐을 때: 링 + 구슬이 아래에서 위로 톡톡 튀는 파동 + 살짝 화면 흔들림.
  // 그리고 갇혀 있던 구슬 친구들이 눈을 뜬다 — 이게 정렬하는 이유다.
  completeTube(i, hex) {
    const rect = this.rects[i];
    if (!rect) return;
    const now = performance.now();
    for (let k = 0; k < this.capacity; k++) {
      this.impacts.push({ tube: i, index: k, t0: now + k * 45, dur: 230, amp: 0.3 });
    }
    this.addRing(rect.x + rect.w / 2, rect.y + rect.h / 2, hex, { r0: 8, r1: rect.w * 1.5, dur: 460 });
    this.shakeScreen(3.5, 190);
    this.burstAtTube(i, hex, 20);
    this.faces.set(i, now + 150); // 파동이 지나간 뒤 얼굴이 뜬다
  }

  burstAtTube(i, hex, n = 18) {
    const r = this.rects[i];
    if (!r) return;
    this._burst(r.x + r.w / 2, r.y + 8, hex, n);
  }

  _burst(x, y, hex, n = 14) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 60 + Math.random() * 170;
      this.particles.push({
        x, y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 90,
        g: 420,
        ttl: 0.45 + Math.random() * 0.5,
        age: 0,
        size: 2 + Math.random() * 3,
        color: hex,
        shape: 'circle',
      });
    }
  }

  celebrate() {
    const colors = Object.values(COLOR_HEX);
    for (let i = 0; i < 120; i++) {
      this.particles.push({
        x: Math.random() * this.cssW,
        y: -20 - Math.random() * 60,
        vx: (Math.random() - 0.5) * 90,
        vy: 70 + Math.random() * 160,
        g: 230,
        ttl: 1.4 + Math.random() * 0.9,
        age: 0,
        w: 5 + Math.random() * 4,
        h: 8 + Math.random() * 5,
        rot: Math.random() * Math.PI,
        vr: (Math.random() - 0.5) * 9,
        color: colors[(Math.random() * colors.length) | 0],
        shape: 'rect',
      });
    }
  }

  // 특정 칸 구슬이 지금 받고 있는 충격량 → 눌림 정도와 밀림 거리
  _impactAt(tube, index, now) {
    let squash = 1;
    let dy = 0;
    for (const im of this.impacts) {
      if (im.tube !== tube) continue;
      const d = im.index - index; // 0 = 맞은 칸, 1 = 그 아래, 2 = 그 아래아래
      if (d < 0 || d > 2) continue;
      const p = (now - im.t0) / im.dur;
      if (p < 0 || p >= 1) continue;
      const decay = d === 0 ? 1 : d === 1 ? 0.45 : 0.18;
      const amp = Math.pow(1 - p, 2.2) * im.amp * decay;
      squash -= amp;
      dy += amp * 7;
    }
    return { squash: Math.max(0.62, squash), dy };
  }

  // ---------- 매 프레임 ----------

  _loop(now) {
    requestAnimationFrame(this._loop);
    const ctx = this.ctx;
    if (!this.state || !this.rects.length) {
      ctx && ctx.clearRect(0, 0, this.cssW, this.cssH);
      return;
    }
    ctx.clearRect(0, 0, this.cssW, this.cssH);

    // 끝난 충격/링 정리
    if (this.impacts.length) {
      this.impacts = this.impacts.filter((im) => now - im.t0 < im.dur);
    }
    if (this.rings.length) {
      this.rings = this.rings.filter((r) => now - r.t0 < r.dur);
    }

    let sx = 0;
    let sy = 0;
    if (this.screenShake) {
      const p = (now - this.screenShake.t0) / this.screenShake.dur;
      if (p >= 1) this.screenShake = null;
      else {
        const m = this.screenShake.mag * Math.pow(1 - p, 2);
        sx = Math.sin(now / 11) * m;
        sy = Math.cos(now / 8) * m * 0.6;
      }
    }

    ctx.save();
    if (sx || sy) ctx.translate(sx, sy);

    const F = this.flight;
    // 공중에 떠 있어서 튜브에 그리지 않을 구슬 수
    const airborne = new Map();
    if (F) {
      airborne.set(F.to, F.amount);
      if (F.returning) airborne.set(F.from, (airborne.get(F.from) || 0) + F.returning);
    }
    if (this.held) airborne.set(this.held.tube, this.held.count);

    for (let i = 0; i < this.state.bottles.length; i++) {
      const rect = { ...this.rects[i] };
      if (this.nudge && this.nudge.i === i) {
        const el = now - this.nudge.t0;
        if (el < 300) rect.x += Math.sin(el / 16) * 5 * (1 - el / 300);
        else this.nudge = null;
      }
      const balls = this.state.bottles[i];
      const hideTop = airborne.get(i) || 0;
      const visible = balls.slice(0, Math.max(0, balls.length - hideTop));
      const complete = balls.length === this.capacity && new Set(balls).size === 1;
      // 안내 중에는 다른 튜브를 물러나게 하되, 색 구분이 이 게임의 핵심이라 살짝만 죽인다
      const dim = this.guide !== null && i !== this.guide && !(this.held && this.held.tube === i);

      if (dim) ctx.save(), (ctx.globalAlpha = 0.62);
      this._drawTube(rect, visible, i, now, {
        selected: this.held?.tube === i,
        complete,
      });
      if (dim) ctx.restore();
    }

    this._drawRings(now);
    if (this.held) this._drawHeld(now);
    if (F) this._drawFlight(now, F);
    if (!this.held && !F) this._drawGuide(now);
    this._drawParticles(now);

    ctx.restore();
  }

  _drawRings(now) {
    const ctx = this.ctx;
    for (const ring of this.rings) {
      const p = clamp01((now - ring.t0) / ring.dur);
      const r = ring.r0 + (ring.r1 - ring.r0) * easeOutCubic(p);
      ctx.save();
      ctx.strokeStyle = rgba(ring.hex, 0.7 * (1 - p));
      ctx.lineWidth = 3 * (1 - p) + 0.6;
      ctx.beginPath();
      ctx.arc(ring.x, ring.y, r, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
  }

  // 떠오르는 중~떠 있는 묶음
  _drawHeld(now) {
    const H = this.held;
    const rect = this.rects[H.tube];
    if (!rect) return;
    const balls = this.state.bottles[H.tube];
    const base = balls.length - H.count; // 묶음 아래에 남는 구슬 수
    const raw = clamp01((now - H.t0) / 190);
    const t = easeOutBack(raw);
    const hex = COLOR_HEX[H.color];
    // 살짝 위아래로 떠 있는 느낌
    const bob = Math.sin(now / 420) * 2;
    // 솟아오를 때 살짝 늘어난다 (자석에 끌려 올라가는 느낌)
    const stretch = 1 + 0.2 * (1 - raw) * (raw > 0 ? 1 : 0);
    const { ballR } = this._metrics(rect);

    for (let j = 0; j < H.count; j++) {
      const from = this._slotPos(rect, base + j);
      const to = this._heldPos(rect, j);
      const p = {
        x: from.x + (to.x - from.x) * t,
        y: from.y + (to.y - from.y) * t + bob * t,
      };
      this._drawBall(p.x, p.y, ballR, hex, { magnet: raw > 0.55, squash: stretch });
    }
  }

  _drawFlight(now, F) {
    const el = now - F.t0;
    const srcRect = this.rects[F.from];
    const dstRect = this.rects[F.to];
    const hex = COLOR_HEX[F.color];
    const { ballR } = this._metrics(dstRect);
    const dstLen = this.state.bottles[F.to].length;
    const srcLen = this.state.bottles[F.from].length;
    let allDone = true;

    // 목적지로 날아가는 구슬
    for (let j = 0; j < F.amount; j++) {
      // 묶음 위쪽 구슬이 먼저 떠난다 (자석에서 떨어지듯)
      const order = F.amount - 1 - j;
      const start = order * F.STAGGER;
      const t = clamp01((el - start) / F.TRAVEL);
      const slotIndex = dstLen - F.amount + j;
      const p0 = this._heldPos(srcRect, F.returning + order);
      const p1 = this._slotPos(dstRect, slotIndex);
      const cp = { x: (p0.x + p1.x) / 2, y: Math.min(p0.y, p1.y) - 46 };

      if (t < 1) {
        allDone = false;
        const e = easeInOut(t);
        // 잔상 — 빠른 움직임이 눈에 남게. 입체 구슬을 반투명하게 겹치면 어두운 얼룩처럼
        // 보이므로, 밝은 단색 원으로 그려 색이 흐르는 궤적처럼 읽히게 한다.
        const ctx = this.ctx;
        for (const [back, alpha] of [[0.14, 0.16], [0.07, 0.3]]) {
          const g = qbez(p0, cp, p1, easeInOut(Math.max(0, t - back)));
          ctx.save();
          ctx.globalAlpha = alpha;
          ctx.fillStyle = shade(hex, 0.2);
          ctx.beginPath();
          ctx.arc(g.x, g.y, ballR * 0.88, 0, Math.PI * 2);
          ctx.fill();
          ctx.restore();
        }
        const p = qbez(p0, cp, p1, e);
        this._drawBall(p.x, p.y, ballR, hex, {});
      } else {
        if (!F.landedAt.has(j)) {
          F.landedAt.set(j, now);
          this.addImpact(F.to, slotIndex);
          this.addRing(p1.x, p1.y, hex, { r0: ballR * 0.7, r1: ballR * 2.1, dur: 260 });
          F.onLand && F.onLand(slotIndex);
        }
        const { squash, dy } = this._impactAt(F.to, slotIndex, now);
        this._drawBall(p1.x, p1.y + dy, ballR, hex, { squash });
      }
    }

    // 공간이 없어 되돌아가는 구슬
    for (let j = 0; j < F.returning; j++) {
      const t = clamp01(el / (F.TRAVEL * 0.75));
      if (t < 1) allDone = false;
      const p0 = this._heldPos(srcRect, j);
      const slotIndex = srcLen - F.returning + j;
      const p1 = this._slotPos(srcRect, slotIndex);
      const e = easeOutCubic(t);
      const r = this._metrics(srcRect).ballR;
      if (t >= 1) {
        const { squash, dy } = this._impactAt(F.from, slotIndex, now);
        this._drawBall(p1.x, p1.y + dy, r, hex, { squash });
      } else {
        this._drawBall(p0.x, p0.y + (p1.y - p0.y) * e, r, hex, {});
      }
    }

    if (allDone) {
      this.flight = null;
      if (!F.doneFired) {
        F.doneFired = true;
        F.onDone && F.onDone();
      }
    }
  }

  _drawTube(rect, balls, tubeIndex, now, { selected, complete }) {
    const ctx = this.ctx;
    const { x, y, w, h } = rect;
    const r = w * 0.42;
    const { ballR } = this._metrics(rect);

    // 바닥 그림자
    ctx.save();
    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.beginPath();
    ctx.ellipse(x + w / 2, y + h + 6, w * 0.4, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    if (selected || complete) {
      ctx.save();
      ctx.shadowColor = selected ? 'rgba(120,200,255,0.85)' : 'rgba(255,214,110,0.6)';
      ctx.shadowBlur = selected ? 20 : 15;
      rr(ctx, x, y, w, h, r);
      ctx.fillStyle = 'rgba(255,255,255,0.02)';
      ctx.fill();
      ctx.restore();
    }

    // 유리관
    rr(ctx, x, y, w, h, r);
    ctx.fillStyle = 'rgba(255,255,255,0.05)';
    ctx.fill();

    // 구슬 — 충격을 받은 칸은 눌리고 밀린다.
    // 완성된 튜브의 구슬은 눈을 뜬다 (갇혀 있던 친구가 깨어난 것)
    const faceAt = complete ? (this.faces.get(tubeIndex) ?? -Infinity) : null;
    const faceIn = faceAt === null ? 0 : clamp01((now - faceAt) / 260);
    for (let k = 0; k < balls.length; k++) {
      const p = this._slotPos(rect, k);
      const { squash, dy } = this._impactAt(tubeIndex, k, now);
      this._drawBall(p.x, p.y + dy, ballR, COLOR_HEX[balls[k]], {
        squash,
        face: faceIn > 0 ? faceIn : 0,
        faceSeed: tubeIndex * 7 + k,
        now,
      });
    }

    // 유리 광택
    ctx.save();
    rr(ctx, x + 1, y + 1, w - 2, h - 2, r - 1);
    ctx.clip();
    ctx.fillStyle = 'rgba(255,255,255,0.06)';
    rr(ctx, x + w * 0.14, y + 8, w * 0.15, h - 16, w * 0.075);
    ctx.fill();
    ctx.restore();

    rr(ctx, x, y, w, h, r);
    ctx.strokeStyle = selected ? 'rgba(160,215,255,0.8)' : 'rgba(255,255,255,0.26)';
    ctx.lineWidth = selected ? 2.2 : 1.5;
    ctx.stroke();

    // 입구
    ctx.beginPath();
    ctx.ellipse(x + w / 2, y + 1, w / 2 - 2, 3.2, 0, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.32)';
    ctx.lineWidth = 1.4;
    ctx.stroke();

    if (complete) {
      const bx = x + w - 2;
      const by = y - 6;
      ctx.save();
      ctx.fillStyle = '#ffd166';
      ctx.beginPath();
      ctx.arc(bx, by, 9, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(0,0,0,0.55)';
      ctx.lineWidth = 2.2;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(bx - 3.6, by + 0.2);
      ctx.lineTo(bx - 1, by + 3);
      ctx.lineTo(bx + 3.8, by - 2.8);
      ctx.stroke();
      ctx.restore();
    }
  }

  // 깨어난 구슬 친구의 얼굴. grow는 0~1 (뜨는 중), seed로 눈 깜빡임 타이밍을 흩는다.
  _drawFace(r, grow, seed, now) {
    const ctx = this.ctx;
    const s = easeOutBack(clamp01(grow));
    if (s <= 0) return;
    // 3초쯤마다 한 번씩, 구슬마다 다른 시점에 깜빡인다
    const cycle = (now / 1000 + seed * 0.83) % 3.2;
    const blink = cycle < 0.13 ? 1 - Math.abs(cycle - 0.065) / 0.065 : 0;
    const eyeR = r * 0.13 * s;
    const eyeY = -r * 0.16;
    const eyeX = r * 0.3;

    ctx.save();
    ctx.fillStyle = 'rgba(28,26,48,0.88)';
    for (const sx of [-eyeX, eyeX]) {
      ctx.beginPath();
      if (blink > 0.4) {
        // 감은 눈 — 짧은 선
        ctx.ellipse(sx, eyeY, eyeR * 1.15, eyeR * 0.22, 0, 0, Math.PI * 2);
      } else {
        ctx.ellipse(sx, eyeY, eyeR, eyeR * 1.2, 0, 0, Math.PI * 2);
      }
      ctx.fill();
    }
    // 웃는 입
    ctx.strokeStyle = 'rgba(28,26,48,0.8)';
    ctx.lineWidth = Math.max(1.1, r * 0.075) * s;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.arc(0, r * 0.1, r * 0.32 * s, 0.28 * Math.PI, 0.72 * Math.PI);
    ctx.stroke();
    ctx.restore();
  }

  // 금속 느낌의 구슬. magnet=true면 자석에 붙은 듯 테두리가 빛난다.
  // squash < 1 이면 납작하게 눌리고, > 1 이면 위로 늘어난다.
  // face > 0 이면 깨어난 얼굴을 그린다.
  _drawBall(cx, cy, r, hex, { magnet = false, squash = 1, face = 0, faceSeed = 0, now = 0 }) {
    const ctx = this.ctx;
    ctx.save();
    ctx.translate(cx, cy);
    if (squash !== 1) ctx.scale(1 / squash, squash);

    if (magnet) {
      ctx.shadowColor = 'rgba(170,225,255,0.95)';
      ctx.shadowBlur = 11;
    }
    // 검정을 섞으면 색이 탁해져 구분이 어려워진다. 같은 색의 명암만 쓴다.
    const g = ctx.createRadialGradient(-r * 0.3, -r * 0.34, r * 0.08, 0, 0, r * 1.08);
    g.addColorStop(0, shade(hex, 0.62));
    g.addColorStop(0.34, hex);
    g.addColorStop(1, shade(hex, -0.3));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;

    // 위쪽 하이라이트
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    ctx.beginPath();
    ctx.ellipse(-r * 0.28, -r * 0.4, r * 0.28, r * 0.18, -0.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = magnet ? 'rgba(200,240,255,0.9)' : 'rgba(0,0,0,0.22)';
    ctx.lineWidth = magnet ? 1.6 : 1;
    ctx.beginPath();
    ctx.arc(0, 0, r - 0.5, 0, Math.PI * 2);
    ctx.stroke();

    if (face > 0) this._drawFace(r, face, faceSeed, now);
    ctx.restore();
  }

  // 튜토리얼: 눌러야 할 튜브 위 맥동 링 + 손가락
  _drawGuide(now) {
    if (this.guide === null) return;
    const r = this.rects[this.guide];
    if (!r) return;
    const ctx = this.ctx;
    const cx = r.x + r.w / 2;
    const cy = r.y + r.h * 0.5;
    const beat = (Math.sin(now / 330) + 1) / 2;

    ctx.save();
    ctx.strokeStyle = `rgba(255,255,255,${0.45 - 0.32 * beat})`;
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.arc(cx, cy, 19 + beat * 15, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    ctx.save();
    ctx.translate(cx + 2, cy - 6 + beat * 9);
    ctx.rotate(0.28);
    ctx.scale(1.25, 1.25);
    ctx.lineJoin = 'round';
    ctx.lineWidth = 3;
    ctx.strokeStyle = 'rgba(20,24,48,0.92)';
    ctx.fillStyle = '#ffffff';
    ctx.shadowColor = 'rgba(0,0,0,0.45)';
    ctx.shadowBlur = 12;
    ctx.shadowOffsetY = 4;
    rr(ctx, -5.5, 0, 11, 33, 5.5); // 검지
    ctx.fill();
    ctx.stroke();
    rr(ctx, -23, 30, 15, 12, 6); // 엄지
    ctx.fill();
    ctx.stroke();
    rr(ctx, -16, 26, 33, 29, 12); // 주먹
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  _drawParticles(now) {
    if (!this.particles.length) return;
    const ctx = this.ctx;
    const dt = Math.min(0.033, (now - (this._lastP || now)) / 1000);
    this._lastP = now;
    const alive = [];
    for (const p of this.particles) {
      p.age += dt;
      if (p.age >= p.ttl) continue;
      p.vy += p.g * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.vr) p.rot += p.vr * dt;
      ctx.save();
      ctx.globalAlpha = clamp01((p.ttl - p.age) / (p.ttl * 0.3));
      ctx.fillStyle = p.color;
      if (p.shape === 'rect') {
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rot);
        ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
      } else {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
      alive.push(p);
    }
    this.particles = alive;
  }
}
