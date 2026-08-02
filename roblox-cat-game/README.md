# 🐱 고양이 시뮬레이터 (Roblox Cat Simulator)

로블록스에서 바로 돌아가는 **Pet Simulator 방식의 고양이 게임**입니다.
별도 에셋 없이 스크립트만으로 월드·고양이·캐릭터·UI가 전부 만들어집니다.

## 📥 바로 다운로드

**[CatGame-v5.rbxl 다운로드](https://github.com/HugoSeong0721/amazon-affiliate-share/raw/claude/roblox-cat-game-nwoz9h/roblox-cat-game/build/CatGame-v5.rbxl)**

```
https://github.com/HugoSeong0721/amazon-affiliate-share/raw/claude/roblox-cat-game-nwoz9h/roblox-cat-game/build/CatGame-v5.rbxl
```

클릭하면 바로 받아지고, 더블클릭하면 Roblox Studio가 열립니다. 로그인·계정 불필요.

> 공유용 링크는 반드시 `.rbxl` 쪽을 쓰세요. `.rbxlx`(XML)는 브라우저가 다운로드
> 대신 텍스트로 펼쳐 보여줍니다.

## 게임 구조

Pet Simulator 계열의 핵심 순환을 그대로 따릅니다.

```
고양이가 알아서 물건을 부순다  →  코인이 나온다  →  상자를 열어 더 센 고양이를 뽑는다
        ↑                                                            │
        └──────  더 단단한 구역을 해금한다  ←──────────────────────────┘
```

- **조작이 없습니다.** 서 있기만 하면 데리고 다니는 고양이들이 사거리 안의 물건을 자동으로 때립니다.
- **파워가 전부입니다.** 고양이마다 파워가 있고, 장착한 4마리의 합이 초당 부수는 힘입니다.
- **숫자가 커집니다.** 1.23K / 12.3M 처럼 줄여서 표시합니다.

### 구역 5곳

| 구역 | 해금 | 물건 체력 | 개당 코인 | 상자 |
|---|---|---|---|---|
| 우리집 마당 | 처음부터 | 10 | 8 | 낡은 상자 50 |
| 뒷골목 | 320 | 400 | 60 | 종이 상자 300 |
| 공원 | 2.4K | 1.6K | 900 | 소풍 바구니 4.5K |
| 항구 | 36K | 12K | 14K | 생선 궤짝 70K |
| 달빛 옥상 | 560K | 100K | 220K | 별빛 상자 1.1M |

### 고양이 10마리 · 5등급

일반(치즈·고등어) → 고급(까망·하양) → 희귀(삼색·턱시도) → 영웅(샴·벵갈) → 전설(황금·무지개).
파워는 5에서 시작해 120,000까지 갑니다.

- **자동 장착** — 더 센 고양이를 뽑으면 가장 약한 아이와 알아서 바꿔 낍니다
- **합성** — 같은 고양이 3마리 → ✨골든 (파워 5배)
- **환생** — 달빛 옥상까지 열고 5천만 코인을 모으면, 코인·구역은 초기화되고
  고양이는 남으면서 모든 파워가 영구히 +25%

### 진행 속도

자동 플레이 테스트 기준 **14분**이면 마지막 구역까지 갑니다.

| 구역 도달 | 시간 | 그때 파워 |
|---|---|---|
| 우리집 마당 | 0분 | 5 |
| 뒷골목 | 1.3분 | 65 |
| 공원 | 7.0분 | 91 |
| 항구 | 10.4분 | 1.92K |
| 달빛 옥상 | 14.0분 | 8.66K |

더 긴 그라인드를 원하면 `CatConfig.lua`의 `UnlockCost`와 `EggCost`만 올리면 됩니다.

## 튜토리얼

처음 들어오면 안내창이 뜨고 4단계로 손을 잡아줍니다. 설명을 읽는 게 아니라
**실제로 해내야** 넘어갑니다.

1. **가만히 서 있기** — 고양이가 알아서 부순다는 걸 알게 됩니다 (코인이 들어오면 통과)
2. **상자 열기** — 상자 위에 `여기예요! ▼` 화살표가 뜹니다 (고양이가 늘면 통과)
3. **파워 키우기** — `파워 12 / 30` 처럼 진행도가 실시간으로 보입니다
4. **뒷골목 해금** — 문 위에 화살표, 구역 버튼이 반짝입니다

언제든 `건너뛰기` 가능. 한 번 끝내면 다시 뜨지 않습니다.

## Roblox Studio에 넣는 방법

### 방법 1 — place 파일 바로 열기 (가장 쉬움)

1. [Roblox Studio](https://create.roblox.com/) 설치 후 실행
2. 위 링크로 `CatGame-v5.rbxl`을 받아서 더블클릭 (또는 *File > Open from File*)
3. **▶ Play**

### 방법 2 — 스크립트 9개 복사-붙여넣기

| 파일 | 위치 | 종류 | 이름 |
|---|---|---|---|
| `src/ReplicatedStorage/CatConfig.lua` | ReplicatedStorage | **ModuleScript** | `CatConfig` |
| `src/ReplicatedStorage/BigNumber.lua` | ReplicatedStorage | **ModuleScript** | `BigNumber` |
| `src/ServerScriptService/CatGameServer.server.lua` | ServerScriptService | **Script** | `CatGameServer` |
| `src/ServerScriptService/Breakables.server.lua` | ServerScriptService | **Script** | `Breakables` |
| `src/ServerScriptService/World.server.lua` | ServerScriptService | **Script** | `World` |
| `src/ServerScriptService/CharacterSetup.server.lua` | ServerScriptService | **Script** | `CharacterSetup` |
| `src/StarterPlayerScripts/CatGameClient.client.lua` | StarterPlayer > StarterPlayerScripts | **LocalScript** | `CatGameClient` |
| `src/StarterPlayerScripts/CatTutorial.client.lua` | StarterPlayer > StarterPlayerScripts | **LocalScript** | `CatTutorial` |
| `src/StarterCharacterScripts/Animate.client.lua` | StarterPlayer > StarterCharacterScripts | **LocalScript** | `Animate` |

⚠️ 종류와 이름이 표와 정확히 같아야 합니다.

### 방법 3 — 직접 빌드

```sh
bash tools/build.sh     # build/ 에 .rbxlx 와 .rbxl 둘 다 생성
```

새로 배포할 때는 `tools/build_rbxlx.py` 맨 위의 `VERSION`을 올리세요.
GitHub raw가 같은 경로를 몇 분간 캐싱하기 때문에, 파일명을 바꿔야 확실히 새 버전이 갑니다.

## 🧪 헤드리스 플레이 테스트

Studio 없이 **게임 스크립트를 진짜 Luau로 실행해서** 검증합니다.
로블록스가 쓰는 것과 같은 Luau VM을 임베드하고, 인스턴스 트리·시그널·
RemoteEvent 왕복·가상 시계 위의 task 스케줄러를 흉내냈습니다.

```sh
cargo build --release --manifest-path tests/runner/Cargo.toml
./tests/runner/target/release/luarun tests/main.luau

SKIP_CLIENT=1 ./tests/runner/target/release/luarun tests/main.luau   # 서버만
```

38개 항목을 확인합니다 — 접속, 핵심 부수기 루프, 사거리, 상자 뽑기, 장착 제한,
합성, 구역 해금 순서, 환생 조건, 숫자 표기, 퇴장 처리. 마지막에는 **자동
플레이어가 처음부터 끝까지 게임을 클리어**하며 각 구역 도달 시간을 재줍니다.

가상 시계라서 14분짜리 플레이가 몇 초 만에 끝납니다. 덕분에 밸런스를
"돌려보고" 고칠 수 있습니다.

이 도구가 잡아낸 실제 버그:

- **구역 교착** — 현재 구역이 "코인을 벌 때만" 갱신돼서, 다른 구역으로 걸어가면
  옛 구역이 그대로 잡히고 → 때릴 게 없고 → 코인이 안 들어오고 → 갱신도 안 되는
  무한 정지. 자동 플레이어가 뒷골목에서 90분을 서 있다가 걸렸습니다.
- **파워 정체** — 4마리를 채운 뒤에는 더 센 고양이를 뽑아도 자동 장착이 안 돼서
  파워가 영영 안 올랐습니다.

**한계:** 화면에 뭐가 어떻게 그려지는지는 못 봅니다. 렌더링·레이아웃·카메라
문제는 여전히 Studio에서 직접 확인해야 합니다.

## 캐릭터도 파츠로 직접 만듭니다

게시하지 않은 place는 PlaceId가 0이라 로블록스 에셋 서버 요청이 전부 거부됩니다
(콘솔의 `serverplaceid=0`). 기본 아바타는 몸통이 MeshPart라 그게 막히면 캐릭터가
통째로 안 보입니다. 그래서 캐릭터도 R6 규격으로 직접 조립하고
(`CharacterSetup.server.lua`), 걷기 동작도 관절을 돌려서 만듭니다
(`Animate.client.lua`). 다운로드하는 에셋이 하나도 없습니다.

> 게시한 뒤 플레이어의 진짜 아바타를 쓰고 싶으면 `CharacterSetup.server.lua`를
> 지우면 됩니다.

## 데이터 저장 켜기

*File > Game Settings > Security* → **Enable Studio Access to API Services**
(게임을 게시해야 활성화됨). 꺼도 플레이는 정상, 저장만 안 됩니다.

## 파일 구조

```
roblox-cat-game/
├── build/CatGame-v5.rbxl         ← 공유·다운로드용 (v1~v4도 남겨둠)
├── default.project.json          ← Rojo 프로젝트 설정
├── src/
│   ├── ReplicatedStorage/CatConfig.lua               (모든 수치·고양이·구역)
│   ├── ReplicatedStorage/BigNumber.lua               (1.23K 표기)
│   ├── ServerScriptService/CatGameServer.server.lua  (데이터·고양이·뽑기·환생)
│   ├── ServerScriptService/Breakables.server.lua     (부수기 루프)
│   ├── ServerScriptService/World.server.lua          (구역 5곳 건설)
│   ├── ServerScriptService/CharacterSetup.server.lua (파츠로 만든 캐릭터)
│   ├── StarterPlayerScripts/CatGameClient.client.lua (HUD·패널)
│   ├── StarterPlayerScripts/CatTutorial.client.lua   (4단계 튜토리얼)
│   └── StarterCharacterScripts/Animate.client.lua    (에셋 없는 걷기)
├── tests/
│   ├── main.luau                 ← 시나리오 + 자동 플레이어
│   ├── mock/roblox.luau          ← 로블록스 API 흉내
│   └── runner/                   ← Luau VM 런처 (Rust)
└── tools/
    ├── build.sh                  ← .rbxlx + .rbxl 빌드
    ├── build_rbxlx.py            ← XML place 조립
    └── rbxlx2rbxl/               ← XML → 바이너리 변환기
```

## 다음에 붙일 만한 것

- 🎰 10연 뽑기, 뽑기 연출 화면
- 🏆 서버 랭킹 (OrderedDataStore)
- 🎒 인벤토리 정렬·잠금·대량 합성
- 💎 다이아 / 게임패스 (코인 2배, 슬롯 확장, 자동 뽑기)
- 🐣 시즌 한정 고양이, 이벤트 구역
