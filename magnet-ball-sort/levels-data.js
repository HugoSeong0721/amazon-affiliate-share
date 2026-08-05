// 자동 생성 파일 — 직접 수정하지 말 것.
// 다시 만들려면: node magnet-ball-sort/tools/bake-levels.mjs
// 원본 스펙: levels.js

// 용량은 레벨마다 다를 수 있다 (마지막 두 판은 5칸). CAPACITY는 기본값일 뿐이다.
export const CAPACITY = 4;

export const LEVEL_DATA = [
 {
  "capacity": 4,
  "targets": [
   "R",
   "O"
  ],
  "tubes": [
   [
    "O",
    "O",
    "R",
    "R"
   ],
   [],
   [
    "O",
    "R",
    "O",
    "R"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   }
  ],
  "solutionLength": 5,
  "seed": 301
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O"
  ],
  "tubes": [
   [
    "O",
    "R",
    "R",
    "O"
   ],
   [
    "R",
    "R",
    "O",
    "O"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   }
  ],
  "solutionLength": 4,
  "seed": 302
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y"
  ],
  "tubes": [
   [],
   [
    "Y",
    "O",
    "R",
    "Y"
   ],
   [
    "R",
    "Y",
    "Y",
    "O"
   ],
   [
    "O",
    "O",
    "R",
    "R"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   }
  ],
  "solutionLength": 7,
  "seed": 303
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y"
  ],
  "tubes": [
   [
    "Y",
    "R",
    "Y",
    "Y"
   ],
   [],
   [
    "R",
    "O",
    "Y",
    "R"
   ],
   [
    "O",
    "O",
    "R",
    "O"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 2
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   }
  ],
  "solutionLength": 8,
  "seed": 304
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G"
  ],
  "tubes": [
   [
    "Y",
    "R",
    "R",
    "G"
   ],
   [
    "O",
    "O",
    "O",
    "Y"
   ],
   [
    "R",
    "G",
    "Y",
    "G"
   ],
   [
    "G",
    "Y",
    "O",
    "R"
   ],
   [],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 0,
    "to": 5
   },
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 5
   }
  ],
  "solutionLength": 11,
  "seed": 305
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G"
  ],
  "tubes": [
   [
    "G",
    "Y",
    "G",
    "G"
   ],
   [
    "O",
    "Y",
    "O",
    "R"
   ],
   [
    "R",
    "Y",
    "R",
    "Y"
   ],
   [
    "O",
    "G",
    "O",
    "R"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   }
  ],
  "solutionLength": 13,
  "seed": 306
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C"
  ],
  "tubes": [
   [
    "O",
    "C",
    "Y",
    "R"
   ],
   [
    "Y",
    "G",
    "O",
    "Y"
   ],
   [],
   [
    "C",
    "G",
    "C",
    "O"
   ],
   [
    "R",
    "R",
    "O",
    "C"
   ],
   [
    "R",
    "Y",
    "G",
    "G"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 4,
    "to": 2
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 4,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 5
   },
   {
    "type": "pour",
    "from": 0,
    "to": 6
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "pour",
    "from": 5,
    "to": 1
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   }
  ],
  "solutionLength": 17,
  "seed": 307
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C"
  ],
  "tubes": [
   [
    "Y",
    "C",
    "G",
    "Y"
   ],
   [
    "O",
    "G",
    "R",
    "R"
   ],
   [],
   [
    "O",
    "R",
    "C",
    "C"
   ],
   [
    "R",
    "Y",
    "G",
    "Y"
   ],
   [
    "O",
    "C",
    "O",
    "G"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 4,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 4,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 5
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 4,
    "to": 0
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 5,
    "to": 3
   },
   {
    "type": "pour",
    "from": 5,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 5
   }
  ],
  "solutionLength": 16,
  "seed": 308
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B"
  ],
  "tubes": [
   [
    "R",
    "R",
    "G",
    "O"
   ],
   [
    "B",
    "G",
    "O",
    "O"
   ],
   [],
   [
    "G",
    "R",
    "B",
    "C"
   ],
   [],
   [
    "Y",
    "O",
    "C",
    "B"
   ],
   [
    "C",
    "Y",
    "B",
    "R"
   ],
   [
    "Y",
    "Y",
    "C",
    "G"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 6,
    "to": 0
   },
   {
    "type": "pour",
    "from": 5,
    "to": 6
   },
   {
    "type": "pour",
    "from": 3,
    "to": 5
   },
   {
    "type": "pour",
    "from": 7,
    "to": 1
   },
   {
    "type": "pour",
    "from": 1,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 6,
    "to": 1
   },
   {
    "type": "pour",
    "from": 5,
    "to": 3
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 6
   },
   {
    "type": "pour",
    "from": 7,
    "to": 3
   },
   {
    "type": "pour",
    "from": 6,
    "to": 7
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   }
  ],
  "solutionLength": 18,
  "seed": 309
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B"
  ],
  "tubes": [
   [],
   [
    "R",
    "B",
    "O",
    "C"
   ],
   [
    "Y",
    "O",
    "Y",
    "R"
   ],
   [
    "G",
    "Y",
    "Y",
    "G"
   ],
   [
    "B",
    "G",
    "R",
    "B"
   ],
   [
    "O",
    "R",
    "G",
    "C"
   ],
   [
    "C",
    "B",
    "C",
    "O"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "pour",
    "from": 5,
    "to": 0
   },
   {
    "type": "pour",
    "from": 6,
    "to": 1
   },
   {
    "type": "pour",
    "from": 6,
    "to": 0
   },
   {
    "type": "pour",
    "from": 4,
    "to": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 5
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 6
   },
   {
    "type": "pour",
    "from": 4,
    "to": 1
   },
   {
    "type": "pour",
    "from": 5,
    "to": 4
   },
   {
    "type": "pour",
    "from": 5,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 5
   },
   {
    "type": "pour",
    "from": 3,
    "to": 2
   },
   {
    "type": "pour",
    "from": 4,
    "to": 3
   },
   {
    "type": "pour",
    "from": 6,
    "to": 4
   },
   {
    "type": "pour",
    "from": 0,
    "to": 6
   }
  ],
  "solutionLength": 18,
  "seed": 310
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B",
   "P"
  ],
  "tubes": [
   [
    "B",
    "O",
    "C",
    "O"
   ],
   [
    "G",
    "Y",
    "Y",
    "Y"
   ],
   [
    "R",
    "B",
    "B",
    "C"
   ],
   [
    "G",
    "C",
    "O",
    "P"
   ],
   [],
   [],
   [
    "Y",
    "P",
    "P",
    "G"
   ],
   [
    "B",
    "R",
    "G",
    "R"
   ],
   [
    "P",
    "R",
    "C",
    "O"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 4
   },
   {
    "type": "pour",
    "from": 6,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   },
   {
    "type": "pour",
    "from": 8,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 8
   },
   {
    "type": "pour",
    "from": 3,
    "to": 5
   },
   {
    "type": "pour",
    "from": 8,
    "to": 3
   },
   {
    "type": "pour",
    "from": 7,
    "to": 8
   },
   {
    "type": "pour",
    "from": 7,
    "to": 1
   },
   {
    "type": "pour",
    "from": 7,
    "to": 8
   },
   {
    "type": "pour",
    "from": 2,
    "to": 7
   },
   {
    "type": "pour",
    "from": 8,
    "to": 2
   },
   {
    "type": "pour",
    "from": 6,
    "to": 8
   },
   {
    "type": "pour",
    "from": 4,
    "to": 6
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 5
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 0,
    "to": 5
   },
   {
    "type": "pour",
    "from": 0,
    "to": 7
   }
  ],
  "solutionLength": 20,
  "seed": 311
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B",
   "P"
  ],
  "tubes": [
   [
    "G",
    "G",
    "B",
    "C"
   ],
   [
    "O",
    "O",
    "R",
    "B"
   ],
   [
    "C",
    "P",
    "G",
    "C"
   ],
   [
    "R",
    "O",
    "G",
    "P"
   ],
   [],
   [
    "B",
    "Y",
    "Y",
    "R"
   ],
   [
    "Y",
    "P",
    "R",
    "C"
   ],
   [
    "P",
    "B",
    "O",
    "Y"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "pour",
    "from": 6,
    "to": 4
   },
   {
    "type": "pour",
    "from": 6,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 7,
    "to": 5
   },
   {
    "type": "pour",
    "from": 7,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 7
   },
   {
    "type": "pour",
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 7,
    "to": 5
   },
   {
    "type": "pour",
    "from": 6,
    "to": 7
   },
   {
    "type": "pour",
    "from": 2,
    "to": 6
   }
  ],
  "solutionLength": 21,
  "seed": 312
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B",
   "P",
   "K"
  ],
  "tubes": [
   [
    "G",
    "C",
    "O",
    "P"
   ],
   [],
   [
    "Y",
    "R",
    "P",
    "P"
   ],
   [
    "K",
    "B",
    "Y",
    "B"
   ],
   [
    "R",
    "K",
    "O",
    "K"
   ],
   [
    "K",
    "C",
    "B",
    "G"
   ],
   [],
   [
    "C",
    "P",
    "Y",
    "G"
   ],
   [
    "O",
    "O",
    "R",
    "R"
   ],
   [
    "B",
    "G",
    "C",
    "Y"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 8,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 8
   },
   {
    "type": "pour",
    "from": 0,
    "to": 6
   },
   {
    "type": "pour",
    "from": 5,
    "to": 0
   },
   {
    "type": "pour",
    "from": 7,
    "to": 0
   },
   {
    "type": "pour",
    "from": 9,
    "to": 7
   },
   {
    "type": "pour",
    "from": 9,
    "to": 6
   },
   {
    "type": "pour",
    "from": 9,
    "to": 0
   },
   {
    "type": "pour",
    "from": 5,
    "to": 9
   },
   {
    "type": "pour",
    "from": 5,
    "to": 6
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 4,
    "to": 8
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 7,
    "to": 2
   },
   {
    "type": "pour",
    "from": 7,
    "to": 1
   },
   {
    "type": "pour",
    "from": 6,
    "to": 7
   },
   {
    "type": "pour",
    "from": 3,
    "to": 9
   },
   {
    "type": "pour",
    "from": 3,
    "to": 2
   },
   {
    "type": "pour",
    "from": 3,
    "to": 9
   },
   {
    "type": "pour",
    "from": 3,
    "to": 5
   }
  ],
  "solutionLength": 23,
  "seed": 313
 },
 {
  "capacity": 4,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B",
   "P",
   "K"
  ],
  "tubes": [
   [
    "P",
    "K",
    "P",
    "Y"
   ],
   [
    "O",
    "Y",
    "Y",
    "G"
   ],
   [],
   [
    "O",
    "R",
    "K",
    "B"
   ],
   [
    "Y",
    "B",
    "C",
    "G"
   ],
   [
    "O",
    "P",
    "G",
    "R"
   ],
   [
    "C",
    "C",
    "K",
    "C"
   ],
   [
    "P",
    "K",
    "R",
    "B"
   ],
   [
    "R",
    "B",
    "O",
    "G"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 7,
    "to": 2
   },
   {
    "type": "pour",
    "from": 3,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 7
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 6,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   },
   {
    "type": "pour",
    "from": 7,
    "to": 3
   },
   {
    "type": "pour",
    "from": 6,
    "to": 7
   },
   {
    "type": "pour",
    "from": 4,
    "to": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 8,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 5,
    "to": 0
   },
   {
    "type": "pour",
    "from": 5,
    "to": 8
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 1,
    "to": 4
   },
   {
    "type": "pour",
    "from": 8,
    "to": 1
   },
   {
    "type": "pour",
    "from": 8,
    "to": 5
   },
   {
    "type": "pour",
    "from": 3,
    "to": 8
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 7,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 7
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 7
   }
  ],
  "solutionLength": 26,
  "seed": 314
 },
 {
  "capacity": 5,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B",
   "P"
  ],
  "tubes": [
   [
    "O",
    "Y",
    "G",
    "B",
    "R"
   ],
   [
    "R",
    "O",
    "C",
    "G",
    "R"
   ],
   [
    "P",
    "G",
    "C",
    "O",
    "Y"
   ],
   [],
   [
    "G",
    "Y",
    "Y",
    "P",
    "C"
   ],
   [
    "B",
    "P",
    "B",
    "B",
    "C"
   ],
   [
    "O",
    "C",
    "R",
    "O",
    "Y"
   ],
   [
    "B",
    "G",
    "P",
    "R",
    "P"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 4,
    "to": 3
   },
   {
    "type": "pour",
    "from": 5,
    "to": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 8
   },
   {
    "type": "pour",
    "from": 0,
    "to": 5
   },
   {
    "type": "pour",
    "from": 1,
    "to": 8
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 6,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 6,
    "to": 1
   },
   {
    "type": "pour",
    "from": 6,
    "to": 8
   },
   {
    "type": "pour",
    "from": 6,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 6
   },
   {
    "type": "pour",
    "from": 1,
    "to": 8
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 4,
    "to": 2
   },
   {
    "type": "pour",
    "from": 4,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 7,
    "to": 2
   },
   {
    "type": "pour",
    "from": 7,
    "to": 8
   },
   {
    "type": "pour",
    "from": 7,
    "to": 2
   },
   {
    "type": "pour",
    "from": 7,
    "to": 4
   },
   {
    "type": "pour",
    "from": 5,
    "to": 7
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 7
   }
  ],
  "solutionLength": 30,
  "seed": 315
 },
 {
  "capacity": 5,
  "targets": [
   "R",
   "O",
   "Y",
   "G",
   "C",
   "B",
   "P",
   "K"
  ],
  "tubes": [
   [
    "P",
    "C",
    "P",
    "C",
    "Y"
   ],
   [
    "P",
    "B",
    "O",
    "G",
    "K"
   ],
   [
    "K",
    "R",
    "K",
    "B",
    "P"
   ],
   [
    "K",
    "P",
    "K",
    "G",
    "R"
   ],
   [
    "Y",
    "C",
    "R",
    "Y",
    "O"
   ],
   [
    "Y",
    "O",
    "R",
    "B",
    "B"
   ],
   [
    "C",
    "O",
    "G",
    "C",
    "G"
   ],
   [
    "B",
    "R",
    "Y",
    "O",
    "G"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 7,
    "to": 8
   },
   {
    "type": "pour",
    "from": 4,
    "to": 7
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 6,
    "to": 8
   },
   {
    "type": "pour",
    "from": 6,
    "to": 0
   },
   {
    "type": "pour",
    "from": 6,
    "to": 8
   },
   {
    "type": "pour",
    "from": 7,
    "to": 6
   },
   {
    "type": "pour",
    "from": 4,
    "to": 7
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 8
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 8
   },
   {
    "type": "pour",
    "from": 1,
    "to": 6
   },
   {
    "type": "pour",
    "from": 5,
    "to": 1
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 0,
    "to": 3
   },
   {
    "type": "pour",
    "from": 6,
    "to": 0
   },
   {
    "type": "pour",
    "from": 4,
    "to": 6
   },
   {
    "type": "pour",
    "from": 7,
    "to": 4
   },
   {
    "type": "pour",
    "from": 5,
    "to": 7
   },
   {
    "type": "pour",
    "from": 5,
    "to": 0
   },
   {
    "type": "pour",
    "from": 4,
    "to": 5
   },
   {
    "type": "pour",
    "from": 7,
    "to": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 7
   },
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   }
  ],
  "solutionLength": 34,
  "seed": 316
 }
];
