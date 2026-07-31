// 레벨 정의. 실제 병 배치는 sort-engine의 generateLevel(seed 고정)로 만들어져
// 언제나 같은 레벨이 나오고, 생성 시점에 솔버로 "풀 수 있음"이 보장된다.
// R/Y/B = 1차색(섞임), O/G/P = 2차색(목표).

export const CAPACITY = 4;

export const LEVELS = [
  { targets: ['O'], extraEmpty: 2, seed: 101 }, // 튜토리얼: 빨강+노랑=주황
  { targets: ['G'], extraEmpty: 2, seed: 102 },
  { targets: ['O', 'P'], extraEmpty: 2, seed: 103 },
  { targets: ['G', 'O'], extraEmpty: 2, seed: 104 },
  { targets: ['O', 'G', 'P'], extraEmpty: 2, seed: 105 },
  { targets: ['O', 'O', 'G'], extraEmpty: 2, seed: 106 },
  { targets: ['R', 'O', 'G'], extraEmpty: 2, seed: 107 }, // 1차색 목표 등장: 빨강은 순수하게 지켜야 함
  { targets: ['O', 'G', 'P'], extraEmpty: 1, seed: 108 }, // 빈 병 1개로 압박
  { targets: ['P', 'P', 'G', 'O'], extraEmpty: 2, seed: 109 },
  { targets: ['Y', 'P', 'O', 'G'], extraEmpty: 1, seed: 110 },
  { targets: ['O', 'O', 'G', 'G'], extraEmpty: 1, seed: 111 },
  { targets: ['R', 'B', 'O', 'G', 'P'], extraEmpty: 2, seed: 112 },
  { targets: ['O', 'G', 'P', 'O', 'G'], extraEmpty: 1, seed: 113 },
  { targets: ['Y', 'R', 'G', 'P', 'O'], extraEmpty: 1, seed: 114 },
  { targets: ['O', 'G', 'P', 'O', 'G', 'P'], extraEmpty: 1, seed: 115 },
];
