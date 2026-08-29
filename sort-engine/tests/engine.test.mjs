import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mixOf,
  blendOf,
  componentsOf,
  isPrimary,
  canPour,
  pour,
  canShake,
  shake,
  shakePreview,
  applyMove,
  legalMoves,
  isLocked,
  isWin,
  solve,
  generateLevel,
  SHAKE_RULES,
  CLASSIC_RULES,
} from '../index.js';

const S = (bottles, capacity = 4) => ({ capacity, bottles: bottles.map((b) => b.slice()) });

test('혼합 규칙: 1차색 쌍만 섞인다', () => {
  assert.equal(mixOf('R', 'Y'), 'O');
  assert.equal(mixOf('Y', 'B'), 'G');
  assert.equal(mixOf('R', 'B'), 'P');
  assert.equal(mixOf('O', 'G'), null);
  assert.deepEqual(componentsOf('O').sort(), ['R', 'Y']);
  assert.equal(componentsOf('R'), null);
  assert.ok(isPrimary('R') && !isPrimary('O'));
});

test('blendOf: 정확히 반반일 때만 2차색이 나온다', () => {
  assert.equal(blendOf(['R', 'R', 'Y', 'Y']), 'O');
  assert.equal(blendOf(['Y', 'R', 'Y', 'R']), 'O', '순서는 상관없다');
  assert.equal(blendOf(['B', 'Y', 'Y', 'B']), 'G');
  assert.equal(blendOf(['R', 'R', 'R', 'R']), 'R', '단색은 그대로');
  assert.equal(blendOf(['R', 'R', 'R', 'Y']), null, '3:1은 안 된다');
  assert.equal(blendOf(['R', 'Y', 'B', 'B']), null, '3색은 안 된다');
  assert.equal(blendOf(['O', 'O', 'Y', 'Y']), null, '2차색이 섞이면 안 된다');
  assert.equal(blendOf([]), null);
});

test('붓기는 절대 섞지 않는다 — 다른 색 위에도 그냥 쌓인다', () => {
  const res = pour(S([['R', 'R'], ['Y', 'Y']]), 0, 1, SHAKE_RULES);
  assert.deepEqual(res.state.bottles, [[], ['Y', 'Y', 'R', 'R']]);
  assert.equal(res.color, 'R');
  assert.equal(res.amount, 2);
});

test('붓기: 맨 위 덩어리가 공간만큼만 옮겨간다 (양 조절의 핵심)', () => {
  // 빨강 3개 중 공간이 2칸뿐이면 2개만 간다 → 정확히 2개를 덜어내는 방법
  const res = pour(S([['R', 'R', 'R'], ['Y', 'Y']]), 0, 1, SHAKE_RULES);
  assert.deepEqual(res.state.bottles, [['R'], ['Y', 'Y', 'R', 'R']]);
  assert.equal(res.amount, 2);

  // 맨 위 덩어리만 움직인다. 아래 깔린 색은 안 나온다.
  const only = pour(S([['R', 'Y', 'Y'], []]), 0, 1, SHAKE_RULES);
  assert.deepEqual(only.state.bottles, [['R'], ['Y', 'Y']]);
});

test('붓기: 가득 찬 병에는 못 붓고, 빈 병에서는 못 붓는다', () => {
  assert.equal(canPour(S([['R'], ['Y', 'Y', 'Y', 'Y']]), 0, 1, SHAKE_RULES), false);
  assert.equal(canPour(S([[], ['Y']]), 0, 1, SHAKE_RULES), false);
  assert.equal(canPour(S([['R'], ['Y']]), 0, 0, SHAKE_RULES), false);
});

test('클래식 모드에서는 같은 색 위에만 부을 수 있다', () => {
  assert.equal(canPour(S([['R'], ['Y']]), 0, 1, CLASSIC_RULES), false);
  assert.equal(canPour(S([['R'], ['R']]), 0, 1, CLASSIC_RULES), true);
  assert.equal(canPour(S([['R'], []]), 0, 1, CLASSIC_RULES), true);
  // 자유 붓기 모드에서는 아무 위에나 가능
  assert.equal(canPour(S([['R'], ['Y']]), 0, 1, SHAKE_RULES), true);
});

test('흔들기: 가득 찬 반반 병만 섞이고, 결과는 순서와 무관하다', () => {
  const st = S([
    ['R', 'Y', 'R', 'Y'], // 반반 → 가능
    ['R', 'R', 'R', 'Y'], // 3:1 → 불가
    ['R', 'R', 'Y'], // 안 참 → 불가
    ['R', 'R', 'R', 'R'], // 이미 단색 → 불가
    ['O', 'O', 'Y', 'Y'], // 2차색 포함 → 불가
  ]);
  assert.equal(canShake(st, 0, SHAKE_RULES), true);
  assert.equal(canShake(st, 1, SHAKE_RULES), false);
  assert.equal(canShake(st, 2, SHAKE_RULES), false);
  assert.equal(canShake(st, 3, SHAKE_RULES), false);
  assert.equal(canShake(st, 4, SHAKE_RULES), false);
  assert.equal(shakePreview(st, 0, SHAKE_RULES), 'O');
  assert.equal(shakePreview(st, 1, SHAKE_RULES), null);

  const res = shake(st, 0, SHAKE_RULES);
  assert.deepEqual(res.state.bottles[0], ['O', 'O', 'O', 'O']);
  assert.equal(res.color, 'O');
  assert.deepEqual(res.from, ['R', 'Y', 'R', 'Y']);

  // 클래식 모드에는 흔들기가 없다
  assert.equal(canShake(st, 0, CLASSIC_RULES), false);
  assert.equal(shake(st, 0, CLASSIC_RULES), null);
});

