// 레벨 스펙. 실제 배치는 sort-engine의 generateLevel(seed 고정)로 만들어져
// 언제나 같은 레벨이 나오고, 생성 시점에 솔버로 "풀 수 있음"이 보장된다.
//
// 규칙은 클래식이다: 같은 색 위 또는 빈 튜브에만 옮길 수 있고, 색은 절대 변하지 않는다.
// 그래서 색 이름은 그냥 이름표다 — 몇 가지든 쓸 수 있다.
//
// 난이도는 짐작하지 않고 **측정했다.** 아래 CONFIGS의 median은 각 설정으로 레벨을
// 여러 개 뽑아 솔버가 찾은 최소 수의 중앙값이다 (tools/probe 참고).
// 굽는 단계에서 전체를 이 최소 수 기준으로 정렬하므로 곡선이 단조 증가한다.

export const CAPACITY = 4; // 기본값. 레벨마다 다를 수 있다.

// 색 순서는 고정. 앞에서부터 필요한 만큼 쓴다.
export const PALETTE = ['R', 'O', 'Y', 'G', 'C', 'B', 'P', 'K'];

// [용량, 색 수, 빈 튜브 수, 측정된 최소 수 중앙값]
const CONFIGS = [
  [4, 2, 2, 4], [4, 2, 1, 5], [5, 2, 1, 5], [4, 3, 1, 6], [5, 2, 2, 6], [4, 3, 2, 7],
  [5, 3, 1, 9], [4, 4, 1, 11], [5, 3, 2, 11], [4, 5, 1, 13], [4, 4, 2, 14], [5, 4, 1, 14],
  [4, 5, 2, 17], [5, 4, 2, 17], [4, 6, 2, 18], [4, 6, 1, 18], [5, 5, 2, 21], [5, 5, 1, 21],
  [4, 7, 1, 22], [4, 7, 2, 23], [4, 8, 1, 24], [5, 6, 1, 24], [5, 6, 2, 25], [4, 8, 2, 27],
  [5, 7, 1, 28], [5, 7, 2, 30], [5, 8, 2, 33], [5, 8, 1, 33],
];

// 쉬운 설정은 적게, 어려운 설정은 많이 준다.
// 초반에 비슷한 난이도가 길게 늘어지면 지루해지고, 후반은 오래 붙잡아야 하므로.
function countFor(median) {
  if (median <= 7) return 3;
  if (median <= 25) return 5;
  // 최상단 난이도는 빈 튜브가 하나뿐이라 풀 수 있는 배치 자체가 드물다.
  // 생성 실패를 감안해 시드를 넉넉히 준다 (실패한 건 굽는 단계에서 걸러진다).
  if (median >= 33) return 9;
  return 6;
}

// 측정된 중앙값 주변으로 허용 구간을 준다. 너무 좁으면 생성이 실패하고,
// 너무 넓으면 같은 설정 안에서 난이도가 튄다.
function bandFor(median) {
  const slack = median <= 7 ? 2 : Math.max(3, Math.round(median * 0.18));
  return [Math.max(3, median - slack), median + slack];
}

// 굽는 도구와 테스트가 같은 스펙 목록을 보도록 한 곳에서 만든다.
export function buildSpecs() {
  const specs = [];
  CONFIGS.forEach(([capacity, colors, extraEmpty, median], ci) => {
    const [minMoves, maxMoves] = bandFor(median);
    for (let j = 0; j < countFor(median); j++) {
      specs.push({
        targets: PALETTE.slice(0, colors),
        capacity,
        extraEmpty,
        minMoves,
        maxMoves,
        seed: 5000 + ci * 100 + j,
      });
    }
  });
  return specs;
}

export const LEVEL_SPECS = buildSpecs();
