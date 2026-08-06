// 이메일 수집 엔드포인트 — 구글 시트에 한 줄씩 쌓는 Apps Script 웹앱.
// 서버 없이(무료) 정적 사이트에서 가입 이메일을 모으는 가장 간단한 방법이다.
//
// 배포 순서 (5분):
//   1) sheets.new 로 새 스프레드시트를 만든다
//   2) 메뉴: 확장 프로그램 → Apps Script → 이 파일 내용을 붙여넣고 저장
//   3) 배포 → 새 배포 → 유형: 웹 앱
//        - 실행 계정: 나
//        - 액세스 권한: 전체 사용자 (익명 POST를 받아야 하므로)
//   4) 나온 웹 앱 URL을 signup.js 의 SIGNUP_CONFIG.collectEndpoint 에 붙여넣는다
//
// 시트에는 [시각, 이메일, 이름, 구글ID, 게임, 클라이언트 시각] 순으로 쌓인다.
// 같은 이메일이 여러 번 올 수 있다(기기·재설치) — 정리는 시트에서 중복 제거로.

function doPost(e) {
  var d = {};
  try {
    d = JSON.parse(e.postData.contents);
  } catch (err) {}
  SpreadsheetApp.getActiveSpreadsheet()
    .getSheets()[0]
    .appendRow([new Date(), d.email || '', d.name || '', d.sub || '', d.game || '', d.ts || '']);
  return ContentService.createTextOutput('ok');
}
