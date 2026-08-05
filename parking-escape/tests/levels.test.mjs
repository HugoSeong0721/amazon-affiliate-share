import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  W,
  H,
  EXIT_ROW,
  PLAYER,
  rangeOf,
  moveVehicle,
  coordOf,
  isWin,
  occupancy,
  decodeVehicles,
  decodeMoves,
} from '../engine.js';
import { LEVEL_DATA } from '../levels-data.js';
import { LEVEL_COUNT } from '../levels.js';

test('레벨이 100개 이상이고 목표 개수와 일치한다', () => {
  assert.ok(LEVEL_DATA.length >= 100, `레벨이 ${LEVEL_DATA.length}개뿐`);
  assert.equal(LEVEL_DATA.length, LEVEL_COUNT);
});

test('모든 레벨: 플레이어는 출구 행의 가로 2칸 차다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const p = decodeVehicles(lv.v)[PLAYER];
    assert.equal(p.h, true, `레벨 ${i + 1}의 플레이어가 세로차`);
    assert.equal(p.len, 2, `레벨 ${i + 1}의 플레이어 길이 ${p.len}`);
    assert.equal(p.y, EXIT_ROW, `레벨 ${i + 1}의 플레이어가 출구 행 밖`);
  });
});

test('모든 레벨: 출구 행의 가로차는 플레이어뿐이다 (아니면 영구히 막힌다)', () => {
  LEVEL_DATA.forEach((lv, i) => {
    decodeVehicles(lv.v).forEach((v, k) => {
      if (k === PLAYER) return;
      assert.ok(!(v.h && v.y === EXIT_ROW), `레벨 ${i + 1}의 ${k}번 가로차가 출구 행에 있다`);
    });
  });
});

test('모든 레벨: 차가 격자 안에 겹침 없이 놓인다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    const vs = decodeVehicles(lv.v);
    for (const v of vs) {
      const endX = v.h ? v.x + v.len - 1 : v.x;
      const endY = v.h ? v.y : v.y + v.len - 1;
      assert.ok(v.x >= 0 && v.y >= 0 && endX < W && endY < H, `레벨 ${i + 1}의 차가 격자 밖`);
    }
    const g = occupancy(vs);
    let cells = 0;
    for (let k = 0; k < W * H; k++) if (g[k] !== -1) cells++;
    assert.equal(cells, vs.reduce((a, v) => a + v.len, 0), `레벨 ${i + 1}에 겹치는 차가 있다`);
  });
});

test('모든 레벨의 참고 해가 매 수 합법이고, 재생하면 탈출이다', () => {
  LEVEL_DATA.forEach((lv, i) => {
    let vs = decodeVehicles(lv.v);
    assert.equal(isWin(vs), false, `레벨 ${i + 1}이 시작부터 클리어 상태`);
    for (const mv of decodeMoves(lv.sol)) {
      const { min, max } = rangeOf(vs, mv.v);
      assert.ok(
        mv.to >= min && mv.to <= max && mv.to !== coordOf(vs[mv.v]),
        `레벨 ${i + 1} 해에 불가능한 수: ${JSON.stringify(mv)}`
      );
      vs = moveVehicle(vs, mv.v, mv.to);
    }
    assert.equal(isWin(vs), true, `레벨 ${i + 1} 해를 재생해도 탈출이 아니다`);
  });
});

test('par가 참고 해 길이와 일치한다 (별점 기준이 어긋나면 안 된다)', () => {
  LEVEL_DATA.forEach((lv, i) => {
    assert.equal(decodeMoves(lv.sol).length, lv.par, `레벨 ${i + 1}의 par 불일치`);
  });
});

test('난이도가 단조 증가하고, 시작은 튜토리얼답고, 끝은 씹을 맛이 있다', () => {
  const pars = LEVEL_DATA.map((lv) => lv.par);
  pars.forEach((p, i) => {
    if (i === 0) return;
    assert.ok(p >= pars[i - 1], `레벨 ${i + 1}(${p}수)이 앞 레벨(${pars[i - 1]}수)보다 쉬움`);
  });
  assert.equal(pars[0], 1, `첫 레벨이 ${pars[0]}수 — 손가락 안내 하나로 끝나야 한다`);
  assert.ok(pars.at(-1) >= 20, `마지막 레벨이 ${pars.at(-1)}수 — 마무리가 너무 싱겁다`);
});

test('첫 레벨은 한 번의 드래그(택시 → 출구)로 끝난다', () => {
  const lv = LEVEL_DATA[0];
  const moves = decodeMoves(lv.sol);
  assert.equal(moves.length, 1);
  assert.equal(moves[0].v, PLAYER);
  const vs = decodeVehicles(lv.v);
  assert.equal(moves[0].to, W - vs[PLAYER].len);
});
