import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateLevel, applyMove, isWin, SHAKE_RULES } from '../../sort-engine/index.js';
import { LEVELS, CAPACITY } from '../levels.js';
import { LEVEL_DATA, CAPACITY as BAKED_CAPACITY } from '../levels-data.js';

test('구운 레벨 데이터: 해를 재생하면 전부 클리어된다', () => {
  assert.equal(LEVEL_DATA.length, LEVELS.length);
  assert.equal(BAKED_CAPACITY, CAPACITY);
  LEVEL_DATA.forEach((lv, i) => {
    let st = { capacity: BAKED_CAPACITY, bottles: lv.bottles.map((b) => b.slice()) };
    assert.equal(isWin(st, lv.targets), false, `레벨 ${i + 1}이 시작부터 클리어 상태`);
    for (const mv of lv.solution) {
      const r = applyMove(st, mv, SHAKE_RULES);
      assert.ok(r, `레벨 ${i + 1} 해 재생 중 불가능한 수: ${JSON.stringify(mv)}`);
      st = r.state;
    }
    assert.equal(isWin(st, lv.targets), true, `레벨 ${i + 1} 해 재생해도 미클리어`);
    assert.equal(lv.solution.length, lv.solutionLength);
  });
});

test('2차색 목표는 반드시 흔들기를 거쳐야 한다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const secondaries = lv.targets.filter((t) => !'RYB'.includes(t)).length;
    const shakes = lv.solution.filter((m) => m.type === 'shake').length;
    assert.equal(shakes, secondaries, `레벨 ${i + 1}: 2차색 ${secondaries}개인데 흔들기 ${shakes}번`);
  });
});

test('난이도가 대체로 오르막이다 (큰 역전이 없다)', () => {
  const lens = LEVEL_DATA.map((lv) => lv.solutionLength);
  // 레벨 6은 1차색 목표를 소개하는 쉬어가는 구간이라 예외로 둔다
  lens.forEach((len, i) => {
    if (i === 0 || i === 5) return;
    const earlier = Math.max(...lens.slice(0, i).filter((_, k) => k !== 5));
    assert.ok(
      len >= earlier - 2,
      `레벨 ${i + 1}(${len}수)이 앞 레벨 최고치(${earlier}수)보다 크게 쉬움`
    );
  });
});

test('구운 데이터가 levels.js 스펙과 동기화되어 있다 (bake 잊음 방지)', () => {
  LEVELS.forEach((def, i) => {
    const fresh = generateLevel({ ...def, capacity: CAPACITY, rules: SHAKE_RULES, solverNodes: 600000 });
    assert.deepEqual(
      LEVEL_DATA[i].bottles,
      fresh.bottles,
      `레벨 ${i + 1}: levels.js 수정 후 bake-levels.mjs를 다시 실행하세요`
    );
    assert.deepEqual(LEVEL_DATA[i].targets, fresh.targets);
  });
});
