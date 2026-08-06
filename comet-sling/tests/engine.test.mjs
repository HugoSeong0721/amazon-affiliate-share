// 엔진 계약 테스트 — node --test comet-sling/tests/engine.test.mjs
//
// 세 가지를 지킨다:
//  1) 결정론: 같은 시드 + 같은 입력 = 같은 런
//  2) 플레이 가능성 불변식: 궤도는 절대 소행성에 닿지 않고, 앵커 간 직선은 항상 열려 있다
//  3) 난이도 곡선의 단조성

import test from 'node:test';
import assert from 'node:assert/strict';
import { DT, WORLD, newRun, step, score, paramsAt, assistAt, ensureTrack, makeRng } from '../engine.js';

function runScript(seed, script, steps) {
  // script(i) → hold 여부
  const s = newRun(seed);
  for (let i = 0; i < steps && !s.dead; i++) step(s, { hold: script(i) });
  return s;
}

test('같은 시드 + 같은 입력 = 같은 런 (결정론)', () => {
  const script = (i) => (i % 400) < 220; // 홀드/릴리즈를 반복하는 임의 패턴
  const a = runScript(12345, script, 6000);
  const b = runScript(12345, script, 6000);
  assert.equal(a.x, b.x);
  assert.equal(a.y, b.y);
  assert.equal(a.height, b.height);
  assert.equal(a.sparks, b.sparks);
  assert.equal(a.dead, b.dead);
  assert.equal(score(a), score(b));
});

test('다른 시드는 다른 트랙을 만든다', () => {
  const a = newRun(1);
  const b = newRun(2);
  const differs = a.anchors.some((an, i) => !b.anchors[i] || an.x !== b.anchors[i].x);
  assert.ok(differs);
});

test('ensureTrack은 호출 시점·횟수와 무관하게 같은 트랙을 깐다', () => {
  const a = newRun(777);
  ensureTrack(a, 5000);
  const b = newRun(777);
  for (let y = 300; y <= 5000; y += 137) ensureTrack(b, y); // 잘게 나눠 호출
  ensureTrack(b, 5000);
  const n = Math.min(a.anchors.length, b.anchors.length);
  for (let i = 0; i < n; i++) {
    assert.equal(a.anchors[i].x, b.anchors[i].x);
    assert.equal(a.anchors[i].y, b.anchors[i].y);
  }
});

function distToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

test('트랙 불변식: 궤도 안전 · 직선 개방 · 통로 안 (시드 200개)', () => {
  for (let seed = 1; seed <= 200; seed++) {
    const s = newRun(seed);
    ensureTrack(s, 3000);

    // 앵커: y 단조 증가, 최대 궤도가 벽 안에 들어온다
    const maxX = WORLD.halfW - WORLD.orbitMax - WORLD.cometR - 2;
    for (let i = 0; i < s.anchors.length; i++) {
      const a = s.anchors[i];
      assert.ok(Math.abs(a.x) <= maxX + 1e-9, `seed ${seed}: 앵커 ${i}가 벽에 너무 가깝다`);
      if (i > 0) assert.ok(a.y > s.anchors[i - 1].y, `seed ${seed}: 앵커 y가 단조 증가하지 않는다`);
    }

    const anchorClear = WORLD.orbitMax + WORLD.hazardR + WORLD.cometR + 3;
    const lineClear = WORLD.hazardR + WORLD.cometR + 4;
    for (const hz of s.hazards) {
      // 통로 안
      assert.ok(Math.abs(hz.x) <= WORLD.halfW - WORLD.hazardR - 1 + 1e-9, `seed ${seed}: 소행성이 벽을 뚫었다`);
      // 어떤 앵커의 최대 궤도에도 닿지 않는다 → 궤도 중 죽을 수 없다
      for (const a of s.anchors) {
        assert.ok(
          Math.hypot(a.x - hz.x, a.y - hz.y) >= anchorClear - 1e-9,
          `seed ${seed}: 소행성이 앵커 궤도 안에 있다`
        );
      }
      // 이웃 앵커 사이 직선은 항상 열려 있다
      for (let i = 1; i < s.anchors.length; i++) {
        const p = s.anchors[i - 1], q = s.anchors[i];
        if (hz.y < p.y - 5 || hz.y > q.y + 5) continue;
        assert.ok(
          distToSegment(hz.x, hz.y, p.x, p.y, q.x, q.y) >= lineClear - 1e-9,
          `seed ${seed}: 소행성이 이상적인 비행선을 막는다`
        );
      }
    }
  }
});

