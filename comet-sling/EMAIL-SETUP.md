# 이메일 수집 연결하기 (5~10분, 무료)

게임 첫 화면의 가입 게이트는 이미 들어가 있다. 아래 두 가지를 연결하면 완성:

1. **이메일이 쌓일 구글 시트** — 필수 (이게 없으면 이메일이 기기에만 저장된다)
2. **"구글로 계속하기" 버튼** — 선택 (한 번 눌러 가입되는 버튼)

둘 다 끝나면 나온 값 두 개를 `signup.js` 맨 위 `SIGNUP_CONFIG`에 붙여넣거나,
**값만 채팅으로 알려주면 내가 넣고 배포까지 해준다.**

---

## 1. 구글 시트에 이메일 쌓기 (필수)

1. [sheets.new](https://sheets.new) 접속 → 새 시트가 열린다 (이 시트에 이메일이 쌓인다)
2. 메뉴에서 **확장 프로그램 → Apps Script** 클릭
3. 열린 편집기에 원래 있던 코드를 지우고 아래를 통째로 붙여넣기:

```javascript
// 이메일은 emails 탭에, 랭킹 점수는 scores 탭에 쌓인다
function doPost(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var d = JSON.parse(e.postData.contents);
  var name = d.type === 'score' ? 'scores' : 'emails';
  var sheet = ss.getSheetByName(name) || ss.insertSheet(name);
  if (d.type === 'score') {
    sheet.appendRow([new Date(), d.email || '(anonymous)', d.score, d.game || '']);
  } else {
    sheet.appendRow([new Date(), d.email, d.via || '', d.game || '']);
  }
  return ContentService.createTextOutput('ok');
}
```

4. 오른쪽 위 **배포 → 새 배포** 클릭
5. 톱니바퀴(⚙) → **웹 앱** 선택
6. "액세스 권한이 있는 사용자" → **모든 사용자** 로 변경 ← 중요!
7. **배포** 클릭 → 권한 허용 창이 뜨면 허용
8. 나온 **웹 앱 URL** (`https://script.google.com/macros/s/…/exec`)을 복사

→ 이 URL이 `SIGNUP_CONFIG.endpoint` 값이다.

## 2. "구글로 계속하기" 버튼 켜기 (선택)

1. [console.cloud.google.com](https://console.cloud.google.com) 접속 → 프로젝트 하나 생성
2. **API 및 서비스 → OAuth 동의 화면** → 외부(External) → 앱 이름/이메일만 채우고 저장
3. **API 및 서비스 → 사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID**
4. 유형: **웹 애플리케이션**
5. "승인된 자바스크립트 원본"에 게임이 열리는 주소들을 추가:
   - `https://raw.githack.com`
   - `https://rawcdn.githack.com`
   - `https://hugoseong0721.github.io`
6. 만들기 → 나온 **클라이언트 ID** (`…apps.googleusercontent.com`)를 복사

→ 이 값이 `SIGNUP_CONFIG.googleClientId` 값이다.

---

## 랭킹은 어떻게 되나

1. **지금 바로 (서버 불필요)** — 결과 카드의 "📤 Challenge a friend"가 `?beat=점수` 링크를
   공유한다. 친구가 열면 그 높이에 **결승선**이 그려지고, 넘으면 팡파레가 울린다.
2. **endpoint 연결 후** — 신기록이 날 때마다 `scores` 탭에 (시각, 이메일, 점수)가 쌓인다.
   시트에서 점수 내림차순 정렬만 해도 랭킹표다.
3. **게임 안 랭킹판** — scores 데이터가 쌓이기 시작하면, 게임 안에 Top 10 보드를
   붙일 수 있다 (Apps Script `doGet` + JSONP). endpoint URL이 생기면 요청할 것.

## 동작 방식

- 첫 실행 때만 게이트가 뜬다. 가입하거나 "just play"를 누르면 다시 묻지 않는다
- 이메일은 기기(`cms.email`)에 저장되고, endpoint가 있으면 시트로도 전송된다
- 전송 실패분은 큐(`cms.emailQueue`)에 쌓였다가 다음 실행 때 재시도된다
- 구글 버튼은 클라이언트 ID가 비어 있으면 아예 렌더되지 않는다 (이메일 입력은 항상 있다)
- "just play"는 일부러 남겨 뒀다 — 강제 가입은 이메일 몇 개보다 훨씬 비싼
  플레이어 이탈을 부른다. 리텐션이 붙은 뒤 조이는 게 맞다
