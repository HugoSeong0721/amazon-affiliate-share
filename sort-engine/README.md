# sort-engine — 소트 퍼즐 공용 엔진

소트 퍼즐 게임들이 공유하는 **순수 로직 엔진**. 렌더링/DOM 의존성이 전혀 없어서
브라우저(ES module)와 Node(테스트) 양쪽에서 그대로 돌아간다.

"4개의 앱, 1개의 엔진" 전략의 그 엔진이다. 새 게임(자석 구슬, 젤리, 테마 리스킨 등)은
이 엔진 위에 스킨과 트위스트만 얹는다.

## 구성

| 파일 | 역할 |
|---|---|
| `colors.js` | 색 정의 + RYB 혼합 규칙, `blendOf()` 비율 판정 |
| `state.js` | 게임 상태, 승리 판정, 상태 정규화 키 |
| `moves.js` | 수 규칙 — 붓기와 흔들기 (`CLASSIC_RULES` / `SHAKE_RULES`) |
| `solver.js` | 가중 A* 솔버 — 풀 수 있는지 확정 판정 + 참고 해 |
| `generator.js` | 시드 기반 레벨 생성기 (목표색 → 재료 역산 → 섞기 → 솔버 검증) |
| `rng.js` | 시드 난수 (같은 시드 = 같은 레벨) |

## 수(move)는 두 종류다

```js
{ type: 'pour', from, to }  // 맨 위 덩어리를 옮긴다. 색은 절대 안 변한다.
{ type: 'shake', at }       // 병을 흔들어 안의 물감을 한 색으로 만든다.
```

`applyMove(state, move, rules)`로 둘 다 실행한다. 붓기가 섞지 않는 게 핵심 —
색이 바뀌는 유일한 순간은 흔들기뿐이다.

## 핵심 API

```js
import {
  canPour, pour,            // 붓기
  canShake, shake,          // 흔들기
  shakePreview,             // 흔들면 무슨 색이 나오는지 (UI 미리보기용)
  applyMove,                // 수 종류 상관없이 실행
  isWin, isComplete,        // 판정
  solve,                    // 솔버: {solved, moves, exhausted}
  generateLevel,            // 레벨 생성: {bottles, targets, solution, ...}
  CLASSIC_RULES, SHAKE_RULES,
} from './sort-engine/index.js';

// 클래식 워터소트 게임을 만들고 싶으면 (같은 색 위에만 붓기, 흔들기 없음):
const lv = generateLevel({ seed: 7, targets: ['R', 'Y', 'B'], rules: CLASSIC_RULES });

// 물감 섞기 게임(paint-mix-sort)은:
const lv2 = generateLevel({ seed: 7, targets: ['O', 'G', 'P'], rules: SHAKE_RULES });
```

- `pour()`는 맨 위 같은 색 구간을 (공간이 허락하는 만큼) 옮긴다. **색은 안 변한다.**
  정확한 양을 덜어내려면 목적지의 남은 공간으로 조절해야 한다.
- `shake()`는 가득 찬 병의 두 1차색이 정확히 반반일 때만 된다 (`blendOf` 참고).
- `solve()`가 `solved:false, exhausted:true`를 주면 **확실히 못 푸는 상태** — 게임에서
  "막혔어요" 배너를 띄우는 데 쓴다. `exhausted:false`는 노드 예산 초과(판단 불가).
- `generateLevel()`은 풀 수 있음이 검증된 배치만 반환한다. `minMoves`/`maxMoves`로
  난이도 구간을, `fillBottles`로 물감이 흩어진 정도를 조절한다.
  게임에는 미리 구워서(bake) 싣는 걸 권장 (`paint-mix-sort/tools/bake-levels.mjs` 참고).

## 테스트

```bash
node --test sort-engine/tests/*.test.mjs paint-mix-sort/tests/*.test.mjs
```

## 새 변형 게임 만들 때

1. 폴더 하나 만들고 (`jelly-sort/` 등) `../sort-engine/index.js`를 import
2. 규칙이 같으면 `rules`만 고르고, 새 트위스트면 `moves.js` 패턴을 따라 rules 객체 확장
3. `levels.js`(스펙) → bake 스크립트 → `levels-data.js`(데이터) 파이프라인 복사
4. 렌더러만 새로 (paint-mix-sort의 `render.js`가 출발점으로 좋음)
