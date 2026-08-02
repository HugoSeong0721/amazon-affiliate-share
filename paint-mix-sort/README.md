# 페인트 믹스 (Paint Mix Sort)

물감을 **섞는** 소트 퍼즐. 클래식 워터소트는 정리만 하지만, 여기서는 1차색을 부딪혀
2차색을 만들어 **목표 팔레트**를 완성해야 한다.

## 규칙

- 같은 색 위에는 언제든 부을 수 있다 (클래식과 동일)
- 🔴+🟡=🟠 · 🟡+🔵=🟢 · 🔴+🔵=🟣 — 1차색끼리 부으면 닿은 구간 전체가 2차색으로 변한다
  (양이 안 맞아도 된다. 빨강 1칸 + 노랑 3칸이면 4칸 전부 주황이 된다)
- 2차색은 더 이상 섞이지 않는다 (잘못 섞으면 못 되돌린다 — 되돌리기 버튼뿐)
- 하단 **만들 색** 선반의 빈 병들을 전부 채우면 클리어
- 목표에 1차색이 있으면 그 색은 순수하게 지켜야 한다
- 완성된 2차색 병은 잠긴다 (실수로 부어서 스스로 망칠 수 없다)

레벨 1은 문구 대신 **손가락이 직접 짚어주고**, 안내한 병 외에는 눌러도 반응하지 않는다.

☰ 버튼으로 **레벨 목차**를 연다. 타일 아래 점이 그 레벨의 목표 색이라 난이도 곡선이
한눈에 보인다. 프로토타입이라 전부 열려 있다 — 출시 때는 클리어한 다음 레벨까지만
여는 게 맞다 (`game.js`의 `openLevels()` 주석 참고).

## 실행

정적 서버로 레포 루트를 서빙하고 `/paint-mix-sort/` 접속:

```bash
python3 -m http.server 8000
# → http://localhost:8000/paint-mix-sort/
```

`?debug`를 붙이면 `window.__pms` 디버그 API(레벨 점프, 자동 클리어 등)가 열린다.

## 단일 파일로 빌드

외부 요청이 전혀 없는 자립형 HTML 하나로 묶는다. 공유 링크, 웹뷰 앱 패키징
(Capacitor 등), 오프라인 배포에 그대로 쓸 수 있다.

```bash
node paint-mix-sort/tools/build-single-file.mjs
# → paint-mix-sort/dist/paint-mix-sort.html (약 56KB)

# 문서 셸(<html>/<head>/<body>)을 직접 씌우는 호스트에 임베드할 때
node paint-mix-sort/tools/build-single-file.mjs out.html --fragment
```

`localStorage`가 막힌 샌드박스에서도 죽지 않도록 메모리 폴백이 자동으로 들어간다.

## 레벨 추가/수정

1. `levels.js`에서 스펙(목표색, 빈 병 수, 시드) 수정
2. `node paint-mix-sort/tools/bake-levels.mjs` 실행 → `levels-data.js` 재생성
   (생성기가 솔버로 "풀 수 있음"을 검증한 배치만 저장된다)
3. `node --test paint-mix-sort/tests/*.test.mjs`로 확인

## 구조

- 로직은 전부 [`../sort-engine/`](../sort-engine/README.md) — 이 폴더는 표현만 담당
- `render.js` 캔버스 렌더러(붓기/혼합 애니메이션, 파티클), `audio.js` WebAudio 효과음,
  `game.js` 컨트롤러(막힘 감지 포함), `main.js` 부트스트랩
- 매 수 이후 솔버가 백그라운드로 돌며 **확실히 막힌 상태**면 배너로 알려준다
