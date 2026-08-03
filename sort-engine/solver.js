// 가중 A* (greedy 성향) 솔버.
// solved=false && exhausted=true 이면 탐색 공간을 전부 확인한 것 → 확실히 풀 수 없는 상태.
// solved=false && exhausted=false 는 노드 예산 초과 → 판단 불가.

import { isWin, isUniform, stateKey } from './state.js';
import { legalMoves, applyMove, CLASSIC_RULES } from './moves.js';

class MinHeap {
  constructor() { this.a = []; }
  get size() { return this.a.length; }
  push(item) {
    const a = this.a;
    a.push(item);
    let i = a.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (a[p].f <= a[i].f) break;
      [a[p], a[i]] = [a[i], a[p]];
      i = p;
    }
  }
  pop() {
    const a = this.a;
    if (!a.length) return null;
    const top = a[0];
    const last = a.pop();
    if (a.length) {
      a[0] = last;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1;
        const r = l + 1;
        let m = i;
        if (l < a.length && a[l].f < a[m].f) m = l;
        if (r < a.length && a[r].f < a[m].f) m = r;
        if (m === i) break;
        [a[m], a[i]] = [a[i], a[m]];
        i = m;
      }
    }
    return top;
  }
}

// 휴리스틱: 아직 못 만든 목표 수 + 물감이 흩어진 정도.
// 같은 색이 여러 병에 나뉘어 있을수록 모으는 데 수가 든다.
function heuristic(state, targets) {
  const done = [];
  const spread = new Map();
  for (const b of state.bottles) {
    if (!b.length) continue;
    if (b.length === state.capacity && isUniform(b)) done.push(b[0]);
    for (const c of new Set(b)) spread.set(c, (spread.get(c) || 0) + 1);
  }
  const remaining = targets.slice();
  for (const c of done) {
    const idx = remaining.indexOf(c);
    if (idx >= 0) remaining.splice(idx, 1);
  }
  let scatter = 0;
  for (const count of spread.values()) scatter += count - 1;
  return remaining.length * 2 + scatter;
}

export function solve(state, targets, rules = CLASSIC_RULES, opts = {}) {
  const maxNodes = opts.maxNodes ?? 200000;
  const maxDepth = opts.maxDepth ?? 120;
  const weight = opts.weight ?? 3;

  if (isWin(state, targets)) return { solved: true, moves: [], nodes: 0, exhausted: false };

  const heap = new MinHeap();
  const visited = new Set([stateKey(state)]);
  heap.push({ state, moves: [], f: heuristic(state, targets) * weight });
  let nodes = 0;

  while (heap.size > 0) {
    if (nodes >= maxNodes) return { solved: false, nodes, exhausted: false };
    const cur = heap.pop();
    nodes++;
    if (cur.moves.length >= maxDepth) continue;
    for (const mv of legalMoves(cur.state, rules)) {
      const res = applyMove(cur.state, mv, rules);
      if (!res) continue;
      const key = stateKey(res.state);
      if (visited.has(key)) continue;
      visited.add(key);
      const moves = cur.moves.concat([mv]);
      if (isWin(res.state, targets)) return { solved: true, moves, nodes, exhausted: false };
      heap.push({ state: res.state, moves, f: moves.length + heuristic(res.state, targets) * weight });
    }
  }
  return { solved: false, nodes, exhausted: true };
}
