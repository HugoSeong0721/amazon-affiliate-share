# Magnet Balls — 안드로이드 앱 셸

[`../magnet-ball-sort/`](../magnet-ball-sort/README.md) 게임을 Google Play에 올리기 위한
Capacitor 래퍼. 게임 코드는 여기 없다 — 단일 파일 빌드가 `www/`로 들어와 웹뷰에 실린다.

| 항목 | 값 |
|---|---|
| 앱 ID | `io.github.hugoseong0721.magnetballs` (출시 후 변경 불가) |
| 앱 이름 | Magnet Balls |
| versionCode / versionName | `android/app/build.gradle`에서 관리 (업로드마다 versionCode +1) |

## 빌드는 CI가 한다

안드로이드 스튜디오 없이 [`.github/workflows/android-build.yml`](../.github/workflows/android-build.yml)이
main 푸시(관련 경로) 또는 수동 실행으로 돈다:

- **디버그 APK** — 항상 빌드. Actions 아티팩트에서 받아 폰에 바로 설치해 테스트.
- **릴리즈 AAB** — 서명 시크릿이 등록된 경우에만. Play Console에 올리는 파일.

파이프라인: `게임 소스 → build-single-file → www/index.html → cap sync → gradle`.
게임을 고치면 앱도 자동으로 새 빌드가 나온다.

## 로컬에서 만지고 싶을 때

```bash
cd magnet-balls-app
npm ci
npm run sync          # 게임 빌드 → www → 안드로이드 프로젝트에 복사
# 이후 android/를 Android Studio로 열거나 cd android && ./gradlew assembleDebug
```

## 아이콘·스플래시

`assets/`의 원본 5장(1024/2732px)은 Playwright 렌더링으로 만들었다
(스크립트는 세션 스크래치패드의 render-assets.mjs). 다시 굽려면:

```bash
npx capacitor-assets generate --android
```

## 서명 (Play 업로드 전 1회)

키스토어를 만들어 GitHub Secrets 4개를 등록하면 CI가 서명된 AAB를 만든다.
레포에는 키 파일을 절대 커밋하지 않는다 (.gitignore로 차단).

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload-keystore.jks   # → ANDROID_KEYSTORE_BASE64 시크릿에 붙여넣기
```

| Secret | 내용 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | .jks 파일 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 키스토어 비밀번호 |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 |

Play Console에서 **Play App Signing**(구글이 앱 서명 키 관리)을 쓰므로,
이 키는 "업로드 키"일 뿐이고 분실해도 구글에 재설정을 요청할 수 있다.

## 구글 로그인 (이메일 수집 + 진행 저장)

코드는 전부 들어가 있고 **Firebase 설정이 감지될 때만 켜진다** — 설정 전 빌드에서는
게임의 로그인 UI가 통째로 숨는다. 켜는 절차 (Firebase 콘솔에서 약 10분):

1. [console.firebase.google.com](https://console.firebase.google.com) → **프로젝트 추가**
   (이름 자유, Google 애널리틱스는 꺼도 된다)
2. **Android 앱 추가** → 패키지 이름 `io.github.hugoseong0721.magnetballs`
3. 내려받은 `google-services.json`을 base64로 만들어 시크릿 등록
   (`base64 -w0 google-services.json`) → Secret `GOOGLE_SERVICES_JSON_B64`
   — 공개 레포라 파일을 직접 커밋하지 않는다
4. **Authentication → Sign-in method → Google** 사용 설정
5. **Firestore Database** 만들기 (프로덕션 모드) → 규칙 탭에 아래를 붙여넣기:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /players/{uid} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```

6. **서명 지문(SHA-1) 등록** — 구글 로그인은 등록된 서명의 빌드에서만 된다.
   Firebase 프로젝트 설정 → 내 앱 → Android → "디지털 지문 추가"에:
   - 업로드 키: `keytool -list -v -keystore upload-keystore.jks -alias upload` 의 SHA1
   - 출시 후: Play Console → 설정 → 앱 서명 → "앱 서명 키 인증서"의 SHA-1도 추가

시크릿을 넣은 다음 빌드부터 로그인이 살아난다. 이때부터 공개 릴리즈에
`magnet-balls.apk`(업로드 키 서명)가 함께 올라가는데, **로그인 테스트는 이 파일로
해야 한다** — 디버그 APK는 CI 러너의 임시 키로 서명돼 구글이 로그인을 거부한다.
(서명이 바뀌므로 기존 디버그 설치 위에 덮어쓰기는 안 되고, 한 번 지우고 설치해야 한다.)

모인 이메일 보는 곳: Firebase 콘솔 → **Authentication → Users**.
CSV 내보내기는 `firebase auth:export users.csv --project <프로젝트ID>`.

관련 정책 페이지(이미 게시됨): [개인정보처리방침](https://hugoseong0721.github.io/amazon-affiliate-share/magnet-ball-sort/privacy.html)
· [계정 삭제 안내](https://hugoseong0721.github.io/amazon-affiliate-share/magnet-ball-sort/delete-account.html)
— Play Console 데이터 안전 섹션에는 "이메일 주소 수집(선택), 계정 관리 목적,
앱 내 + 웹 삭제 경로 제공"으로 신고한다.

## 다음에 붙일 것: AdMob

게임의 광고 자리는 provider 인터페이스(`isReady()`/`show()`)로 분리돼 있다
([`../magnet-ball-sort/ads.js`](../magnet-ball-sort/ads.js)). 실제 광고를 붙이는 절차:

1. AdMob 계정 → 앱 등록 → **앱 ID**와 **전면 광고 단위 ID** 발급
2. `npm i @capacitor-community/admob`, AndroidManifest에 앱 ID 메타데이터 추가
3. 게임 부트스트랩에서 네이티브 환경이면 AdMob provider로 교체
   (웹에서는 지금처럼 플레이스홀더 유지)

AdMob 계정과 광고 단위 ID가 나온 뒤에 작업한다 — ID 없이는 테스트가 안 된다.
