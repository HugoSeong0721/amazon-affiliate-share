// 주차장 탈출 엔진 — 순수 로직. DOM 의존이 전혀 없어 브라우저와 Node 양쪽에서 돌아간다.
//
// 보드는 6×6. 차량은 {x, y, len, h}로 나타낸다 (h=true면 가로, 아니면 세로).
// 차량 0번이 항상 플레이어(택시)다: 가로 2칸, 출구 행에 산다.
// 차는 자기 축을 따라서만 미끄러진다. 한 번의 미끄러짐(거리 무관)이 한 수다.
//
// 소트 퍼즐과 달리 모든 수가 되돌릴 수 있어서 "막다른 길"이 존재하지 않는다 —
// 시작이 풀리는 판이면 어떤 순서로 밀어도 영원히 풀 수 있다. 그래서 이 게임에는
// 막다른 길 패널이 없고, 되돌리기는 오직 별점(수 아끼기)을 위해 존재한다.

export const W = 6;
export const H = 6;
export const EXIT_ROW = 2; // 출구는 이 행의 오른쪽 벽에 뚫려 있다
export const PLAYER = 0;

// 시드 난수 — 같은 시드는 언제나 같은 레벨을 만든다
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 점유 격자. 칸마다 차량 번호, 비었으면 -1.
export function occupancy(vehicles) {
  const g = new Int8Array(W * H).fill(-1);
  vehicles.forEach((v, i) => {
    for (let k = 0; k < v.len; k++) {
      const x = v.h ? v.x + k : v.x;
      const y = v.h ? v.y : v.y + k;
      g[y * W + x] = i;
    }
  });
  return g;
}

// 차량 i가 축을 따라 갈 수 있는 변수 좌표(가로차는 x, 세로차는 y)의 구간
export function rangeOf(vehicles, i, g = occupancy(vehicles)) {
  const v = vehicles[i];
  const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? -2 : g[y * W + x]);
  let min = v.h ? v.x : v.y;
  let max = min;
  if (v.h) {
    while (at(min - 1, v.y) === -1) min--;
    while (at(max + v.len, v.y) === -1) max++;
  } else {
    while (at(v.x, min - 1) === -1) min--;
    while (at(v.x, max + v.len) === -1) max++;
  }
  return { min, max };
}

// 검사 없이 차량 i를 to로 옮긴 새 배열 (호출자가 rangeOf로 합법성을 보장한다)
export function moveVehicle(vehicles, i, to) {
  return vehicles.map((v, k) => (k === i ? (v.h ? { ...v, x: to } : { ...v, y: to }) : v));
}

export function coordOf(v) {
  return v.h ? v.x : v.y;
}

// 플레이어가 오른쪽 벽에 닿으면 탈출이다
export function isWin(vehicles) {
  const p = vehicles[PLAYER];
  return p.x === W - p.len;
}

// 상태 키 — 고정 속성(축·길이·고정 좌표)은 변하지 않으므로 변수 좌표만 담으면 된다
export function keyOf(vehicles) {
  let k = '';
  for (const v of vehicles) k += coordOf(v);
  return k;
}

function fromKey(template, key) {
  return template.map((v, i) => {
    const c = key.charCodeAt(i) - 48;
    return v.h ? { ...v, x: c } : { ...v, y: c };
  });
}

