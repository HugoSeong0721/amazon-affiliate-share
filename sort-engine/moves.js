// 붓기 규칙.
// rules.allowMix = false → 클래식 워터소트 (같은 색 위에만 부을 수 있음)
// rules.allowMix = true  → 1차색끼리는 서로 부을 수 있고, 닿은 구간이 2차색으로 섞인다.

import { isPrimary, mixOf } from './colors.js';
import { cloneState, topRun } from './state.js';

export const CLASSIC_RULES = { allowMix: false };
export const MIX_RULES = { allowMix: true };

export function canPour(state, from, to, rules = CLASSIC_RULES) {
  if (from === to) return false;
  const src = state.bottles[from];
  const dst = state.bottles[to];
  if (!src || !dst) return false;
  if (src.length === 0) return false;
  if (dst.length >= state.capacity) return false;
  if (dst.length === 0) return true;
  const a = src[src.length - 1];
  const b = dst[dst.length - 1];
  if (a === b) return true;
  return rules.allowMix ? mixOf(a, b) !== null : false;
}

// 붓기 실행. 맨 위 같은 색 구간 전체가 (공간이 허락하는 만큼) 이동한다.
// 다른 색 위에 부으면(혼합) 부은 양 + 닿은 구간 전체가 혼합색으로 변한다.
// 반환: { state, from, to, amount, color, mixed, mixedRunBefore } 또는 불가 시 null
export function pour(state, from, to, rules = CLASSIC_RULES) {
  if (!canPour(state, from, to, rules)) return null;
  const next = cloneState(state);
  const src = next.bottles[from];
  const dst = next.bottles[to];
  const run = topRun(src);
  const space = next.capacity - dst.length;
  const amount = Math.min(run.count, space);

  const before = dst.length ? dst[dst.length - 1] : null;
  let color = run.color;
  let mixed = false;
  let mixedRunBefore = 0;

  if (before !== null && before !== run.color) {
    color = mixOf(run.color, before);
    mixed = true;
    mixedRunBefore = topRun(dst).count;
    for (let i = dst.length - mixedRunBefore; i < dst.length; i++) dst[i] = color;
  }
  src.length -= amount;
  for (let i = 0; i < amount; i++) dst.push(color);

  return { state: next, from, to, amount, color, mixed, mixedRunBefore };
}

// 완성돼서 더 이상 손댈 수 없는 병 (가득 + 단색).
// 단, 혼합 모드의 1차색 완성병은 깨서 섞어야 풀리는 배치가 있어 잠그지 않는다.
// UI와 솔버가 같은 규칙을 쓰도록 여기 한 곳에서만 판단한다.
export function isLocked(state, i, rules = CLASSIC_RULES) {
  const b = state.bottles[i];
  if (!b || b.length !== state.capacity) return false;
  for (let k = 1; k < b.length; k++) if (b[k] !== b[0]) return false;
  return !(rules.allowMix && isPrimary(b[0]));
}

// 탐색용 합법 수 나열. 무의미한 수는 가지치기한다:
// - 완성돼 잠긴 병에서는 나갈 수 없다.
// - 단색 병 → 빈 병 이동은 상태가 그대로라 제외.
export function legalMoves(state, rules = CLASSIC_RULES) {
  const moves = [];
  const n = state.bottles.length;
  for (let from = 0; from < n; from++) {
    const src = state.bottles[from];
    if (!src.length) continue;
    if (isLocked(state, from, rules)) continue;
    let uniform = true;
    for (let i = 1; i < src.length; i++) if (src[i] !== src[0]) { uniform = false; break; }
    for (let to = 0; to < n; to++) {
      if (to === from) continue;
      if (uniform && state.bottles[to].length === 0) continue;
      if (canPour(state, from, to, rules)) moves.push({ from, to });
    }
  }
  return moves;
}
