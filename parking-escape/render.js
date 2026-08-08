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
    // "누가 주인공이고 어디로 가는지"를 첫 터치 전까지 바닥 차선으로 보여준다
    this.intro = { t0: now };
    this._wasClear = false;
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
    this.flashFx = null;
    this.guide = null;
  }

  // 택시 앞이 출구까지 뻥 뚫렸는가 — 게이트 연출과 "지금이야!" 신호의 근거
  _pathClear() {
    if (!this.vehicles) return false;
    const p = this.vehicles[PLAYER];
    const g = occupancy(this.vehicles);
    for (let x = p.x + p.len; x < W; x++) {
      if (g[EXIT_ROW * W + x] !== -1) return false;
    }
    return true;
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
    this.intro = null; // 만지기 시작하면 안내 차선은 치운다
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
      dur: 1100,
      cb,
      confettied: false,
    };
    this.drag = null;
    this.intro = null;
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

    // 탈출 주행 — 움찔(발진 준비) → 배기 연기를 뿜으며 가속 → 게이트 섬광
    const ea = this.exitAnim;
    if (ea) {
      const t = clamp((now - ea.t0) / ea.dur, 0, 1);
      const dist = W + 3.4 - ea.from;
      const REV = 0.16; // 이 구간 동안 뒤로 살짝 움츠렸다가 튀어나간다
      if (t < REV) {
        this.disp[PLAYER] = ea.from - 0.07 * Math.sin((t / REV) * Math.PI);
      } else {
        this.disp[PLAYER] = ea.from + dist * easeInQuad((t - REV) / (1 - REV));
      }
      const r = this.carRect(PLAYER);
      // 속도선
      if (t > REV && Math.random() < 0.55) {
        this.streaks.push({
          x: r.x, y: r.y + Math.random() * r.h,
          len: this.cell * (0.5 + Math.random() * 0.8),
          t0: now, dur: 260,
        });
      }
      // 배기 연기 — 꽁무니에서 몽글몽글
      if (Math.random() < (t < REV ? 0.5 : 0.3)) {
        this.dust.push({
          x: r.x - this.cell * 0.05,
          y: r.y + r.h * (0.35 + Math.random() * 0.3),
          vx: -0.02 * this.cell - Math.random() * 0.015 * this.cell,
          vy: (Math.random() - 0.5) * 0.01 * this.cell,
          r: (0.07 + Math.random() * 0.07) * this.cell,
          t0: now, dur: 450 + Math.random() * 250,
        });
      }
      if (!ea.confettied && this.disp[PLAYER] + 2 > W) {
        ea.confettied = true;
        this.celebrate();
        // 게이트 통과 섬광
        this.flashFx = { t0: now };
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

    // 길이 뚫리는 순간을 잡아 게이트를 밝히고 "딩" 신호를 보낸다
    this._exitClear = this._pathClear();
    if (this._exitClear && !this._wasClear) {
      this._wasClear = true;
      if (!this.exitAnim) this.handlers.onExitOpen?.();
    } else if (!this._exitClear) {
      this._wasClear = false;
    }

    this._drawLot(now);
    this._drawIntroLane(now); // 차 밑에 깔리는 안내 차선
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
    this._drawIntroMarker(now);
    this._drawGuide(now);
    this._drawParticles(now);
  }

  // 레벨 시작 안내: 택시에서 출구로 흐르는 점선 차선. 첫 터치나 4초 뒤에 사라진다.
  _introAlpha(now) {
    if (!this.intro || !this.vehicles || this.exitAnim) return 0;
    const age = now - this.intro.t0;
    if (age > 4100) {
      this.intro = null;
      return 0;
    }
    if (age < 400) return age / 400;
    if (age > 3600) return 1 - (age - 3600) / 500;
    return 1;
  }

  _drawIntroLane(now) {
    const a = this._introAlpha(now);
    if (a <= 0) return;
    const { ctx, cell } = this;
    const r = this.carRect(PLAYER);
    const y = this.oy + (EXIT_ROW + 0.5) * cell;
    ctx.save();
    ctx.globalAlpha = 0.4 * a;
    ctx.strokeStyle = TAXI_HEX;
    ctx.lineWidth = cell * 0.09;
    ctx.lineCap = 'round';
    ctx.setLineDash([cell * 0.24, cell * 0.2]);
    ctx.lineDashOffset = -((now / 26) % (cell * 0.44)); // 출구 쪽으로 흐른다
    ctx.beginPath();
    ctx.moveTo(r.x + r.w * 0.55, y);
    ctx.lineTo(this.ox + W * cell + this.wall * 0.7, y);
    ctx.stroke();
    ctx.restore();
  }

  // 택시 위에서 통통 튀는 마커 — 차들 위에 그려야 가려지지 않는다
  _drawIntroMarker(now) {
    const a = this._introAlpha(now);
    if (a <= 0) return;
    const { ctx, cell } = this;
    const r = this.carRect(PLAYER);
    const bob = Math.sin(now / 220) * cell * 0.07;
    const mx = r.x + r.w / 2;
    const my = r.y - cell * 0.3 + bob;
    const s = cell * 0.17;
    ctx.globalAlpha = a;
    ctx.fillStyle = TAXI_HEX;
    ctx.strokeStyle = 'rgba(40,30,0,0.55)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(mx - s, my - s * 1.2);
    ctx.lineTo(mx + s, my - s * 1.2);
    ctx.lineTo(mx, my);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.globalAlpha = 1;
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

    // 출구는 검은 구멍이 아니라 밝은 진입로 — 바닥이 울타리를 뚫고 이어진다
    const gapY0 = oy + EXIT_ROW * cell;
    const drive = ctx.createLinearGradient(ox + W * cell, 0, ox + W * cell + wall, 0);
    drive.addColorStop(0, '#222c47');
    drive.addColorStop(1, '#2c3859');
    ctx.fillStyle = drive;
    ctx.fillRect(ox + W * cell - 1, gapY0, wall + 1, cell);

    // 벽 대신 산울타리 — 동글동글한 덤불이 주차장을 감싼다 (출구만 뚫려 있다)
    const mid = wall * 0.5;
    const hedge = (x0, y0, x1, y1, seed) => {
      const len = Math.hypot(x1 - x0, y1 - y0);
      const n = Math.max(2, Math.round(len / (wall * 0.52)));
      for (let k = 0; k <= n; k++) {
        const t = k / n;
        const px = x0 + (x1 - x0) * t;
        const py = y0 + (y1 - y0) * t;
        const br = wall * (0.5 + Math.sin(k * 2.1 + seed) * 0.08);
        ctx.fillStyle = k % 2 ? '#2f6b45' : '#28603f';
        ctx.beginPath();
        ctx.arc(px, py, br, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.07)';
        ctx.beginPath();
        ctx.arc(px - br * 0.2, py - br * 0.28, br * 0.55, 0, Math.PI * 2);
        ctx.fill();
      }
    };
    hedge(bx + mid, by + mid, bx + bs - mid, by + mid, 0); // 위
    hedge(bx + mid, by + bs - mid, bx + bs - mid, by + bs - mid, 2); // 아래
    hedge(bx + mid, by + mid, bx + mid, by + bs - mid, 4); // 왼쪽
    hedge(bx + bs - mid, by + mid, bx + bs - mid, gapY0 - wall * 0.2, 6); // 오른쪽 위
    hedge(bx + bs - mid, gapY0 + cell + wall * 0.2, bx + bs - mid, by + bs - mid, 8); // 오른쪽 아래

    // 울타리에 핀 꽃 — 자리 고정 장식 (출구 근처는 피해 둔다)
    for (const [fx, fy] of [[0.13, 0], [0.57, 0], [0.86, 0], [0, 0.32], [0, 0.72], [0.33, 1], [0.74, 1], [1, 0.82]]) {
      const px = bx + mid + (bs - wall) * fx;
      const py = by + mid + (bs - wall) * fy;
      ctx.fillStyle = '#ff9ec3';
      for (let a = 0; a < 5; a++) {
        ctx.beginPath();
        ctx.arc(
          px + Math.cos((a / 5) * Math.PI * 2) * wall * 0.17,
          py + Math.sin((a / 5) * Math.PI * 2) * wall * 0.17,
          wall * 0.13,
          0,
          Math.PI * 2
        );
        ctx.fill();
      }
      ctx.fillStyle = '#ffd23e';
      ctx.beginPath();
      ctx.arc(px, py, wall * 0.11, 0, Math.PI * 2);
      ctx.fill();
    }

    // --- 골인 게이트 ---
    // 길이 뚫리면 게이트가 확 밝아지고 갈매기가 빨라진다 — "지금이야!"를 빛으로 말한다
    const open = this._exitClear;
    const gx = ox + W * cell;
    const gy = gapY0 + cell / 2;

    // 따뜻한 빛이 주차장 안으로 새어 들어온다
    const breathe = open ? 0.3 + 0.1 * Math.sin(now / 170) : 0.1 + 0.04 * Math.sin(now / 520);
    const glow = ctx.createRadialGradient(gx, gy, 0, gx, gy, cell * 1.9);
    glow.addColorStop(0, rgba(TAXI_HEX, breathe));
    glow.addColorStop(1, rgba(TAXI_HEX, 0));
    ctx.fillStyle = glow;
    ctx.fillRect(gx - cell * 1.9, gy - cell * 1.9, cell * 3.8, cell * 3.8);

    // 출구 칸 바닥 표시
    ctx.fillStyle = rgba(TAXI_HEX, open ? 0.16 : 0.09);
    ctx.fillRect(ox + (W - 1) * cell, gapY0, cell, cell);

    // 체커 깃발 두 개 — 골인 지점이라는 만국 공용어
    const flag = (fx, fy, phase) => {
      const poleH = cell * 0.5;
      ctx.strokeStyle = '#c9d1e8';
      ctx.lineWidth = Math.max(2, cell * 0.045);
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(fx, fy);
      ctx.lineTo(fx, fy - poleH);
      ctx.stroke();
      const fw = cell * 0.34;
      const fh = cell * 0.22;
      const wave = Math.sin(now / 260 + phase) * fh * 0.18;
      const sq = fw / 3;
      for (let cxk = 0; cxk < 3; cxk++) {
        for (let cyk = 0; cyk < 2; cyk++) {
          ctx.fillStyle = (cxk + cyk) % 2 ? '#f4f6fb' : '#1d2233';
          const lean = (cxk / 3) * wave;
          ctx.fillRect(fx + cxk * sq, fy - poleH + cyk * (fh / 2) + lean, sq + 0.5, fh / 2 + 0.5);
        }
      }
    };
    flag(gx + wall * 0.22, gapY0 - wall * 0.28, 0);
    flag(gx + wall * 0.22, gapY0 + cell + wall * 0.75, 2.1);

    // 밖으로 흐르는 갈매기 — 길이 뚫리면 두 배로 빨라진다
    const pulse = (now / (open ? 380 : 900)) % 1;
    for (let k = 0; k < 2; k++) {
      const t = (pulse + k * 0.5) % 1;
      const cx = gx + wall * 0.1 + t * wall * 1.1;
      const s = cell * 0.16;
      ctx.strokeStyle = rgba(TAXI_HEX, (open ? 1 : 0.8) * (1 - t));
      ctx.lineWidth = Math.max(2.5, cell * 0.05);
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(cx - s * 0.6, gy - s);
      ctx.lineTo(cx + s * 0.4, gy);
      ctx.lineTo(cx - s * 0.6, gy + s);
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

    // 주인공 표식 — 택시 밑에서 숨쉬는 빛무리. 길이 뚫리면 확 밝아진다.
    if (isPlayer && !this.exitAnim) {
      const strength = (this._exitClear ? 0.42 : 0.2) * (0.75 + 0.25 * Math.sin(now / 380));
      const hr = Math.max(w, h) * 0.78;
      const halo = ctx.createRadialGradient(cx, cy, 0, cx, cy, hr);
      halo.addColorStop(0, rgba(TAXI_HEX, strength));
      halo.addColorStop(1, rgba(TAXI_HEX, 0));
      ctx.fillStyle = halo;
      ctx.fillRect(cx - hr, cy - hr, hr * 2, hr * 2);
    }

    // 그림자 — 회전과 무관하게 항상 오른쪽 아래로 진다
    ctx.fillStyle = `rgba(5,8,18,${dragging ? 0.5 : 0.34})`;
    rr(ctx, x + (dragging ? 4 : 2), y + (dragging ? 6 : 3), w, h, Math.min(w, h) * 0.3);
    ctx.fill();

    // 앞뒤가 있는 진짜 차로 그린다. 로컬 좌표(-y = 차 앞)로 회전해 두면
    // 한 벌의 그리기 코드가 네 방향을 모두 처리한다. 택시는 언제나 출구(오른쪽)를 본다.
    const facing = isPlayer ? 1 : (i * 37 + 13) % 5 < 3 ? 1 : -1;
    const angle = v.h ? (facing > 0 ? Math.PI / 2 : -Math.PI / 2) : facing > 0 ? Math.PI : 0;
    ctx.save();
    ctx.translate(x + w / 2, y + h / 2);
    ctx.rotate(angle);
    this._drawCarBody(i, hex, Math.max(w, h), Math.min(w, h), now, isPlayer);
    ctx.restore();
  }

  // 로컬 좌표의 귀여운 탑다운 차. L = 길이(px), Wd = 폭(px), 앞 = -y.
  _drawCarBody(i, hex, L, Wd, now, isPlayer) {
    const { ctx } = this;
    const v = this.vehicles[i];
    const bw = Wd * 0.84; // 차체 폭 — 바퀴가 옆으로 살짝 삐져나온다
    const bl = L * 0.97;
    const bx = -bw / 2;
    const by = -bl / 2;

    // 바퀴 (2칸 차는 4개, 3칸 차·버스는 6개)
    const wheelW = Wd * 0.17;
    const wheelH = Math.min(L * 0.15, Wd * 0.3);
    ctx.fillStyle = '#141a2c';
    const rows = v.len === 2 ? [-0.26, 0.3] : [-0.3, 0.03, 0.35];
    for (const t of rows) {
      for (const sx of [-1, 1]) {
        rr(ctx, (sx * bw) / 2 - wheelW / 2, t * bl - wheelH / 2, wheelW, wheelH, wheelW * 0.45);
        ctx.fill();
      }
    }

    // 차체 — 앞모서리가 더 둥글다 (roundRect 미지원 브라우저는 균일 곡률로)
    const body = ctx.createLinearGradient(0, by, 0, by + bl);
    body.addColorStop(0, shade(hex, 0.26));
    body.addColorStop(0.5, hex);
    body.addColorStop(1, shade(hex, -0.16));
    ctx.fillStyle = body;
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(bx, by, bw, bl, [bw * 0.44, bw * 0.44, bw * 0.3, bw * 0.3]);
    else rr(ctx, bx, by, bw, bl, bw * 0.34);
    ctx.fill();
    ctx.strokeStyle = shade(hex, -0.34);
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // 헤드라이트 · 테일라이트
    ctx.fillStyle = '#fff3bf';
    for (const sx of [-1, 1]) {
      ctx.beginPath();
      ctx.arc(sx * bw * 0.26, by + bl * 0.055, bw * 0.09, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = '#ff5257';
    for (const sx of [-1, 1]) {
      rr(ctx, sx * bw * 0.26 - bw * 0.09, by + bl * 0.945 - bl * 0.02, bw * 0.18, bl * 0.035, bw * 0.04);
      ctx.fill();
    }

    // 앞유리 → 지붕 → 뒷유리
    const glass = ctx.createLinearGradient(0, by + bl * 0.15, 0, by + bl * 0.36);
    glass.addColorStop(0, '#dcecff');
    glass.addColorStop(1, '#9dbde8');
    ctx.fillStyle = glass;
    rr(ctx, -bw * 0.39, by + bl * 0.15, bw * 0.78, bl * 0.19, bw * 0.14);
    ctx.fill();

    const roofTop = by + bl * 0.37;
    const roofH = bl * (v.len === 2 ? 0.3 : 0.42);
    ctx.fillStyle = shade(hex, 0.08);
    rr(ctx, -bw * 0.41, roofTop, bw * 0.82, roofH, bw * 0.16);
    ctx.fill();
    ctx.strokeStyle = shade(hex, -0.22);
    ctx.lineWidth = 1;
    ctx.stroke();

    // 3칸 차는 지붕 양옆에 창문이 줄지어 있는 버스 느낌
    if (v.len === 3) {
      ctx.fillStyle = 'rgba(157,189,232,0.9)';
      for (let k = 0; k < 3; k++) {
        const wy = roofTop + roofH * (0.14 + k * 0.3);
        for (const sx of [-1, 1]) {
          rr(ctx, sx * bw * 0.41 - (sx > 0 ? bw * 0.07 : 0), wy, bw * 0.07, roofH * 0.2, bw * 0.02);
          ctx.fill();
        }
      }
    }

    ctx.fillStyle = 'rgba(157,189,232,0.95)';
    rr(ctx, -bw * 0.34, roofTop + roofH + bl * 0.015, bw * 0.68, bl * 0.1, bw * 0.1);
    ctx.fill();

    // 앞유리 너머의 눈 — 가끔 깜빡인다. 이게 이 게임의 표정이다.
    const blink = (now / 1000 + i * 0.83) % 3.7 < 0.12 ? 0.18 : 1;
    const eyeR = bw * 0.085;
    const eyeY = by + bl * 0.245;
    for (const sx of [-1, 1]) {
      ctx.save();
      ctx.translate(sx * bw * 0.16, eyeY);
      ctx.scale(1, blink);
      ctx.fillStyle = '#1d2439';
      ctx.beginPath();
      ctx.arc(0, 0, eyeR, 0, Math.PI * 2);
      ctx.fill();
      if (blink === 1) {
        ctx.fillStyle = 'rgba(255,255,255,0.9)';
        ctx.beginPath();
        ctx.arc(-eyeR * 0.3, -eyeR * 0.3, eyeR * 0.35, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    if (isPlayer) this._drawTaxiTrim(bw, bl, by, roofTop, roofH, now);
  }

  // 택시 장식: 옆구리 체커 줄 + 지붕등. 출구로 달려 나갈 주인공이라는 표식.
  _drawTaxiTrim(bw, bl, by, roofTop, roofH, now) {
    const { ctx } = this;
    const seg = bl * 0.07;
    for (const sx of [-1, 1]) {
      const stripX = sx * bw * 0.5 - (sx > 0 ? bw * 0.09 : 0);
      ctx.save();
      rr(ctx, stripX, by + bl * 0.16, bw * 0.09, bl * 0.68, bw * 0.03);
      ctx.clip();
      for (let k = 0; k * seg < bl * 0.68; k++) {
        ctx.fillStyle = k % 2 ? '#1d2233' : '#f4f6fb';
        ctx.fillRect(stripX, by + bl * 0.16 + k * seg, bw * 0.09, seg);
      }
      ctx.restore();
    }

    // 지붕등 — 은은하게 깜빡여 시선을 끈다
    const blink = 0.55 + 0.45 * Math.sin(now / 320);
    ctx.fillStyle = '#e8890c';
    rr(ctx, -bw * 0.12, roofTop + roofH * 0.5 - bl * 0.028, bw * 0.24, bl * 0.056, bl * 0.024);
    ctx.fill();
    ctx.fillStyle = `rgba(255,238,140,${blink})`;
    rr(ctx, -bw * 0.08, roofTop + roofH * 0.5 - bl * 0.018, bw * 0.16, bl * 0.036, bl * 0.016);
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

    // 게이트 통과 섬광 — 짧고 환하게
    if (this.flashFx) {
      const t = (now - this.flashFx.t0) / 320;
      if (t >= 1) this.flashFx = null;
      else {
        const gx = this.ox + W * this.cell;
        const gy = this.oy + (EXIT_ROW + 0.5) * this.cell;
        const fr = this.cell * (1 + t * 2.2);
        const g = ctx.createRadialGradient(gx, gy, 0, gx, gy, fr);
        g.addColorStop(0, `rgba(255,248,220,${0.55 * (1 - t)})`);
        g.addColorStop(1, 'rgba(255,248,220,0)');
        ctx.fillStyle = g;
        ctx.fillRect(gx - fr, gy - fr, fr * 2, fr * 2);
      }
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