test('난이도 곡선은 단조 증가한다', () => {
  let prev = paramsAt(0);
  for (let h = 50; h <= 8000; h += 50) {
    const p = paramsAt(h);
    assert.ok(p.speed >= prev.speed, `speed가 ${h}에서 줄었다`);
    assert.ok(p.hazardChance >= prev.hazardChance, `hazardChance가 ${h}에서 줄었다`);
    prev = p;
  }
  assert.ok(paramsAt(0).speed >= 25 && paramsAt(1e6).speed <= 100.001);
});

test('에임 어시스트는 초반에만 있고 단조 감소하며 800에서 사라진다', () => {
  assert.ok(assistAt(0) > 0.3);
  let prev = assistAt(0);
  for (let h = 50; h <= 900; h += 50) {
    const a = assistAt(h);
    assert.ok(a <= prev, `assist가 ${h}에서 늘었다`);
    prev = a;
  }
  assert.equal(assistAt(800), 0);
  assert.equal(assistAt(5000), 0);
});

test('계속 잡고 있으면 첫 앵커 궤도에 들어가고, 영원히 죽지 않는다', () => {
  const s = newRun(42);
  for (let i = 0; i < 20000 && !s.dead; i++) step(s, { hold: true });
  assert.equal(s.dead, false, `죽음: ${s.deathCause}`);
  assert.equal(s.mode, 'orbit');
});

test('놓으면 접선 + 초반 위쪽 어시스트 방향으로 날아간다', () => {
  const s = newRun(42);
  // 궤도에 들어갈 때까지 홀드
  let i = 0;
  while (s.mode !== 'orbit' && i++ < 2000) step(s, { hold: true });
  assert.equal(s.mode, 'orbit');
  const o = s.orbit;
  const tx = -Math.sin(o.theta) * o.dir;
  const ty = Math.cos(o.theta) * o.dir + assistAt(s.height);
  const len = Math.hypot(tx, ty);
  step(s, { hold: false });
  // 릴리즈 직후 방향 == 릴리즈 시점의 접선+어시스트 (한 스텝 안에서 theta가 더 돌지 않았는지)
  assert.ok(Math.hypot(s.dirX - tx / len, s.dirY - ty / len) < 1e-9);
  assert.equal(s.mode, 'flying');
  // 단위벡터
  assert.ok(Math.abs(Math.hypot(s.dirX, s.dirY) - 1) < 1e-9);
});

test('잡는 순간 회전 방향은 진행 방향을 잇는다 (접선·속도 내적 > 0)', () => {
  for (let seed = 1; seed <= 30; seed++) {
    const s = newRun(seed);
    let i = 0;
    while (s.mode !== 'orbit' && !s.dead && i++ < 4000) step(s, { hold: true });
    if (s.mode !== 'orbit') continue;
    const o = s.orbit;
    const tx = -Math.sin(o.theta) * o.dir, ty = Math.cos(o.theta) * o.dir;
    // 잡기 직전 방향은 dirX/dirY에 남아 있다
    assert.ok(tx * s.dirX + ty * s.dirY > -1e-6, `seed ${seed}: 회전이 진행을 거스른다`);
  }
});

test('벽에 닿으면 죽는다', () => {
  const s = newRun(7);
  s.dirX = 1; s.dirY = 0; // 오른쪽 벽으로 직진
  for (let i = 0; i < 2000 && !s.dead; i++) step(s, { hold: false });
  assert.equal(s.dead, true);
  assert.equal(s.deathCause, 'wall');
});

test('최고점에서 fallLimit 이상 떨어지면 죽는다', () => {
  const s = newRun(7);
  for (let i = 0; i < 240; i++) step(s, { hold: false }); // 위로 좀 올라간 뒤
  s.dirX = 0; s.dirY = -1; // 수직 낙하
  for (let i = 0; i < 6000 && !s.dead; i++) step(s, { hold: false });
  assert.equal(s.dead, true);
  assert.equal(s.deathCause, 'fell');
});

test('점수 = 높이/4 + 니어미스×25', () => {
  const s = newRun(9);
  s.height = 400;
  s.sparks = 3;
  assert.equal(score(s), 100 + 75);
});

test('makeRng는 [0,1) 범위의 결정적 수열을 낸다', () => {
  const a = makeRng(5), b = makeRng(5);
  for (let i = 0; i < 100; i++) {
    const va = a(), vb = b();
    assert.equal(va, vb);
    assert.ok(va >= 0 && va < 1);
  }
});
