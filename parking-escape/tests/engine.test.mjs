import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  W,
  H,
  EXIT_ROW,
  PLAYER,
  occupancy,
  rangeOf,
  moveVehicle,
  coordOf,
  isWin,
  solve,
  generate,
  encodeVehicles,
  decodeVehicles,
  encodeMoves,
  decodeMoves,
} from '../engine.js';
import { LEVEL_DATA } from '../levels-data.js';

// 손으로 만든 판: 택시(0)가 출구 행에, 세로 트럭(1)이 길을 막는다.
//   . . . . . .
//   . . . 1 . .
//   0 0 . 1 . .   ← 출구 행
//   . . . 1 . .
//   . . . . . .
//   . . . . . .
const blocked = () => [
  { x: 0, y: EXIT_ROW, len: 2, h: true },
  { x: 3, y: 1, len: 3, h: false },
];

test('rangeOf — 벽과 다른 차에 막힌다', () => {
  const vs = blocked();
  // 택시는 트럭 앞까지만 (x 0..1)
  assert.deepEqual(rangeOf(vs, 0), { min: 0, max: 1 });
  // 트럭은 위로 1칸, 아래로 1칸 (y 0..3)
  assert.deepEqual(rangeOf(vs, 1), { min: 0, max: 3 });
});

test('moveVehicle — 원본을 건드리지 않는 새 상태를 만든다', () => {
  const vs = blocked();
  const moved = moveVehicle(vs, 1, 3);
  assert.equal(vs[1].y, 1);
  assert.equal(moved[1].y, 3);
  assert.equal(coordOf(moved[1]), 3);
});

test('solve — 트럭을 비키고 택시가 나가는 최소 2수를 찾는다', () => {
  const r = solve(blocked());
  assert.equal(r.solved, true);
  assert.equal(r.par, 2);
  // 재생하면 정말 탈출이어야 한다
  let vs = blocked();
  for (const mv of r.moves) vs = moveVehicle(vs, mv.v, mv.to);
  assert.equal(isWin(vs), true);
});

test('solve — 시작부터 탈출 상태면 0수', () => {
  const r = solve([{ x: W - 2, y: EXIT_ROW, len: 2, h: true }]);
  assert.equal(r.solved, true);
  assert.equal(r.par, 0);
});

test('solve — 출구 행을 가로차가 막으면 영원히 못 푼다', () => {
  const vs = [
    { x: 0, y: EXIT_ROW, len: 2, h: true },
    { x: 3, y: EXIT_ROW, len: 2, h: true }, // 같은 행의 가로차 — 절대 못 비킨다
  ];
  const r = solve(vs);
  assert.equal(r.solved, false);
  assert.equal(r.exhausted, true);
});

test('generate — 같은 시드는 언제나 같은 레벨을 만든다', () => {
  const a = generate({ seed: 12345, cars: 8 });
  const b = generate({ seed: 12345, cars: 8 });
  assert.ok(a && b);
  assert.equal(encodeVehicles(a.vehicles), encodeVehicles(b.vehicles));
  assert.equal(a.par, b.par);
});

test('직렬화 왕복 — 차량과 해가 그대로 돌아온다', () => {
  const lv = generate({ seed: 777, cars: 9 });
  assert.ok(lv);
  assert.deepEqual(decodeVehicles(encodeVehicles(lv.vehicles)), lv.vehicles);
  assert.deepEqual(decodeMoves(encodeMoves(lv.moves)), lv.moves);
});

test('occupancy — 모든 차가 격자 안에 겹침 없이 놓인다', () => {
  const lv = generate({ seed: 424242, cars: 12 });
  assert.ok(lv);
  const g = occupancy(lv.vehicles);
  let cells = 0;
  for (let i = 0; i < W * H; i++) if (g[i] !== -1) cells++;
  assert.equal(
    cells,
    lv.vehicles.reduce((a, v) => a + v.len, 0),
    '겹치는 차가 있다'
  );
});

test('레벨 데이터 인코딩이 한 자리로 안전하다 (차량 36대·좌표 6칸 이하)', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const vs = decodeVehicles(lv.v);
    assert.ok(vs.length <= 36, `레벨 ${i + 1}의 차량이 ${vs.length}대`);
    for (const mv of decodeMoves(lv.sol)) {
      assert.ok(mv.v >= 0 && mv.v < vs.length, `레벨 ${i + 1} 해의 차량 번호 범위 밖: ${mv.v}`);
      assert.ok(mv.to >= 0 && mv.to < Math.max(W, H), `레벨 ${i + 1} 해의 좌표 범위 밖: ${mv.to}`);
    }
  });
});
