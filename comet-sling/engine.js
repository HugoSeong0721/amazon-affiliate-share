// 순수 게임 로직 — DOM/캔버스 없음. 시드 RNG, 트랙 생성, 고정 스텝 물리, 충돌, 점수.
//
// 결정론이 이 파일의 계약이다: 같은 시드 + 같은 입력 시퀀스 = 같은 런.
// 물리는 고정 dt(1/120초)로만 전진하고, 트랙은 앵커 인덱스 순서로만 생성되므로
// ensureTrack을 언제 몇 번 부르든 결과가 같다. 테스트가 이 계약을 검증한다.

export const DT = 1 / 120; // 고정 물리 스텝(초)

// 월드 좌표: y는 위로 증가. 코멧은 (0,0)에서 출발해 위로 난다.
export const WORLD = {
  halfW: 50,          // 통로 반폭 — 벽에 닿으면 죽는다
  cometR: 2.2,        // 코멧 반지름
  hazardR: 5.5,       // 소행성 반지름
  captureR: 38,       // 이 거리 안의 앵커를 잡을 수 있다 (홀드 중 자동)
  orbitMin: 11,       // 궤도 반지름 하한 — 너무 붙어서 잡으면 이만큼 밀어낸다
  orbitMax: 26,       // 궤도 반지름 상한
  nearMissBand: 5,    // 소행성을 이 여유 안으로 스치면 보너스
  fallLimit: 130,     // 최고점에서 이만큼 떨어지면 죽는다 (카메라 밖)
  genMargin: 260,     // 코멧 위로 이만큼 미리 트랙을 깔아 둔다
};

