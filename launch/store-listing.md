# Slang Crossword — Play 스토어 등록 자료

계정 등록 후 Play Console에 그대로 복사해서 쓰면 되는 자료 모음.
스크린샷·피처 그래픽은 `store-assets/` 폴더에 있음.

---

## 앱 기본 정보

| 항목 | 값 |
|---|---|
| 앱 이름 (30자 이내) | `Slang Crossword: Learn Slang` |
| 짧은 설명 (80자 이내) | `Learn Gen Z slang & texting acronyms by solving crossword puzzles. No cap!` |
| 카테고리 | 게임 > 단어 (또는 교육) |
| 태그 | word game, crossword, slang, learn English |
| 개인정보처리방침 URL | `https://hugoseong0721.github.io/amazon-affiliate-share/crossword/privacy.html` |
| 웹 게임 URL | `https://hugoseong0721.github.io/amazon-affiliate-share/crossword/` |

## 전체 설명 (영어)

```
Ever felt lost when someone says "no cap", "rizz", or "delulu"? 🧩

Slang Crossword teaches you the slang, memes, and texting acronyms everyone
actually uses — by making you solve crossword puzzles with them.

HOW IT WORKS
• Read the clue, fill in the word — classic crossword rules
• Every answer is real modern slang: from LOL and BTW to brainrot and aura farming
• Clear a level to unlock the next. It gets harder as you go!

12 LEVELS OF INTERNET FLUENCY
• Basic texting acronyms (LOL, BTW, FYI)
• Everyday chat (WYD, HMU, OMW)
• Gen Z slang (rizz, ick, delulu, no cap)
• Dating terms (situationship, red flag, breadcrumbing)
• The freshest memes (brainrot, aura farming, 6-7)

FEATURES
• Fresh puzzle layout every time you play
• Hints when you're stuck (fewer at higher levels!)
• English & Korean clue languages
• Works offline — play anywhere
• No account, no sign-up, no ads, no tracking

Whether you're an English learner, a parent decoding your kid's texts, or
just someone who nods along pretending to know what "gyat" means —
this one's for you. IYKYK. 😎
```

## 전체 설명 (한국어)

```
"no cap", "rizz", "delulu"... 무슨 말인지 몰라서 검색해본 적 있다면? 🧩

Slang Crossword는 요즘 진짜로 쓰이는 영어 신조어·밈·줄임말을
크로스워드 퍼즐로 풀면서 배우는 게임입니다.

이렇게 플레이해요
• 단서(뜻)를 읽고 격자에 단어 채우기 — 정통 크로스워드 방식
• 정답은 전부 실제 쓰이는 요즘 영어: LOL, BTW부터 brainrot, aura farming까지
• 레벨을 깨면 다음 레벨이 열리고, 갈수록 어려워집니다!

12개 레벨로 인터넷 영어 정복
• 기본 줄임말 (LOL, BTW, FYI)
• 일상 채팅 (WYD, HMU, OMW)
• Z세대 슬랭 (rizz, ick, delulu, no cap)
• 연애 용어 (situationship, red flag)
• 최신 밈 (brainrot, aura farming, 6-7)

특징
• 매판 새로 생성되는 퍼즐 배치
• 막힐 땐 힌트 (높은 레벨일수록 적게!)
• 영어/한국어 단서 전환
• 오프라인 플레이 지원
• 계정·가입·광고·추적 없음

영어 학습자도, 자녀의 문자를 해독하고 싶은 부모님도,
"gyat"이 뭔지 모르면서 아는 척해온 분도 환영합니다. 😎
```

## 콘텐츠 등급 설문 가이드 (IARC)

- 폭력/성적 콘텐츠/약물/도박: **없음**
- 비속어: **가벼움** (슬랭 교육 맥락에서 mild한 표현의 유래 설명 포함 — 예: gyat, PMO. "Infrequent/Mild Language" 선택 권장)
- 예상 등급: Everyone 10+ 또는 Teen

## 데이터 안전 섹션 답변

- 데이터 수집: **아니요** (모든 진행 데이터는 기기 내 localStorage)
- 데이터 공유: **아니요**
- 데이터 암호화 전송: 해당 없음 (수집 안 함)
- 데이터 삭제 요청: 해당 없음 (수집 안 함)

## 결제 관련 주의 ⚠️

현재 웹 버전의 $0.99 레벨 팩은 외부 결제(Stripe) 기반.
**Play 스토어 배포판에서는 정책상 Google Play Billing을 써야 함.**
초기 출시 옵션 (택 1):
1. **앱 버전은 잠금 해제 전체 무료** (paywall 끄기) — 가장 간단, 심사 리스크 0
2. Play Billing 연동 (TWA에서는 PWABuilder의 Play Billing 옵션 사용) — 나중에

## 개인 개발자 계정 출시 요건 체크리스트

- [ ] Play Console 계정 생성 ($25) + 신분증 인증
- [ ] 비공개 테스트 트랙 생성 → 테스터 12명 이상 모집 → **14일간 테스트 유지**
- [ ] 테스트 기간 동안: 스토어 등록정보(이 문서 내용) 입력, 콘텐츠 등급, 데이터 안전 작성
- [ ] `assetlinks.json` 배포 (아래 참고)
- [ ] 14일 후 프로덕션 출시 신청

## assetlinks.json (TWA 주소창 제거용)

PWABuilder에서 Android 패키지를 만들면 서명 키의 SHA-256 지문을 알려줌.
그 지문으로 아래 파일을 만들어 **`https://hugoseong0721.github.io/.well-known/assetlinks.json`** 에 배포해야 함.

⚠️ 중요: 이 파일은 도메인 루트에 있어야 해서 **`hugoseong0721.github.io`라는 이름의
저장소를 새로 만들어** 거기에 `.well-known/assetlinks.json`으로 올려야 함
(지금 저장소는 `/amazon-affiliate-share/` 하위라 루트에 파일을 둘 수 없음).

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "io.github.hugoseong0721.slangcrossword",
    "sha256_cert_fingerprints": ["여기에 PWABuilder가 알려주는 SHA-256 지문"]
  }
}]
```

계정 만들고 나면 이 단계는 같이 진행하면 됨.
