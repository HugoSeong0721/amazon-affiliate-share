import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mixOf,
  componentsOf,
  isPrimary,
  canPour,
  pour,
  legalMoves,
  isWin,
  solve,
  generateLevel,
  MIX_RULES,
  CLASSIC_RULES,
} from '../index.js';

const S = (bottles, capacity = 4) => ({ capacity, bottles: bottles.map((b) => b.slice()) });

test('혼합 규칙: 1차색 쌍만 섞인다', () => {
  assert.equal(mixOf('R', 'Y'), 'O');
  assert.equal(mixOf('Y', 'R'), 'O');
  assert.equal(mixOf('Y', 'B'), 'G');
  assert.equal(mixOf('R', 'B'), 'P');
  assert.equal(mixOf('R', 'R'), 'R');
  assert.equal(mixOf('O', 'G'), null);
  assert.equal(mixOf('R', 'O'), null);
  assert.deepEqual(componentsOf('O').sort(), ['R', 'Y']);
  assert.deepEqual(componentsOf('G').sort(), ['B', 'Y']);
  assert.deepEqual(componentsOf('P').sort(), ['B', 'R']);
  assert.equal(componentsOf('R'), null);
  assert.ok(isPrimary('R') && !isPrimary('O'));
});

test('붓기: 같은 색 위로는 run 전체가 이동, 공간만큼만', () => {
  const res = pour(S([['R', 'R', 'Y'], ['Y']]), 0, 1, MIX_RULES);
  assert.deepEqual(res.state.bottles, [['R', 'R'], ['Y', 'Y']]);
  assert.equal(res.amount, 1);
  assert.equal(res.mixed, false);

  // run 3개 중 공간이 1칸이면 1개만 이동
  const partial = pour(S([['Y', 'Y', 'Y'], ['Y', 'Y', 'Y']]), 0, 1, MIX_RULES);
  assert.deepEqual(partial.state.bottles, [['Y', 'Y'], ['Y', 'Y', 'Y', 'Y']]);
  assert.equal(partial.amount, 1);
});

test('붓기: 빈 병으로는 run 전체 이동, 혼합 없음', () => {
  const res = pour(S([['R', 'Y', 'Y'], []]), 0, 1, MIX_RULES);
  assert.deepEqual(res.state.bottles, [['R'], ['Y', 'Y']]);
  assert.equal(res.mixed, false);
});

test('혼합: 부은 양 + 닿은 구간 전체가 2차색으로 변한다', () => {
  const res = pour(S([['R', 'R'], ['Y', 'Y']]), 0, 1, MIX_RULES);
  assert.deepEqual(res.state.bottles, [[], ['O', 'O', 'O', 'O']]);
  assert.equal(res.mixed, true);
  assert.equal(res.color, 'O');
  assert.equal(res.amount, 2);
  assert.equal(res.mixedRunBefore, 2);
});

test('혼합: 공간이 모자라면 남은 물감은 원래 병에 남는다', () => {
  const res = pour(S([['R', 'R', 'R'], ['Y', 'Y']]), 0, 1, MIX_RULES);
  assert.deepEqual(res.state.bottles, [['R'], ['O', 'O', 'O', 'O']]);
  assert.equal(res.amount, 2);
});

test('혼합: 닿은 구간만 변하고 그 아래는 그대로', () => {
  const res = pour(S([['R'], ['B', 'Y']]), 0, 1, MIX_RULES);
  assert.deepEqual(res.state.bottles, [[], ['B', 'O', 'O']]);
});

test('2차색끼리 / 2차색+1차색은 부을 수 없다', () => {
  assert.equal(canPour(S([['O'], ['G']]), 0, 1, MIX_RULES), false);
  assert.equal(canPour(S([['Y'], ['O']]), 0, 1, MIX_RULES), false);
  // 클래식 모드에서는 다른 색이면 무조건 불가
  assert.equal(canPour(S([['R'], ['Y']]), 0, 1, CLASSIC_RULES), false);
  assert.equal(canPour(S([['R'], ['Y']]), 0, 1, MIX_RULES), true);
});

test('승리 판정: 완성 색 목록이 목표와 정확히 일치해야 한다', () => {
  const win = S([['O', 'O', 'O', 'O'], ['G', 'G', 'G', 'G'], []]);
  assert.equal(isWin(win, ['O', 'G']), true);
  assert.equal(isWin(win, ['G', 'O']), true);
  assert.equal(isWin(win, ['O', 'P']), false);
  assert.equal(isWin(S([['O', 'O', 'O'], ['O']]), ['O']), false); // 가득 차지 않음
  assert.equal(isWin(S([['O', 'O', 'O', 'O'], ['O', 'O', 'O', 'O']]), ['O', 'G']), false); // 색 불일치
});

