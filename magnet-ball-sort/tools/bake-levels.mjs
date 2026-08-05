// 레벨 굽기: levels.js의 스펙으로 레벨을 생성/검증하고, 최소 수 기준으로 정렬해
// levels-data.js로 저장한다. 게임 런타임은 이 데이터만 읽으므로 로드가 즉시 끝난다.
//
// 데이터를 압축해서 담는다 (레벨이 100개를 넘으면 형식이 곧 번들 크기가 된다):
//   tubes: 튜브당 문자열 하나  ["ROYG", "YG", ""]
//   sol:   한 수를 두 글자로   "0121" = 0→1, 2→1
//
// 사용법:  node magnet-ball-sort/tools/bake-levels.mjs

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { generateLevel, CLASSIC_RULES, pour, isWin } from '../../sort-engine/index.js';
import { LEVEL_SPECS } from '../levels.js';

const outPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'levels-data.js');
const t0 = performance.now();

const skipped = [];

const baked = LEVEL_SPECS.map((spec, i) => {
  let lv;
  try {
    lv = generateLevel({ ...spec, rules: CLASSIC_RULES, solverNodes: 900000, maxTries: 300 });
  } catch (err) {
    // 빈 튜브가 하나뿐인 고난도 설정은 풀 수 있는 배치 자체가 드물어 실패할 수 있다.
    // 조용히 건너뛰면 "다 됐다"로 읽히므로 반드시 남긴다.
    skipped.push({ i, spec, why: err.message });
    return null;
  }

  // 한 수를 두 글자로 담으므로 튜브가 10개를 넘으면 안 된다
  if (lv.bottles.length > 10) {
    throw new Error(`스펙 ${i}: 튜브가 ${lv.bottles.length}개 — 해 인코딩(한 자리)이 깨진다`);
  }

  // 저장 전에 해가 정말 클리어로 이어지는지 확인
  let st = { capacity: lv.capacity, bottles: lv.bottles.map((b) => b.slice()) };
  for (const mv of lv.solution) {
    const r = pour(st, mv.from, mv.to, CLASSIC_RULES);
    if (!r) throw new Error(`스펙 ${i}: 해에 불가능한 수가 있다`);
    st = r.state;
  }
  if (!isWin(st, lv.targets)) throw new Error(`스펙 ${i}: 해를 재생해도 클리어가 아니다`);

  return {
    cap: lv.capacity,
    tubes: lv.bottles.map((b) => b.join('')),
    sol: lv.solution.map((m) => `${m.from}${m.to}`).join(''),
    par: lv.solutionLength,
    colors: lv.targets.length,
    empty: spec.extraEmpty,
    seed: spec.seed,
  };
}).filter(Boolean);

if (skipped.length) {
  console.log(`\n⚠ 생성 실패로 건너뛴 스펙 ${skipped.length}개:`);
  for (const s of skipped) {
    console.log(
      `   #${s.i} 용량${s.spec.capacity}·색${s.spec.targets.length}·빈${s.spec.extraEmpty}·시드${s.spec.seed}`
    );
  }
  console.log('');
}

// 최소 수 기준으로 정렬 → 난이도 곡선이 단조 증가한다.
// 같은 값이면 튜브가 적은 쪽을 먼저 (시각적으로도 단순한 판이 앞에 온다).
baked.sort((a, b) => a.par - b.par || a.tubes.length - b.tubes.length);

const pars = baked.map((l) => l.par);
const buckets = new Map();
for (const l of baked) {
  const k = `용량${l.cap}·색${l.colors}·빈${l.empty}`;
  buckets.set(k, (buckets.get(k) || 0) + 1);
}

console.log(`레벨 ${baked.length}개 생성 (${((performance.now() - t0) / 1000).toFixed(1)}초)`);
console.log(`최소 수: ${pars[0]} → ${pars.at(-1)} (단조 증가: ${pars.every((p, i) => i === 0 || p >= pars[i - 1]) ? '예' : '아니오'})`);
console.log(`설정 ${buckets.size}종, 튜브 최대 ${Math.max(...baked.map((l) => l.tubes.length))}개`);

// 10단위로 곡선 미리보기
const preview = [];
for (let i = 0; i < baked.length; i += 10) preview.push(`${i + 1}:${baked[i].par}수`);
console.log('곡선  ' + preview.join('  '));

const header =
  '// 자동 생성 파일 — 직접 수정하지 말 것.\n' +
  '// 다시 만들려면: node magnet-ball-sort/tools/bake-levels.mjs\n' +
  '// 원본 스펙: levels.js\n' +
  '//\n' +
  '// cap   = 튜브 용량 (레벨마다 다름)\n' +
  '// tubes = 튜브당 문자열 하나. 왼쪽이 바닥.\n' +
  '// sol   = 참고 해. 두 글자가 한 수 ("0121" = 0→1, 2→1)\n' +
  '// par   = 참고 해의 길이 (별점 기준)\n\n';

const body = baked
  .map(
    (l) =>
      ` {cap:${l.cap},par:${l.par},tubes:${JSON.stringify(l.tubes)},sol:"${l.sol}"}`
  )
  .join(',\n');

writeFileSync(outPath, `${header}export const LEVEL_DATA = [\n${body}\n];\n`);
const kb = (Buffer.byteLength(body) / 1024).toFixed(0);
console.log(`\n저장 완료 → ${outPath} (${kb}KB)`);
