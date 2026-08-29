// 순수 게임 로직 — DOM/캔버스 없음. 고정 스텝 이동, 드롭 판정(자르기/퍼펙트), 속도 곡선.
//
// 결정론이 계약이다: 같은 시드 + 같은 스텝에서의 드롭 = 같은 탑.
// 물리는 고정 dt(1/120초)로만 전진하고, 판정은 전부 이 파일의 순수 함수다.
// 테스트가 이 계약과 자르기 수학을 검증한다.

export const DT = 1 / 120; // 고정 물리 스텝(초)

export const CONFIG = {
  baseW: 100, // 첫 블록 폭 (월드 단위)
  blockH: 14, // 블록 높이
  travel: 120, // 움직이는 블록 중심의 왕복 범위 (±)
  perfectEps: 3.5, // 이 오차 안이면 퍼펙트 — 폭이 깎이지 않는다
  regrowEvery: 5, // 연속 퍼펙트 n번마다
  regrowAmount: 10, // 폭이 이만큼 회복된다 (baseW 상한)
  speedBase: 85, // 유닛/초
  speedGain: 2.4, // 층당 증가
  speedMax: 275,
};

// mulberry32 — 작고 결정적인 시드 RNG (형제 게임들과 동일. 여기서는 색상 시작점에만 쓴다)
export function makeRng(seed) {
  let s = seed >>> 0;
  return function rng() {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 속도 곡선 — 층수에 대해 단조 증가, 상한 있음. 테스트가 검증한다.
export function speedAt(floor) {
  return Math.min(CONFIG.speedMax, CONFIG.speedBase + CONFIG.speedGain * floor);
}

export function newRun(seed = 0) {
  const rng = makeRng(seed);
  return {
    seed,
    hue0: Math.floor(rng() * 360), // 탑 색의 시작점 — 시드가 하는 일의 전부
    floors: [{ x: 0, w: CONFIG.baseW }], // 바닥 블록
    moving: { x: -CONFIG.travel, dir: 1, w: CONFIG.baseW },
    combo: 0, // 연속 퍼펙트
    over: false,
  };
}

// 층수 = 쌓아 올린 블록 수 (바닥 제외) — 점수 그 자체
export function score(s) {
  return s.floors.length - 1;
}

// 고정 스텝 하나만큼 움직이는 블록을 전진시킨다. 가장자리에서 방향을 튕긴다.
export function step(s) {
  if (s.over) return;
  const m = s.moving;
  m.x += m.dir * speedAt(score(s)) * DT;
  if (m.x > CONFIG.travel) {
    m.x = CONFIG.travel - (m.x - CONFIG.travel);
    m.dir = -1;
  } else if (m.x < -CONFIG.travel) {
    m.x = -CONFIG.travel + (-CONFIG.travel - m.x);
    m.dir = 1;
  }
}

// 드롭 — 이 게임의 유일한 입력. 결과는 셋 중 하나:
//   perfect: 오차가 perfectEps 안 — 폭 유지, 콤보 증가, regrowEvery마다 폭 회복
//   cut:     겹친 만큼만 남고, 삐져나온 조각은 잘려 떨어진다
//   miss:    겹침이 없다 — 게임 오버
export function drop(s) {
  if (s.over) return null;
  const top = s.floors[s.floors.length - 1];
  const m = s.moving;
  const dx = m.x - top.x;

  if (Math.abs(dx) <= CONFIG.perfectEps) {
    s.combo += 1;
    let w = m.w;
    if (s.combo % CONFIG.regrowEvery === 0) {
      w = Math.min(CONFIG.baseW, w + CONFIG.regrowAmount); // 보상: 좁아진 탑이 숨을 돌린다
    }
    s.floors.push({ x: top.x, w });
    spawnNext(s, w);
    return { type: 'perfect', combo: s.combo, floor: score(s) };
  }

  const left = Math.max(top.x - top.w / 2, m.x - m.w / 2);
  const right = Math.min(top.x + top.w / 2, m.x + m.w / 2);
  const overlap = right - left;

  if (overlap <= 0) {
    s.over = true;
    return { type: 'miss', floor: score(s) };
  }

  s.combo = 0;
  const newX = (left + right) / 2;
  // 잘려 나가는 조각 — 렌더러가 떨어뜨리는 연출에 쓴다
  const cutW = m.w - overlap;
  const cutX = dx > 0 ? right + cutW / 2 : left - cutW / 2;
  s.floors.push({ x: newX, w: overlap });
  spawnNext(s, overlap);
  return { type: 'cut', floor: score(s), cut: { x: cutX, w: cutW, side: dx > 0 ? 1 : -1 } };
}

// 다음 블록은 반대편에서 나온다 — 리듬이 좌우로 흔들린다
function spawnNext(s, w) {
  const fromLeft = score(s) % 2 === 1;
  s.moving = {
    x: fromLeft ? -CONFIG.travel : CONFIG.travel,
    dir: fromLeft ? 1 : -1,
    w,
  };
}
