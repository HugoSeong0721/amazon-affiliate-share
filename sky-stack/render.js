// 캔버스 렌더러 — 탑, 움직이는 블록, 잘려 떨어지는 조각, 하늘 그라데이션.
// 엔진 상태를 읽기만 하고, 게임 규칙은 전혀 모른다.

import { CONFIG, score } from './engine.js';

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dpr = Math.min(2, window.devicePixelRatio || 1);
    this.camY = 0; // 카메라가 보는 탑 높이 (블록 단위, 부드럽게 따라간다)
    this.debris = []; // 잘려 떨어지는 조각들 (연출 전용)
    this.flash = 0; // 퍼펙트 잔광
    this.resize();
  }

  resize() {
    const { canvas, dpr } = this;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (!w || !h) return;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }

  reset(state) {
    this.camY = 0;
    this.debris = [];
    this.flash = 0;
    this.state = state;
  }

  // 층 → 블록 색. 시드의 hue0에서 시작해 층마다 색상환을 조금씩 돈다.
  colorAt(state, floor, light = 0) {
    const hue = (state.hue0 + floor * 7) % 360;
    return `hsl(${hue} 62% ${Math.min(88, 58 + light)}%)`;
  }

  addDebris(state, cut, floor) {
    this.debris.push({
      x: cut.x,
      y: floor,
      w: cut.w,
      vy: 0,
      vx: cut.side * 26,
      rot: 0,
      vr: cut.side * (1.4 + Math.min(2, cut.w / 30)),
      color: this.colorAt(state, floor),
    });
  }

  notePerfect() {
    this.flash = 1;
  }

  // dt초만큼 연출(카메라·조각·잔광)을 전진시킨다
  tick(state, dt) {
    const target = Math.max(0, score(state) - 1);
    this.camY += (target - this.camY) * Math.min(1, dt * 7);
    this.flash = Math.max(0, this.flash - dt * 2.4);
    for (const d of this.debris) {
      d.vy -= dt * 340; // 아래로 (월드 y는 위가 +)
      d.y += (d.vy * dt) / CONFIG.blockH;
      d.x += d.vx * dt;
      d.rot += d.vr * dt;
    }
    this.debris = this.debris.filter((d) => d.y > this.camY - 30);
  }

  draw(state) {
    const { ctx, canvas, dpr } = this;
    const W = canvas.width;
    const H = canvas.height;
    if (!W || !H) return;

    // 하늘 — 탑이 높아질수록 새벽 → 한낮 → 성층권으로 미묘하게 어두워진다
    const alt = Math.min(1, this.camY / 120);
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, `hsl(${215 + alt * 15} ${70 - alt * 30}% ${74 - alt * 52}%)`);
    g.addColorStop(1, `hsl(${205 + alt * 10} ${62 - alt * 25}% ${86 - alt * 44}%)`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    // 월드 → 화면 변환 (W는 이미 물리 픽셀 — dpr을 다시 곱하지 않는다)
    const unit = W / 300; // 월드 300유닛이 화면 폭
    const cx = W / 2;
    const baseY = H * 0.72; // 탑 기준선
    const yOf = (floorIdx) => baseY - (floorIdx - this.camY) * CONFIG.blockH * unit;
    const bh = CONFIG.blockH * unit;

    const drawBlock = (x, w, y, color, glow = 0) => {
      const px = cx + x * unit - (w * unit) / 2;
      ctx.fillStyle = color;
      if (glow > 0) {
        ctx.save();
        ctx.shadowColor = 'rgba(255,255,255,0.9)';
        ctx.shadowBlur = 26 * glow * dpr;
      }
      ctx.fillRect(px, y - bh, w * unit, bh);
      if (glow > 0) ctx.restore();
      // 윗면 하이라이트·옆면 음영 한 줄씩 — 납작한 그림에 부피감을 준다
      ctx.fillStyle = 'rgba(255,255,255,0.28)';
      ctx.fillRect(px, y - bh, w * unit, Math.max(1.5 * dpr, bh * 0.12));
      ctx.fillStyle = 'rgba(0,0,0,0.10)';
      ctx.fillRect(px, y - Math.max(1.5 * dpr, bh * 0.14), w * unit, Math.max(1.5 * dpr, bh * 0.14));
    };

    // 탑 — 화면에 걸리는 층만
    const floors = state.floors;
    const first = Math.max(0, Math.floor(this.camY - baseY / bh));
    for (let i = first; i < floors.length; i++) {
      const y = yOf(i);
      if (y < -bh) break;
      drawBlock(floors[i].x, floors[i].w, y, this.colorAt(state, i));
    }

    // 잘려 떨어지는 조각
    for (const d of this.debris) {
      ctx.save();
      ctx.translate(cx + d.x * unit, yOf(d.y) - bh / 2);
      ctx.rotate(d.rot * 0.35);
      ctx.globalAlpha = 0.9;
      ctx.fillStyle = d.color;
      ctx.fillRect((-d.w * unit) / 2, -bh / 2, d.w * unit, bh);
      ctx.restore();
    }

    // 움직이는 블록 — 다음에 얹힐 자리 위에서 왕복
    if (!state.over) {
      const m = state.moving;
      drawBlock(m.x, m.w, yOf(floors.length), this.colorAt(state, floors.length, 6), this.flash);
    }
  }
}
