import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateLevel, pour, isWin, topRun, CLASSIC_RULES } from '../../sort-engine/index.js';
import { LEVELS, PALETTE } from '../levels.js';
import { LEVEL_DATA } from '../levels-data.js';

const stateOf = (lv) => ({ capacity: lv.capacity, bottles: lv.tubes.map((t) => t.slice()) });

test('구운 레벨 데이터: 해를 재생하면 전부 클리어된다', () => {
  assert.equal(LEVEL_DATA.length, LEVELS.length);
  LEVEL_DATA.forEach((lv, i) => {
    let st = stateOf(lv);
    assert.equal(isWin(st, lv.targets), false, `레벨 ${i + 1}이 시작부터 클리어 상태`);
    for (const mv of lv.solution) {
      const r = pour(st, mv.from, mv.to, CLASSIC_RULES);
      assert.ok(r, `레벨 ${i + 1} 해 재생 중 불가능한 수: ${JSON.stringify(mv)}`);
      st = r.state;
    }
    assert.equal(isWin(st, lv.targets), true, `레벨 ${i + 1} 해 재생해도 미클리어`);
    assert.equal(lv.solution.length, lv.solutionLength);
  });
});

test('클래식 규칙이므로 색은 절대 변하지 않는다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const before = lv.tubes.flat().sort().join('');
    let st = stateOf(lv);
    for (const mv of lv.solution) st = pour(st, mv.from, mv.to, CLASSIC_RULES).state;
    const after = st.bottles.flat().sort().join('');
    assert.equal(after, before, `레벨 ${i + 1}에서 구슬 구성이 바뀜`);
  });
});

test('각 색은 정확히 용량만큼 있고, 팔레트 안의 색만 쓴다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const counts = new Map();
    for (const c of lv.tubes.flat()) counts.set(c, (counts.get(c) || 0) + 1);
    assert.equal(counts.size, lv.targets.length, `레벨 ${i + 1} 색 종류 수 불일치`);
    for (const [c, n] of counts) {
      assert.ok(PALETTE.includes(c), `레벨 ${i + 1}에 팔레트 밖의 색 ${c}`);
      assert.equal(n, lv.capacity, `레벨 ${i + 1}의 ${c} 개수가 ${n} (용량 ${lv.capacity})`);
    }
  });
});

test('난이도가 대체로 오르막이다 (큰 역전이 없다)', () => {
  const lens = LEVEL_DATA.map((lv) => lv.solutionLength);
  lens.forEach((len, i) => {
    if (i === 0) return;
    const best = Math.max(...lens.slice(0, i));
    assert.ok(len >= best - 2, `레벨 ${i + 1}(${len}수)이 앞 레벨 최고치(${best}수)보다 크게 쉬움`);
  });
  assert.equal(
    lens[lens.length - 1],
    Math.max(...lens),
    '마지막 레벨이 가장 어렵지 않다'
  );
});

test('자석으로 집히는 묶음은 항상 맨 위 같은 색 구간이다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    let st = stateOf(lv);
    for (const mv of lv.solution) {
      const src = st.bottles[mv.from];
      const run = topRun(src);
      // 집은 묶음은 전부 같은 색이고, 그 아래는 다른 색(또는 바닥)이어야 한다
      for (let k = 0; k < run.count; k++) {
        assert.equal(src[src.length - 1 - k], run.color, `레벨 ${i + 1} 묶음 색이 섞임`);
      }
      const below = src[src.length - 1 - run.count];
      assert.ok(below === undefined || below !== run.color, `레벨 ${i + 1} 묶음이 덜 잡힘`);
      st = pour(st, mv.from, mv.to, CLASSIC_RULES).state;
    }
  });
});

test('구운 데이터가 levels.js 스펙과 동기화되어 있다 (bake 잊음 방지)', () => {
  LEVELS.forEach((def, i) => {
    const fresh = generateLevel({ ...def, rules: CLASSIC_RULES, solverNodes: 800000 });
    assert.deepEqual(
      LEVEL_DATA[i].tubes,
      fresh.bottles,
      `레벨 ${i + 1}: levels.js 수정 후 bake-levels.mjs를 다시 실행하세요`
    );
    assert.equal(LEVEL_DATA[i].capacity, fresh.capacity);
  });
});
