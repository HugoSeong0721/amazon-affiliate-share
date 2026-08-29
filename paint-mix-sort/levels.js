// 레벨 정의. 실제 병 배치는 sort-engine의 generateLevel(seed 고정)로 만들어져
// 언제나 같은 레벨이 나오고, 생성 시점에 솔버로 "풀 수 있음"이 보장된다.
// R/Y/B = 1차색, O/G/P = 흔들어 만드는 2차색.
//
// fillBottles = 물감을 나눠 담을 병 수 (클수록 흩어져서 모으기 어렵다)
// extraEmpty  = 빈 병 수 (적을수록 옮길 자리가 없어 어렵다)
// minMoves/maxMoves = 참고해 길이의 허용 구간. 이 밖으로 풀리는 배치는 버려서
//                     난이도가 들쭉날쭉해지지 않게 한다.

export const CAPACITY = 4;

export const LEVELS = [
  // 1~3: 기본기. 흔들기 → 붓고 흔들기 순으로 하나씩 가르친다.
  { targets: ['O'], fillBottles: 1, extraEmpty: 1, minMoves: 1, maxMoves: 1, seed: 201 },
  { targets: ['O'], fillBottles: 2, extraEmpty: 1, minMoves: 2, maxMoves: 3, seed: 202 },
  { targets: ['G'], fillBottles: 2, extraEmpty: 1, minMoves: 2, maxMoves: 4, seed: 203 },

  // 4~7: 목표가 둘로 늘고, 1차색 목표가 등장한다.
  { targets: ['O', 'P'], fillBottles: 2, extraEmpty: 2, minMoves: 5, maxMoves: 8, seed: 204 },
  { targets: ['G', 'O'], fillBottles: 3, extraEmpty: 1, minMoves: 5, maxMoves: 9, seed: 205 },
  { targets: ['R', 'O'], fillBottles: 2, extraEmpty: 1, minMoves: 4, maxMoves: 6, seed: 206 },
  { targets: ['O', 'O'], fillBottles: 3, extraEmpty: 1, minMoves: 5, maxMoves: 9, seed: 207 },

  // 8~10: 목표 셋. 물감이 더 흩어진다.
  { targets: ['O', 'G', 'P'], fillBottles: 3, extraEmpty: 2, minMoves: 8, maxMoves: 12, seed: 208 },
  { targets: ['O', 'O', 'G'], fillBottles: 4, extraEmpty: 1, minMoves: 9, maxMoves: 13, seed: 209 },
  { targets: ['Y', 'G', 'P'], fillBottles: 4, extraEmpty: 1, minMoves: 10, maxMoves: 14, seed: 210 },

  // 11~15: 빈 병이 모자라 옮길 자리를 계속 계산해야 한다.
  { targets: ['G', 'P', 'O', 'O'], fillBottles: 5, extraEmpty: 2, minMoves: 12, maxMoves: 17, seed: 211 },
  { targets: ['R', 'B', 'O', 'G'], fillBottles: 5, extraEmpty: 2, minMoves: 14, maxMoves: 19, seed: 212 },
  { targets: ['G', 'P', 'O', 'O'], fillBottles: 5, extraEmpty: 1, minMoves: 15, maxMoves: 18, seed: 214 },
  { targets: ['O', 'G', 'P', 'O', 'G'], fillBottles: 6, extraEmpty: 1, minMoves: 18, maxMoves: 22, seed: 213 },
  { targets: ['O', 'G', 'P', 'O', 'G', 'P'], fillBottles: 7, extraEmpty: 1, minMoves: 18, maxMoves: 26, seed: 215 },
];