// BFS 솔버. 모든 이웃이 정확히 한 수 거리이므로 BFS가 곧 최소 수다.
// 반환: { solved, moves: [{v, to}], par, nodes, exhausted }
export function solve(vehicles, { maxNodes = 500000 } = {}) {
  if (isWin(vehicles)) return { solved: true, moves: [], par: 0, nodes: 0, exhausted: false };

  const start = keyOf(vehicles);
  const seen = new Map([[start, null]]); // key → { prev, move }
  const queue = [start];
  const goalX = W - vehicles[PLAYER].len;
  let goalKey = null;
  let nodes = 0;

  for (let qi = 0; qi < queue.length && !goalKey; qi++) {
    const key = queue[qi];
    if (++nodes > maxNodes) return { solved: false, moves: [], par: 0, nodes, exhausted: false };
    const vs = fromKey(vehicles, key);
    const g = occupancy(vs);

    for (let i = 0; i < vs.length && !goalKey; i++) {
      const { min, max } = rangeOf(vs, i, g);
      const cur = coordOf(vs[i]);
      for (let to = min; to <= max; to++) {
        if (to === cur) continue;
        const nk = key.slice(0, i) + to + key.slice(i + 1);
        if (seen.has(nk)) continue;
        seen.set(nk, { prev: key, move: { v: i, to } });
        if (i === PLAYER && to === goalX) {
          goalKey = nk;
          break;
        }
        queue.push(nk);
      }
    }
  }

  if (!goalKey) return { solved: false, moves: [], par: 0, nodes, exhausted: true };

  const moves = [];
  for (let k = goalKey; seen.get(k); k = seen.get(k).prev) moves.unshift(seen.get(k).move);
  return { solved: true, moves, par: moves.length, nodes, exhausted: false };
}

function overlapsAny(g, v) {
  for (let k = 0; k < v.len; k++) {
    const x = v.h ? v.x + k : v.x;
    const y = v.h ? v.y : v.y + k;
    if (g[y * W + x] !== -1) return true;
  }
  return false;
}

// 레벨 생성: 차를 무작위로 깔고 솔버로 "풀 수 있음"을 확정한다.
// 출구 행의 가로차는 플레이어 말고는 금지 — 그 행에서 절대 비킬 수 없어 판을 영구히 막는다.
export function generate({ seed, cars, maxNodes = 500000 }) {
  const rng = mulberry32(seed);
  const ri = (n) => Math.floor(rng() * n);

  // 플레이어는 출구까지 최소 한 칸은 달리게 (x 0..3)
  const vehicles = [{ x: ri(W - 2), y: EXIT_ROW, len: 2, h: true }];
  const hRows = [0, 1, 3, 4, 5];

  let guard = cars * 40;
  while (vehicles.length < cars && guard-- > 0) {
    const h = rng() < 0.45;
    const len = rng() < 0.7 ? 2 : 3;
    const v = h
      ? { x: ri(W - len + 1), y: hRows[ri(hRows.length)], len, h: true }
      : { x: ri(W), y: ri(H - len + 1), len, h: false };
    if (overlapsAny(occupancy(vehicles), v)) continue;
    vehicles.push(v);
  }
  if (vehicles.length < cars) return null;

  const r = solve(vehicles, { maxNodes });
  if (!r.solved || r.par < 1) return null;
  return { vehicles, moves: r.moves, par: r.par };
}

// --- 직렬화 (levels-data.js 압축 형식) ---
// 차량 하나 = 4글자 "xyLh"  (예: "0221" = x0 y2 len2 가로)
// 수 하나  = 2글자, 차량 번호(base36) + 목표 좌표  (예: "a3" = 10번 차를 3으로)

export function encodeVehicles(vehicles) {
  return vehicles.map((v) => `${v.x}${v.y}${v.len}${v.h ? 1 : 0}`).join('');
}

export function decodeVehicles(str) {
  const out = [];
  for (let i = 0; i + 3 < str.length; i += 4) {
    out.push({
      x: Number(str[i]),
      y: Number(str[i + 1]),
      len: Number(str[i + 2]),
      h: str[i + 3] === '1',
    });
  }
  return out;
}

export function encodeMoves(moves) {
  return moves.map((m) => m.v.toString(36) + m.to).join('');
}

export function decodeMoves(str) {
  const out = [];
  for (let i = 0; i + 1 < str.length; i += 2) {
    out.push({ v: parseInt(str[i], 36), to: Number(str[i + 1]) });
  }
  return out;
}