// mulberry32 — 작고 결정적인 시드 RNG
export function makeRng(seed) {
  let s = seed >>> 0;
  return function rng() {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 높이에 따른 난이도 곡선 — 전부 단조. 테스트가 단조성을 검증한다.
// 첫 플레이테스트 피드백("너무 어려워")에 맞춰 시작을 느리고 너그럽게,
// 정점은 그대로 두어 상급자의 목표는 지킨다.
export function paramsAt(height) {
  const h = Math.max(0, height);
  const ramp = 1 - Math.exp(-h / 1300); // 0 → 1 포화 곡선 (완만하게)
  return {
    speed: 32 + 68 * ramp,                          // 32 → 100
    hazardChance: Math.min(0.85, 0.08 + 1.0 * ramp), // 구간당 소행성 확률
    maxHazards: h < 250 ? 1 : h < 2500 ? 2 : 3,     // 구간당 최대 소행성 수 (후반 3개)
    anchorJitter: 14 + 16 * ramp,                   // 앵커 좌우 흔들림 폭
    // 500부터 소행성이 좌우로 흔들리기 시작 — 진폭이 서서히 자라 10에서 멈춘다
    sway: Math.min(10, Math.max(0, (h - 500) / 250)),
    // 자석 조준의 관용각 — 배우는 동안 25°, 올라갈수록 촘촘해져 14°에서 멈춘다.
    // 후반의 "어려움"이 반사신경이 아니라 조준 정밀도에서 오게 한다.
    snapDeg: Math.max(14, 25 - h / 450),
  };
}

// 흔들리는 소행성의 현재 x — 시간의 순수 함수라 결정론이 유지된다
export function hazardXAt(hz, t) {
  return hz.swayA ? hz.x + hz.swayA * Math.sin(hz.swayW * t + hz.swayP) : hz.x;
}

// 초반 에임 어시스트 — 릴리즈 방향을 위쪽으로 이만큼 끌어당긴다.
// 완벽한 타이밍이 아니어도 대충 위로 가게 해서, 조작을 배우는 동안 벽에 덜 부딪히게.
// 높이 800에서 완전히 사라진다 (단조 감소).
export function assistAt(height) {
  return Math.max(0, 0.38 * (1 - Math.max(0, height) / 800));
}

// 궤도 회전 각속도 — 순수하게 speed/r 로 하면 작은 원이 정신없이 빨라진다
// (반지름 11 vs 26 이 2.4배 차이). 유효 반지름을 눌러서 차이는 남기되 얌전하게:
// 작은 원은 '살짝 빠르고', 큰 원은 '여유로운' 정도 (약 1.5배 차이).
export function orbitOmega(speed, r) {
  return speed / (0.55 * r + 10);
}

// 자석 조준 — 릴리즈 방향이 근처 앵커와 관용각(높이에 따라 25°→14°) 이내로 맞으면
// 그 앵커로 스냅한다. "옆으로 튕겨나간다"는 느낌의 해독제.
const SNAP_MAX_DIST = 230;

// 지금 놓으면 날아갈 방향 (순수 함수 — 릴리즈와 조준선 표시가 같은 값을 쓴다).
// 반환: { dx, dy, snapped } — snapped 는 스냅된 앵커 인덱스 또는 null
export function aim(state) {
  const o = state.orbit;
  if (!o) return { dx: state.dirX, dy: state.dirY, snapped: null };
  let dx = -Math.sin(o.theta) * o.dir;
  let dy = Math.cos(o.theta) * o.dir + assistAt(state.height);
  const len = Math.hypot(dx, dy);
  dx /= len;
  dy /= len;

  // 진행 방향과 가장 잘 맞는 앵커를 찾는다 (지금 돌고 있는 앵커는 제외).
  // 소행성이 막고 있는 앵커에는 스냅하지 않는다 — 금색으로 잠긴 조준선은
  // "여기로 가면 닿는다"는 약속이므로, 가는 길에 죽으면 거짓말이 된다.
  let best = null, bestCos = Math.cos((paramsAt(state.height).snapDeg * Math.PI) / 180);
  for (let i = state.anchorFrom || 0; i < state.anchors.length; i++) {
    if (i === o.i) continue;
    const a = state.anchors[i];
    if (a.y > state.y + SNAP_MAX_DIST) break;       // 위로 정렬 — 더 볼 필요 없다
    const ax = a.x - state.x, ay = a.y - state.y;
    const d = Math.hypot(ax, ay);
    if (d < WORLD.orbitMin || d > SNAP_MAX_DIST) continue;
    const cos = (ax * dx + ay * dy) / d;
    if (cos > bestCos && pathIsClear(state, a.x, a.y)) { bestCos = cos; best = i; }
  }
  if (best !== null) {
    const a = state.anchors[best];
    const d = Math.hypot(a.x - state.x, a.y - state.y);
    return { dx: (a.x - state.x) / d, dy: (a.y - state.y) / d, snapped: best };
  }
  return { dx, dy, snapped: null };
}

// 코멧에서 (tx,ty)까지 직선이 소행성에 막히지 않는지 (창 안의 소행성만 본다).
// 흔들리는 소행성은 지금 위치가 아니라 '흔들릴 수 있는 범위 전체'를 피한다 —
// 금색 조준선은 안전 약속이라, 날아가는 동안 흔들려 들어와도 안 죽어야 한다.
function pathIsClear(state, tx, ty) {
  const clear = WORLD.hazardR + WORLD.cometR + 1;
  const top = Math.max(state.y, ty) + 200;
  for (let i = state.hazardFrom || 0; i < state.hazards.length; i++) {
    const hz = state.hazards[i];
    if (hz.y > top) break;
    if (distToSegment(hz.x, hz.y, state.x, state.y, tx, ty) < clear + (hz.swayA || 0)) return false;
  }
  return true;
}

// ----- 트랙 생성 (앵커 순서대로만 소비되는 RNG 스트림) -----

function nextAnchor(prev, rng, p) {
  const dy = 58 + rng() * 26;
  const maxX = WORLD.halfW - WORLD.orbitMax - WORLD.cometR - 2;
  let x = prev.x + (rng() * 2 - 1) * p.anchorJitter * 2;
  x = Math.max(-maxX, Math.min(maxX, x));
  return { x, y: prev.y + dy };
}

function distToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2));
  const cx = ax + t * dx, cy = ay + t * dy;
  return Math.hypot(px - cx, py - cy);
}

