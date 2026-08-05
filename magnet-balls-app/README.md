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

## 다음에 붙일 것: AdMob

게임의 광고 자리는 provider 인터페이스(`isReady()`/`show()`)로 분리돼 있다
([`../magnet-ball-sort/ads.js`](../magnet-ball-sort/ads.js)). 실제 광고를 붙이는 절차:

1. AdMob 계정 → 앱 등록 → **앱 ID**와 **전면 광고 단위 ID** 발급
2. `npm i @capacitor-community/admob`, AndroidManifest에 앱 ID 메타데이터 추가
3. 게임 부트스트랩에서 네이티브 환경이면 AdMob provider로 교체
   (웹에서는 지금처럼 플레이스홀더 유지)

AdMob 계정과 광고 단위 ID가 나온 뒤에 작업한다 — ID 없이는 테스트가 안 된다.
