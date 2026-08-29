// 데일리 챌린지 풀 굽기 → daily-data.js
//
// 매일 하나씩 나가는 특별 퍼즐 풀이다. 날짜 → 풀 인덱스 매핑은 daily.js가 하고,
// 여기서는 "적당히 어렵고(중간 난이도), 풀 수 있음이 보장된" 판을 넉넉히 굽는다.
// 풀을 다 돌면 처음부터 재사용된다 — 반 년 뒤에 같은 판을 알아볼 사람은 없다.
//
// 캠페인(bake-levels)과 시드 대역을 다르게 써서 같은 판이 겹치지 않는다.
//
// 사용법:  node magnet-ball-sort/tools/bake-daily.mjs

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { generateLevel, CLASSIC_RULES, pour, isWin } from '../../sort-engine/index.js';
import { PALETTE } from '../levels.js';

const outPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'daily-data.js');
const t0 = performance.now();

// 데일리는 "출근길 한 판" 난이도다: 튜토리얼처럼 시시하지도, 최고 난도처럼
// 20분을 붙잡지도 않는다. 측정 중앙값 11~22수 구간의 설정만 쓴다 (levels.js 참고).
const CONFIGS = [
  [4, 4, 1, 11], [5, 3, 2, 11], [4, 5, 1, 13], [4, 4, 2, 14], [5, 4, 1, 14],
  [4, 5, 2, 17], [5, 4, 2, 17], [4, 6, 2, 18], [4, 6, 1, 18],
  [5, 5, 2, 21], [5, 5, 1, 21], [4, 7, 1, 22],
];
const PER_CONFIG = 15; // 12설정 × 15 = 풀 180판 (약 반 년 주기)

const bandFor = (median) => {
  const slack = Math.max(3, Math.round(median * 0.18));
  return [Math.max(3, median - slack), median + slack];
};

const skipped = [];
const baked = [];

CONFIGS.forEach(([capacity, colors, extraEmpty, median], ci) => {
  const [minMoves, maxMoves] = bandFor(median);
  for (let j = 0; j < PER_CONFIG; j++) {
    const seed = 90000 + ci * 100 + j; // 캠페인(5000대)과 겹치지 않는 대역
    let lv;
    try {
      lv = generateLevel({
        targets: PALETTE.slice(0, colors),
        capacity,
        extraEmpty,
        minMoves,
        maxMoves,
        seed,
        rules: CLASSIC_RULES,
        solverNodes: 900000,
        maxTries: 300,
      });
    } catch (err) {
      skipped.push({ ci, seed, why: err.message });
      continue;
    }

    if (lv.bottles.length > 10) {
      throw new Error(`설정 ${ci} 시드 ${seed}: 튜브 ${lv.bottles.length}개 — 해 인코딩이 깨진다`);
    }
    let st = { capacity: lv.capacity, bottles: lv.bottles.map((b) => b.slice()) };
    for (const mv of lv.solution) {
      const r = pour(st, mv.from, mv.to, CLASSIC_RULES);
      if (!r) throw new Error(`설정 ${ci} 시드 ${seed}: 해에 불가능한 수`);
      st = r.state;
    }
    if (!isWin(st, lv.targets)) throw new Error(`설정 ${ci} 시드 ${seed}: 해 재생해도 미클리어`);

    baked.push({
      cap: lv.capacity,
      tubes: lv.bottles.map((b) => b.join('')),
      sol: lv.solution.map((m) => `${m.from}${m.to}`).join(''),
      par: lv.solutionLength,
    });
  }
});

if (skipped.length) {
  console.log(`⚠ 생성 실패로 건너뛴 시드 ${skipped.length}개:`);
  for (const s of skipped) console.log(`   설정#${s.ci} 시드${s.seed}`);
}

// 결정적으로 섞는다 — 연이은 날의 난이도가 오르내리도록 (풀 순서 = 날짜 순서다).
// Math.random 은 재현이 안 되므로 고정 시드 LCG를 쓴다.
let rng = 1234567;
const next = () => (rng = (rng * 1103515245 + 12345) & 0x7fffffff) / 0x80000000;
for (let i = baked.length - 1; i > 0; i--) {
  const j = Math.floor(next() * (i + 1));
  [baked[i], baked[j]] = [baked[j], baked[i]];
}

const pars = baked.map((l) => l.par);
console.log(`데일리 풀 ${baked.length}판 생성 (${((performance.now() - t0) / 1000).toFixed(1)}초)`);
console.log(`최소 수 범위: ${Math.min(...pars)} ~ ${Math.max(...pars)}`);
console.log(
  `첫 14일 미리보기: ${pars.slice(0, 14).join(', ')}수`
);

const header =
  '// 자동 생성 파일 — 직접 수정하지 말 것.\n' +
  '// 다시 만들려면: node magnet-ball-sort/tools/bake-daily.mjs\n' +
  '//\n' +
  '// 데일리 챌린지 풀. 날짜 → 인덱스 매핑은 daily.js가 한다.\n' +
  '// 형식은 levels-data.js 와 같다 (cap/tubes/sol/par).\n\n';

const body = baked
  .map((l) => ` {cap:${l.cap},par:${l.par},tubes:${JSON.stringify(l.tubes)},sol:"${l.sol}"}`)
  .join(',\n');

writeFileSync(outPath, `${header}export const DAILY_POOL = [\n${body}\n];\n`);
console.log(`저장 완료 → ${outPath} (${(Buffer.byteLength(body) / 1024).toFixed(0)}KB)`);