// 구간(a→b) 사이에 소행성을 놓되, 플레이 가능성 불변식을 지킨다:
//  - 어떤 앵커와도 orbitMax + hazardR + cometR + 3 이상 떨어진다 (궤도 중 절대 안 부딪힘)
//  - a→b 직선에서 hazardR + cometR + 4 이상 떨어진다 (이상적인 비행선은 항상 열려 있다)
//  - 통로 안에 완전히 들어간다
function placeHazards(a, b, allAnchors, rng, p) {
  const out = [];
  let n = 0;
  if (rng() < p.hazardChance) {
    n = 1;
    if (p.maxHazards > 1 && rng() < 0.35) n++;
    if (p.maxHazards > 2 && rng() < 0.3) n++;
  }
  for (let k = 0; k < n; k++) {
    // 흔들리는 소행성은 진폭만큼 모든 안전거리를 더 벌린다 — 흔들려도 불변식이 깨지지 않게
    const swayA = p.sway > 0 ? p.sway * (0.35 + 0.65 * rng()) : 0;
    const swayW = 0.6 + rng() * 0.8;      // 흔들림 각속도(rad/s)
    const swayP = rng() * Math.PI * 2;    // 위상
    const anchorClear = WORLD.orbitMax + WORLD.hazardR + WORLD.cometR + 3 + swayA;
    const lineClear = WORLD.hazardR + WORLD.cometR + 4 + swayA;
    const maxX = WORLD.halfW - WORLD.hazardR - 1 - swayA;
    for (let tries = 0; tries < 25; tries++) {
      const y = a.y + (0.25 + rng() * 0.5) * (b.y - a.y);
      const x = (rng() * 2 - 1) * maxX;
      if (distToSegment(x, y, a.x, a.y, b.x, b.y) < lineClear) continue;
      if (allAnchors.some((an) => Math.hypot(an.x - x, an.y - y) < anchorClear)) continue;
      if (out.some((hz) => Math.hypot(hz.x - x, hz.y - y) < WORLD.hazardR * 2 + 2 + swayA + hz.swayA)) continue;
      out.push({ x, y, swayA, swayW, swayP });
      break;
    }
  }
  return out;
}

// ----- 런 상태 -----

export function newRun(seed) {
  const state = {
    seed: seed >>> 0,
    rng: makeRng(seed),
    t: 0,
    mode: 'flying',          // 'flying' | 'orbit'
    x: 0, y: 0,
    dirX: 0, dirY: 1,        // 비행 방향 (단위벡터)
    orbit: null,             // { i, r, theta, dir }
    height: 0,               // 도달 최고 y — 점수의 뼈대
    sparks: 0,               // 니어미스 횟수
    dead: false,
    deathCause: null,        // 'wall' | 'hazard' | 'fell'
    anchors: [{ x: 0, y: 64 }],
    hazards: [],
    // 스캔 시작점 — 코멧 아래로 한참 지난 것들은 영원히 무관해지므로 건너뛴다.
    // (인덱스는 그대로 두므로 orbit.i / _credited 가 안전하다)
    anchorFrom: 0,
    hazardFrom: 0,
    // 방금 놓은 앵커 — 사거리를 벗어나기 전까지는 다시 잡히지 않는다.
    // (없으면 놓자마자 같은 앵커를 다시 잡아 제자리를 뱅뱅 돈다)
    noLatch: -1,
    _credited: new Set(),    // 니어미스 중복 방지 (hazard 인덱스)
    _held: false,
    events: [],              // 프레임 이벤트 큐 — 렌더러/사운드가 비운다
  };
  ensureTrack(state, WORLD.genMargin);
  return state;
}

// upToY까지 트랙을 깔아 둔다. 앵커 i → i+1 순서로만 RNG를 소비하므로 결정적이다.
export function ensureTrack(state, upToY) {
  while (state.anchors[state.anchors.length - 1].y < upToY) {
    const prev = state.anchors[state.anchors.length - 1];
    const p = paramsAt(prev.y);
    const next = nextAnchor(prev, state.rng, p);
    state.anchors.push(next);
    for (const hz of placeHazards(prev, next, state.anchors, state.rng, p)) state.hazards.push(hz);
  }
}

export function score(state) {
  return Math.floor(state.height / 4) + state.sparks * 25;
}

function tryLatch(state) {
  let best = -1, bestD = WORLD.captureR;
  for (let i = state.anchorFrom; i < state.anchors.length; i++) {
    if (i === state.noLatch) continue;              // 방금 놓은 앵커는 건너뛴다
    const a = state.anchors[i];
    if (a.y > state.y + WORLD.captureR) break;      // 위로 정렬 — 더 볼 필요 없다
    if (a.y < state.y - WORLD.captureR) continue;   // 한참 지난 앵커는 안 잡는다
    const d = Math.hypot(a.x - state.x, a.y - state.y);
    if (d < bestD) { bestD = d; best = i; }
  }
  if (best < 0) return false;
  const a = state.anchors[best];
  const relX = state.x - a.x, relY = state.y - a.y;
  const r = Math.max(WORLD.orbitMin, Math.min(WORLD.orbitMax, bestD));
  // 진행 방향이 이어지도록 회전 방향을 고른다: cross(rel, dir) > 0 → 반시계
  const cross = relX * state.dirY - relY * state.dirX;
  const dir = cross >= 0 ? 1 : -1;
  state.orbit = { i: best, r, theta: Math.atan2(relY, relX), dir };
  state.mode = 'orbit';
  state.events.push({ type: 'latch', i: best });
  return true;
}

