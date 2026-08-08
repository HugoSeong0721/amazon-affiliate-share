// 엔진 계약 테스트 — node --test torch-dive/tests/engine.test.mjs
//
// 세 가지를 지킨다:
//  1) 결정론: 같은 (daySeed, runIndex) + 같은 행동 순서 = 같은 다이브
//  2) 공정함 불변식: 1층 무해골 · 모든 층에 안전한 문 ≥ 1 · 표시된 구성 = 실제 내용물
//  3) 곡선의 단조성: 깊을수록 보상도 위험 한계도 줄어들지 않는다

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CONFIG,
  makeRng,
  hashSeed,
  valueAt,
  skullBoundsAt,
  makeFloor,
  newDive,
  openDoor,
  peekDoor,
  bankOut,
} from '../engine.js';

// 안전한 문(해골 아님)의 인덱스 — 테스트는 내용물을 훔쳐본다
function safeIndex(s) {
  return s.floor.doors.findIndex((d) => d !== 'skull');
}

test('같은 (daySeed, runIndex) + 같은 행동 = 같은 다이브 (결정론)', () => {
  const play = () => {
    const s = newDive(hashSeed('2026-08-06'), 1);
    const trace = [];
    for (let step = 0; step < 12 && !s.over; step++) {
      if (step === 3) peekDoor(s, 2);
      const i = (step * 7 + 1) % CONFIG.doorsPerFloor;
      const res = openDoor(s, i);
      trace.push(`${res.type}:${res.gain}`);
    }
    return { trace: trace.join(','), carried: s.carried, floorNum: s.floorNum, over: s.over, lanterns: s.lanterns };
  };
  assert.deepEqual(play(), play());
});

test('runIndex가 다르면 배치도 다르다 — 하루 3다이브는 서로 다른 던전', () => {
  const day = hashSeed('2026-08-06');
  const layout = (runIndex) => {
    const s = newDive(day, runIndex);
    const rows = [];
    for (let f = 0; f < 6 && !s.over; f++) {
      rows.push(s.floor.doors.join(','));
      openDoor(s, safeIndex(s));
    }
    return rows.join('|');
  };
  assert.notEqual(layout(0), layout(1));
  assert.notEqual(layout(1), layout(2));
});

test('날짜 문자열이 다르면 시드도 다르다 (hashSeed)', () => {
  assert.equal(hashSeed('2026-08-06'), hashSeed('2026-08-06'));
  assert.notEqual(hashSeed('2026-08-06'), hashSeed('2026-08-07'));
});

test('공정함 불변식 — 시드 300개 × 깊이 25층', () => {
  for (let seed = 1; seed <= 300; seed++) {
    const s = newDive(seed, 0);
    for (let f = 1; f <= 25; f++) {
      const { n, doors, comp } = s.floor;
      assert.equal(n, f);
      assert.equal(doors.length, CONFIG.doorsPerFloor);

      // 표시되는 구성 = 실제 내용물 (정직함)
      const actual = { coin: 0, gem: 0, lantern: 0, skull: 0 };
      for (const d of doors) actual[d] += 1;
      assert.deepEqual(comp, actual, `seed ${seed} floor ${f}`);

      // 해골 수는 공표된 한계 안 — 1층은 0개, 어떤 층에도 안전한 문이 있다
      const { min, max } = skullBoundsAt(f);
      assert.ok(comp.skull >= min && comp.skull <= max, `seed ${seed} floor ${f}: ${comp.skull}`);
      assert.ok(comp.skull < CONFIG.doorsPerFloor);
      if (f === 1) assert.equal(comp.skull, 0);

      openDoor(s, safeIndex(s)); // 안전한 문으로 계속 내려간다
      assert.ok(!s.over);
    }
  }
});

test('곡선의 단조성 — 보상과 해골 한계는 깊이에 대해 줄지 않는다', () => {
  for (let f = 1; f <= 40; f++) {
    const a = valueAt(f);
    const b = valueAt(f + 1);
    assert.ok(b.coin > a.coin && b.gem > a.gem);
    assert.ok(a.gem > a.coin);
    const sa = skullBoundsAt(f);
    const sb = skullBoundsAt(f + 1);
    assert.ok(sb.min >= sa.min && sb.max >= sa.max);
    assert.ok(sa.min <= sa.max);
    assert.ok(sa.max <= CONFIG.doorsPerFloor - 1);
  }
});

