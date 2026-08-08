// 엔진 계약 테스트 — node --test sky-stack/tests/engine.test.mjs
//
// 세 가지를 지킨다:
//  1) 결정론: 같은 시드 + 같은 스텝에서의 드롭 = 같은 탑
//  2) 자르기 수학: 겹침·퍼펙트·미스 판정이 정확하다
//  3) 곡선: 속도는 단조 증가하고 상한이 있으며, 폭은 절대 늘어나서 base를 넘지 않는다

import test from 'node:test';
import assert from 'node:assert/strict';
import { DT, CONFIG, makeRng, speedAt, newRun, step, drop, score } from '../engine.js';

// n스텝 전진 후 드롭하는 스크립트 플레이어
function play(seed, dropSteps) {
  const s = newRun(seed);
  const results = [];
  for (const n of dropSteps) {
    for (let i = 0; i < n && !s.over; i++) step(s);
    results.push(drop(s));
    if (s.over) break;
  }
  return { s, results };
}

test('같은 시드 + 같은 드롭 타이밍 = 같은 탑 (결정론)', () => {
  const script = [40, 55, 62, 48, 71, 33, 90, 44, 58, 66];
  const a = play(7, script);
  const b = play(7, script);
  assert.deepEqual(
    a.s.floors,
    b.s.floors
  );
  assert.equal(a.s.over, b.s.over);
  assert.deepEqual(a.results, b.results);
});

test('시드는 색상 시작점만 바꾼다 — 물리는 동일', () => {
  const a = play(1, [50, 50, 50]);
  const b = play(2, [50, 50, 50]);
  assert.deepEqual(a.s.floors, b.s.floors);
  assert.notEqual(newRun(1).hue0, newRun(2).hue0);
});

test('퍼펙트 — 오차가 perfectEps 안이면 폭이 깎이지 않고 콤보가 오른다', () => {
  const s = newRun(0);
  s.moving.x = CONFIG.perfectEps - 0.01; // 바닥 중심(0)에서 eps 안
  const res = drop(s);
  assert.equal(res.type, 'perfect');
  assert.equal(res.combo, 1);
  assert.equal(s.floors[1].w, CONFIG.baseW);
  assert.equal(s.floors[1].x, 0); // 퍼펙트는 정확히 아래 블록 위에 스냅
});

test('자르기 — 겹친 만큼만 남고, 잘린 조각의 폭과 위치가 맞다', () => {
  const s = newRun(0);
  s.moving.x = 30; // 오른쪽으로 30 밀린 드롭 (폭 100 → 겹침 70)
  const res = drop(s);
  assert.equal(res.type, 'cut');
  const top = s.floors[1];
  assert.ok(Math.abs(top.w - 70) < 1e-9);
  assert.ok(Math.abs(top.x - 15) < 1e-9); // 겹침 구간 [-20,50]의 중심
  assert.ok(Math.abs(res.cut.w - 30) < 1e-9);
  assert.equal(res.cut.side, 1);
  assert.ok(Math.abs(res.cut.x - 65) < 1e-9); // 잘린 조각 [50,80]의 중심
});

test('왼쪽 오버행도 대칭으로 잘린다', () => {
  const s = newRun(0);
  s.moving.x = -30;
  const res = drop(s);
  assert.equal(res.type, 'cut');
  assert.ok(Math.abs(s.floors[1].x - -15) < 1e-9);
  assert.equal(res.cut.side, -1);
  assert.ok(Math.abs(res.cut.x - -65) < 1e-9);
});

test('미스 — 겹침이 없으면 게임 오버, 그 뒤 드롭은 무시된다', () => {
  const s = newRun(0);
  s.moving.x = CONFIG.baseW + 1; // 완전히 빗나감
  const res = drop(s);
  assert.equal(res.type, 'miss');
  assert.ok(s.over);
  assert.equal(drop(s), null);
  const before = s.moving.x;
  step(s);
  assert.equal(s.moving.x, before); // 죽은 뒤에는 움직이지도 않는다
});

test('연속 퍼펙트 regrowEvery번마다 폭이 회복되고, baseW를 넘지 않는다', () => {
  const s = newRun(0);
  s.moving.x = 20; // 먼저 폭을 80으로 깎는다
  drop(s);
  for (let i = 1; i <= CONFIG.regrowEvery * 2; i++) {
    s.moving.x = s.floors[s.floors.length - 1].x; // 정확히 위에 — 퍼펙트
    drop(s);
    const w = s.floors[s.floors.length - 1].w;
    if (i === CONFIG.regrowEvery) assert.ok(Math.abs(w - (80 + CONFIG.regrowAmount)) < 1e-9);
    assert.ok(w <= CONFIG.baseW + 1e-9);
  }
});

test('폭은 어떤 플레이에서도 단조 감소(퍼펙트 회복 제외)하고 음수가 되지 않는다', () => {
  for (let seed = 1; seed <= 50; seed++) {
    const s = newRun(seed);
    let prevW = CONFIG.baseW;
    for (let f = 0; f < 30 && !s.over; f++) {
      for (let i = 0; i < 30 + ((seed * 13 + f * 7) % 60); i++) step(s);
      const res = drop(s);
      if (!res || res.type === 'miss') break;
      const w = s.floors[s.floors.length - 1].w;
      assert.ok(w > 0);
      if (res.type === 'cut') assert.ok(w <= prevW + 1e-9);
      prevW = w;
    }
  }
});

test('속도 곡선 — 단조 증가, 상한 고정', () => {
  for (let f = 0; f < 200; f++) {
    assert.ok(speedAt(f + 1) >= speedAt(f));
    assert.ok(speedAt(f) <= CONFIG.speedMax);
  }
  assert.equal(speedAt(1000), CONFIG.speedMax);
});

test('움직이는 블록은 왕복 범위를 벗어나지 않고 방향을 튕긴다', () => {
  const s = newRun(3);
  let flips = 0;
  let prevDir = s.moving.dir;
  for (let i = 0; i < 20000; i++) {
    step(s);
    assert.ok(s.moving.x >= -CONFIG.travel - 1e-9 && s.moving.x <= CONFIG.travel + 1e-9);
    if (s.moving.dir !== prevDir) flips += 1;
    prevDir = s.moving.dir;
  }
  assert.ok(flips >= 2); // 실제로 왕복하고 있다
});

test('블록은 층마다 반대편에서 나온다', () => {
  const s = newRun(0);
  const sides = [];
  for (let f = 0; f < 4; f++) {
    s.moving.x = s.floors[s.floors.length - 1].x; // 퍼펙트로 계속
    drop(s);
    sides.push(s.moving.dir);
  }
  assert.deepEqual(sides, [1, -1, 1, -1]);
});

test('score = 쌓은 블록 수 (바닥 제외)', () => {
  const s = newRun(0);
  assert.equal(score(s), 0);
  s.moving.x = 0;
  drop(s);
  assert.equal(score(s), 1);
});

test('makeRng는 [0,1) 범위의 결정적 스트림이다', () => {
  const a = makeRng(42);
  const b = makeRng(42);
  for (let i = 0; i < 1000; i++) {
    const x = a();
    assert.equal(x, b());
    assert.ok(x >= 0 && x < 1);
  }
});
