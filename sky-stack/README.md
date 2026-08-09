# 스카이 스택 (Sky Stack — Tap to Stack)

좌우로 움직이는 블록을 탭해서 위로, 위로 쌓는 원탭 아케이드.
삐져나온 만큼 잘려 나가고, 블록은 점점 좁아지고, 완전히 빗나가면 끝.
정확히 맞추면 **퍼펙트** — 폭이 깎이지 않고, 연속 5번이면 폭이 회복된다.

## 왜 이 게임인가 — 3초 안에 이해된다

앞선 실험(토치 다이브)의 첫 플레이테스트 반응은 "뭐 하는 건지 모르겠다"였다.
확률을 읽는 푸시-유어-럭은 깊이는 있었지만 **첫 3초의 이해**를 통과하지 못했다.
스카이 스택은 그 반성에서 출발한다:

- **규칙이 전부 화면에 보인다** — 움직이는 블록, 쌓인 탑, 잘려 떨어지는 조각.
  글자 하나 없이도 두 번째 탭부터는 전문가다
- **입력이 탭 하나** — 언제 누르느냐가 실력의 전부
- **한 판 20~60초, 재시작은 탭 한 번** — 엔드리스 최고 기록 사냥
- 쌓을 때마다 펜타토닉 음계가 한 계단씩 올라간다 — 탑이 높아지는 것이 **들린다**.
  퍼펙트는 화음, 콤보가 쌓이면 옥타브가 얹힌다
- 하늘은 탑이 높아질수록 한낮 → 성층권으로 어두워진다 — 진행이 배경에 새겨진다

시리즈의 신조는 그대로다: 설명하지 않는다, 손맛이 먼저다, 판정은 코드가 보증한다
(자르기 수학·퍼펙트 오차·속도 곡선 전부 계약 테스트), 광고는 런 사이에만.

## 규칙 (코드 기준)

- 블록 폭 100에서 시작, 겹친 만큼만 남는다 — `drop()`의 구간 교집합이 유일한 판정
- 오차 3.5 이내는 퍼펙트: 폭 유지 + 콤보. 연속 5퍼펙트마다 폭 +10 회복 (상한 100)
- 속도는 층당 +2.4 (85 → 275 상한) — 단조 증가를 테스트가 검증한다
- 블록은 층마다 반대편에서 나온다 — 리듬이 좌우로 흔들린다
- 시드는 색상 시작점만 바꾼다. 물리는 시드와 무관하게 완전 결정적이다

## 일시정지

⏸ 버튼, Esc/P 키, 그리고 **화면을 벗어나는 모든 순간**(탭 전환·홈 버튼·전화·공유 시트·랭킹 열기)에
자동으로 멈춘다. 멈춰 있는 동안 물리는 정지하고 그리기만 계속되며, 멈춘 시간은 런 길이에서 빠진다
(광고 노출 판정이 "긴 런이었다"고 착각하지 않게). 카드 바깥을 누르면 바로 이어진다.

## 친구 공유

결과 화면과 일시정지 화면의 📤 SHARE 한 번:
- 모바일은 시스템 공유 시트(카톡·문자·인스타…)를 띄운다 — `navigator.share`
- 데스크톱 등 시트가 없는 곳은 클립보드에 복사하고 토스트로 알린다
- 문구는 점수를 담는다: "I stacked 42 blocks — can you beat me?" (0점이면 초대 문구)
- 주소는 테스트 쿼리(`?seed` 등)를 떼고 보낸다

## 랭킹

🏆 버튼(HUD·결과·일시정지 어디서든). 이메일 수집과 같은 원칙 — **서버 없이 시작하고, 주소 하나로 전역이 된다**:

