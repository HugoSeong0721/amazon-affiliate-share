// 색 정의와 혼합 규칙 (RYB 물감 모델)
// 1차색 둘을 섞으면 2차색이 된다. 2차색은 더 이상 섞이지 않는다.

export const PRIMARIES = ['R', 'Y', 'B'];
export const SECONDARIES = ['O', 'G', 'P'];

const MIX_TABLE = {
  'R|Y': 'O', // 빨강 + 노랑 = 주황
  'B|Y': 'G', // 노랑 + 파랑 = 초록
  'B|R': 'P', // 빨강 + 파랑 = 보라
};

export function isPrimary(color) {
  return PRIMARIES.includes(color);
}

// 두 색이 만났을 때의 결과 색. 같은 색이면 그대로, 섞을 수 없는 조합이면 null.
export function mixOf(a, b) {
  if (a === b) return a;
  return MIX_TABLE[[a, b].sort().join('|')] ?? null;
}

// 2차색을 구성하는 1차색 쌍. 1차색이 들어오면 null.
export function componentsOf(color) {
  for (const [pair, result] of Object.entries(MIX_TABLE)) {
    if (result === color) return pair.split('|');
  }
  return null;
}

// 물감 한 통을 흔들었을 때 나오는 색.
// - 전부 같은 색이면 그 색 (흔들 필요 없음)
// - 서로 다른 두 1차색이 정확히 반반이면 2차색
// - 그 외(비율이 안 맞거나, 3색 이상이거나, 2차색이 섞여 있으면)는 null = 섞을 수 없음
// 순서는 상관없다. 중요한 건 비율뿐이다.
export function blendOf(units) {
  if (!units.length) return null;
  const counts = new Map();
  for (const u of units) counts.set(u, (counts.get(u) || 0) + 1);
  if (counts.size === 1) return units[0];
  if (counts.size !== 2) return null;
  const [[a, ca], [b, cb]] = [...counts];
  if (ca !== cb) return null;
  if (!isPrimary(a) || !isPrimary(b)) return null;
  return mixOf(a, b);
}
