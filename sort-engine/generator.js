// 레벨 생성기.
// 목표색에서 필요한 물감 단위를 역산해 무작위로 병에 나눠 담고,
// 솔버로 "풀 수 있고, 너무 쉽지도 않은" 배치가 나올 때까지 다시 섞는다.
// 같은 seed + 같은 파라미터 → 항상 같은 레벨.

import { componentsOf, isPrimary } from './colors.js';
import { mulberry32, shuffled } from './rng.js';
import { isWin } from './state.js';
import { solve } from './solver.js';
import { SHAKE_RULES } from './moves.js';

export function generateLevel(params) {
  const {
    seed,
    targets,
    capacity = 4,
    extraEmpty = 2,
    rules = SHAKE_RULES,
    minMoves = 4,
    // 해가 이 길이를 넘으면 그 배치도 버린다. minMoves와 함께 난이도 구간을 만든다.
    maxMoves = Infinity,
    maxTries = 200,
    solverNodes = 250000,
    // 물감을 몇 개의 병에 나눠 담을지. 기본값은 딱 맞게 채우는 것(= 목표 수).
    // 이보다 크게 주면 병들이 덜 찬 채로 흩어져서 모으는 수가 늘어난다.
    fillBottles = targets.length,
  } = params;
  if (!Number.isInteger(seed)) throw new Error('generateLevel: seed가 필요합니다');
  if (!targets || !targets.length) throw new Error('generateLevel: targets가 필요합니다');
  if (capacity % 2 !== 0) throw new Error('generateLevel: capacity는 짝수여야 합니다 (반반 혼합)');
  const rand = mulberry32(seed);

  // 목표색 → 필요한 물감 단위.
  // 2차색은 두 1차색을 정확히 반반씩 써야 만들어진다.
  const units = [];
  for (const t of targets) {
    if (isPrimary(t)) {
      for (let i = 0; i < capacity; i++) units.push(t);
    } else {
      const comps = componentsOf(t);
      if (!comps) throw new Error(`generateLevel: 알 수 없는 목표색 ${t}`);
      for (let i = 0; i < capacity / 2; i++) units.push(comps[0], comps[1]);
    }
  }

  // 물감을 담을 병들의 크기를 최대한 고르게 나눈다.
  if (fillBottles * capacity < units.length) {
    throw new Error(`generateLevel: fillBottles=${fillBottles}로는 물감 ${units.length}칸을 담을 수 없습니다`);
  }
  const sizes = [];
  const base = Math.floor(units.length / fillBottles);
  const extra = units.length % fillBottles;
  for (let i = 0; i < fillBottles; i++) sizes.push(base + (i < extra ? 1 : 0));

  let best = null;
  for (let attempt = 0; attempt < maxTries; attempt++) {
    const dealt = shuffled(units, rand);
    const filled = [];
    let at = 0;
    for (const size of sizes) {
      filled.push(dealt.slice(at, at + size));
      at += size;
    }
    for (let i = 0; i < extraEmpty; i++) filled.push([]);
    const bottles = shuffled(filled, rand);

    const state = { capacity, bottles };
    if (isWin(state, targets)) continue;

    const res = solve(state, targets, rules, { maxNodes: solverNodes });
    if (!res.solved) continue;

    const level = {
      capacity,
      targets: targets.slice(),
      bottles: bottles.map((b) => b.slice()),
      seed,
      attempt,
      solution: res.moves,
      solutionLength: res.moves.length,
    };
    // 난이도 구간 안에 들면 채택. 못 찾으면 구간 중앙에 가장 가까운 걸 쓴다.
    const len = level.solutionLength;
    if (len >= minMoves && len <= maxMoves) return level;
    const mid = Number.isFinite(maxMoves) ? (minMoves + maxMoves) / 2 : minMoves;
    if (!best || Math.abs(len - mid) < Math.abs(best.solutionLength - mid)) best = level;
  }

  if (best) return best;
  throw new Error(
    `generateLevel: seed=${seed} targets=${targets.join(',')} — ${maxTries}번 안에 풀 수 있는 배치를 찾지 못함`
  );
}
