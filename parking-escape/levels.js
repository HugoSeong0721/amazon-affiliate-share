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

// 원하는 난이도 곡선: 1수에서 시작해 꾸준히 오른다.
// maxPar는 풀에서 실제로 나온 최댓값 — 곡선은 "있는 것 중에서" 고른다.
//
// 세 번의 실플레이 피드백으로 다듬었다:
//   t^1.35     → "20레벨까지 너무 쉽다가 갑자기 어려워진다" (초반을 너무 오래 눌러둔다)
//   선형+이차  → "그래도 너무 쉽다" (2~4수 구간이 20레벨이나 늘어진다)
//   지금 t^0.6 → 튜토리얼은 레벨 1 하나뿐. 레벨 2부터 바로 3수, 10레벨쯤 7수,
//                20레벨쯤 10수에 닿은 뒤 완만하게 최댓값까지 오른다.
//
// "그냥 택시만 쭉 끌면 끝"인 par 1 판은 레벨 1(손가락 안내)뿐이다.
// 레벨 2부터는 최소 2수 — 2수짜리 해는 반드시 다른 차를 한 대는 비켜야 나온다
// (같은 차를 연달아 미는 건 한 수로 접히므로 par 2 = 남의 차 개입이 보장된다).
const FREE_RIDE_LEVELS = 1;

export function curveTargets(maxPar, count = LEVEL_COUNT) {
  const targets = [];
  for (let i = 0; i < count; i++) {
    const t = count === 1 ? 0 : i / (count - 1);
    const shaped = Math.pow(t, 0.6);
    const want = Math.max(1, Math.round(1 + (maxPar - 1) * shaped));
    targets.push(i < FREE_RIDE_LEVELS ? want : Math.max(2, want));
  }
  return targets;
}
