// 캔버스 렌더러 — 튜브, 구슬, 자석 집기/날아가기 애니메이션.
// 게임 로직은 전혀 모르고, 상태와 수(move) 결과만 받아 그린다.
//
// 이 게임의 규칙은 설명 대신 애니메이션으로 전달된다:
// 튜브를 누르면 맨 위 같은 색 구슬들이 자석처럼 딱 붙어 함께 떠오른다.
// 몇 개가 움직일지 손대기 전에 눈으로 보이므로 규칙을 글로 읽을 필요가 없다.

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
  animateMove({ result, heldCount, onDone }) {
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
      TRAVEL: 330,
      STAGGER: 42,
      onDone,
      doneFired: false,
      landed: new Set(),
    };
    this.held = null;
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

  // ---------- 매 프레임 ----------

  _loop(now) {
    requestAnimationFrame(this._loop);
    const ctx = this.ctx;
    if (!this.state || !this.rects.length) {
      ctx && ctx.clearRect(0, 0, this.cssW, this.cssH);
      return;
    }
    ctx.clearRect(0, 0, this.cssW, this.cssH);

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
      this._drawTube(rect, visible, {
        selected: this.held?.tube === i,
        complete,
      });
      if (dim) ctx.restore();
    }

    if (this.held) this._drawHeld(now);
    if (F) this._drawFlight(now, F);
    if (!this.held && !F) this._drawGuide(now);
    this._drawParticles(now);
  }

  // 떠오르는 중~떠 있는 묶음
  _drawHeld(now) {
    const H = this.held;
    const rect = this.rects[H.tube];
    if (!rect) return;
    const balls = this.state.bottles[H.tube];
    const base = balls.length - H.count; // 묶음 아래에 남는 구슬 수
    const t = easeOutBack(clamp01((now - H.t0) / 190));
    const hex = COLOR_HEX[H.color];
    // 살짝 위아래로 떠 있는 느낌
    const bob = Math.sin(now / 420) * 2;

    for (let j = 0; j < H.count; j++) {
      const from = this._slotPos(rect, base + j);
      const to = this._heldPos(rect, j);
      const p = {
        x: from.x + (to.x - from.x) * t,
        y: from.y + (to.y - from.y) * t + bob * t,
      };
      const { ballR } = this._metrics(rect);
      this._drawBall(p.x, p.y, ballR, hex, { magnet: t > 0.6 });
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
      if (t < 1) allDone = false;
      const p0 = this._heldPos(srcRect, F.returning + order);
      const p1 = this._slotPos(dstRect, dstLen - F.amount + j);
      const cp = { x: (p0.x + p1.x) / 2, y: Math.min(p0.y, p1.y) - 46 };
      const e = easeInOut(t);
      const p = qbez(p0, cp, p1, e);
      if (t >= 1 && !F.landed.has(j)) F.landed.add(j);
      // 착지 직전 살짝 눌리는 스쿼시
      const squash = t > 0.86 ? 1 - Math.sin((t - 0.86) / 0.14 * Math.PI) * 0.16 : 1;
      this._drawBall(p.x, p.y, ballR, hex, { squash });
    }

    // 공간이 없어 되돌아가는 구슬
    for (let j = 0; j < F.returning; j++) {
      const t = clamp01(el / (F.TRAVEL * 0.7));
      if (t < 1) allDone = false;
      const p0 = this._heldPos(srcRect, j);
      const p1 = this._slotPos(srcRect, srcLen - F.returning + j);
      const e = easeOutCubic(t);
      this._drawBall(p0.x, p0.y + (p1.y - p0.y) * e, this._metrics(srcRect).ballR, hex, {});
    }

    if (allDone) {
      this.flight = null;
      if (!F.doneFired) {
        F.doneFired = true;
        F.onDone && F.onDone();
      }
    }
  }

  _drawTube(rect, balls, { selected, complete }) {
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

    // 구슬
    for (let k = 0; k < balls.length; k++) {
      const p = this._slotPos(rect, k);
      this._drawBall(p.x, p.y, ballR, COLOR_HEX[balls[k]], {});
    }

    // 유리 광택 + 외곽선
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

  // 금속 느낌의 구슬. magnet=true면 자석에 붙은 듯 테두리가 빛난다.
  _drawBall(cx, cy, r, hex, { magnet = false, squash = 1 }) {
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
