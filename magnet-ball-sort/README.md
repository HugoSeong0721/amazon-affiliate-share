# 자석 구슬 (Magnet Ball Sort)

색깔별로 구슬을 모으는 클래식 소트 퍼즐. 같은 색 구슬은 **자석처럼 붙어서 함께** 움직인다.

## 설계 원칙: 설명하지 않는다

이 게임에는 튜토리얼 문구도, 목표 표시도, 범례도 없다. 화면을 보면 목표가 그냥 보인다 —
**어질러진 걸 색깔별로 정리하는 것.** 사람은 섞인 색을 보면 설명 없이도 정리하고 싶어진다.

규칙 역시 글이 아니라 애니메이션으로 전달한다. 튜브를 누르면 맨 위 같은 색 구슬들이
자석처럼 딱 붙어 함께 떠오른다. **몇 개가 움직일지 손대기 전에 눈으로 보이므로**
"맨 위 같은 색 덩어리가 함께 이동한다"는 규칙을 읽을 필요가 없다.

(이건 앞서 만든 [`../paint-mix-sort/`](../paint-mix-sort/README.md)에서 배운 교훈이다.
그 게임은 목표가 "레시피"라서 반드시 배워야 알 수 있었고, 그래서 실패했다.)

## 규칙

- 튜브를 눌러 맨 위 같은 색 구슬 묶음을 집는다
- **같은 색 위** 또는 **빈 튜브**에만 놓을 수 있다 (색은 절대 변하지 않는다)
- 공간이 모자라면 들어갈 만큼만 들어가고 나머지는 되돌아온다
- 모든 튜브를 한 색으로 채우면 클리어
- 완성된 튜브는 잠긴다 (실수로 흐트러뜨릴 수 없다)
- 막히면 되돌리기(↩︎). 확실히 못 푸는 상태가 되면 알려준다

## 실행

정적 서버로 레포 루트를 서빙하고 `/magnet-ball-sort/` 접속:

```bash
python3 -m http.server 8000
# → http://localhost:8000/magnet-ball-sort/
```

`?debug`를 붙이면 `window.__mbs` 디버그 API(레벨 점프, 자동 클리어 등)가 열린다.

## 단일 파일로 빌드

외부 요청이 전혀 없는 자립형 HTML 하나로 묶는다. 공유 링크, 웹뷰 앱 패키징
(Capacitor 등), 오프라인 배포에 그대로 쓸 수 있다.

```bash
node magnet-ball-sort/tools/build-single-file.mjs
# → magnet-ball-sort/dist/magnet-ball-sort.html (약 69KB)

# 문서 셸(<html>/<head>/<body>)을 직접 씌우는 호스트에 임베드할 때
node magnet-ball-sort/tools/build-single-file.mjs out.html --fragment
```

## 레벨 추가/수정

1. `levels.js`에서 스펙(색 수, 빈 튜브 수, 난이도 구간, 시드, 용량) 수정
2. `node magnet-ball-sort/tools/bake-levels.mjs` 실행 → `levels-data.js` 재생성
3. `node --test magnet-ball-sort/tests/*.test.mjs`로 확인

난이도 레버는 세 개다: **색 수**(2~8), **빈 튜브 수**(2 → 1), **튜브 용량**(4 → 5).
16레벨이 참고해 5수에서 34수까지 오르막으로 이어진다. 마지막 두 판만 용량 5칸이다.

## 구조

- 로직은 전부 [`../sort-engine/`](../sort-engine/README.md) — `CLASSIC_RULES`를 쓴다.
  이 폴더는 표현만 담당한다.
- `render.js` 캔버스 렌더러(자석 집기, 포물선 비행, 파티클), `audio.js` WebAudio 효과음,
  `game.js` 컨트롤러(막힘 감지, 목차 포함), `main.js` 부트스트랩
- 단일 파일 빌드는 엔진의 공용 번들러(`../sort-engine/tools/bundle.mjs`)를 쓴다
