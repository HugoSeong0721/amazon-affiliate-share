// 레벨 굽기: levels.js의 스펙으로 레벨을 생성/검증해서 levels-data.js로 저장한다.
// 게임 런타임은 이 데이터만 읽으므로 레벨 로드가 즉시 끝난다.
//
// 사용법:  node magnet-ball-sort/tools/bake-levels.mjs

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { generateLevel, CLASSIC_RULES } from '../../sort-engine/index.js';
import { LEVELS, CAPACITY } from '../levels.js';

const outPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'levels-data.js');

const baked = LEVELS.map((def, i) => {
  const t0 = performance.now();
  const lv = generateLevel({ ...def, rules: CLASSIC_RULES, solverNodes: 800000 });
  console.log(
    `레벨 ${String(i + 1).padStart(2)}: 튜브 ${String(lv.bottles.length).padStart(2)}개 ` +
      `(색 ${lv.targets.length} + 빈 ${def.extraEmpty}, 용량 ${lv.capacity}), ` +
      `참고해 ${String(lv.solutionLength).padStart(2)}수, ${(performance.now() - t0).toFixed(0)}ms`
  );
  return {
    capacity: lv.capacity,
    targets: lv.targets,
    tubes: lv.bottles,
    solution: lv.solution,
    solutionLength: lv.solutionLength,
    seed: def.seed,
  };
});

const header =
  '// 자동 생성 파일 — 직접 수정하지 말 것.\n' +
  '// 다시 만들려면: node magnet-ball-sort/tools/bake-levels.mjs\n' +
  '// 원본 스펙: levels.js\n\n';

writeFileSync(
  outPath,
  header +
    `// 용량은 레벨마다 다를 수 있다 (마지막 두 판은 5칸). CAPACITY는 기본값일 뿐이다.\n` +
    `export const CAPACITY = ${CAPACITY};\n\nexport const LEVEL_DATA = ${JSON.stringify(baked, null, 1)};\n`
);
console.log(`\n${baked.length}개 레벨 저장 완료 → ${outPath}`);
