// 레벨 굽기: 시드를 잔뜩 돌려 후보 풀을 만들고, par(최소 수)를 측정한 뒤
// levels.js의 목표 곡선에 가장 가까운 판을 골라 levels-data.js로 저장한다.
// 게임 런타임은 이 데이터만 읽으므로 로드가 즉시 끝난다.
//
// 사용법:  node parking-escape/tools/bake-levels.mjs

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  generate,
  solve,
  isWin,
  moveVehicle,
  rangeOf,
  coordOf,
  keyOf,
  encodeVehicles,
  encodeMoves,
} from '../engine.js';
import { POOL_SPECS, LEVEL_COUNT, curveTargets } from '../levels.js';

const outPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'levels-data.js');
const t0 = performance.now();

// 1) 후보 풀 — 같은 배치가 두 번 나오면 하나만 남긴다
const pool = [];
const seenBoards = new Set();
let failed = 0;
for (const spec of POOL_SPECS) {
  const lv = generate(spec);
  if (!lv) {
    failed++;
    continue;
  }
  const board = encodeVehicles(lv.vehicles);
  if (seenBoards.has(board)) continue;
  seenBoards.add(board);
  pool.push({ ...lv, cars: spec.cars, seed: spec.seed, board });
}
console.log(
  `후보 ${pool.length}개 생성 (시드 ${POOL_SPECS.length}개 중 실패 ${failed}, 중복 ${
    POOL_SPECS.length - failed - pool.length
  })`
);

// 2) 목표 곡선에 맞춰 고르기 — par가 가장 가까운 미사용 후보.
//    같은 par면 차가 많은 판을 고른다 (뒤로 갈수록 판이 빽빽해 보여야 어렵게 느껴진다).
const maxPar = Math.max(...pool.map((l) => l.par));
const targets = curveTargets(maxPar);
const used = new Set();
const picked = targets.map((want, li) => {
  let best = null;
  let bestScore = Infinity;
  for (const cand of pool) {
    if (used.has(cand.board)) continue;
    // 초반(목표가 낮을수록)은 차도 적은 판을 골라 화면까지 쉬워 보이게 한다
    const carBias = want <= 3 ? cand.cars : -cand.cars * 0.01;
    const score = Math.abs(cand.par - want) + carBias * 0.001;
    if (score < bestScore) {
      bestScore = score;
      best = cand;
    }
  }
  if (!best) throw new Error(`레벨 ${li + 1}: 남은 후보가 없다`);
  used.add(best.board);
  return best;
});

// 3) 최종 정렬 — 난이도(par)가 단조 증가해야 한다
picked.sort((a, b) => a.par - b.par || a.cars - b.cars);

// 4) 저장 전 검증: 해를 그대로 재생하면 정말 탈출인가, 매 수가 그 시점에 합법인가
for (const [i, lv] of picked.entries()) {
  let vs = lv.vehicles;
  if (isWin(vs)) throw new Error(`레벨 ${i + 1}이 시작부터 클리어 상태`);
  for (const mv of lv.moves) {
    const { min, max } = rangeOf(vs, mv.v);
    if (mv.to < min || mv.to > max || mv.to === coordOf(vs[mv.v])) {
      throw new Error(`레벨 ${i + 1}: 해에 불가능한 수 ${JSON.stringify(mv)} (상태 ${keyOf(vs)})`);
    }
    vs = moveVehicle(vs, mv.v, mv.to);
  }
  if (!isWin(vs)) throw new Error(`레벨 ${i + 1}: 해를 재생해도 탈출이 아니다`);
  // 굽는 값과 즉석 솔버가 일치하는지 한 번 더 (인코딩 버그 조기 발견)
  const r = solve(lv.vehicles);
  if (!r.solved || r.par !== lv.par) throw new Error(`레벨 ${i + 1}: par 불일치 ${r.par} != ${lv.par}`);
}

const pars = picked.map((l) => l.par);
console.log(`레벨 ${picked.length}개 선택 (${((performance.now() - t0) / 1000).toFixed(1)}초)`);
console.log(
  `최소 수: ${pars[0]} → ${pars.at(-1)} (단조 증가: ${
    pars.every((p, i) => i === 0 || p >= pars[i - 1]) ? '예' : '아니오'
  })`
);
console.log(`차량 수: ${picked[0].cars} → ${picked.at(-1).cars} (최대 ${Math.max(...picked.map((l) => l.cars))})`);

const preview = [];
for (let i = 0; i < picked.length; i += 10) preview.push(`${i + 1}:${picked[i].par}수`);
console.log('곡선  ' + preview.join('  '));

const header =
  '// 자동 생성 파일 — 직접 수정하지 말 것.\n' +
  '// 다시 만들려면: node parking-escape/tools/bake-levels.mjs\n' +
  '// 원본 스펙: levels.js\n' +
  '//\n' +
  '// v   = 차량 목록. 4글자가 차 한 대 "xyLh" (x, y, 길이, 가로=1). 첫 차가 플레이어.\n' +
  '// sol = 참고 해. 2글자가 한 수, 차량 번호(base36) + 목표 좌표 ("a3" = 10번 차를 3으로)\n' +
  '// par = 참고 해의 길이 = 솔버가 찾은 최소 수 (별점 기준)\n\n';

const body = picked
  .map((l) => ` {par:${l.par},v:"${encodeVehicles(l.vehicles)}",sol:"${encodeMoves(l.moves)}"}`)
  .join(',\n');

writeFileSync(outPath, `${header}export const LEVEL_DATA = [\n${body}\n];\n`);
const kb = (Buffer.byteLength(body) / 1024).toFixed(0);
console.log(`\n저장 완료 → ${outPath} (${kb}KB)`);

if (picked.length !== LEVEL_COUNT) {
  console.log(`⚠ 목표 ${LEVEL_COUNT}개 중 ${picked.length}개만 구웠다`);
}
