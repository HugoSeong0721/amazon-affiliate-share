// 캔버스 렌더러 — 게임의 '분위기'가 사는 곳.
// 깊은 우주 배경, 패럴랙스 별, 네온 글로우, 코멧 트레일, 파티클, 화면 흔들림.
// 월드 좌표(y 위로 증가)를 화면 좌표로 뒤집어 그린다. 카메라는 y만 따라간다.

import { WORLD } from './engine.js';

const COL = {
  bgTop: '#0a0618',
  bgBottom: '#03030a',
  comet: '#8ef6ff',
  cometCore: '#ffffff',
  trail: 'rgba(110, 235, 255, 0.55)',
  anchor: '#b06bff',
  anchorActive: '#e3c2ff',
  hazard: '#ff5a3c',
  hazardCore: '#7d1f10',
  wall: 'rgba(120, 90, 255, 0.5)',
  spark: '#ffd34d',
  hint: 'rgba(255,255,255,0.85)',
};

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.camY = 0;
    this.trail = [];
    this.particles = [];
    this._shake = 0;
    this._stars = this._makeStars();
    this._t = 0;
    this.resize();
  }

  _makeStars() {
    // 고정 시드 별밭 — 층마다 패럴랙스 계수가 다르다
    const layers = [];
    let s = 1234567;
    const rnd = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
    for (const [count, depth, size] of [[70, 0.15, 1], [45, 0.35, 1.6], [22, 0.6, 2.4]]) {
      const pts = [];
      for (let i = 0; i < count; i++) pts.push({ x: rnd(), y: rnd(), tw: rnd() * Math.PI * 2 });
      layers.push({ pts, depth, size });
    }
    return layers;
  }

  resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = this.canvas.getBoundingClientRect();
    this.canvas.width = Math.round(r.width * dpr);
    this.canvas.height = Math.round(r.height * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.w = r.width;
    this.h = r.height;
    this.scale = this.w / (WORLD.halfW * 2 + 8);
  }

  reset(state) {
    this.camY = state.y;
    this.trail = [];
    this.particles = [];
    this._shake = 0;
  }

  // 월드 → 화면
  sx(x) { return this.w / 2 + x * this.scale; }
  sy(y) { return this.h * 0.68 - (y - this.camY) * this.scale; }

  shake(power) { this._shake = Math.max(this._shake, power); }

  burst(wx, wy) {
    for (let i = 0; i < 14; i++) {
      const a = Math.random() * Math.PI * 2, v = 30 + Math.random() * 90;
      this.particles.push({ x: wx, y: wy, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.6, max: 0.6, col: COL.spark, r: 1.6 });
    }
  }

  explode(wx, wy) {
    for (let i = 0; i < 42; i++) {
      const a = Math.random() * Math.PI * 2, v = 40 + Math.random() * 200;
      const col = Math.random() < 0.6 ? COL.comet : '#ffffff';
      this.particles.push({ x: wx, y: wy, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.9 + Math.random() * 0.5, max: 1.2, col, r: 1.2 + Math.random() * 2.2 });
    }
  }

  draw(state, ui) {
    const ctx = this.ctx;
    const dt = 1 / 60;
    this._t += dt;

    // 카메라 — 위로는 바로, 아래로는 천천히 따라간다
    const target = Math.max(state.y, state.height - 20);
    this.camY += (target - this.camY) * (state.dead ? 0.04 : 0.14);

    // 트레일 기록 (죽으면 멈춘다)
    if (!state.dead && ui.mode === 'running') {
      this.trail.push({ x: state.x, y: state.y });
      if (this.trail.length > 46) this.trail.shift();
    }

    // 흔들림
    let ox = 0, oy = 0;
    if (this._shake > 0.2) {
      ox = (Math.random() * 2 - 1) * this._shake;
      oy = (Math.random() * 2 - 1) * this._shake;
      this._shake *= 0.86;
    }

    // 배경
    const g = ctx.createLinearGradient(0, 0, 0, this.h);
    g.addColorStop(0, COL.bgTop);
    g.addColorStop(1, COL.bgBottom);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, this.w, this.h);

    ctx.save();
    ctx.translate(ox, oy);

    this._drawStars(ctx);
    this._drawWalls(ctx, state);
    this._drawAnchors(ctx, state, ui);
    this._drawHazards(ctx, state);
    this._drawTrail(ctx);
    if (!state.dead && ui.mode !== 'ready') this._drawComet(ctx, state);
    this._drawParticles(ctx, dt);
    if (ui.mode === 'ready') this._drawReadyHint(ctx, state, ui);

    ctx.restore();
  }

  _drawStars(ctx) {
    for (const layer of this._stars) {
      const scroll = (this.camY * this.scale * layer.depth) % this.h;
      for (const p of layer.pts) {
        let y = (p.y * this.h + scroll) % this.h;
        if (y < 0) y += this.h;
        const tw = 0.45 + 0.55 * Math.abs(Math.sin(this._t * 1.3 + p.tw));
        ctx.globalAlpha = 0.25 + 0.5 * layer.depth * tw;
        ctx.fillStyle = '#cfd9ff';
        ctx.fillRect(p.x * this.w, this.h - y, layer.size, layer.size);
      }
    }
    ctx.globalAlpha = 1;
  }

  _drawWalls(ctx, state) {
    const xl = this.sx(-WORLD.halfW), xr = this.sx(WORLD.halfW);
    for (const x of [xl, xr]) {
      const grad = ctx.createLinearGradient(x - 6, 0, x + 6, 0);
      grad.addColorStop(0, 'rgba(120,90,255,0)');
      grad.addColorStop(0.5, COL.wall);
      grad.addColorStop(1, 'rgba(120,90,255,0)');
      ctx.fillStyle = grad;
      ctx.fillRect(x - 6, 0, 12, this.h);
      ctx.strokeStyle = 'rgba(170,140,255,0.8)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, this.h);
      ctx.stroke();
    }
    // 벽 눈금 — 스크롤이 몸으로 느껴지게
    ctx.strokeStyle = 'rgba(170,140,255,0.35)';
    ctx.lineWidth = 1;
    const stepW = 40 * this.scale;
    const base = (this.camY * this.scale) % stepW;
    for (let y = -stepW; y < this.h + stepW; y += stepW) {
      const yy = y + base;
      for (const [x, d] of [[xl, 1], [xr, -1]]) {
        ctx.beginPath();
        ctx.moveTo(x, yy);
        ctx.lineTo(x + d * 7, yy);
        ctx.stroke();
      }
    }
  }

  _visible(wy, pad = 80) {
    const y = this.sy(wy);
    return y > -pad && y < this.h + pad;
  }

  _drawAnchors(ctx, state, ui) {
    const pulse = 0.5 + 0.5 * Math.sin(this._t * 3.2);
    for (let i = 0; i < state.anchors.length; i++) {
      const a = state.anchors[i];
      if (!this._visible(a.y)) continue;
      const x = this.sx(a.x), y = this.sy(a.y);
      const active = state.orbit && state.orbit.i === i;
      const inRange = !state.dead && Math.hypot(a.x - state.x, a.y - state.y) < WORLD.captureR;

      // 잡을 수 있는 앵커: 점선 캡처 링이 숨쉰다
      if (inRange && !active) {
        ctx.setLineDash([4, 6]);
        ctx.strokeStyle = `rgba(176,107,255,${0.25 + 0.3 * pulse})`;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(x, y, WORLD.captureR * this.scale * (0.92 + 0.06 * pulse), 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // 궤도 중: 실제 궤도 원 + 앵커→코멧 빔
      if (active) {
        ctx.strokeStyle = 'rgba(227,194,255,0.5)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(x, y, state.orbit.r * this.scale, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = 'rgba(227,194,255,0.35)';
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(this.sx(state.x), this.sy(state.y));
        ctx.stroke();
      }

      // 앵커 본체 — 이중 네온 링
      const col = active ? COL.anchorActive : COL.anchor;
      ctx.shadowColor = col;
      ctx.shadowBlur = active ? 22 : 12;
      ctx.strokeStyle = col;
      ctx.lineWidth = active ? 3 : 2;
      ctx.beginPath();
      ctx.arc(x, y, 4.6 * this.scale * 0.55, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.arc(x, y, 1.4 * this.scale * 0.55, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
    }
  }

  _drawHazards(ctx, state) {
    for (let i = 0; i < state.hazards.length; i++) {
      const hz = state.hazards[i];
      if (!this._visible(hz.y)) continue;
      const x = this.sx(hz.x), y = this.sy(hz.y);
      const r = WORLD.hazardR * this.scale;
      const rot = this._t * 0.4 + i * 1.7;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(rot);
      ctx.shadowColor = COL.hazard;
      ctx.shadowBlur = 14;
      ctx.fillStyle = COL.hazardCore;
      ctx.strokeStyle = COL.hazard;
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (let k = 0; k < 8; k++) {
        const a = (k / 8) * Math.PI * 2;
        const rr = r * (0.82 + 0.18 * Math.sin(i * 3.1 + k * 2.7));
        const px = Math.cos(a) * rr, py = Math.sin(a) * rr;
        k === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.fillStyle = 'rgba(255,90,60,0.5)';
      ctx.beginPath();
      ctx.arc(-r * 0.25, -r * 0.2, r * 0.18, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }

  _drawTrail(ctx) {
    if (this.trail.length < 2) return;
    for (let i = 1; i < this.trail.length; i++) {
      const p = this.trail[i - 1], q = this.trail[i];
      const t = i / this.trail.length;
      ctx.strokeStyle = COL.trail;
      ctx.globalAlpha = t * 0.7;
      ctx.lineWidth = t * 5;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(this.sx(p.x), this.sy(p.y));
      ctx.lineTo(this.sx(q.x), this.sy(q.y));
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  _drawComet(ctx, state) {
    const x = this.sx(state.x), y = this.sy(state.y);
    const r = WORLD.cometR * this.scale;
    ctx.shadowColor = COL.comet;
    ctx.shadowBlur = 26;
    ctx.fillStyle = COL.comet;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 10;
    ctx.fillStyle = COL.cometCore;
    ctx.beginPath();
    ctx.arc(x, y, r * 0.55, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
  }

  _drawParticles(ctx, dt) {
    this.particles = this.particles.filter((p) => (p.life -= dt) > 0);
    for (const p of this.particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.97;
      p.vy *= 0.97;
      ctx.globalAlpha = Math.max(0, p.life / p.max);
      ctx.fillStyle = p.col;
      ctx.beginPath();
      ctx.arc(this.sx(p.x), this.sy(p.y), p.r * this.scale * 0.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // 출발대: 코멧이 숨쉬듯 떠 있고, 아직 안 배웠으면 손가락 홀드 힌트를 띄운다.
  // 글로 설명하지 않는다 — 손가락과 링이 전부다.
  _drawReadyHint(ctx, state, ui) {
    const bob = Math.sin(this._t * 2.2) * 4;
    const x = this.sx(state.x), y = this.sy(state.y) + bob;
    const r = WORLD.cometR * this.scale;
    ctx.shadowColor = COL.comet;
    ctx.shadowBlur = 26;
    ctx.fillStyle = COL.comet;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.fillStyle = COL.cometCore;
    ctx.beginPath();
    ctx.arc(x, y, r * 0.55, 0, Math.PI * 2);
    ctx.fill();

    if (!ui.showHint) return;
    // 손가락 + 차오르는 링 = "누르고 있어라"
    const hx = x, hy = y + 74;
    const phase = (this._t % 1.6) / 1.6;
    ctx.strokeStyle = COL.hint;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(hx, hy, 20, -Math.PI / 2, -Math.PI / 2 + Math.min(1, phase * 1.4) * Math.PI * 2);
    ctx.stroke();
    ctx.font = '26px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.globalAlpha = phase < 0.85 ? 1 : 1 - (phase - 0.85) / 0.15;
    ctx.fillText('👆', hx, hy + 1);
    ctx.globalAlpha = 1;
  }
}
