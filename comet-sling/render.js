// 캔버스 렌더러 — 게임의 '분위기'가 사는 곳.
// 깊은 우주 배경, 패럴랙스 별, 네온 글로우, 코멧 트레일, 파티클, 화면 흔들림.
// 월드 좌표(y 위로 증가)를 화면 좌표로 뒤집어 그린다. 카메라는 y만 따라간다.

import { WORLD, aim } from './engine.js';

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
    this._dprCap = 1.5;
    this._frameTimes = [];
    this._lastFrameAt = 0;
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
    // 화소 수가 곧 비용이다. 1.5배까지만 쓰고, 프레임이 밀리면 _autoQuality 가 더 낮춘다.
    const dpr = Math.min(window.devicePixelRatio || 1, this._dprCap ?? 1.5);
    const r = this.canvas.getBoundingClientRect();
    this.dpr = dpr;
    this.canvas.width = Math.round(r.width * dpr);
    this.canvas.height = Math.round(r.height * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.w = r.width;
    this.h = r.height;
    this.scale = this.w / (WORLD.halfW * 2 + 8);
    this._bake();
  }

  // 오프스크린 캔버스 하나를 만들어 CSS 픽셀 기준으로 그릴 수 있게 준비한다
  _surface(w, h) {
    const c = document.createElement('canvas');
    c.width = Math.ceil(w * this.dpr);
    c.height = Math.ceil(h * this.dpr);
    const cx = c.getContext('2d');
    cx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    return { canvas: c, ctx: cx, w, h };
  }

  // 매 프레임 shadowBlur를 다시 계산하면 폰에서 프레임이 반토막 난다.
  // 글로우가 붙는 것들(앵커·소행성·코멧)과 별밭·그라디언트를 리사이즈 때 한 번만 굽는다.
  _bake() {
    // 벽 그라디언트 (좌/우 공용 — x는 그릴 때 옮긴다)
    const wg = this.ctx.createLinearGradient(-6, 0, 6, 0);
    wg.addColorStop(0, 'rgba(120,90,255,0)');
    wg.addColorStop(0.5, COL.wall);
    wg.addColorStop(1, 'rgba(120,90,255,0)');
    this._wallGrad = wg;

    // 앵커 — 평소/활성 두 벌
    const ringR = 4.6 * this.scale * 0.55;
    const coreR = 1.4 * this.scale * 0.55;
    this._sprAnchor = [false, true].map((active) => {
      const blur = active ? 22 : 12;
      const pad = blur + 6;
      const s = this._surface((ringR + pad) * 2, (ringR + pad) * 2);
      const c = s.ctx, m = s.w / 2;
      const col = active ? COL.anchorActive : COL.anchor;
      c.shadowColor = col;
      c.shadowBlur = blur;
      c.strokeStyle = col;
      c.lineWidth = active ? 3 : 2;
      c.beginPath();
      c.arc(m, m, ringR, 0, Math.PI * 2);
      c.stroke();
      c.fillStyle = col;
      c.beginPath();
      c.arc(m, m, coreR, 0, Math.PI * 2);
      c.fill();
      return s;
    });

    // 소행성 — 모양이 조금씩 다른 세 벌 (회전은 그릴 때 준다)
    const hr = WORLD.hazardR * this.scale;
    this._sprHazard = [0, 1, 2].map((variant) => {
      const pad = 14 + 6;
      const s = this._surface((hr + pad) * 2, (hr + pad) * 2);
      const c = s.ctx, m = s.w / 2;
      c.shadowColor = COL.hazard;
      c.shadowBlur = 14;
      c.fillStyle = COL.hazardCore;
      c.strokeStyle = COL.hazard;
      c.lineWidth = 2;
      c.beginPath();
      for (let k = 0; k < 8; k++) {
        const a = (k / 8) * Math.PI * 2;
        const rr = hr * (0.82 + 0.18 * Math.sin(variant * 3.1 + k * 2.7));
        const px = m + Math.cos(a) * rr, py = m + Math.sin(a) * rr;
        k === 0 ? c.moveTo(px, py) : c.lineTo(px, py);
      }
      c.closePath();
      c.fill();
      c.stroke();
      c.shadowBlur = 0;
      c.fillStyle = 'rgba(255,90,60,0.5)';
      c.beginPath();
      c.arc(m - hr * 0.25, m - hr * 0.2, hr * 0.18, 0, Math.PI * 2);
      c.fill();
      return s;
    });

    // 코멧
    const cr = WORLD.cometR * this.scale;
    {
      const pad = 26 + 6;
      const s = this._surface((cr + pad) * 2, (cr + pad) * 2);
      const c = s.ctx, m = s.w / 2;
      c.shadowColor = COL.comet;
      c.shadowBlur = 26;
      c.fillStyle = COL.comet;
      c.beginPath();
      c.arc(m, m, cr, 0, Math.PI * 2);
      c.fill();
      c.shadowBlur = 10;
      c.fillStyle = COL.cometCore;
      c.beginPath();
      c.arc(m, m, cr * 0.55, 0, Math.PI * 2);
      c.fill();
      this._sprComet = s;
    }

  }

  // 기기 성능을 실제로 재서, 60fps를 못 내면 해상도를 한 단계씩 낮춘다.
  // 어떤 폰인지 미리 알 수 없으니 추측하지 않고 측정한다. 내리기만 하고 다시 올리지
  // 않는다 — 왔다 갔다 하면 그게 더 거슬린다.
  _autoQuality() {
    const now = performance.now();
    const prev = this._lastFrameAt;
    this._lastFrameAt = now;
    if (!prev) return;
    const dtMs = now - prev;
    if (dtMs > 500) return; // 탭 전환 등으로 멈춘 구간은 버린다
    const f = this._frameTimes;
    f.push(dtMs);
    if (f.length < 90) return;
    f.sort((a, b) => a - b);
    const median = f[Math.floor(f.length / 2)];
    f.length = 0;
    if (median > 20 && this._dprCap > 1) {
      this._dprCap = Math.max(1, this._dprCap - 0.25);
      this.resize();
    }
  }

  // 스프라이트를 중심 좌표에 그린다 (CSS 픽셀 기준)
  _blit(ctx, s, x, y, rot = 0) {
    if (rot) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(rot);
      ctx.drawImage(s.canvas, -s.w / 2, -s.h / 2, s.w, s.h);
      ctx.restore();
      return;
    }
    ctx.drawImage(s.canvas, x - s.w / 2, y - s.h / 2, s.w, s.h);
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

  clearTrail() { this.trail = []; }

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
    this._autoQuality();

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

    // 배경은 CSS(#app)가 한 번만 칠한다 — 매 프레임 전체 화면을 다시 칠하는 게
    // 렌더링에서 가장 비쌌다. 캔버스는 투명하게 지우기만 한다.
    ctx.clearRect(0, 0, this.w, this.h);

    ctx.save();
    ctx.translate(ox, oy);

    this._drawStars(ctx);
    this._drawWalls(ctx, state);
    if (ui.challenge) this._drawFinishLine(ctx, ui.challenge);
    this._drawAnchors(ctx, state, ui);
    this._drawHazards(ctx, state);
    this._drawTrail(ctx);
    if (!state.dead && state.orbit) this._drawAimLine(ctx, state);
    if (!state.dead && ui.mode !== 'ready') this._drawComet(ctx, state);
    this._drawParticles(ctx, dt);
    if (ui.mode === 'ready') this._drawReadyComet(ctx, state);
    if (ui.mode === 'ready' && ui.demo) this._drawGhostDemo(ctx, state);
    else if (ui.coach) this._drawCoachFinger(ctx, ui.coach === 'hold', ui.coach === 'hold' ? 'hold' : 'let go!');

    ctx.restore();
  }

  _drawStars(ctx) {
    // 상태 변경(fillStyle/globalAlpha)이 별 개수만큼 일어나면 폰에서 비싸다.
    // 반짝임을 층 단위로 묶어 변경 횟수를 137번 → 3번으로 줄인다.
    ctx.fillStyle = '#cfd9ff';
    for (const layer of this._stars) {
      const scroll = (this.camY * this.scale * layer.depth) % this.h;
      const tw = 0.5 + 0.5 * Math.abs(Math.sin(this._t * 1.3 + layer.depth * 7));
      ctx.globalAlpha = 0.25 + 0.5 * layer.depth * tw;
      for (const p of layer.pts) {
        let y = (p.y * this.h + scroll) % this.h;
        if (y < 0) y += this.h;
        ctx.fillRect(p.x * this.w, this.h - y, layer.size, layer.size);
      }
    }
    ctx.globalAlpha = 1;
  }

  _drawWalls(ctx, state) {
    const xl = this.sx(-WORLD.halfW), xr = this.sx(WORLD.halfW);
    for (const x of [xl, xr]) {
      ctx.save();
      ctx.translate(x, 0);
      ctx.fillStyle = this._wallGrad;
      ctx.fillRect(-6, 0, 12, this.h);
      ctx.restore();
      ctx.strokeStyle = 'rgba(170,140,255,0.8)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, this.h);
      ctx.stroke();
    }
    // 벽 눈금 — 스크롤이 몸으로 느껴지게. 한 path에 모아 stroke는 한 번만.
    ctx.strokeStyle = 'rgba(170,140,255,0.35)';
    ctx.lineWidth = 1;
    const stepW = 40 * this.scale;
    const base = (this.camY * this.scale) % stepW;
    ctx.beginPath();
    for (let y = -stepW; y < this.h + stepW; y += stepW) {
      const yy = y + base;
      ctx.moveTo(xl, yy);
      ctx.lineTo(xl + 7, yy);
      ctx.moveTo(xr, yy);
      ctx.lineTo(xr - 7, yy);
    }
    ctx.stroke();
  }

  // 도전장 결승선 — 친구 기록의 높이에 금색 선. 넘으면 초록으로 남는다.
  _drawFinishLine(ctx, c) {
    if (!this._visible(c.height, 40)) return;
    const y = this.sy(c.height);
    const col = c.beaten ? 'rgba(120, 240, 160, 0.75)' : 'rgba(255, 211, 77, 0.75)';
    ctx.save();
    ctx.setLineDash([12, 8]);
    ctx.lineDashOffset = -this._t * 25;
    ctx.strokeStyle = col;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(this.sx(-WORLD.halfW), y);
    ctx.lineTo(this.sx(WORLD.halfW), y);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.font = '800 13px system-ui';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'bottom';
    ctx.fillStyle = col;
    ctx.shadowColor = 'rgba(0,0,0,0.8)';
    ctx.shadowBlur = 5;
    ctx.fillText(c.beaten ? `🏆 ${c.score}` : `🏁 ${c.score}`, this.sx(WORLD.halfW) - 8, y - 5);
    ctx.shadowBlur = 0;
    ctx.restore();
  }

  _visible(wy, pad = 80) {
    const y = this.sy(wy);
    return y > -pad && y < this.h + pad;
  }

  _drawAnchors(ctx, state, ui) {
    const pulse = 0.5 + 0.5 * Math.sin(this._t * 3.2);
    // 점선 큰 원은 래스터화가 비싸다 — 사거리 안의 '가장 가까운' 앵커 하나만 그린다
    let nearest = -1, nearestD = WORLD.captureR;
    if (!state.dead) {
      for (let i = 0; i < state.anchors.length; i++) {
        const a = state.anchors[i];
        if (a.y < state.y - WORLD.captureR) continue;
        const d = Math.hypot(a.x - state.x, a.y - state.y);
        if (d < nearestD) { nearestD = d; nearest = i; }
      }
    }
    for (let i = 0; i < state.anchors.length; i++) {
      const a = state.anchors[i];
      if (!this._visible(a.y)) continue;
      const x = this.sx(a.x), y = this.sy(a.y);
      const active = state.orbit && state.orbit.i === i;
      const inRange = i === nearest;

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

      // 앵커 본체 — 미리 구운 네온 링
      this._blit(ctx, this._sprAnchor[active ? 1 : 0], x, y);
    }
  }

  _drawHazards(ctx, state) {
    for (let i = 0; i < state.hazards.length; i++) {
      const hz = state.hazards[i];
      if (!this._visible(hz.y)) continue;
      this._blit(ctx, this._sprHazard[i % 3], this.sx(hz.x), this.sy(hz.y), this._t * 0.4 + i * 1.7);
    }
  }

  _drawTrail(ctx) {
    const n = this.trail.length;
    if (n < 2) return;
    // 점마다 stroke 하면 폰에서 45번의 래스터화가 된다. 굵기/투명도가 비슷한
    // 네 구간으로 묶어 폴리라인 4번으로 그린다 — 보기엔 그대로다.
    const CHUNKS = 4;
    ctx.strokeStyle = COL.trail;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (let c = 0; c < CHUNKS; c++) {
      const from = Math.floor((c * (n - 1)) / CHUNKS);
      const to = Math.floor(((c + 1) * (n - 1)) / CHUNKS);
      if (to <= from) continue;
      const t = (c + 1) / CHUNKS;
      ctx.globalAlpha = t * 0.7;
      ctx.lineWidth = t * 5;
      ctx.beginPath();
      ctx.moveTo(this.sx(this.trail[from].x), this.sy(this.trail[from].y));
      for (let i = from + 1; i <= to; i++) {
        ctx.lineTo(this.sx(this.trail[i].x), this.sy(this.trail[i].y));
      }
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  // 조준선 — 지금 놓으면 날아갈 방향. 근처 앵커에 스냅되면 금색으로 잠긴다.
  // "옆으로 튕겨나갔다"가 아니라 "옆을 향할 때 놓았다"를 눈으로 알게 해 준다.
  _drawAimLine(ctx, state) {
    const a = aim(state);
    const x0 = this.sx(state.x), y0 = this.sy(state.y);
    let lenW = 85;
    if (a.snapped !== null) {
      const t = state.anchors[a.snapped];
      lenW = Math.hypot(t.x - state.x, t.y - state.y);
    }
    const x1 = this.sx(state.x + a.dx * lenW), y1 = this.sy(state.y + a.dy * lenW);
    const locked = a.snapped !== null;
    const col = locked ? 'rgba(255,211,77,0.9)' : 'rgba(142,246,255,0.45)';

    ctx.save();
    ctx.setLineDash(locked ? [7, 5] : [4, 7]);
    ctx.lineDashOffset = -this._t * 40; // 점선이 진행 방향으로 흐른다
    ctx.strokeStyle = col;
    ctx.lineWidth = locked ? 2.5 : 1.5;
    ctx.beginPath();
    ctx.moveTo(x0, y0);
    ctx.lineTo(x1, y1);
    ctx.stroke();
    ctx.setLineDash([]);

    // 화살촉
    const ang = Math.atan2(y1 - y0, x1 - x0);
    ctx.fillStyle = col;
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x1 - 9 * Math.cos(ang - 0.42), y1 - 9 * Math.sin(ang - 0.42));
    ctx.lineTo(x1 - 9 * Math.cos(ang + 0.42), y1 - 9 * Math.sin(ang + 0.42));
    ctx.closePath();
    ctx.fill();

    // 스냅된 앵커에 잠금 링
    if (locked) {
      const t = state.anchors[a.snapped];
      const pulse = 0.85 + 0.15 * Math.sin(this._t * 8);
      ctx.strokeStyle = 'rgba(255,211,77,0.85)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(this.sx(t.x), this.sy(t.y), 10 * pulse, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  _drawComet(ctx, state) {
    this._blit(ctx, this._sprComet, this.sx(state.x), this.sy(state.y));
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

  // 출발대: 코멧이 숨쉬듯 떠 있다
  _drawReadyComet(ctx, state) {
    const bob = Math.sin(this._t * 2.2) * 4;
    this._blit(ctx, this._sprComet, this.sx(state.x), this.sy(state.y) + bob);
  }

  // 유령 시범 — 첫 릴리즈에 성공하기 전까지, 출발대에서 유령 혜성이 직접 보여준다:
  // 다가가고 → (손가락이 누르면) 붙어서 한 바퀴 돌고 → (손가락이 떼면) 위로 날아간다.
  // 글 대신 손이 가르친다.
  _drawGhostDemo(ctx, state) {
    const a = state.anchors[0];
    const r = 20;
    const T = 4.4, t = this._t % T;
    let gx, gy, pressed = false, label = null, alpha = 0.7;

    if (t < 1.1) {
      // 아래에서 궤도 가장자리로 다가간다
      const k = t / 1.1;
      gx = a.x + r;
      gy = a.y - 60 + 60 * k;
    } else if (t < 3.0) {
      // 손가락이 누르고 — 한 바퀴
      pressed = true;
      label = 'hold';
      const th = ((t - 1.1) / 1.9) * Math.PI * 2;
      gx = a.x + Math.cos(th) * r;
      gy = a.y + Math.sin(th) * r;
    } else if (t < 3.9) {
      // 손가락을 떼고 — 접선(위)으로 날아가며 사라진다
      const k = (t - 3.0) / 0.9;
      gx = a.x + r;
      gy = a.y + k * 90;
      alpha = 0.7 * (1 - k);
      if (k < 0.45) label = 'let go!';
    } else {
      this._drawCoachFinger(ctx, false, null);
      return;
    }

    // 시범 중에는 캡처 링을 항상 보여준다
    ctx.setLineDash([4, 6]);
    ctx.strokeStyle = 'rgba(176,107,255,0.35)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(this.sx(a.x), this.sy(a.y), WORLD.captureR * this.scale * 0.95, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    if (pressed) {
      ctx.strokeStyle = 'rgba(227,194,255,0.45)';
      ctx.beginPath();
      ctx.arc(this.sx(a.x), this.sy(a.y), r * this.scale, 0, Math.PI * 2);
      ctx.stroke();
    }

    // 유령 혜성
    ctx.globalAlpha = alpha;
    this._blit(ctx, this._sprComet, this.sx(gx), this.sy(gy));
    ctx.globalAlpha = 1;

    this._drawCoachFinger(ctx, pressed, label);
  }

  // 화면 아래 중앙의 코치 손가락 — 엄지가 실제로 닿을 자리에서 누름/뗌을 보여준다
  _drawCoachFinger(ctx, pressed, label) {
    const hx = this.w / 2, hy = this.h * 0.88;
    const pulse = 0.5 + 0.5 * Math.sin(this._t * 5);

    ctx.beginPath();
    ctx.arc(hx, hy, pressed ? 24 : 27, 0, Math.PI * 2);
    if (pressed) {
      ctx.fillStyle = `rgba(142,246,255,${0.16 + 0.12 * pulse})`;
      ctx.fill();
      ctx.strokeStyle = COL.hint;
      ctx.lineWidth = 3;
      ctx.stroke();
    } else {
      ctx.strokeStyle = `rgba(255,255,255,${0.3 + 0.25 * pulse})`;
      ctx.lineWidth = 2;
      ctx.setLineDash([3, 5]);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    ctx.font = '26px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('👆', hx, hy + (pressed ? 3 : 0));

    if (label) {
      ctx.font = '800 15px system-ui';
      ctx.fillStyle = label === 'hold' ? COL.hint : COL.spark;
      ctx.shadowColor = 'rgba(0,0,0,0.8)';
      ctx.shadowBlur = 6;
      ctx.fillText(label, hx, hy + 46);
      ctx.shadowBlur = 0;
    }
  }
}
