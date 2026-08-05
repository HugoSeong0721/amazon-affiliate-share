// 레벨 스펙. 실제 배치는 engine의 generate(seed 고정)로 만들어져 언제나 같은 레벨이
// 나오고, 생성 시점에 BFS 솔버로 "풀 수 있음"과 최소 수(par)가 확정된다.
//
// 난이도는 짐작하지 않고 측정한다: 여러 시드로 후보를 잔뜩 만들고 par를 잰 뒤,
// 굽는 단계에서 원하는 곡선에 가장 가까운 판을 고른다. 무작위 배치에서 par가 높은
// 판은 드물기 때문에 "목표 par에 딱 맞춰 생성"이 아니라 "많이 만들고 골라내기"가 맞다.

export const LEVEL_COUNT = 120;

// 후보 풀: 차량 수마다 이만큼의 시드를 돌린다.
// 차가 많을수록 어려운 판이 나올 확률이 높지만 보장은 없다 — 그래서 풀이 넉넉해야 한다.
export const POOL_SPECS = [];
// 어려운 판(par 10+)은 차가 많아야 나오는데 그마저 드물다.
// 그래서 차가 많은 설정일수록 시드를 훨씬 많이 돌린다.
const CAR_COUNTS = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
const seedsFor = (cars) => (cars >= 10 ? 3000 : cars >= 8 ? 1000 : 400);
CAR_COUNTS.forEach((cars, ci) => {
  for (let j = 0; j < seedsFor(cars); j++) {
    POOL_SPECS.push({ cars, seed: 90000 + ci * 10000 + j });
  }
});

// 원하는 난이도 곡선: 1수에서 시작해 완만하게 출발했다가 뒤로 갈수록 가파르게.
// maxPar는 풀에서 실제로 나온 최댓값 — 곡선은 "있는 것 중에서" 고른다.
export function curveTargets(maxPar, count = LEVEL_COUNT) {
  const targets = [];
  for (let i = 0; i < count; i++) {
    const t = count === 1 ? 0 : i / (count - 1);
    targets.push(Math.max(1, Math.round(1 + (maxPar - 1) * Math.pow(t, 1.35))));
  }
  return targets;
}
