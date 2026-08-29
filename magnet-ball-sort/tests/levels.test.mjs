import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pour, isWin, topRun, isLocked, CLASSIC_RULES } from '../../sort-engine/index.js';
import { LEVEL_SPECS, PALETTE } from '../levels.js';
import { LEVEL_DATA } from '../levels-data.js';

// 게임이 하는 것과 같은 방식으로 압축 데이터를 푼다
const decodeTubes = (tubes) => tubes.map((s) => s.split(''));
const decodeSolution = (sol) => {
  const moves = [];
  for (let i = 0; i + 1 < sol.length; i += 2) {
    moves.push({ from: Number(sol[i]), to: Number(sol[i + 1]) });
  }
  return moves;
};
const colorsOf = (tubes) => [...new Set(tubes.join(''))];
const stateOf = (lv) => ({ capacity: lv.cap, bottles: decodeTubes(lv.tubes) });

test('레벨이 100개 이상이고, 스펙 수를 넘지 않는다', () => {
  assert.ok(LEVEL_DATA.length >= 100, `레벨이 ${LEVEL_DATA.length}개뿐`);
  assert.ok(
    LEVEL_DATA.length <= LEVEL_SPECS.length,
    `구운 레벨(${LEVEL_DATA.length})이 스펙(${LEVEL_SPECS.length})보다 많다`
  );
});

test('모든 레벨의 참고 해가 실제로 클리어로 이어진다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const targets = colorsOf(lv.tubes);
    let st = stateOf(lv);
    assert.equal(isWin(st, targets), false, `레벨 ${i + 1}이 시작부터 클리어 상태`);
    for (const mv of decodeSolution(lv.sol)) {
      const r = pour(st, mv.from, mv.to, CLASSIC_RULES);
      assert.ok(r, `레벨 ${i + 1} 해 재생 중 불가능한 수: ${JSON.stringify(mv)}`);
      st = r.state;
    }
    assert.equal(isWin(st, targets), true, `레벨 ${i + 1} 해 재생해도 미클리어`);
  });
});

test('par가 참고 해 길이와 일치한다 (별점 기준이 어긋나면 안 된다)', () => {
  LEVEL_DATA.forEach((lv, i) => {
    assert.equal(decodeSolution(lv.sol).length, lv.par, `레벨 ${i + 1}의 par 불일치`);
  });
});

test('클래식 규칙이므로 구슬 구성은 절대 변하지 않는다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const before = lv.tubes.join('').split('').sort().join('');
    let st = stateOf(lv);
    for (const mv of decodeSolution(lv.sol)) st = pour(st, mv.from, mv.to, CLASSIC_RULES).state;
    const after = st.bottles.flat().sort().join('');
    assert.equal(after, before, `레벨 ${i + 1}에서 구슬 구성이 바뀜`);
  });
});

test('각 색은 정확히 용량만큼 있고, 팔레트 안의 색만 쓴다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const counts = new Map();
    for (const c of lv.tubes.join('')) counts.set(c, (counts.get(c) || 0) + 1);
    assert.ok(counts.size >= 2, `레벨 ${i + 1}의 색이 ${counts.size}가지`);
    for (const [c, n] of counts) {
      assert.ok(PALETTE.includes(c), `레벨 ${i + 1}에 팔레트 밖의 색 ${c}`);
      assert.equal(n, lv.cap, `레벨 ${i + 1}의 ${c} 개수가 ${n} (용량 ${lv.cap})`);
    }
  });
});

test('해 인코딩이 한 자리 숫자로 안전하다 (튜브 10개 이하)', () => {
  LEVEL_DATA.forEach((lv, i) => {
    assert.ok(lv.tubes.length <= 10, `레벨 ${i + 1}의 튜브가 ${lv.tubes.length}개`);
    for (const mv of decodeSolution(lv.sol)) {
      assert.ok(
        Number.isInteger(mv.from) && mv.from >= 0 && mv.from < lv.tubes.length,
        `레벨 ${i + 1} 해의 출발 인덱스가 범위 밖: ${mv.from}`
      );
      assert.ok(
        Number.isInteger(mv.to) && mv.to >= 0 && mv.to < lv.tubes.length,
        `레벨 ${i + 1} 해의 도착 인덱스가 범위 밖: ${mv.to}`
      );
    }
  });
});

test('난이도가 단조 증가한다', () => {
  const pars = LEVEL_DATA.map((lv) => lv.par);
  pars.forEach((p, i) => {
    if (i === 0) return;
    assert.ok(p >= pars[i - 1], `레벨 ${i + 1}(${p}수)이 앞 레벨(${pars[i - 1]}수)보다 쉬움`);
  });
  assert.ok(pars[0] <= 5, `첫 레벨이 ${pars[0]}수 — 튜토리얼로 너무 어렵다`);
  assert.ok(pars.at(-1) >= 25, `마지막 레벨이 ${pars.at(-1)}수 — 마무리가 너무 싱겁다`);
});

test('첫 레벨은 손가락 안내로 끝까지 따라갈 수 있다', () => {
  // 안내는 참고 해를 그대로 짚어주므로, 매 수가 그 시점에 실행 가능해야 한다
  const lv = LEVEL_DATA[0];
  let st = stateOf(lv);
  for (const mv of decodeSolution(lv.sol)) {
    const run = topRun(st.bottles[mv.from]);
    assert.ok(run, '빈 튜브를 집으라고 안내함');
    assert.equal(isLocked(st, mv.from, CLASSIC_RULES), false, '잠긴 튜브를 집으라고 안내함');
    st = pour(st, mv.from, mv.to, CLASSIC_RULES).state;
  }
  assert.equal(isWin(st, colorsOf(lv.tubes)), true);
});