test('isLocked: 흔들어 만든 2차색 병만 잠긴다', () => {
  const st = S([
    ['O', 'O', 'O', 'O'], // 완성된 2차색 → 잠김
    ['R', 'R', 'R', 'R'], // 1차색 가득 → 덜어내야 하므로 안 잠김
    ['O', 'O', 'O'], // 안 참
    ['R', 'Y', 'R', 'Y'], // 단색 아님
  ]);
  assert.equal(isLocked(st, 0, SHAKE_RULES), true);
  assert.equal(isLocked(st, 1, SHAKE_RULES), false);
  assert.equal(isLocked(st, 2, SHAKE_RULES), false);
  assert.equal(isLocked(st, 3, SHAKE_RULES), false);
  assert.equal(canPour(st, 0, 2, SHAKE_RULES), false, '완성된 병은 부을 수 없다');
  assert.equal(isLocked(st, 1, CLASSIC_RULES), true, '클래식에서는 단색 완성병도 잠긴다');
});

test('legalMoves: 흔들기가 포함되고, 잠긴 병과 무의미한 이동은 빠진다', () => {
  const moves = legalMoves(S([['R', 'Y', 'R', 'Y'], ['O', 'O', 'O', 'O'], ['R', 'R'], []]), SHAKE_RULES);
  assert.ok(moves.some((m) => m.type === 'shake' && m.at === 0), '흔들 수 있는 병이 빠짐');
  assert.equal(moves.some((m) => m.type === 'pour' && m.from === 1), false, '잠긴 병에서 나감');
  assert.equal(
    moves.some((m) => m.type === 'pour' && m.from === 2 && m.to === 3),
    false,
    '단색 병 → 빈 병 이동은 무의미'
  );
});

test('승리 판정: 완성 색 목록이 목표와 정확히 일치해야 한다', () => {
  const win = S([['O', 'O', 'O', 'O'], ['G', 'G', 'G', 'G'], []]);
  assert.equal(isWin(win, ['O', 'G']), true);
  assert.equal(isWin(win, ['G', 'O']), true);
  assert.equal(isWin(win, ['O', 'P']), false);
  assert.equal(isWin(S([['R', 'R', 'Y', 'Y']]), ['O']), false, '흔들기 전엔 클리어가 아니다');
});

test('솔버: 붓고 흔들어 목표를 만들고, 해를 재생하면 실제로 승리한다', () => {
  const start = S([['R', 'Y', 'Y', 'Y'], ['R', 'R', 'R', 'Y'], [], []]);
  const res = solve(start, ['O', 'O'], SHAKE_RULES);
  assert.equal(res.solved, true);
  assert.ok(res.moves.some((m) => m.type === 'shake'), '흔들기 없이 2차색이 나올 수 없다');

  let st = start;
  for (const mv of res.moves) {
    const r = applyMove(st, mv, SHAKE_RULES);
    assert.ok(r, '해에 포함된 수는 항상 실행 가능해야 한다');
    st = r.state;
  }
  assert.equal(isWin(st, ['O', 'O']), true);
});

test('솔버: 못 푸는 상태는 exhausted=true로 확정 판정', () => {
  // 노랑이 모자라 주황을 만들 수 없다
  const res = solve(S([['R', 'R', 'R', 'Y']]), ['O'], SHAKE_RULES);
  assert.equal(res.solved, false);
  assert.equal(res.exhausted, true);
});

test('솔버: 클래식 모드(흔들기 없음)도 그대로 동작한다', () => {
  const start = S([['R', 'Y', 'R', 'Y'], ['Y', 'R', 'Y', 'R'], [], []]);
  const res = solve(start, ['R', 'Y'], CLASSIC_RULES);
  assert.equal(res.solved, true);
  assert.equal(res.moves.some((m) => m.type === 'shake'), false);
  let st = start;
  for (const mv of res.moves) st = applyMove(st, mv, CLASSIC_RULES).state;
  assert.equal(isWin(st, ['R', 'Y']), true);
});

test('생성기: 같은 시드는 같은 레벨, 결과는 항상 풀 수 있다', () => {
  const params = { seed: 42, targets: ['O', 'G'], extraEmpty: 2 };
  const a = generateLevel(params);
  const b = generateLevel(params);
  assert.deepEqual(a.bottles, b.bottles);
  assert.equal(a.solutionLength, b.solutionLength);

  for (const seed of [1, 2, 3, 7, 99]) {
    const lv = generateLevel({ seed, targets: ['O', 'G'], extraEmpty: 2 });
    let st = { capacity: lv.capacity, bottles: lv.bottles.map((x) => x.slice()) };
    for (const mv of lv.solution) st = applyMove(st, mv, SHAKE_RULES).state;
    assert.equal(isWin(st, lv.targets), true, `seed=${seed} 해 재생 실패`);
  }
});

test('생성기: 2차색 목표는 두 1차색을 정확히 반반씩 넣는다', () => {
  const lv = generateLevel({ seed: 5, targets: ['O'], extraEmpty: 2 });
  const all = lv.bottles.flat();
  assert.equal(all.length, 4);
  assert.equal(all.filter((c) => c === 'R').length, 2);
  assert.equal(all.filter((c) => c === 'Y').length, 2);

  // 1차색 목표는 그 색으로만 채운다
  const prim = generateLevel({ seed: 5, targets: ['O', 'R'], extraEmpty: 2 });
  const flat = prim.bottles.flat();
  assert.equal(flat.filter((c) => c === 'R').length, 6); // 주황용 2 + 빨강 목표 4
  assert.equal(flat.filter((c) => c === 'Y').length, 2);
});