function release(state) {
  // 접선 + 에임 어시스트 + 자석 조준 — 조준선(aim)이 보여준 그대로 날아간다
  const a = aim(state);
  state.dirX = a.dx;
  state.dirY = a.dy;
  state.noLatch = state.orbit.i;
  state.orbit = null;
  state.mode = 'flying';
  state.events.push({ type: 'release', snapped: a.snapped });
}

function die(state, cause) {
  state.dead = true;
  state.deathCause = cause;
  state.events.push({ type: 'death', cause });
}


// 한 물리 스텝. input = { hold: boolean }
export function step(state, input) {
  if (state.dead) return state;
  state.t += DT;
  const p = paramsAt(state.height);
  const held = !!input.hold;

  // 홀드 에지 처리 — 잡기/놓기
  if (state.mode === 'orbit' && !held) release(state);
  if (state.mode === 'flying' && held) tryLatch(state); // 사거리 밖이면 계속 날면서 다음 스텝에 재시도

  if (state.mode === 'orbit') {
    const o = state.orbit;
    const a = state.anchors[o.i];
    o.theta += o.dir * orbitOmega(p.speed, o.r) * DT;
    state.x = a.x + Math.cos(o.theta) * o.r;
    state.y = a.y + Math.sin(o.theta) * o.r;
  } else {
    state.x += state.dirX * p.speed * DT;
    state.y += state.dirY * p.speed * DT;
  }
  state._held = held;

  if (state.y > state.height) state.height = state.y;
  ensureTrack(state, state.y + WORLD.genMargin);

  // 방금 놓은 앵커의 사거리를 벗어났으면 다시 잡을 수 있게 풀어 준다
  if (state.noLatch >= 0) {
    const a = state.anchors[state.noLatch];
    if (!a || Math.hypot(a.x - state.x, a.y - state.y) > WORLD.captureR + 4) state.noLatch = -1;
  }

  // 창(window) 전진 — 최고점에서 fallLimit 아래로 사라진 것들은 다시 만날 수 없다.
  // 이걸 안 하면 트랙이 길어질수록 매 스텝의 스캔이 무한히 늘어 후반에 끊긴다.
  const cutoff = state.height - WORLD.fallLimit - 80;
  while (state.anchorFrom < state.anchors.length - 1 && state.anchors[state.anchorFrom].y < cutoff) {
    state.anchorFrom++;
  }
  while (state.hazardFrom < state.hazards.length && state.hazards[state.hazardFrom].y < cutoff) {
    state.hazardFrom++;
  }

  // 죽음 판정
  if (Math.abs(state.x) > WORLD.halfW - WORLD.cometR) return die(state, 'wall'), state;
  if (state.y < state.height - WORLD.fallLimit) return die(state, 'fell'), state;

  // 소행성: 충돌 + 니어미스 (지나간 것은 건너뛴다)
  for (let i = state.hazardFrom; i < state.hazards.length; i++) {
    const hz = state.hazards[i];
    // 소행성은 구간 안에서 y가 조금 뒤섞일 수 있으므로, 한 구간보다 훨씬 넉넉히 지나서 끊는다
    if (hz.y > state.y + 200) break;
    const hx = hazardXAt(hz, state.t);

    if (hz.y < state.y - 60) continue;
    const d = Math.hypot(hx - state.x, hz.y - state.y);
    if (d < WORLD.hazardR + WORLD.cometR) return die(state, 'hazard'), state;
    if (d < WORLD.hazardR + WORLD.cometR + WORLD.nearMissBand && !state._credited.has(i)) {
      state._credited.add(i);
      state.sparks += 1;
      state.events.push({ type: 'spark', x: hx, y: hz.y });
    }
  }
  return state;
}

// 이벤트 큐를 비우며 반환 — 렌더러/사운드용
export function drainEvents(state) {
  const ev = state.events;
  state.events = [];
  return ev;
}
