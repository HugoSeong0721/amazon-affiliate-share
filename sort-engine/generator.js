// 레벨 생성기.
// 목표색 목록으로부터 필요한 물감 단위를 역산해 무작위로 병에 나눠 담고,
// 솔버로 "풀 수 있는 배치"인지 검증될 때까지 다시 섞는다.
// 같은 seed + 같은 파라미터 → 항상 같은 레벨.

import { componentsOf, isPrimary } from './colors.js';
import { mulberry32, randInt, shuffled } from './rng.js';
import { isWin } from './state.js';
import { solve } from './solver.js';
import { MIX_RULES } from './moves.js';

export function generateLevel(params) {
  const {
    seed,
    targets,
    capacity = 4,
    extraEmpty = 2,
    rules = MIX_RULES,
    maxTries = 80,
    solverNodes = 250000,
  } = params;
  if (!Number.isInteger(seed)) throw new Error('generateLevel: seed가 필요합니다');
  if (!targets || !targets.length) throw new Error('generateLevel: targets가 필요합니다');
  const rand = mulberry32(seed);

  for (let attempt = 0; attempt < maxTries; attempt++) {
    // 목표색 → 필요한 물감 단위. 2차색 목표는 1차색 두 개로 쪼갠다(비율은 랜덤).
    const units = [];
    for (const t of targets) {
      if (!rules.allowMix || isPrimary(t)) {
        for (let i = 0; i < capacity; i++) units.push(t);
      } else {
        const comps = componentsOf(t);
        if (!comps) throw new Error(`generateLevel: 알 수 없는 목표색 ${t}`);
        const k = randInt(rand, 1, capacity - 1);
        for (let i = 0; i < k; i++) units.push(comps[0]);
        for (let i = 0; i < capacity - k; i++) units.push(comps[1]);
      }
    }

    const dealt = shuffled(units, rand);
    const filled = [];
    for (let i = 0; i < targets.length; i++) {
      filled.push(dealt.slice(i * capacity, (i + 1) * capacity));
    }
    for (let i = 0; i < extraEmpty; i++) filled.push([]);
    const bottles = shuffled(filled, rand);

    const state = { capacity, bottles };
    if (isWin(state, targets)) continue;

    const res = solve(state, targets, rules, { maxNodes: solverNodes });
    if (res.solved) {
      return {
        capacity,
        targets: targets.slice(),
        bottles: bottles.map((b) => b.slice()),
        seed,
        attempt,
        solution: res.moves,
        solutionLength: res.moves.length,
      };
    }
  }
  throw new Error(
    `generateLevel: seed=${seed} targets=${targets.join(',')} — ${maxTries}번 안에 풀 수 있는 배치를 찾지 못함`
  );
}
