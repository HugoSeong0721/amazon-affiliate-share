// 캔버스 렌더러 — 병, 물감, 붓기/흔들기 애니메이션, 파티클.
// 게임 로직은 전혀 모르고, 상태와 수(move) 결과만 받아 그린다.

import { isUniform, topRun } from '../sort-engine/index.js';

export const COLOR_HEX = {
  R: '#ff5252',
  Y: '#ffd93d',
  B: '#4d9fff',
  O: '#ff9f2e',
  G: '#3ddc84',
  P: '#b45cff',
};

export const COLOR_NAME = { R: '빨강', Y: '노랑', B: '파랑', O: '주황', G: '초록', P: '보라' };

// ---------- 색/이징 유틸 ----------

const rgbCache = new Map();
function hexToRgb(hex) {
  let c = rgbCache.get(hex);
  if (!c) {
    c = [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
    rgbCache.set(hex, c);
  }
  return c;
}
function lerpColor(hexA, hexB, t) {
  const a = hexToRgb(hexA);
  const b = hexToRgb(hexB);
  return `rgb(${Math.round(a[0] + (b[0] - a[0]) * t)},${Math.round(
    a[1] + (b[1] - a[1]) * t
  )},${Math.round(a[2] + (b[2] - a[2]) * t)})`;
}
const clamp01 = (t) => Math.max(0, Math.min(1, t));
const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
const easeInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

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

// ---------- 렌더러 ----------

const TILT = 1.08; // 붓는 각도(라디안, 약 62도)
const LIFT = 13; // 선택 시 떠오르는 높이

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.cssW = 0;
    this.cssH = 0;
    this.state = null;
    this.capacity = 4;
    this.selected = null;
    this.guide = null;
    this.anim = null;
    this.shake = null;
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

  setSelected(i) {
    this.selected = i;
  }

  // 튜토리얼 손가락이 가리킬 병. null이면 안내 없음.
  setGuide(i) {
    this.guide = i;
  }

  // 레벨 전환 시 진행 중인 연출을 모두 정리 (onDone은 호출하지 않는다 —
  // 호출부가 상태를 새로 세팅하는 중이므로)
  clearEffects() {
    this.anim = null;
    this.particles = [];
    this.shake = null;
    this.guide = null;
  }

  _layout() {
    if (!this.state || this.cssW < 10) {
      this.rects = [];
      return;
    }
    const n = this.state.bottles.length;
    const rows = Math.ceil(n / 4);
    const perRow = Math.ceil(n / rows);
    const padX = 16;
    const gap = Math.max(12, Math.min(18, (this.cssW - padX * 2) * 0.045));
    const RATIO = 2.5; // 병 높이/너비
    let bw = Math.min(74, (this.cssW - padX * 2 - gap * (perRow - 1)) / perRow);
    const topPad = 30; // 배지/들어올림 여유
    const bottomPad = 18;
    const rowGap = 46;
    const availH = this.cssH - topPad - bottomPad;
    const bhMax = (availH - (rows - 1) * rowGap) / rows;
    const bh = Math.min(bw * RATIO, bhMax);
    bw = bh / RATIO;
    // 병 무리를 캔버스 세로 중앙에 모아 배치
    const contentH = rows * bh + (rows - 1) * rowGap;
    const startY = topPad + Math.max(0, (availH - contentH) / 2);
    this.rects = [];
    for (let r = 0; r < rows; r++) {
      const start = r * perRow;
      const count = Math.min(perRow, n - start);
      const totalW = count * bw + (count - 1) * gap;
      const x0 = (this.cssW - totalW) / 2;
      const y = startY + r * (bh + rowGap);
      for (let k = 0; k < count; k++) {
        this.rects.push({ x: x0 + k * (bw + gap), y, w: bw, h: bh });
      }
    }
  }

  bottleRect(i) {
    return this.rects[i] || null;
  }

  bottleCenter(i) {
    const r = this.rects[i];
    return r ? { x: r.x + r.w / 2, y: r.y + r.h / 2 } : null;
  }

  hitTest(x, y) {
    for (let i = 0; i < this.rects.length; i++) {
      const r = this.rects[i];
      if (x >= r.x - 8 && x <= r.x + r.w + 8 && y >= r.y - LIFT - 12 && y <= r.y + r.h + 10) return i;
    }
    return null;
  }

  shakeBottle(i) {
    this.shake = { i, t0: performance.now() };
  }

  // 붓기 애니메이션. 색은 변하지 않고 덩어리가 옮겨갈 뿐이다.
  animatePour({ prevState, result, onDone }) {
    const srcRect = this.rects[result.from];
    const dstRect = this.rects[result.to];
    if (!srcRect || !dstRect) {
      onDone && onDone();
      return;
    }
    this.anim = {
      kind: 'pour',
      prev: prevState,
      res: result,
      t0: performance.now(),
      MOVE: 230,
      POUR: 240 + 100 * result.amount,
      RETURN: 210,
      dir: srcRect.x <= dstRect.x ? 1 : -1,
      doneFired: false,
      onDone,
    };
  }

  // 흔들기 애니메이션. 병이 부르르 떨리며 층들이 한 색으로 녹아든다.
  animateShake({ prevState, result, onDone }) {
    if (!this.rects[result.at]) {
      onDone && onDone();
      return;
    }
    this.anim = {
      kind: 'shake',
      prev: prevState,
      res: result,
      t0: performance.now(),
      SHAKE: 520,
      SETTLE: 180,
      doneFired: false,
      onDone,
    };
  }

  burstAtBottle(i, hex, n = 16) {
    const r = this.rects[i];
    if (!r) return;
    this._burst(r.x + r.w / 2, r.y + 10, hex, n);
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
    for (let i = 0; i < 110; i++) {
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

    const A = this.anim;
    const pourAnim = A && A.kind === 'pour' ? this._computePour(now, A) : null;
    const shakeAnim = A && A.kind === 'shake' ? this._computeShake(now, A) : null;

    for (let i = 0; i < this.state.bottles.length; i++) {
      // 붓는 중인 원본 병은 기울여서 나중에 위에 그린다
      if (pourAnim && i === A.res.from) continue;

      let rect = { ...this.rects[i] };
      if (this.shake && this.shake.i === i) {
        const el = now - this.shake.t0;
        if (el < 300) rect.x += Math.sin(el / 16) * 5 * (1 - el / 300);
        else this.shake = null;
      }

      let model;
      if (pourAnim && i === A.res.to) {
        model = pourAnim.dstModel;
      } else if (shakeAnim && i === A.res.at) {
        model = shakeAnim.model;
        rect.x += shakeAnim.jitterX;
        rect.y += shakeAnim.jitterY;
      } else {
        const b = this.state.bottles[i];
        model = { colors: b.map((c) => COLOR_HEX[c]), fraction: 1, flash: 0 };
      }

      const selected = this.selected === i && !A;
      if (selected) rect.y -= LIFT;
      const complete =
        this.state.bottles[i].length === this.capacity && isUniform(this.state.bottles[i]);
      const dim = this.guide !== null && i !== this.guide && !selected;
      if (dim) ctx.save(), (ctx.globalAlpha = 0.4);
      this._drawBottle(rect, model, { selected, complete, shadow: true });
      if (dim) ctx.restore();
    }

    if (pourAnim) {
      if (pourAnim.stream) this._drawStream(pourAnim.stream);
      const r0 = this.rects[A.res.from];
      ctx.save();
      ctx.translate(pourAnim.mouth.x, pourAnim.mouth.y);
      ctx.rotate(pourAnim.rot);
      this._drawBottle({ x: -r0.w / 2, y: 0, w: r0.w, h: r0.h }, pourAnim.srcModel, {
        selected: false,
        complete: false,
        shadow: false,
      });
      ctx.restore();
    }

    if (!A) this._drawGuide(now);
    this._drawParticles(now);
  }

  _finish(A) {
    this.anim = null;
    if (!A.doneFired) {
      A.doneFired = true;
      A.onDone && A.onDone();
    }
  }

  _computePour(now, A) {
    const res = A.res;
    const prevSrc = A.prev.bottles[res.from];
    const prevDst = A.prev.bottles[res.to];
    const postSrc = res.state.bottles[res.from];
    const postDst = res.state.bottles[res.to];
    const pouredHex = COLOR_HEX[topRun(prevSrc).color];
    const srcRect = this.rects[res.from];
    const dstRect = this.rects[res.to];

    const startMouth = { x: srcRect.x + srcRect.w / 2, y: srcRect.y };
    const pourMouth = {
      x: dstRect.x + dstRect.w / 2 - A.dir * dstRect.w * 0.62,
      y: dstRect.y - 24,
    };

    const el = now - A.t0;
    const { MOVE, POUR, RETURN } = A;
    const dstPreColors = prevDst.map((c) => COLOR_HEX[c]);
    const srcColorsFull = prevSrc.map((c) => COLOR_HEX[c]);

    if (el < MOVE) {
      const t = easeInOut(clamp01(el / MOVE));
      return {
        mouth: {
          x: startMouth.x + (pourMouth.x - startMouth.x) * t,
          y: startMouth.y + (pourMouth.y - startMouth.y) * t,
        },
        rot: TILT * A.dir * t,
        srcModel: { colors: srcColorsFull, fraction: 1, flash: 0 },
        dstModel: { colors: dstPreColors, fraction: 1, flash: 0 },
        stream: null,
      };
    }

    if (el < MOVE + POUR) {
      const t = easeInOut(clamp01((el - MOVE) / POUR));
      const moved = res.amount * t;
      const remain = prevSrc.length - moved;
      const dstColors = dstPreColors.slice();
      for (let k = 0; k < Math.ceil(moved); k++) dstColors.push(pouredHex);
      return {
        mouth: pourMouth,
        rot: TILT * A.dir,
        srcModel: {
          colors: srcColorsFull.slice(0, Math.ceil(remain)),
          fraction: remain % 1 > 0 ? remain % 1 : 1,
          flash: 0,
        },
        dstModel: { colors: dstColors, fraction: moved % 1 > 0 ? moved % 1 : 1, flash: 0 },
        stream: this._streamGeom(pourMouth, dstRect, prevDst.length + moved, pouredHex, A.dir),
      };
    }

    if (el < MOVE + POUR + RETURN) {
      const t = easeInOut(clamp01((el - MOVE - POUR) / RETURN));
      return {
        mouth: {
          x: pourMouth.x + (startMouth.x - pourMouth.x) * t,
          y: pourMouth.y + (startMouth.y - pourMouth.y) * t,
        },
        rot: TILT * A.dir * (1 - t),
        srcModel: { colors: postSrc.map((c) => COLOR_HEX[c]), fraction: 1, flash: 0 },
        dstModel: { colors: postDst.map((c) => COLOR_HEX[c]), fraction: 1, flash: 0 },
        stream: null,
      };
    }

    this._finish(A);
    return null;
  }

  _computeShake(now, A) {
    const el = now - A.t0;
    const { SHAKE, SETTLE } = A;
    const beforeHex = A.res.from.map((c) => COLOR_HEX[c]);
    const afterHex = COLOR_HEX[A.res.color];

    if (el < SHAKE) {
      const t = clamp01(el / SHAKE);
      // 흔들림은 강하게 시작해 잦아들고, 색은 그동안 서서히 녹아든다
      const power = (1 - t) * 11;
      const blend = easeInOut(clamp01((t - 0.22) / 0.7));
      return {
        jitterX: Math.sin(el / 21) * power,
        jitterY: Math.cos(el / 15) * power * 0.5,
        model: {
          colors: beforeHex.map((hex) => lerpColor(hex, afterHex, blend)),
          fraction: 1,
          flash: Math.sin(t * Math.PI) * 0.22,
        },
      };
    }

    if (el < SHAKE + SETTLE) {
      return {
        jitterX: 0,
        jitterY: 0,
        model: { colors: beforeHex.map(() => afterHex), fraction: 1, flash: 0 },
      };
    }

    this._finish(A);
    return null;
  }

  _surfaceY(rect, unitCount) {
    const pad = 3.5;
    const unitH = (rect.h - pad * 2) / this.capacity;
    return rect.y + rect.h - pad - unitH * unitCount;
  }

  _streamGeom(mouth, dstRect, dstCount, hex, dir) {
    return {
      x0: mouth.x + dir * 7,
      y0: mouth.y + 3,
      x1: dstRect.x + dstRect.w / 2,
      y1: this._surfaceY(dstRect, dstCount),
      color: hex,
    };
  }

  _drawStream(s) {
    const ctx = this.ctx;
    if (s.y1 <= s.y0) return;
    ctx.save();
    ctx.lineCap = 'round';
    ctx.strokeStyle = s.color;
    ctx.lineWidth = 6;
    ctx.globalAlpha = 0.95;
    ctx.beginPath();
    ctx.moveTo(s.x0, s.y0);
    ctx.quadraticCurveTo(s.x1, s.y0 + (s.y1 - s.y0) * 0.35, s.x1, s.y1);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.restore();
  }

  _drawBottle(rect, model, { selected, complete, shadow }) {
    const ctx = this.ctx;
    const { x, y, w, h } = rect;
    const r = w * 0.27;
    const pad = 3.5;
    const unitH = (h - pad * 2) / this.capacity;

    if (shadow) {
      ctx.save();
      ctx.fillStyle = 'rgba(0,0,0,0.30)';
      ctx.beginPath();
      ctx.ellipse(x + w / 2, y + h + 7 + (selected ? LIFT : 0), w * 0.42, 4.5, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    if (selected || complete) {
      ctx.save();
      ctx.shadowColor = selected ? 'rgba(139,107,255,0.9)' : 'rgba(255,220,120,0.55)';
      ctx.shadowBlur = selected ? 20 : 14;
      rr(ctx, x, y, w, h, r);
      ctx.fillStyle = 'rgba(255,255,255,0.02)';
      ctx.fill();
      ctx.restore();
    }

    rr(ctx, x, y, w, h, r);
    ctx.fillStyle = 'rgba(255,255,255,0.055)';
    ctx.fill();

    ctx.save();
    rr(ctx, x + 1, y + 1, w - 2, h - 2, r - 1);
    ctx.clip();
    const n = model.colors.length;
    let topY = null;
    for (let k = 0; k < n; k++) {
      const uh = (k === n - 1 ? model.fraction : 1) * unitH;
      const yTop = y + h - pad - (k * unitH + uh);
      ctx.fillStyle = model.colors[k];
      ctx.fillRect(x + pad, yTop, w - pad * 2, uh + 0.6);
      if (k === n - 1) topY = yTop;
    }
    if (topY !== null && n > 0) {
      ctx.fillStyle = 'rgba(255,255,255,0.28)';
      ctx.beginPath();
      ctx.ellipse(x + w / 2, topY + 1.2, (w - pad * 2) / 2, 2.8, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    if (model.flash > 0) {
      ctx.fillStyle = `rgba(255,255,255,${model.flash})`;
      ctx.fillRect(x, y, w, h);
    }
    ctx.fillStyle = 'rgba(255,255,255,0.07)';
    rr(ctx, x + w * 0.13, y + 7, w * 0.16, h - 14, w * 0.08);
    ctx.fill();
    ctx.restore();

    rr(ctx, x, y, w, h, r);
    ctx.strokeStyle = selected ? 'rgba(190,170,255,0.75)' : 'rgba(255,255,255,0.28)';
    ctx.lineWidth = selected ? 2.2 : 1.6;
    ctx.stroke();
    ctx.beginPath();
    ctx.ellipse(x + w / 2, y + 0.5, w / 2 - 2, 3.4, 0, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx.lineWidth = 1.4;
    ctx.stroke();

    if (complete) {
      const bx = x + w - 3;
      const by = y - 5;
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

  // 튜토리얼: 눌러야 할 병 위에 맥동하는 링 + 손가락 커서
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

    // 검지 든 손. 검지 → 엄지 → 주먹 순서로 그려 주먹이 밑동을 덮게 한다.
    ctx.save();
    ctx.translate(cx + 2, cy - 6 + beat * 9);
    ctx.rotate(0.28); // 오른쪽 아래에서 올라온 손처럼 살짝 기울인다
    ctx.scale(1.3, 1.3);
    ctx.lineJoin = 'round';
    ctx.lineWidth = 3;
    ctx.strokeStyle = 'rgba(26,22,52,0.92)';
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
      const fade = clamp01((p.ttl - p.age) / (p.ttl * 0.3));
      ctx.save();
      ctx.globalAlpha = fade;
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
