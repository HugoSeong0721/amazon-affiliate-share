// 엔진 계약 테스트 — node --test comet-sling/tests/engine.test.mjs
//
// 세 가지를 지킨다:
//  1) 결정론: 같은 시드 + 같은 입력 = 같은 런
//  2) 플레이 가능성 불변식: 궤도는 절대 소행성에 닿지 않고, 앵커 간 직선은 항상 열려 있다
//  3) 난이도 곡선의 단조성

import test from 'node:test';
import assert from 'node:assert/strict';
import { DT, WORLD, newRun, step, score, paramsAt, assistAt, aim, orbitOmega, ensureTrack, makeRng } from '../engine.js';

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

test('스캔 창(window) 전제 검증: 앵커는 정렬, 소행성 뒤섞임은 200 미만', () => {
  // step()은 정렬을 전제로 루프를 조기 종료한다. 그 전제가 깨지면 충돌을 놓친다.
  for (let seed = 1; seed <= 120; seed++) {
    const s = newRun(seed);
    ensureTrack(s, 6000);
    for (let i = 1; i < s.anchors.length; i++) {
      assert.ok(s.anchors[i].y > s.anchors[i - 1].y, `seed ${seed}: 앵커 정렬이 깨졌다`);
    }
    let maxBack = 0;
    for (let i = 1; i < s.hazards.length; i++) {
      maxBack = Math.max(maxBack, s.hazards[i - 1].y - s.hazards[i].y);
    }
    assert.ok(maxBack < 200, `seed ${seed}: 소행성 뒤섞임 ${maxBack.toFixed(1)} — break 문턱을 넘었다`);
  }
});

test('스캔 창이 전진해도 런 결과는 같다 (창 없는 전수 스캔과 동일)', () => {
  // 창 전진이 충돌/니어미스를 놓치지 않는지: 창을 강제로 0에 묶은 런과 비교한다
  const script = (i) => (i % 400) < 220;
  const run = (pin) => {
    const s = newRun(4242);
    for (let i = 0; i < 8000 && !s.dead; i++) {
      if (pin) { s.anchorFrom = 0; s.hazardFrom = 0; }
      step(s, { hold: script(i) });
    }
    return { y: s.y, height: s.height, sparks: s.sparks, dead: s.dead, cause: s.deathCause };
  };
  assert.deepEqual(run(false), run(true));
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

test('궤도 회전: 작은 원이 빠르되 얌전하게 — 차이는 1.3~1.7배, 시작 속도에서 한 바퀴 3~5.5초', () => {
  const speed = paramsAt(0).speed;
  const wSmall = orbitOmega(speed, WORLD.orbitMin);
  const wBig = orbitOmega(speed, WORLD.orbitMax);
  assert.ok(wSmall > wBig, '작은 원이 더 빨라야 한다');
  const ratio = wSmall / wBig;
  assert.ok(ratio >= 1.3 && ratio <= 1.7, `비율 ${ratio.toFixed(2)}가 범위를 벗어났다`);
  for (const r of [WORLD.orbitMin, WORLD.orbitMax]) {
    const period = (2 * Math.PI) / orbitOmega(speed, r);
    assert.ok(period >= 3 && period <= 5.5, `r=${r} 한 바퀴 ${period.toFixed(1)}s`);
  }
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

test('놓으면 조준선(aim)이 보여준 그대로 날아간다', () => {
  const s = newRun(42);
  // 궤도에 들어갈 때까지 홀드
  let i = 0;
  while (s.mode !== 'orbit' && i++ < 2000) step(s, { hold: true });
  assert.equal(s.mode, 'orbit');
  const a = aim(s);
  step(s, { hold: false });
  // 릴리즈 직후 방향 == 릴리즈 시점의 aim (한 스텝 안에서 theta가 더 돌지 않았는지)
  assert.ok(Math.hypot(s.dirX - a.dx, s.dirY - a.dy) < 1e-9);
  assert.equal(s.mode, 'flying');
  // 단위벡터
  assert.ok(Math.abs(Math.hypot(s.dirX, s.dirY) - 1) < 1e-9);
});

test('자석 조준: 얼추 맞으면 앵커로 스냅, 많이 어긋나면 그대로', () => {
  // 높이 5000 → 어시스트 0, 접선이 정확히 위(+y)를 향하는 궤도 상태를 만든다
  const base = {
    x: 0, y: 5000, height: 5000, dirX: 0, dirY: 1,
    hazards: [], hazardFrom: 0, anchorFrom: 0,
    orbit: { i: 0, r: 20, theta: 0, dir: 1 }, // rel=(r,0), dir=+1 → 접선 (0,1)
  };

  // 접선에서 10° 어긋난 위치의 앵커 → 스냅되어 정확히 앵커를 향한다
  const off10 = { x: 100 * Math.sin(10 * Math.PI / 180), y: 5000 + 100 * Math.cos(10 * Math.PI / 180) };
  let a = aim({ ...base, anchors: [{ x: -20, y: 5000 }, off10] });
  assert.equal(a.snapped, 1);
  const d = Math.hypot(off10.x - base.x, off10.y - base.y);
  assert.ok(Math.hypot(a.dx - (off10.x - base.x) / d, a.dy - (off10.y - base.y) / d) < 1e-9);

  // 40° 어긋난 앵커 → 스냅 없음, 순수 접선(0,1)
  const off40 = { x: 100 * Math.sin(40 * Math.PI / 180), y: 5000 + 100 * Math.cos(40 * Math.PI / 180) };
  a = aim({ ...base, anchors: [{ x: -20, y: 5000 }, off40] });
  assert.equal(a.snapped, null);
  assert.ok(Math.hypot(a.dx - 0, a.dy - 1) < 1e-9);

  // 지금 돌고 있는 앵커(i=0)에는 절대 스냅하지 않는다
  a = aim({ ...base, anchors: [{ x: 0, y: 5100 }] , orbit: { ...base.orbit, i: 0 } });
  assert.equal(a.snapped, null);

  // 소행성이 길을 막고 있으면 스냅하지 않는다 (금색 조준선은 안전을 약속한다)
  const blocked = { ...base, anchors: [{ x: -20, y: 5000 }, off10],
    hazards: [{ x: off10.x / 2, y: 5000 + 50 }] };
  assert.equal(aim(blocked).snapped, null);
});

test('스냅된 조준선은 소행성이 없는 길만 가리킨다 (시드 60개 자동 플레이)', () => {
  // 봇이 스냅될 때마다 그 직선이 실제로 비어 있는지 검사한다
  const clear = WORLD.hazardR + WORLD.cometR + 1;
  for (let seed = 1; seed <= 60; seed++) {
    const s = newRun(seed);
    for (let i = 0; i < 20000 && !s.dead; i++) {
      let hold = true;
      if (s.mode === 'orbit') {
        const a = aim(s);
        if (a.snapped !== null) {
          const t = s.anchors[a.snapped];
          for (const hz of s.hazards) {
            assert.ok(
              distToSegment(hz.x, hz.y, s.x, s.y, t.x, t.y) >= clear,
              `seed ${seed}: 스냅 경로가 소행성에 막혀 있다`
            );
          }
          if (a.dy > 0.4) hold = false;
        }
      }
      step(s, { hold });
    }
  }
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
