# 🐶 멍멍 하우스! 강아지 키우기 (Roblox)

로블록스 **강아지 키우기(펫 시뮬레이터)** 게임입니다.
모델·UI·맵을 전부 코드가 만들어주기 때문에 **에셋(모델/이미지) 다운로드가 하나도 필요 없습니다.**

## ⬇️ 바로 실행하기 (추천)

아래 파일을 받아서 **더블클릭하면 Roblox Studio가 바로 열립니다.** 복붙 작업 없음:

### 👉 [**MungMungHouse-v3.rbxl 다운로드**](https://github.com/HugoSeong0721/amazon-affiliate-share/raw/claude/roblox-dog-game-hcwzjz/roblox-dog-game/build/MungMungHouse-v3.rbxl)

받은 뒤 ▶ **Play** 를 누르면 공원에 강아지가 나타납니다.
(스크립트 3개 + 공원 맵 + 조명이 모두 세팅된 상태입니다.)

## ⚠️ 열자마자 꼭 해야 할 것 — 게시(Publish)

다운로드한 place 파일은 아직 **로블록스에 게시되지 않은 상태**라 PlaceId 가 `0` 입니다.
이 상태로 Play 하면 다음 두 가지가 정상 동작하지 않습니다:

| 증상 | 원인 |
|---|---|
| 내 캐릭터가 안 보이고, Output 에 `Failed to load animation ... serverplaceid=0` 에러가 수십 개 | 게시되지 않은 place 는 아바타 · 애니메이션 에셋을 불러올 권한이 없음 |
| 나갔다 들어오면 강아지가 초기화됨 | DataStore 는 PlaceId 가 있어야 동작 |

**해결 방법 (1분):**

1. `File > Publish to Roblox As...` → 이름 입력 → **Create**
2. `Home > Game Settings > Security` → **Enable Studio Access to API Services** 체크 → Save
3. 다시 ▶ **Play**

이제 캐릭터도 보이고, 애니메이션 에러도 사라지고, 저장도 됩니다.
게시는 무료이고, `Game Settings > Permissions` 를 Private 로 두면 나만 볼 수 있습니다.

### 🔍 그래도 캐릭터가 안 보이면

v3 에는 진단 스크립트가 들어 있습니다. ▶ Play 후 **5초** 기다리면
Output 창에 아래 같은 블록이 출력됩니다:

```
===== 🐶 진단 결과 — 이 블록을 복사해서 알려주세요 =====
  PlaceId = 0   ❌ 미게시 상태 (아바타/애니메이션 로딩 불가)
  ✅ 캐릭터 존재: HugoSeong
  ...
  카메라 ↔ 캐릭터 거리 = 14.2 studs   ✅ 3인칭
=========================================================
```

이 내용을 보면 캐릭터가 아예 안 생긴 건지, 몸이 투명한 건지,
1인칭이라 안 보이는 건지 바로 구분됩니다.
문제가 해결되면 `StarterPlayerScripts > DogDiagnostics` 를 지우면 됩니다.

> 🌐 Studio 없이 게임 느낌만 먼저 보고 싶다면, 저장소의 `dog-demo/index.html`을
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

## 설치 방법 B — 직접 붙여넣기 (rbxl 대신 수동으로 할 때)

1. **Roblox Studio** 실행 → `New` → `Baseplate` 템플릿으로 새 게임 생성
2. 탐색기(Explorer)에서 **ServerScriptService** 우클릭 → `Insert Object` → **Script**
   - 만들어진 Script를 열고 기본 내용을 지운 뒤, [`DogServer.server.luau`](./DogServer.server.luau) 내용을 전부 붙여넣기
3. 같은 방법으로 Script를 하나 더 만들어 [`DogWorld.server.luau`](./DogWorld.server.luau) 붙여넣기 (공원 맵 — 생략 가능)
4. 탐색기에서 **StarterPlayer > StarterPlayerScripts** 우클릭 → `Insert Object` → **LocalScript**
   - [`DogUI.client.luau`](./DogUI.client.luau) 내용을 전부 붙여넣기
5. ▶ **Play** 버튼을 누르면 강아지가 옆에 나타납니다! 🎉

## 소스에서 rbxl 다시 빌드하기 (코드 수정 후)

[Rojo](https://rojo.space/) 가 있으면 한 줄이면 됩니다:

```bash
rojo build roblox-dog-game --output roblox-dog-game/build/MungMungHouse-v3.rbxl
```

`default.project.json` 이 스크립트를 어느 서비스에 넣을지 정의하고 있습니다.

### 저장(DataStore)은 어떻게 동작하나

플레이어가 **나갔다가 다시 들어와도 키우던 강아지가 그대로 남습니다.**
저장되는 항목은 다음과 같습니다 (플레이어 UserId 기준):

- 강아지 **이름 · 품종 · 레벨 · 경험치**
- 보유한 **뼈다귀 코인**, 입양해 둔 **품종 목록**
- 배고픔 · 행복 · 에너지 수치

저장 시점은 **2분마다 자동 저장**, **플레이어가 나갈 때**, **서버가 종료될 때** 세 가지입니다.
수치는 접속 중에만 줄어들고 오프라인 동안은 멈춰 있으므로, 오래 안 들어와도
강아지가 굶어 있지는 않습니다.

**데이터 보호:** 로블록스 DataStore 통신이 일시적으로 실패할 수 있는데,
이때 "저장본이 없는 신규 플레이어"로 착각하면 기존 강아지를 새 강아지로
덮어써 버립니다. 이를 막기 위해 불러오기를 **최대 4회 재시도**하고,
그래도 실패하면 **그 세션에는 저장을 아예 하지 않고** 플레이어에게 알립니다.
(기존 저장본은 그대로 보존됩니다.)

> 저장 기능은 위의 **게시 + API Services 켜기**를 해야 동작합니다.
> 안 켜도 게임 자체는 정상 동작하고, 저장만 건너뜁니다.

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

| 파일 | 역할 / 넣는 위치 |
|---|---|
|  `build/MungMungHouse-v3.rbxl` | **완성된 place 파일** — 더블클릭하면 Studio가 열림 (최신) |
| `DogServer.server.luau` | 게임 로직 · `ServerScriptService` > Script |
| `DogWorld.server.luau` | 공원 맵 생성 · `ServerScriptService` > Script |
| `DogUI.client.luau` | 화면 UI · `StarterPlayer > StarterPlayerScripts` > LocalScript |
| `DogDiagnostics.client.luau` | 진단용 임시 스크립트 · 문제 해결 후 삭제 가능 |
| `default.project.json` | Rojo 빌드 설정 (rbxl 재생성용) |
