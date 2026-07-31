# 🐶 멍멍 하우스! 강아지 키우기 (Roblox)

로블록스 **강아지 키우기(펫 시뮬레이터)** 게임 스타터 키트입니다.
스크립트 **딱 2개**만 붙여넣으면 바로 플레이됩니다 — 모델, UI 전부 코드가 만들어주기 때문에
**에셋(모델/이미지) 다운로드가 하나도 필요 없습니다.**

> 🌐 코딩 전에 게임 느낌을 먼저 보고 싶다면, 저장소의 `dog-demo/index.html`을
> 브라우저로 열어보세요. 같은 컨셉의 웹 데모 버전입니다.

## 게임 내용

- 접속하면 강아지가 스폰되어 주인을 **졸졸 따라다니고 꼬리를 흔듭니다**
- **배고픔 🍖 / 행복 💖 / 에너지 ⚡** 수치가 시간이 지나며 변합니다
- 할 수 있는 것:
  - **밥주기** (무료, 쿨타임 12초)
  - **간식** (뼈다귀 코인 15개, 배고픔+행복 회복)
  - **쓰다듬기** (반짝이 효과 + 폴짝 점프)
  - **공놀이** — 공을 던지면 강아지가 쫓아가서 물어옵니다 (+코인)
  - **산책** — 강아지와 함께 걸으면 거리마다 자동으로 코인 보상
- 경험치를 모아 **레벨업**하면 강아지가 조금씩 커지고 코인을 받습니다
- **상점**에서 품종 교체: 믹스견(기본) → 시바견, 웰시코기(다리 짧음!), 푸들, 달마시안(점무늬)
- 강아지 **이름 짓기** (텍스트 필터링 적용 — 로블록스 규정 준수)
- **DataStore 저장** — 코인, 레벨, 품종, 수치가 다시 접속해도 유지

## 설치 방법 (5분 컷)

1. **Roblox Studio** 실행 → `New` → `Baseplate` 템플릿으로 새 게임 생성
2. 탐색기(Explorer)에서 **ServerScriptService** 우클릭 → `Insert Object` → **Script**
   - 만들어진 Script를 열고 기본 내용을 지운 뒤, [`DogServer.server.luau`](./DogServer.server.luau) 내용을 전부 붙여넣기
3. 탐색기에서 **StarterPlayer > StarterPlayerScripts** 우클릭 → `Insert Object` → **LocalScript**
   - [`DogUI.client.luau`](./DogUI.client.luau) 내용을 전부 붙여넣기
4. ▶ **Play** 버튼을 누르면 강아지가 옆에 나타납니다! 🎉

### 저장 기능 켜기 (선택이지만 추천)

Studio 테스트 중에도 저장이 되게 하려면:

- 상단 메뉴 `Home` → `Game Settings` → `Security` →
  **Enable Studio Access to API Services** 체크 → Save
- 이 설정은 게임을 로블록스에 **Publish** 한 뒤에만 켤 수 있습니다
  (`File > Publish to Roblox`)

저장을 안 켜도 게임은 정상 동작하고, 저장만 건너뜁니다.

## 밸런스 바꾸는 법

`DogServer.server.luau` 맨 위 **`CONFIG`** 테이블의 숫자만 바꾸면 됩니다.

| 항목 | 의미 |
|---|---|
| `StartCoins` | 시작 코인 |
| `HungerDecay` | 5초마다 줄어드는 배고픔 (높을수록 빨리 배고파짐) |
| `Actions.fetch.coins` | 공 물어오기 보상 코인 |
| `WalkRewardStuds` | 산책 보상을 받는 거리 간격 |
| `ExpPerLevel` | 레벨업 필요 경험치 (레벨 × 이 값) |
| `ScalePerLevel` | 레벨당 강아지 커지는 비율 |

**품종 추가**는 `BREEDS` 테이블에 항목을 하나 복사해서 색만 바꾸면 상점에 자동으로 나옵니다.
(참고: `earStyle = "pointy"`(쫑긋 귀) / `"floppy"`(접힌 귀), `legScale`(다리 길이), `spots = true`(점무늬))

> 🐱 지난번에 물어보셨던 **고양이 키우기**로 바꾸는 것도 간단합니다:
> `BREEDS` 색상을 고양이 털색으로 바꾸고, `earStyle`을 전부 `"pointy"`로,
> 짖는 대사(`멍멍`)를 `야옹`으로 바꾸면 뼈대는 그대로 재사용됩니다.

## 다음 단계 아이디어

- 🥚 **알 뽑기** — 코인으로 랜덤 품종 뽑기 (희귀도 시스템)
- 🏠 **강아지 집 꾸미기** — 플레이어별 하우징 존
- 👥 **친구 강아지 쓰다듬기** — 소셜 보상
- 🛁 **목욕/미용** — 청결 수치 추가 (웹 데모에는 이미 있음)
- 💎 **Game Pass** — VIP 강아지, 코인 2배 등 수익화

## 파일 구성

| 파일 | 넣는 위치 |
|---|---|
| `DogServer.server.luau` | `ServerScriptService` > Script |
| `DogUI.client.luau` | `StarterPlayer > StarterPlayerScripts` > LocalScript |
