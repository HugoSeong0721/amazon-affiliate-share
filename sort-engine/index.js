// 공용 소트 퍼즐 엔진 — 렌더링과 완전히 분리된 순수 로직.
// 브라우저(ES module)와 Node(node --test) 양쪽에서 그대로 동작한다.

export { PRIMARIES, SECONDARIES, isPrimary, mixOf, componentsOf } from './colors.js';
export { mulberry32, randInt, shuffled } from './rng.js';
export {
  createState,
  cloneState,
  topRun,
  isUniform,
  isComplete,
  stateKey,
  isWin,
} from './state.js';
export { CLASSIC_RULES, MIX_RULES, canPour, pour, legalMoves } from './moves.js';
export { solve } from './solver.js';
export { generateLevel } from './generator.js';
