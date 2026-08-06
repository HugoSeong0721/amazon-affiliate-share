// 순수 게임 로직 — DOM 없음. 시드 RNG, 층 생성, 문 열기/등불 엿보기/챙겨 나가기 판정.
//
// 계약 두 가지, 테스트가 검증한다:
//  1) 결정론 — 같은 (daySeed, runIndex) + 같은 행동 순서 = 같은 던전, 같은 결과.
//     층은 내려가는 순서로만 생성되고 RNG는 그 순서로만 소비된다.
//  2) 정직함 — 층 위에 표시되는 구성(pips)은 문 뒤 내용물과 정확히 일치한다.
//     게임은 절대 거짓말하지 않는다. 확률을 읽고 배짱을 내는 것이 곧 실력이다.

export const CONFIG = {
  doorsPerFloor: 4,
  torchesPerDay: 3, // 하루에 주어지는 다이브 수 — 자정이 지나면 새 던전과 함께 리필
  lanternStart: 1,
  maxLanterns: 2,
};

// mulberry32 — 작고 결정적인 시드 RNG (형제 게임들과 동일)
export function makeRng(seed) {
  let s = seed >>> 0;
  return function rng() {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// FNV-1a — 날짜 문자열('2026-08-06')을 그날의 시드로. 전 세계가 같은 던전을 받는다.
export function hashSeed(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// 보상 곡선 — 깊을수록 단조 증가. 테스트가 단조성을 검증한다.
export function valueAt(floor) {
  return { coin: 10 * floor, gem: 40 * floor };
}

// 해골 수의 하한/상한 — 둘 다 깊이에 대해 단조 증가.
// 상한은 언제나 문 수 - 1: 어떤 층에도 안전한 문이 최소 하나는 있다.
export function skullBoundsAt(floor) {
  if (floor <= 1) return { min: 0, max: 0 }; // 1층은 무조건 안전 — 첫 손맛은 공짜다
  if (floor === 2) return { min: 1, max: 1 };
  if (floor <= 4) return { min: 1, max: 2 };
  if (floor <= 7) return { min: 2, max: 2 };
  return { min: 2, max: 3 };
}

export function gemChanceAt(floor) {
  return Math.min(0.4, 0.12 + 0.02 * floor);
}

export function lanternChanceAt(floor) {
  return floor >= 2 ? 0.22 : 0;
}

function shuffle(arr, rng) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// 층 하나를 생성한다. RNG 소비 순서는 고정: 해골 수 → 등불 → 보석 → 섞기.
export function makeFloor(rng, n) {
  const { min, max } = skullBoundsAt(n);
  const skulls = min + Math.floor(rng() * (max - min + 1));
  const doors = new Array(skulls).fill('skull');
  let rest = CONFIG.doorsPerFloor - skulls;
  if (rest > 0) {
    if (rng() < lanternChanceAt(n)) {
      doors.push('lantern');
      rest -= 1;
    }
  }
  if (rest > 0) {
    if (rng() < gemChanceAt(n)) {
      doors.push('gem');
      rest -= 1;
    }
  }
  while (rest-- > 0) doors.push('coin');
  shuffle(doors, rng);
  const comp = { coin: 0, gem: 0, lantern: 0, skull: 0 };
  for (const d of doors) comp[d] += 1;
  return { n, doors, comp };
}

// 다이브 하나를 시작한다. runIndex가 다르면 같은 날에도 배치가 다르다 —
// 하루 3번의 다이브는 각각 다른 던전이라 외워서 이기는 길이 없다.
export function newDive(daySeed, runIndex = 0) {
  const seed = ((daySeed >>> 0) ^ Math.imul(runIndex + 1, 0x9e3779b9)) >>> 0;
  const s = {
    seed,
    rng: makeRng(seed),
    runIndex,
    floorNum: 0,
    floor: null,
    carried: 0, // 지금 들고 있는 것 — 죽으면 전부 잃는다
    lanterns: CONFIG.lanternStart,
    peeked: [], // 이 층에서 등불로 미리 본 문들
    over: false,
    busted: false,
    banked: 0, // 챙겨 나가는 데 성공한 금액
    lost: 0, // 해골에게 뺏긴 금액 (연출용 기록)
  };
  descend(s);
  return s;
}

function descend(s) {
  s.floorNum += 1;
  s.floor = makeFloor(s.rng, s.floorNum);
  s.peeked = [];
}

// 문을 연다. 안전하면 자동으로 한 층 내려가고, 해골이면 다이브가 끝난다.
// 반환값은 연출용 스냅샷 — doors는 열던 순간의 층 전체 (해골이면 전부 까 보여준다).
export function openDoor(s, i) {
  if (s.over || i < 0 || i >= s.floor.doors.length) return null;
  const type = s.floor.doors[i];
  const v = valueAt(s.floorNum);
  const res = { type, gain: 0, floor: s.floorNum, doors: s.floor.doors.slice() };
  if (type === 'skull') {
    s.busted = true;
    s.over = true;
    s.lost = s.carried;
    s.carried = 0;
  } else if (type === 'coin') {
    res.gain = v.coin;
    s.carried += v.coin;
  } else if (type === 'gem') {
    res.gain = v.gem;
    s.carried += v.gem;
  } else if (type === 'lantern') {
    s.lanterns = Math.min(CONFIG.maxLanterns, s.lanterns + 1);
  }
  if (!s.over) descend(s);
  return res;
}

// 등불 하나를 태워 문 하나를 미리 본다. 내용물은 그대로 — 정보만 산다.
export function peekDoor(s, i) {
  if (s.over || s.lanterns <= 0 || i < 0 || i >= s.floor.doors.length) return null;
  if (s.peeked.includes(i)) return null;
  s.lanterns -= 1;
  s.peeked.push(i);
  return s.floor.doors[i];
}

// 들고 있는 것을 챙겨 지상으로 — 다이브는 여기서 끝난다. 빈손으로는 못 나간다(나갈 이유도 없다).
export function bankOut(s) {
  if (s.over || s.carried <= 0) return 0;
  s.banked = s.carried;
  s.over = true;
  return s.banked;
}
