// 게임 상태: { capacity, bottles }
// bottles[i]는 색 문자열 배열, 인덱스 0이 병 바닥이고 마지막이 맨 위.

export function createState(capacity, bottles) {
  return { capacity, bottles: bottles.map((b) => b.slice()) };
}

export function cloneState(state) {
  return { capacity: state.capacity, bottles: state.bottles.map((b) => b.slice()) };
}

// 병 맨 위에서 이어지는 같은 색 구간
export function topRun(bottle) {
  const n = bottle.length;
  if (!n) return null;
  const color = bottle[n - 1];
  let count = 1;
  while (count < n && bottle[n - 1 - count] === color) count++;
  return { color, count };
}

export function isUniform(bottle) {
  if (!bottle.length) return false;
  for (let i = 1; i < bottle.length; i++) if (bottle[i] !== bottle[0]) return false;
  return true;
}

export function isComplete(state, i) {
  const b = state.bottles[i];
  return b.length === state.capacity && isUniform(b);
}

// 병 순서를 무시한 정규화 키 (탐색 중복 제거용)
export function stateKey(state) {
  return state.bottles.map((b) => b.join('')).sort().join(',');
}

// 승리: 모든 병이 (빈 병) 또는 (가득 찬 단색 병)이고,
// 완성된 색 목록이 목표 색 목록과 정확히 일치한다.
export function isWin(state, targets) {
  const done = [];
  for (let i = 0; i < state.bottles.length; i++) {
    const b = state.bottles[i];
    if (b.length === 0) continue;
    if (!isComplete(state, i)) return false;
    done.push(b[0]);
  }
  if (done.length !== targets.length) return false;
  return done.slice().sort().join('') === targets.slice().sort().join('');
}
