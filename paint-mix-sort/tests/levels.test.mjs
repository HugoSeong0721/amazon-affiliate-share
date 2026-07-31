import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateLevel, pour, isWin, MIX_RULES } from '../../sort-engine/index.js';
import { LEVELS, CAPACITY } from '../levels.js';
import { LEVEL_DATA, CAPACITY as BAKED_CAPACITY } from '../levels-data.js';

test('구운 레벨 데이터: 해를 재생하면 전부 클리어된다', () => {
  assert.equal(LEVEL_DATA.length, LEVELS.length);
  assert.equal(BAKED_CAPACITY, CAPACITY);
  LEVEL_DATA.forEach((lv, i) => {
    let st = { capacity: BAKED_CAPACITY, bottles: lv.bottles.map((b) => b.slice()) };
    assert.equal(isWin(st, lv.targets), false, `레벨 ${i + 1}이 시작부터 클리어 상태`);
    for (const mv of lv.solution) {
      const r = pour(st, mv.from, mv.to, MIX_RULES);
      assert.ok(r, `레벨 ${i + 1} 해 재생 중 불가능한 수`);
      st = r.state;
    }
    assert.equal(isWin(st, lv.targets), true, `레벨 ${i + 1} 해 재생해도 미클리어`);
    assert.equal(lv.solution.length, lv.solutionLength);
  });
});

test('구운 데이터가 levels.js 스펙과 동기화되어 있다 (bake 잊음 방지)', () => {
  LEVELS.forEach((def, i) => {
    const fresh = generateLevel({ ...def, capacity: CAPACITY, rules: MIX_RULES, solverNodes: 600000 });
    assert.deepEqual(
      LEVEL_DATA[i].bottles,
      fresh.bottles,
      `레벨 ${i + 1}: levels.js 수정 후 bake-levels.mjs를 다시 실행하세요`
    );
    assert.deepEqual(LEVEL_DATA[i].targets, fresh.targets);
  });
});
