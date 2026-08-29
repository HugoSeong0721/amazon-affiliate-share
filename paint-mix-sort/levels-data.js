// 자동 생성 파일 — 직접 수정하지 말 것.
// 다시 만들려면: node paint-mix-sort/tools/bake-levels.mjs
// 원본 스펙: levels.js

export const CAPACITY = 4;

export const LEVEL_DATA = [
 {
  "targets": [
   "O"
  ],
  "bottles": [
   [
    "R",
    "R",
    "Y",
    "Y"
   ],
   []
  ],
  "solution": [
   {
    "type": "shake",
    "at": 0
   }
  ],
  "solutionLength": 1,
  "seed": 201
 },
 {
  "targets": [
   "O"
  ],
  "bottles": [
   [],
   [
    "Y",
    "Y"
   ],
   [
    "R",
    "R"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
   }
  ],
  "solutionLength": 2,
  "seed": 202
 },
 {
  "targets": [
   "G"
  ],
  "bottles": [
   [],
   [
    "B",
    "Y"
   ],
   [
    "Y",
    "B"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
   }
  ],
  "solutionLength": 3,
  "seed": 203
 },
 {
  "targets": [
   "O",
   "P"
  ],
  "bottles": [
   [],
   [
    "B",
    "R",
    "R",
    "R"
   ],
   [
    "R",
    "Y",
    "Y",
    "B"
   ],
   []
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
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
   },
   {
    "type": "shake",
    "at": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "shake",
    "at": 1
   }
  ],
  "solutionLength": 6,
  "seed": 204
 },
 {
  "targets": [
   "G",
   "O"
  ],
  "bottles": [
   [
    "R",
    "B"
   ],
   [
    "B",
    "R",
    "Y"
   ],
   [
    "Y",
    "Y",
    "Y"
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
    "to": 3
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
    "to": 3
   },
   {
    "type": "shake",
    "at": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
   }
  ],
  "solutionLength": 8,
  "seed": 205
 },
 {
  "targets": [
   "R",
   "O"
  ],
  "bottles": [
   [],
   [
    "R",
    "R",
    "Y",
    "R"
   ],
   [
    "R",
    "R",
    "R",
    "Y"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 2,
    "to": 0
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
    "type": "shake",
    "at": 1
   }
  ],
  "solutionLength": 4,
  "seed": 206
 },
 {
  "targets": [
   "O",
   "O"
  ],
  "bottles": [
   [
    "Y",
    "Y",
    "Y"
   ],
   [],
   [
    "R",
    "R",
    "R"
   ],
   [
    "Y",
    "R"
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
    "from": 2,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "shake",
    "at": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
   }
  ],
  "solutionLength": 6,
  "seed": 207
 },
 {
  "targets": [
   "O",
   "G",
   "P"
  ],
  "bottles": [
   [
    "Y",
    "B",
    "R",
    "R"
   ],
   [
    "Y",
    "B",
    "B",
    "Y"
   ],
   [],
   [],
   [
    "Y",
    "R",
    "R",
    "B"
   ]
  ],
  "solution": [
   {
    "type": "shake",
    "at": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 4,
    "to": 0
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
    "type": "shake",
    "at": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 3
   },
   {
    "type": "shake",
    "at": 3
   }
  ],
  "solutionLength": 8,
  "seed": 208
 },
 {
  "targets": [
   "O",
   "O",
   "G"
  ],
  "bottles": [
   [
    "Y",
    "R",
    "Y"
   ],
   [
    "B",
    "R",
    "Y"
   ],
   [
    "R",
    "B",
    "R"
   ],
   [
    "Y",
    "Y",
    "Y"
   ],
   []
  ],
  "solution": [
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
    "from": 0,
    "to": 3
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "shake",
    "at": 0
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
    "from": 3,
    "to": 4
   },
   {
    "type": "shake",
    "at": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "shake",
    "at": 3
   }
  ],
  "solutionLength": 12,
  "seed": 209
 },
 {
  "targets": [
   "Y",
   "G",
   "P"
  ],
  "bottles": [
   [],
   [
    "R",
    "Y",
    "B"
   ],
   [
    "Y",
    "Y",
    "R"
   ],
   [
    "B",
    "Y",
    "B"
   ],
   [
    "Y",
    "B",
    "Y"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 4
   },
   {
    "type": "pour",
    "from": 2,
    "to": 1
   },
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
    "from": 3,
    "to": 0
   },
   {
    "type": "pour",
    "from": 4,
    "to": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "shake",
    "at": 1
   },
   {
    "type": "pour",
    "from": 3,
    "to": 4
   },
   {
    "type": "shake",
    "at": 4
   }
  ],
  "solutionLength": 12,
  "seed": 210
 },
 {
  "targets": [
   "G",
   "P",
   "O",
   "O"
  ],
  "bottles": [
   [
    "Y",
    "Y",
    "Y"
   ],
   [
    "Y",
    "R",
    "R"
   ],
   [
    "Y",
    "R",
    "B"
   ],
   [],
   [],
   [
    "R",
    "Y",
    "B"
   ],
   [
    "R",
    "B",
    "R",
    "B"
   ]
  ],
  "solution": [
   {
    "type": "shake",
    "at": 6
   },
   {
    "type": "pour",
    "from": 2,
    "to": 5
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
    "from": 2,
    "to": 0
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "pour",
    "from": 5,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
   },
   {
    "type": "pour",
    "from": 1,
    "to": 5
   },
   {
    "type": "pour",
    "from": 5,
    "to": 0
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "pour",
    "from": 0,
    "to": 5
   },
   {
    "type": "shake",
    "at": 5
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "shake",
    "at": 1
   }
  ],
  "solutionLength": 15,
  "seed": 211
 },
 {
  "targets": [
   "R",
   "B",
   "O",
   "G"
  ],
  "bottles": [
   [
    "B",
    "R",
    "B"
   ],
   [
    "Y",
    "R",
    "Y"
   ],
   [],
   [
    "B",
    "R",
    "Y"
   ],
   [
    "B",
    "B",
    "R"
   ],
   [],
   [
    "B",
    "Y",
    "R",
    "R"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 3,
    "to": 1
   },
   {
    "type": "pour",
    "from": 6,
    "to": 3
   },
   {
    "type": "pour",
    "from": 4,
    "to": 0
   },
   {
    "type": "pour",
    "from": 4,
    "to": 6
   },
   {
    "type": "pour",
    "from": 3,
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
    "to": 3
   },
   {
    "type": "pour",
    "from": 6,
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
    "to": 6
   },
   {
    "type": "pour",
    "from": 1,
    "to": 6
   },
   {
    "type": "shake",
    "at": 6
   },
   {
    "type": "pour",
    "from": 4,
    "to": 1
   },
   {
    "type": "shake",
    "at": 1
   }
  ],
  "solutionLength": 14,
  "seed": 212
 },
 {
  "targets": [
   "G",
   "P",
   "O",
   "O"
  ],
  "bottles": [
   [
    "Y",
    "B",
    "R"
   ],
   [
    "R",
    "B",
    "Y"
   ],
   [
    "Y",
    "R",
    "R"
   ],
   [
    "R",
    "B",
    "R",
    "Y"
   ],
   [
    "Y",
    "Y",
    "B"
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
    "from": 0,
    "to": 4
   },
   {
    "type": "shake",
    "at": 4
   },
   {
    "type": "pour",
    "from": 0,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
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
    "from": 1,
    "to": 0
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
    "from": 0,
    "to": 3
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "shake",
    "at": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "shake",
    "at": 1
   }
  ],
  "solutionLength": 15,
  "seed": 214
 },
 {
  "targets": [
   "O",
   "G",
   "P",
   "O",
   "G"
  ],
  "bottles": [
   [
    "B",
    "R",
    "Y"
   ],
   [
    "Y",
    "R",
    "Y"
   ],
   [
    "Y",
    "R",
    "B"
   ],
   [
    "B",
    "B",
    "Y"
   ],
   [
    "B",
    "Y",
    "R",
    "R"
   ],
   [],
   [
    "B",
    "Y",
    "Y",
    "R"
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
    "from": 0,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 3
   },
   {
    "type": "pour",
    "from": 4,
    "to": 0
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
    "to": 4
   },
   {
    "type": "pour",
    "from": 6,
    "to": 2
   },
   {
    "type": "pour",
    "from": 0,
    "to": 4
   },
   {
    "type": "shake",
    "at": 4
   },
   {
    "type": "pour",
    "from": 3,
    "to": 6
   },
   {
    "type": "pour",
    "from": 1,
    "to": 3
   },
   {
    "type": "shake",
    "at": 3
   },
   {
    "type": "pour",
    "from": 0,
    "to": 1
   },
   {
    "type": "shake",
    "at": 1
   },
   {
    "type": "pour",
    "from": 2,
    "to": 0
   },
   {
    "type": "shake",
    "at": 0
   },
   {
    "type": "pour",
    "from": 2,
    "to": 6
   },
   {
    "type": "shake",
    "at": 6
   }
  ],
  "solutionLength": 21,
  "seed": 213
 },
 {
  "targets": [
   "O",
   "G",
   "P",
   "O",
   "G",
   "P"
  ],
  "bottles": [
   [
    "Y",
    "B",
    "B"
   ],
   [
    "R",
    "B",
    "Y"
   ],
   [
    "R",
    "R",
    "Y"
   ],
   [],
   [
    "Y",
    "R",
    "B",
    "Y"
   ],
   [
    "B",
    "R",
    "Y"
   ],
   [
    "R",
    "Y",
    "B",
    "B"
   ],
   [
    "R",
    "R",
    "Y",
    "B"
   ]
  ],
  "solution": [
   {
    "type": "pour",
    "from": 1,
    "to": 0
   },
   {
    "type": "shake",
    "at": 0
   },
   {
    "type": "pour",
    "from": 1,
    "to": 5
   },
   {
    "type": "pour",
    "from": 1,
    "to": 2
   },
   {
    "type": "pour",
    "from": 6,
    "to": 1
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
    "type": "shake",
    "at": 7
   },
   {
    "type": "pour",
    "from": 2,
    "to": 6
   },
   {
    "type": "pour",
    "from": 4,
    "to": 2
   },
   {
    "type": "shake",
    "at": 2
   },
   {
    "type": "pour",
    "from": 4,
    "to": 1
   },
   {
    "type": "pour",
    "from": 4,
    "to": 6
   },
   {
    "type": "pour",
    "from": 5,
    "to": 6
   },
   {
    "type": "pour",
    "from": 5,
    "to": 4
   },
   {
    "type": "pour",
    "from": 6,
    "to": 5
   },
   {
    "type": "pour",
    "from": 6,
    "to": 5
   },
   {
    "type": "shake",
    "at": 5
   },
   {
    "type": "pour",
    "from": 1,
    "to": 4
   },
   {
    "type": "shake",
    "at": 4
   },
   {
    "type": "pour",
    "from": 1,
    "to": 6
   },
   {
    "type": "shake",
    "at": 6
   }
  ],
  "solutionLength": 22,
  "seed": 215
 }
];