- `LEADERBOARD_CONFIG.url` 이 비어 있으면: 내 최고 기록만 보여주고 "This device only" 라고 정직하게 알린다
- Apps Script 웹앱 주소를 넣으면: 전 세계 TOP 20. 신기록일 때만 제출하고(POST), 조회는 JSONP(GET)
- 서버 응답은 신뢰하지 않는다 — 형식이 맞는 행만, 점수순으로, 20개까지 (`normalizeTop`)
- 이름은 `textContent` 로만 넣는다 (남의 이름이 HTML 로 해석되지 않게)
- 플레이 도중에 열어도 **진행 중인 점수가 내 줄로 끼어든다** — 지금 몇 등인지 보인다

시트에 받는 Apps Script (이메일 수집 배포와 같은 스크립트에 붙여도 된다):

```js
function doPost(e) {
  const r = JSON.parse(e.postData.contents);
  const sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('scores');
  const rows = sh.getDataRange().getValues();          // [pid, name, score]
  const i = rows.findIndex((row) => row[0] === r.pid);
  if (i < 0) sh.appendRow([r.pid, r.name, r.score]);
  else if (r.score > rows[i][2]) sh.getRange(i + 1, 2, 1, 2).setValues([[r.name, r.score]]);
  return ContentService.createTextOutput('ok');
}

function doGet(e) {                                     // JSONP
  const sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('scores');
  const top = sh.getDataRange().getValues()
    .map((r) => ({ name: r[1], score: Number(r[2]) || 0 }))
    .sort((a, b) => b.score - a.score)
    .slice(0, Number(e.parameter.limit) || 20);
  return ContentService
    .createTextOutput(`${e.parameter.callback}(${JSON.stringify(top)})`)
    .setMimeType(ContentService.MimeType.JAVASCRIPT);
}
```

## 광고

전면 광고는 **런과 런 사이에만** 뜬다 — 플레이 도중에는 절대 안 뜬다.
처음 3런은 무조건 무광고, 8초보다 짧았던 런 뒤에는 건너뛰고(연속 즉사에 광고까지 겹치면 최악),
그 뒤로는 3런마다 + 최소 90초 간격. 닫기 버튼은 5초 뒤에 열린다.
실제 SDK를 붙일 때는 [ads.js](./ads.js)의 provider 객체 하나만 갈아끼우면 된다. `?noads`로 끌 수 있다.

## 가입 게이트 — 이메일부터 모은다

첫 실행 때 게임 위로 가입 카드가 얹힌다. `play as guest`로 건너뛸 수 있고,
건너뛴 사람에게는 HUD에 ✉️가 남는다. 서버 없이 굴러간다 —
[signup.js](./signup.js)의 `SIGNUP_CONFIG` 세 줄이 전부:

1. **이메일 직접 입력** — 항상 켜져 있다. 수집처는 `collectUrl`:
   - 구글 폼(가장 쉬움): 폼의 `…/formResponse` URL + `formEntry`에 이메일 질문의 `entry.123…`
   - 또는 Apps Script 웹앱 URL (`formEntry`는 비움) — 가입 경로·날짜까지 시트에 쌓인다
2. **Google로 계속하기** — `googleClientId`를 넣으면 버튼이 나타난다
   (승인된 자바스크립트 원본에 게임을 올린 도메인 등록 필요)
3. 수집처가 없거나 오프라인이면 로컬 큐(`sky.signupQueue`)에 쌓았다가 다음 실행 때 재시도

## 개발

```
node --test sky-stack/tests/*.mjs            # 결정론 + 자르기 수학 + 랭킹/공유/가입 헬퍼 (33 tests)
node sky-stack/tools/build-single-file.mjs   # 자립형 HTML 한 파일 (dist/, 51KB)
```

테스트용 쿼리: `?seed=123`(색상 고정) · `?noads` · `?signup`(게이트 강제 표시)
· `?gclient=` / `?collect=` / `?entry=`(가입 설정) · `?lb=`(랭킹 주소 임시 주입)

저장 키: `sky.best` · `sky.runs` · `sky.muted` · `sky.ads` · `sky.user` · `sky.signupQueue`
· `sky.pid`(랭킹용 기기 ID) · `sky.name` · `sky.lbCache`