test('legalMoves: 완성된 2차색 병은 잠기고, 1차색 완성병은 깰 수 있다', () => {
  // 완성된 주황 병에서 나가는 수는 없어야 한다
  const locked = legalMoves(S([['O', 'O', 'O', 'O'], ['O', 'O'], []]), MIX_RULES);
  assert.equal(locked.some((m) => m.from === 0), false);
  // 완성된 빨강 병은 부분 이동(같은 색 위)으로 깰 수 있어야 한다
  const breakable = legalMoves(S([['R', 'R', 'R', 'R'], ['R', 'R'], []]), MIX_RULES);
  assert.equal(breakable.some((m) => m.from === 0 && m.to === 1), true);
  // 단색 병 → 빈 병은 무의미하므로 제외
  assert.equal(breakable.some((m) => m.from === 0 && m.to === 2), false);
});

test('솔버: 간단한 혼합 레벨을 풀고, 해를 재생하면 실제로 승리한다', () => {
  const start = S([['R', 'Y', 'R', 'Y'], [], []]);
  const res = solve(start, ['O'], MIX_RULES);
  assert.equal(res.solved, true);
  let st = start;
  for (const mv of res.moves) {
    const r = pour(st, mv.from, mv.to, MIX_RULES);
    assert.ok(r, '해에 포함된 수는 항상 실행 가능해야 한다');
    st = r.state;
  }
  assert.equal(isWin(st, ['O']), true);
});

test('솔버: 못 푸는 상태는 exhausted=true로 확정 판정', () => {
  // 빈 병도 없고 부을 곳도 없는 상태
  const res = solve(S([['R', 'R', 'R', 'Y']]), ['O'], MIX_RULES);
  assert.equal(res.solved, false);
  assert.equal(res.exhausted, true);

  // [RRRR],[YYYY] + 빈 병 2개: 어떤 수를 둬도 대칭 반복 → 풀 수 없음
  const res2 = solve(S([['R', 'R', 'R', 'R'], ['Y', 'Y', 'Y', 'Y'], [], []]), ['O', 'O'], MIX_RULES);
  assert.equal(res2.solved, false);
  assert.equal(res2.exhausted, true);
});

test('솔버: 클래식 모드(혼합 없음)도 동작한다', () => {
  const start = S([['R', 'Y', 'R', 'Y'], ['Y', 'R', 'Y', 'R'], [], []]);
  const res = solve(start, ['R', 'Y'], CLASSIC_RULES);
  assert.equal(res.solved, true);
  let st = start;
  for (const mv of res.moves) st = pour(st, mv.from, mv.to, CLASSIC_RULES).state;
  assert.equal(isWin(st, ['R', 'Y']), true);
});

test('생성기: 같은 시드는 같은 레벨, 결과는 항상 풀 수 있다', () => {
  const params = { seed: 42, targets: ['O', 'G', 'P'], extraEmpty: 2 };
  const a = generateLevel(params);
  const b = generateLevel(params);
  assert.deepEqual(a.bottles, b.bottles);
  assert.equal(a.solutionLength, b.solutionLength);

  for (const seed of [1, 2, 3, 7, 99, 1234]) {
    const lv = generateLevel({ seed, targets: ['O', 'G'], extraEmpty: 2 });
    let st = { capacity: lv.capacity, bottles: lv.bottles.map((x) => x.slice()) };
    for (const mv of lv.solution) st = pour(st, mv.from, mv.to, MIX_RULES).state;
    assert.equal(isWin(st, lv.targets), true, `seed=${seed} 해 재생 실패`);
  }
});

test('생성기: 물감 단위 보존 — 목표를 만들 수 있는 재료가 정확히 담긴다', () => {
  const lv = generateLevel({ seed: 5, targets: ['O', 'R'], extraEmpty: 2 });
  const all = lv.bottles.flat().sort().join('');
  // O = R k개 + Y (4-k)개, R 목표 = R 4개 → R은 5~7개, Y는 1~3개, 합 8
  assert.equal(all.length, 8);
  const rCount = [...all].filter((c) => c === 'R').length;
  const yCount = [...all].filter((c) => c === 'Y').length;
  assert.ok(rCount >= 5 && rCount <= 7);
  assert.equal(rCount + yCount, 8);
});