test('문 열기 — 동전·보석은 그 층의 공표 가치만큼 벌고 한 층 내려간다', () => {
  for (let seed = 1; seed <= 120; seed++) {
    const s = newDive(seed, 0);
    let carried = 0;
    for (let f = 1; f <= 10; f++) {
      const before = s.floorNum;
      const res = openDoor(s, safeIndex(s));
      const v = valueAt(before);
      if (res.type === 'coin') carried += v.coin;
      if (res.type === 'gem') carried += v.gem;
      assert.equal(res.gain, res.type === 'coin' ? v.coin : res.type === 'gem' ? v.gem : 0);
      assert.equal(s.carried, carried);
      assert.equal(s.floorNum, before + 1);
    }
  }
});

test('해골 — 들고 있던 것을 전부 잃고 다이브가 끝난다', () => {
  // 2층은 항상 해골이 정확히 1개다 — 그 문을 일부러 연다
  const s = newDive(7, 0);
  openDoor(s, safeIndex(s));
  const carriedBefore = s.carried;
  const skullAt = s.floor.doors.indexOf('skull');
  assert.ok(skullAt >= 0);
  const res = openDoor(s, skullAt);
  assert.equal(res.type, 'skull');
  assert.ok(s.busted && s.over);
  assert.equal(s.carried, 0);
  assert.equal(s.lost, carriedBefore);
  assert.equal(openDoor(s, 0), null); // 끝난 다이브에는 아무 것도 못 한다
  assert.equal(bankOut(s), 0);
});

test('해골 스냅샷은 층 전체를 까 보여준다 (연출 계약)', () => {
  const s = newDive(7, 0);
  openDoor(s, safeIndex(s));
  const doors = s.floor.doors.slice();
  const res = openDoor(s, doors.indexOf('skull'));
  assert.deepEqual(res.doors, doors);
});

test('등불 엿보기 — 실제 내용물을 알려주고, 등불 하나를 쓰고, 같은 문은 두 번 못 본다', () => {
  const s = newDive(11, 0);
  openDoor(s, safeIndex(s)); // 2층으로 — 등불 쓸 이유가 생기는 곳
  assert.equal(s.lanterns, CONFIG.lanternStart);
  const t = peekDoor(s, 1);
  assert.equal(t, s.floor.doors[1]);
  assert.equal(s.lanterns, CONFIG.lanternStart - 1);
  assert.equal(peekDoor(s, 1), null); // 같은 문 재탕 금지
  assert.equal(peekDoor(s, 2), null); // 등불이 없다
});

test('엿본 문 목록은 층을 내려가면 비워진다', () => {
  const s = newDive(11, 0);
  openDoor(s, safeIndex(s));
  peekDoor(s, 0);
  assert.deepEqual(s.peeked, [0]);
  openDoor(s, safeIndex(s));
  assert.deepEqual(s.peeked, []);
});

test('등불은 상한을 넘지 않는다', () => {
  for (let seed = 1; seed <= 400; seed++) {
    const s = newDive(seed, 0);
    for (let f = 1; f <= 15 && !s.over; f++) {
      const i = s.floor.doors.indexOf('lantern');
      openDoor(s, i >= 0 ? i : safeIndex(s)); // 등불이 보이면 무조건 줍는다
      assert.ok(s.lanterns <= CONFIG.maxLanterns, `seed ${seed}: ${s.lanterns}`);
    }
  }
});

test('챙겨 나가기 — 들고 있던 만큼 banked, 빈손으로는 못 나간다', () => {
  const s = newDive(3, 0);
  assert.equal(bankOut(s), 0); // 1층, 아직 빈손
  openDoor(s, safeIndex(s));
  openDoor(s, safeIndex(s));
  const carried = s.carried;
  if (carried > 0) {
    assert.equal(bankOut(s), carried);
    assert.equal(s.banked, carried);
    assert.ok(s.over && !s.busted);
    assert.equal(openDoor(s, 0), null);
  }
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

test('makeFloor는 호출 시점과 무관하게 RNG 스트림 순서만 따른다', () => {
  const floors = (chunked) => {
    const rng = makeRng(99);
    const out = [];
    for (let n = 1; n <= 12; n++) out.push(makeFloor(rng, n).doors.join(','));
    return out.join(chunked ? '|' : '|');
  };
  assert.equal(floors(false), floors(true));
});
