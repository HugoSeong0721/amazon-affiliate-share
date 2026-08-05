// 캔버스 렌더러 — 주차장, 차, 드래그 물리(스프링·러버밴드·쿵), 탈출 연출.
// 게임 로직은 rangeOf 같은 순수 함수만 빌려 쓰고, 규칙 판단은 콜백으로 넘긴다.
//
// 이 게임의 규칙은 설명 대신 손끝으로 전달된다:
// 차를 잡으면 살짝 떠오르고, 축을 따라서만 끌려오고, 막힌 곳에서 쿵 하고 멈춘다.
// "차는 자기 방향으로만 움직인다"를 글로 읽을 필요가 없다 — 손이 먼저 배운다.
//
// 손맛의 재료: 칸을 지날 때마다 딸깍(디텐트), 놓으면 자리로 딱 붙는 스프링,
// 벽에 부딪히면 화면이 미세하게 흔들리고 먼지가 튄다.

import { W, H, EXIT_ROW, PLAYER, coordOf, occupancy, rangeOf } from './engine.js';

export const TAXI_HEX = '#ffce3a';
export const CAR_HEX = [
  '#4a90ff', '#ff4d5a', '#35d07f', '#a96bff', '#ff6bd0',
  '#2fd3d3', '#ff9838', '#7c8cff', '#9bd356', '#5ad0a5',
  '#e06c9a', '#c9d1e8',
];

