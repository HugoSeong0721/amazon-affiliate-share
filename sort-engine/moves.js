// 수(move) 규칙.
//
// 이 엔진은 두 가지 행동을 안다:
//   { type: 'pour',  from, to }  — 맨 위 같은 색 덩어리를 다른 병으로 옮긴다. 절대 섞이지 않는다.
//   { type: 'shake', at }        — 병을 흔들어 안의 물감을 비율대로 한 색으로 만든다.
//
// 붓기가 섞지 않는 게 핵심이다. 병 안에 다른 색이 층층이 쌓여 있어도 그냥 쌓여 있을 뿐이고,
// 흔들어야 비로소 섞인다. 그래서 "이미 닿아 있는데 왜 안 섞이지?"라는 모순이 없다.
//
// rules.freePour = true  → 아무 색 위에나 부을 수 있다 (섞이지 않으니 막을 이유가 없다)
// rules.freePour = false → 같은 색 위 또는 빈 병에만 (클래식 워터소트)
// rules.shake            → 흔들기 사용 가능 여부

import { blendOf, isPrimary } from './colors.js';
import { cloneState, topRun, isUniform } from './state.js';

export const CLASSIC_RULES = { freePour: false, shake: false };
export const SHAKE_RULES = { freePour: true, shake: true };

// 완성돼서 더 이상 손댈 수 없는 병.
// 흔들어 만든 2차색 병은 목표 그 자체라 잠근다 (실수로 부어서 스스로 망칠 수 없게).
// 1차색으로 가득 찬 병은 잠그지 않는다 — 거기서 정확한 양을 덜어내야 하는 경우가 많다.
export function isLocked(state, i, rules = CLASSIC_RULES) {
  const b = state.bottles[i];
  if (!b || b.length !== state.capacity || !isUniform(b)) return false;
  return rules.shake ? !isPrimary(b[0]) : true;
}

export function canPour(state, from, to, rules = CLASSIC_RULES) {
  if (from === to) return false;
  const src = state.bottles[from];
  const dst = state.bottles[to];
  if (!src || !dst) return false;
  if (src.length === 0) return false;
  if (dst.length >= state.capacity) return false;
  if (isLocked(state, from, rules)) return false;
  if (rules.freePour) return true;
  if (dst.length === 0) return true;
  return src[src.length - 1] === dst[dst.length - 1];
}

// 붓기 실행. 맨 위 같은 색 구간이 (공간이 허락하는 만큼) 그대로 옮겨간다.
// 색은 절대 변하지 않는다. 정확한 양을 옮기고 싶으면 목적지의 남은 공간으로 조절해야 한다 —
// 이 "공간으로 양을 재는" 감각이 퍼즐의 핵심이다.
// 반환: { state, from, to, amount, color } 또는 불가 시 null
export function pour(state, from, to, rules = CLASSIC_RULES) {
  if (!canPour(state, from, to, rules)) return null;
  const next = cloneState(state);
  const src = next.bottles[from];
  const dst = next.bottles[to];
  const run = topRun(src);
  const amount = Math.min(run.count, next.capacity - dst.length);
  src.length -= amount;
  for (let i = 0; i < amount; i++) dst.push(run.color);
  return { state: next, from, to, amount, color: run.color };
}

// 흔들 수 있는가. 가득 찬 병이면서, 서로 다른 두 1차색이 정확히 반반일 때만.
// 이미 단색인 병은 흔들어봐야 그대로라 제외한다.
export function canShake(state, i, rules = CLASSIC_RULES) {
  if (!rules.shake) return false;
  const b = state.bottles[i];
  if (!b || b.length !== state.capacity) return false;
  if (isUniform(b)) return false;
  return blendOf(b) !== null;
}

// 흔들었을 때 나올 색 (미리보기용). 못 흔들면 null.
export function shakePreview(state, i, rules = CLASSIC_RULES) {
  return canShake(state, i, rules) ? blendOf(state.bottles[i]) : null;
}

// 흔들기 실행. 반환: { state, at, color, from } 또는 불가 시 null
export function shake(state, i, rules = CLASSIC_RULES) {
  if (!canShake(state, i, rules)) return null;
  const next = cloneState(state);
  const before = next.bottles[i].slice();
  const color = blendOf(before);
  next.bottles[i] = new Array(before.length).fill(color);
  return { state: next, at: i, color, from: before };
}

export function applyMove(state, move, rules = CLASSIC_RULES) {
  return move.type === 'shake'
    ? shake(state, move.at, rules)
    : pour(state, move.from, move.to, rules);
}

// 탐색용 합법 수 나열. 무의미한 수는 쳐낸다:
// - 잠긴 병에서는 나갈 수 없다
// - 단색 병 → 빈 병 이동은 상태가 사실상 그대로라 제외
// - 흔들기는 항상 유의미하다 (되돌릴 수 없는 확정 행동)
export function legalMoves(state, rules = CLASSIC_RULES) {
  const moves = [];
  const n = state.bottles.length;

  for (let i = 0; i < n; i++) {
    if (canShake(state, i, rules)) moves.push({ type: 'shake', at: i });
  }

  for (let from = 0; from < n; from++) {
    const src = state.bottles[from];
    if (!src.length) continue;
    if (isLocked(state, from, rules)) continue;
    const uniform = isUniform(src);
    for (let to = 0; to < n; to++) {
      if (to === from) continue;
      if (uniform && state.bottles[to].length === 0) continue;
      if (canPour(state, from, to, rules)) moves.push({ type: 'pour', from, to });
    }
  }
  return moves;
}