const rgbCache = new Map();
function hexToRgb(hex) {
  let c = rgbCache.get(hex);
  if (!c) {
    c = [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
    rgbCache.set(hex, c);
  }
  return c;
}

// amt > 0 이면 흰쪽, < 0 이면 검은쪽으로
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

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
const easeOutBack = (t) => 1 + 2.0 * Math.pow(t - 1, 3) + 1.3 * Math.pow(t - 1, 2);
const easeInQuad = (t) => t * t;

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

// 러버밴드: 구간을 넘어간 만큼 저항이 붙는다 (최대 0.42칸)
const overshoot = (d) => Math.sign(d) * Math.min(Math.abs(d) * 0.28, 0.42);

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.cssW = 0;
    this.cssH = 0;

    this.vehicles = null; // 논리 상태 (게임이 준다)
    this.disp = []; // 차량별 표시 좌표 (float, 변수축)
    this.vel = []; // 스프링 속도
    this.settled = []; // 스프링이 자리에 붙었는지 (쿵 소리를 한 번만 내기 위해)
    this.spawnAt = []; // 레벨 시작 등장 연출

    this.drag = null; // { v, range, grab, cur, last, lastT, edge }
    this.exitAnim = null; // 탈출 주행 { t0, from, dur, cb, confettied }
    this.guide = null; // { v, to } — 첫 레벨 손가락 안내
    this.nudges = new Map(); // v → t0 (안 움직이는 차를 흔들 때)
    this.dust = [];
    this.confetti = [];
    this.streaks = [];
    this.shakeFx = null;

    // 입력 → 게임 콜백. 게임(컨트롤러)이 채운다.
    this.handlers = {
      canDrag: () => true,
      onPick: () => {},
      onDetent: () => {},
      onBump: () => {},
      onStuck: () => {},
      onThunk: () => {},
      onCommit: () => {},
    };

    this._loop = this._loop.bind(this);
    this._lastT = performance.now();
    requestAnimationFrame(this._loop);
  }

  resize() {
    const r = this.canvas.getBoundingClientRect();
    this.cssW = r.width;
    this.cssH = r.height;
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.canvas.width = Math.round(r.width * this.dpr);
    this.canvas.height = Math.round(r.height * this.dpr);
    this._metrics();
  }

  _metrics() {
    const pad = 10;
    const side = Math.max(60, Math.min(this.cssW, this.cssH) - pad * 2);
    this.wall = Math.max(10, side * 0.045);
    this.cell = (side - this.wall * 2) / W;
    this.ox = (this.cssW - side) / 2 + this.wall; // 격자 원점 (칸 0,0의 왼쪽 위)
    this.oy = (this.cssH - side) / 2 + this.wall;
    this.side = side;
  }

  // --- 상태 ---

  // 레벨 시작: 표시 좌표를 리셋하고 차들을 순서대로 등장시킨다
  reset(vehicles) {
    this.vehicles = vehicles;
    this.disp = vehicles.map(coordOf);
    this.vel = vehicles.map(() => 0);
    this.settled = vehicles.map(() => true);
    const now = performance.now();
    this.spawnAt = vehicles.map((_, i) => now + i * 40);
    this.drag = null;
    this.exitAnim = null;
    this.clearEffects();
  }

  // 수가 적용된 뒤: 논리 상태만 갈아끼우고 표시 좌표는 스프링이 따라가게 둔다
  setState(vehicles) {
    this.vehicles = vehicles;
    vehicles.forEach((v, i) => {
      if (Math.abs(this.disp[i] - coordOf(v)) > 0.004) this.settled[i] = false;
    });
  }

  clearEffects() {
    this.dust = [];
    this.confetti = [];
    this.streaks = [];
    this.nudges.clear();
    this.shakeFx = null;
    this.guide = null;
  }

  setGuide(move) {
    this.guide = move;
  }

  nudgeVehicle(i) {
    this.nudges.set(i, performance.now());
  }

  shake(amp = 3) {
    this.shakeFx = { amp, t0: performance.now(), dur: 240 };
  }

  // --- 좌표 ---

  carRect(i, disp = this.disp[i]) {
    const v = this.vehicles[i];
    const gx = v.h ? disp : v.x;
    const gy = v.h ? v.y : disp;
    return {
      x: this.ox + gx * this.cell,
      y: this.oy + gy * this.cell,
      w: (v.h ? v.len : 1) * this.cell,
      h: (v.h ? 1 : v.len) * this.cell,
    };
  }

  vehicleCenter(i) {
    if (!this.vehicles || !this.vehicles[i]) return null;
    const r = this.carRect(i);
    return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
  }

  hitTest(x, y) {
    if (!this.vehicles) return null;
    const slop = Math.min(8, this.cell * 0.12);
    // 나중에 그려진(위에 보이는) 차가 우선
    for (let i = this.vehicles.length - 1; i >= 0; i--) {
      const r = this.carRect(i);
      if (x >= r.x - slop && x <= r.x + r.w + slop && y >= r.y - slop && y <= r.y + r.h + slop) {
        return i;
      }
    }
    return null;
  }

  // --- 입력 (main.js가 포인터 좌표를 넘긴다) ---

  pointerDown(x, y) {
    if (!this.vehicles || this.exitAnim) return;
    const i = this.hitTest(x, y);
    if (i === null) return;
    if (!this.handlers.canDrag(i)) {
      this.nudgeVehicle(i);
      this.handlers.onStuck(i);
      return;
    }
    const v = this.vehicles[i];
    const range = rangeOf(this.vehicles, i);
    const axisPx = v.h ? x : y;
    this.drag = {
      v: i,
      range,
      // 손가락이 차의 어디를 잡았는지 (놓을 때까지 그 지점이 손을 따라온다)
      grab: axisPx - (v.h ? this.ox : this.oy) - this.disp[i] * this.cell,
      cur: this.disp[i],
      last: axisPx,
      lastT: performance.now(),
      vel: 0,
      edge: 0, // -1/1 = 지금 구간 끝에 눌려 있음
      moved: false,
      stuckTold: false,
    };
    this.handlers.onPick(i);
  }

  pointerMove(x, y) {
    const d = this.drag;
    if (!d) return;
    const v = this.vehicles[d.v];
    const axisPx = v.h ? x : y;
    const now = performance.now();
    const dt = Math.max(1, now - d.lastT);
    d.vel = (axisPx - d.last) / dt; // px/ms
    d.last = axisPx;
    d.lastT = now;

    const want = (axisPx - (v.h ? this.ox : this.oy) - d.grab) / this.cell;
    const { min, max } = d.range;
    let cur = want;
    let edge = 0;
    if (want < min) {
      cur = min + overshoot(want - min);
      edge = -1;
    } else if (want > max) {
      cur = max + overshoot(want - max);
      edge = 1;
    }

    // 칸 경계를 지날 때마다 딸깍 — 손가락에 눈금이 느껴진다
    const before = Math.round(clamp(d.cur, min, max));
    const after = Math.round(clamp(cur, min, max));
    if (before !== after) this.handlers.onDetent(d.v, after);

    // 구간 끝에 처음 부딪히는 순간, 속도가 실려 있으면 쿵
    if (edge !== 0 && d.edge === 0) {
      const speed = Math.abs(d.vel);
      if (min === max && !d.stuckTold && Math.abs(want - min) > 0.3) {
        // 아예 움직일 수 없는 차 — 한 번만 알려준다
        d.stuckTold = true;
        this.nudgeVehicle(d.v);
        this.handlers.onStuck(d.v);
      } else if (speed > 0.25) {
        this.shake(Math.min(4, speed * 6));
        this._spawnDust(d.v, edge, Math.min(1, speed));
        this.handlers.onBump(d.v, speed);
      }
    }
    d.edge = edge;
    if (Math.abs(cur - this.disp[d.v]) > 0.001) d.moved = true;
    d.cur = cur;
    this.disp[d.v] = cur;
    this.settled[d.v] = false;
  }

  pointerUp() {
    const d = this.drag;
    if (!d) return;
    this.drag = null;
    const to = Math.round(clamp(d.cur, d.range.min, d.range.max));
    const from = coordOf(this.vehicles[d.v]);
    // 던지는 손맛: 놓는 순간의 속도를 스프링에 실어준다
    this.vel[d.v] = d.vel * (16.7 / this.cell) * 14;
    if (to !== from) this.handlers.onCommit(d.v, to);
    // to === from 이면 스프링이 제자리로 데려간다
  }

  pointerCancel() {
    if (this.drag) this.drag = null;
  }

  // --- 연출 ---

  _spawnDust(i, edge, power) {
    const v = this.vehicles[i];
    const r = this.carRect(i);
    // 부딪힌 쪽 끝
    const px = v.h ? (edge > 0 ? r.x + r.w : r.x) : r.x + r.w / 2;
    const py = v.h ? r.y + r.h / 2 : edge > 0 ? r.y + r.h : r.y;
    const n = 3 + Math.round(power * 4);
    for (let k = 0; k < n; k++) {
      const a = Math.random() * Math.PI * 2;
      const sp = (0.4 + Math.random() * 0.9) * power * 0.09 * this.cell;
      this.dust.push({
        x: px, y: py,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 0.02 * this.cell,
        r: (0.05 + Math.random() * 0.06) * this.cell,
        t0: performance.now(), dur: 380 + Math.random() * 220,
      });
    }
  }

  // 탈출: 택시가 출구로 가속해 화면 밖까지 달려 나간다
  driveOut(cb) {
    this.exitAnim = {
      t0: performance.now(),
      from: this.disp[PLAYER],
      dur: 950,
      cb,
      confettied: false,
    };
    this.drag = null;
  }

  celebrate() {
    const cx = this.ox + W * this.cell + this.wall;
    const cy = this.oy + (EXIT_ROW + 0.5) * this.cell;
    const hexes = [TAXI_HEX, ...CAR_HEX.slice(0, 6)];
    for (let k = 0; k < 110; k++) {
      const fromExit = k < 55;
      const a = fromExit ? Math.PI * (1.15 + Math.random() * 0.7) : Math.PI * (0.25 + Math.random() * 0.5);
      const sp = (0.25 + Math.random() * 0.5) * this.cell * (fromExit ? 0.34 : 0.2);
      this.confetti.push({
        x: fromExit ? cx : this.cssW * Math.random(),
        y: fromExit ? cy : -10,
        vx: Math.cos(a) * sp * (fromExit ? -1 : 1),
        vy: Math.sin(a) * sp * (fromExit ? 1 : 0.4) + 0.04 * this.cell,
        w: 4 + Math.random() * 5,
        rot: Math.random() * Math.PI,
        vr: (Math.random() - 0.5) * 0.28,
        hex: hexes[k % hexes.length],
        t0: performance.now(),
        dur: 1400 + Math.random() * 700,
      });
    }
  }

  // --- 루프 ---

  _loop(now) {
    const dt = Math.min(0.05, (now - this._lastT) / 1000);
    this._lastT = now;
    this._physics(now, dt);
    this._draw(now);
    requestAnimationFrame(this._loop);
  }

  _physics(now, dt) {
    if (!this.vehicles) return;
    for (let i = 0; i < this.vehicles.length; i++) {
      if (this.drag && this.drag.v === i) continue;
      if (this.exitAnim && i === PLAYER) continue;
      const target = coordOf(this.vehicles[i]);
      const diff = target - this.disp[i];
      if (Math.abs(diff) < 0.003 && Math.abs(this.vel[i]) < 0.06) {
        if (!this.settled[i]) {
          this.settled[i] = true;
          const impact = Math.abs(this.vel[i]) + Math.abs(diff) * 8;
          this.disp[i] = target;
          this.vel[i] = 0;
          this.handlers.onThunk(i, impact);
        }
        continue;
      }
      // 살짝 덜 감쇠된 스프링 — 미세한 오버슛이 "딱 붙는" 느낌을 만든다
      this.vel[i] += diff * 320 * dt;
      this.vel[i] *= Math.exp(-19 * dt);
      this.disp[i] += this.vel[i] * dt;
      this.settled[i] = false;
    }

    // 탈출 주행
    const ea = this.exitAnim;
    if (ea) {
      const t = clamp((now - ea.t0) / ea.dur, 0, 1);
      const dist = W + 3.4 - ea.from; // 화면 밖까지
      this.disp[PLAYER] = ea.from + dist * easeInQuad(t);
      // 속도선
      if (t > 0.15 && Math.random() < 0.5) {
        const r = this.carRect(PLAYER);
        this.streaks.push({
          x: r.x, y: r.y + Math.random() * r.h,
          len: this.cell * (0.5 + Math.random() * 0.8),
          t0: now, dur: 260,
        });
      }
      if (!ea.confettied && this.disp[PLAYER] + 2 > W) {
        ea.confettied = true;
        this.celebrate();
      }
      if (t >= 1) {
        this.exitAnim = null;
        ea.cb?.();
      }
    }
  }

  _draw(now) {
    const { ctx, dpr } = this;
    if (!this.cssW) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, this.cssW, this.cssH);

    // 부딪힘 흔들림
    if (this.shakeFx) {
      const t = (now - this.shakeFx.t0) / this.shakeFx.dur;
      if (t >= 1) this.shakeFx = null;
      else {
        const a = this.shakeFx.amp * (1 - t);
        ctx.translate(Math.sin(t * 42) * a, Math.cos(t * 31) * a * 0.6);
      }
    }

    this._drawLot(now);
    if (this.vehicles) {
      // 드래그 중인 차는 맨 위에
      const order = this.vehicles.map((_, i) => i);
      if (this.drag) {
        order.splice(order.indexOf(this.drag.v), 1);
        order.push(this.drag.v);
      } else {
        order.splice(order.indexOf(PLAYER), 1);
        order.push(PLAYER);
      }
      for (const i of order) this._drawCar(i, now);
    }
    this._drawGuide(now);
    this._drawParticles(now);
  }

  // 주차장 바닥과 벽, 출구
  _drawLot(now) {
    const { ctx, ox, oy, cell, wall } = this;
    const bx = ox - wall;
    const by = oy - wall;
    const bs = this.side;

    // 바닥
    rr(ctx, bx, by, bs, bs, wall * 1.6);
    const floor = ctx.createLinearGradient(0, by, 0, by + bs);
    floor.addColorStop(0, '#252f4a');
    floor.addColorStop(1, '#1b2338');
    ctx.fillStyle = floor;
    ctx.fill();

    // 주차 칸 눈금
    ctx.strokeStyle = 'rgba(255,255,255,0.055)';
    ctx.lineWidth = 1;
    for (let k = 1; k < W; k++) {
      ctx.beginPath();
      ctx.moveTo(ox + k * cell, oy + 3);
      ctx.lineTo(ox + k * cell, oy + H * cell - 3);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(ox + 3, oy + k * cell);
      ctx.lineTo(ox + W * cell - 3, oy + k * cell);
      ctx.stroke();
    }
    // 칸 모서리 점 — 주차장 느낌
    ctx.fillStyle = 'rgba(255,255,255,0.10)';
    for (let gx = 0; gx <= W; gx++) {
      for (let gy = 0; gy <= H; gy++) {
        ctx.beginPath();
        ctx.arc(ox + gx * cell, oy + gy * cell, 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // 벽 — 오른쪽 벽만 출구 높이만큼 비워 둔다
    const gapY0 = oy + EXIT_ROW * cell;
    const wallFill = '#3a466b';
    const wr = wall * 0.5;
    ctx.fillStyle = wallFill;
    rr(ctx, bx, by, bs, wall, wr); // 위
    ctx.fill();
    rr(ctx, bx, by + bs - wall, bs, wall, wr); // 아래
    ctx.fill();
    rr(ctx, bx, by, wall, bs, wr); // 왼쪽
    ctx.fill();
    rr(ctx, bx + bs - wall, by, wall, gapY0 - by, wr); // 오른쪽 위 조각
    ctx.fill();
    rr(ctx, bx + bs - wall, gapY0 + cell, wall, by + bs - gapY0 - cell, wr); // 오른쪽 아래 조각
    ctx.fill();

    // 출구는 검은 구멍이 아니라 밝은 진입로 — 바닥이 벽을 뚫고 이어진다
    const drive = ctx.createLinearGradient(ox + W * cell, 0, ox + W * cell + wall, 0);
    drive.addColorStop(0, '#222c47');
    drive.addColorStop(1, '#2c3859');
    ctx.fillStyle = drive;
    ctx.fillRect(ox + W * cell - 1, gapY0, wall + 1, cell);

    // 출구 칸 바닥 표시 + 밖으로 흐르는 갈매기 — 목표를 글자 없이 말한다
    const pulse = (now / 900) % 1;
    ctx.fillStyle = rgba(TAXI_HEX, 0.10);
    ctx.fillRect(ox + (W - 1) * cell, gapY0, cell, cell);
    for (let k = 0; k < 2; k++) {
      const t = (pulse + k * 0.5) % 1;
      const cx = ox + W * cell + wall * 0.1 + t * wall * 1.1;
      const cy = gapY0 + cell / 2;
      const s = cell * 0.16;
      ctx.strokeStyle = rgba(TAXI_HEX, 0.85 * (1 - t));
      ctx.lineWidth = Math.max(2.5, cell * 0.05);
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(cx - s * 0.6, cy - s);
      ctx.lineTo(cx + s * 0.4, cy);
      ctx.lineTo(cx - s * 0.6, cy + s);
      ctx.stroke();
    }
  }

  _drawCar(i, now) {
    const { ctx, cell } = this;
    const v = this.vehicles[i];
    const isPlayer = i === PLAYER;
    const dragging = this.drag && this.drag.v === i;

    // 등장 연출
    let spawnScale = 1;
    const st = (now - this.spawnAt[i]) / 260;
    if (st < 0) return;
    if (st < 1) spawnScale = easeOutBack(st);

    // 잘못 건드렸을 때 도리도리
    let nx = 0;
    const nt = this.nudges.get(i);
    if (nt !== undefined) {
      const t = (now - nt) / 300;
      if (t >= 1) this.nudges.delete(i);
      else nx = Math.sin(t * Math.PI * 5) * (1 - t) * cell * 0.06;
    }

    const r = this.carRect(i);
    const inset = cell * 0.07;
    let x = r.x + inset + (v.h ? 0 : nx);
    let y = r.y + inset + (v.h ? nx : 0);
    let w = r.w - inset * 2;
    let h = r.h - inset * 2;

    // 드래그 중엔 살짝 커지고 떠오른다
    const lift = dragging ? 1.035 : 1;
    const s = spawnScale * lift;
    const cx = x + w / 2;
    const cy = y + h / 2;
    x = cx - (w / 2) * s;
    y = cy - (h / 2) * s;
    w *= s;
    h *= s;

    const hex = isPlayer ? TAXI_HEX : CAR_HEX[(i - 1) % CAR_HEX.length];
    const rad = Math.min(w, h) * 0.28;

    // 그림자
    ctx.fillStyle = `rgba(5,8,18,${dragging ? 0.5 : 0.34})`;
    rr(ctx, x + (dragging ? 4 : 2), y + (dragging ? 6 : 3), w, h, rad);
    ctx.fill();

    // 차체
    const body = ctx.createLinearGradient(x, y, v.h ? x : x + w, v.h ? y + h : y);
    body.addColorStop(0, shade(hex, 0.22));
    body.addColorStop(0.55, hex);
    body.addColorStop(1, shade(hex, -0.18));
    ctx.fillStyle = body;
    rr(ctx, x, y, w, h, rad);
    ctx.fill();
    ctx.strokeStyle = shade(hex, -0.34);
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // 유리(캐빈) — 축 방향 중앙에 얹어 차라는 걸 말해준다
    const along = v.h ? w : h;
    const across = v.h ? h : w;
    const cabLen = along * (v.len === 2 ? 0.46 : 0.5);
    const cabAcross = across * 0.68;
    const cabA = (along - cabLen) / 2;
    const cabB = (across - cabAcross) / 2;
    const cabX = v.h ? x + cabA : x + cabB;
    const cabY = v.h ? y + cabB : y + cabA;
    const cabW = v.h ? cabLen : cabAcross;
    const cabH = v.h ? cabAcross : cabLen;
    const glass = ctx.createLinearGradient(cabX, cabY, cabX, cabY + cabH);
    glass.addColorStop(0, 'rgba(216,235,255,0.92)');
    glass.addColorStop(1, 'rgba(130,165,215,0.9)');
    ctx.fillStyle = glass;
    rr(ctx, cabX, cabY, cabW, cabH, Math.min(cabW, cabH) * 0.3);
    ctx.fill();
    // 창틀 한 줄 — 앞창/뒷창 분리
    ctx.strokeStyle = rgba(hex, 0.75);
    ctx.lineWidth = Math.max(1.5, cell * 0.035);
    ctx.beginPath();
    if (v.h) {
      ctx.moveTo(cabX + cabW / 2, cabY + 1);
      ctx.lineTo(cabX + cabW / 2, cabY + cabH - 1);
    } else {
      ctx.moveTo(cabX + 1, cabY + cabH / 2);
      ctx.lineTo(cabX + cabW - 1, cabY + cabH / 2);
    }
    ctx.stroke();

    // 윗면 하이라이트
    const hl = ctx.createLinearGradient(x, y, x, y + h * 0.5);
    hl.addColorStop(0, 'rgba(255,255,255,0.28)');
    hl.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = hl;
    rr(ctx, x, y, w, h * 0.5, rad);
    ctx.fill();

    if (isPlayer) this._drawTaxiTrim(x, y, w, h, now);
  }

  // 택시 장식: 체커 밴드 + 지붕등. 출구로 달려 나갈 주인공이라는 표식.
  _drawTaxiTrim(x, y, w, h, now) {
    const { ctx } = this;
    const band = h * 0.16;
    const by = y + h / 2 - band / 2;
    const seg = band; // 정사각 체커
    ctx.save();
    rr(ctx, x + w * 0.06, by, w * 0.88, band, band * 0.3);
    ctx.clip();
    for (let k = 0; k * seg < w; k++) {
      ctx.fillStyle = k % 2 ? '#1d2233' : '#f4f6fb';
      ctx.fillRect(x + w * 0.06 + k * seg, by, seg, band);
    }
    ctx.restore();

    // 지붕등 — 은은하게 깜빡여 시선을 끈다
    const blink = 0.65 + 0.35 * Math.sin(now / 320);
    const lw = w * 0.1;
    const lh = h * 0.16;
    ctx.fillStyle = `rgba(255,244,200,${blink})`;
    rr(ctx, x + w / 2 - lw / 2, y - lh * 0.32, lw, lh, lh * 0.4);
    ctx.fill();
  }

  // 첫 레벨 안내: 잡을 차를 링으로 짚고, 유령 손이 미는 방향을 반복해서 보여준다
  _drawGuide(now) {
    const g = this.guide;
    if (!g || !this.vehicles || this.exitAnim) return;
    const { ctx, cell } = this;
    const v = this.vehicles[g.v];
    const r = this.carRect(g.v);

    const pulse = 0.5 + 0.5 * Math.sin(now / 260);
    ctx.strokeStyle = `rgba(255,255,255,${0.35 + 0.4 * pulse})`;
    ctx.lineWidth = 3;
    rr(ctx, r.x - 4, r.y - 4, r.w + 8, r.h + 8, cell * 0.3);
    ctx.stroke();

    if (this.drag && this.drag.v === g.v) return; // 이미 잡았으면 손은 치운다
    // 유령 손끝 — 이모지는 폰트가 없는 기기에서 깨지므로 도형으로 그린다
    const t = easeOutCubic((now / 1500) % 1);
    const from = { x: r.x + r.w * 0.6, y: r.y + r.h * 0.62 };
    const delta = (g.to - coordOf(v)) * cell * t;
    const hx = from.x + (v.h ? delta : 0);
    const hy = from.y + (v.h ? 0 : delta);
    ctx.globalAlpha = t < 0.12 ? t / 0.12 : t > 0.82 ? (1 - t) / 0.18 : 1;
    const fr = cell * 0.17;
    ctx.beginPath();
    ctx.arc(hx, hy, fr * (1.7 - 0.5 * t), 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.75)';
    ctx.lineWidth = 2.5;
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(hx, hy, fr, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  _drawParticles(now) {
    const { ctx } = this;

    for (let i = this.dust.length - 1; i >= 0; i--) {
      const p = this.dust[i];
      const t = (now - p.t0) / p.dur;
      if (t >= 1) {
        this.dust.splice(i, 1);
        continue;
      }
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.92;
      p.vy *= 0.92;
      ctx.fillStyle = `rgba(200,210,235,${0.3 * (1 - t)})`;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r * (1 + t * 1.6), 0, Math.PI * 2);
      ctx.fill();
    }

    for (let i = this.streaks.length - 1; i >= 0; i--) {
      const s = this.streaks[i];
      const t = (now - s.t0) / s.dur;
      if (t >= 1) {
        this.streaks.splice(i, 1);
        continue;
      }
      ctx.strokeStyle = `rgba(255,240,180,${0.5 * (1 - t)})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(s.x - s.len * t, s.y);
      ctx.lineTo(s.x - s.len * t - s.len * 0.6, s.y);
      ctx.stroke();
    }

    for (let i = this.confetti.length - 1; i >= 0; i--) {
      const c = this.confetti[i];
      const t = (now - c.t0) / c.dur;
      if (t >= 1) {
        this.confetti.splice(i, 1);
        continue;
      }
      c.x += c.vx;
      c.y += c.vy;
      c.vy += 0.05 * (this.cell / 60);
      c.rot += c.vr;
      ctx.save();
      ctx.translate(c.x, c.y);
      ctx.rotate(c.rot);
      ctx.globalAlpha = t > 0.7 ? (1 - t) / 0.3 : 1;
      ctx.fillStyle = c.hex;
      ctx.fillRect(-c.w / 2, -c.w / 2, c.w, c.w * 0.62);
      ctx.restore();
      ctx.globalAlpha = 1;
    }
  }
}
