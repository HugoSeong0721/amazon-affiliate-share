# 🐱 로블록스 고양이 키우기 (Cat Care Starter)

로블록스에서 바로 돌아가는 **고양이 키우기(펫 시뮬레이터) 스타터 게임**입니다.
별도 에셋 없이 스크립트만으로 고양이 모델·UI·게임 로직이 전부 만들어집니다.

## 게임 내용

- 시작하면 **치즈냥이** 한 마리와 코인 50개를 받습니다
- 고양이가 플레이어 옆에 둥둥 떠서 따라다닙니다 (최대 3마리)
- 고양이 근처에서 **E 키**(모바일은 화면 버튼)로 밥을 줄 수 있습니다
  - 밥을 주면 코인 +2, 고양이 경험치 +10
  - 레벨이 오르면 고양이가 점점 **커집니다** (최대 2.5배)
- 데리고 다니는 고양이 레벨 합만큼 10초마다 코인이 자동으로 들어옵니다
- **상점**에서 새 고양이 입양: 까망냥이(100) · 하양냥이(250) · 삼색냥이(600) · 황금냥이(2000)
- **내 고양이** 메뉴에서 데려갈 고양이를 골라 장착/해제
- 코인·고양이·레벨은 DataStore에 **자동 저장**됩니다 (아래 설정 필요)

## 📥 바로 다운로드

**[CatGame-v1.rbxl 다운로드](https://github.com/HugoSeong0721/amazon-affiliate-share/raw/claude/roblox-cat-game-nwoz9h/roblox-cat-game/build/CatGame-v1.rbxl)**

```
https://github.com/HugoSeong0721/amazon-affiliate-share/raw/claude/roblox-cat-game-nwoz9h/roblox-cat-game/build/CatGame-v1.rbxl
```

클릭하면 바로 받아지고, 더블클릭하면 Roblox Studio가 열립니다. 로그인·계정 불필요.

> XML 버전(`build/CatGame-v1.rbxlx`)도 같은 내용입니다. 브라우저에서 링크로 열면
> 다운로드 대신 텍스트가 펼쳐지므로, **공유용 링크는 `.rbxl` 쪽을 쓰세요.**

## Roblox Studio에 넣는 방법

### 방법 1 — place 파일 바로 열기 (가장 쉬움)

1. [Roblox Studio](https://create.roblox.com/) 설치 후 실행
2. 위 링크로 `CatGame-v1.rbxl`을 받아서 더블클릭 (또는 Studio에서 *File > Open from File*)
3. **▶ Play** 버튼으로 바로 테스트

### 방법 2 — 스크립트 3개 복사-붙여넣기

Studio에서 새 **Baseplate** 템플릿을 만들고, Explorer 창에서:

| 파일 | 만들 위치 | 만들 종류 | 이름 |
|---|---|---|---|
| `src/ReplicatedStorage/CatConfig.lua` | ReplicatedStorage | **ModuleScript** | `CatConfig` |
| `src/ServerScriptService/CatGameServer.server.lua` | ServerScriptService | **Script** | `CatGameServer` |
| `src/StarterPlayerScripts/CatGameClient.client.lua` | StarterPlayer > StarterPlayerScripts | **LocalScript** | `CatGameClient` |

각 위치에서 `+` 버튼으로 해당 종류의 스크립트를 만들고, 파일 내용을 통째로 붙여넣으면 끝입니다.
⚠️ 종류(Script / LocalScript / ModuleScript)와 이름이 표와 정확히 같아야 합니다.

### 방법 3 — Rojo (개발자용)

[Rojo](https://rojo.space/)가 설치되어 있다면:

```sh
rojo build -o CatGame.rbxl     # place 파일 생성
rojo serve                     # 또는 Studio 플러그인으로 실시간 동기화
```

Rojo 없이 place 파일을 다시 만들려면 (python3 + Rust 필요):

```sh
bash tools/build.sh            # build/ 에 .rbxlx 와 .rbxl 둘 다 생성
```

스크립트를 고쳐서 새로 배포할 때는 `tools/build_rbxlx.py` 맨 위의 `VERSION`을
올려주세요. GitHub raw 링크는 같은 경로의 파일을 몇 분간 캐싱하기 때문에,
파일명을 바꿔야 받는 사람이 확실히 새 버전을 받습니다.

## 데이터 저장 켜기 (중요)

Studio 테스트에서 저장까지 확인하려면:

1. *File > Game Settings > Security*
2. **Enable Studio Access to API Services** 켜기 (게임을 Roblox에 게시해야 활성화됨)

끄고 플레이해도 게임은 정상 동작하고, 저장만 되지 않습니다.
실제로 게시된 게임에서는 자동으로 저장됩니다.

## 게임 밸런스 바꾸기

`CatConfig.lua` 숫자만 고치면 됩니다 — 밥 쿨타임, 경험치, 가격, 최대 마리 수,
레벨당 커지는 비율 등. 새 품종을 추가하려면 `Breeds` 테이블에 항목 하나만 더 넣으세요.

## 다음에 추가해볼 만한 아이디어

- 🥚 알 뽑기(가챠): 확률로 희귀 고양이 등장
- ✨ 희귀도 등급과 반짝이 이펙트 (ParticleEmitter)
- 🏆 리더보드: 서버 전체 코인 랭킹 (OrderedDataStore)
- 🎾 장난감/간식 아이템, 고양이 쓰다듬기 애니메이션
- 🏠 고양이 집 꾸미기, 친구 고양이 구경하기
- 💎 Robux 게임패스 (코인 2배, 슬롯 확장)

## 파일 구조

```
roblox-cat-game/
├── build/
│   ├── CatGame-v1.rbxl           ← 공유·다운로드용 (바이너리, 링크 클릭 시 바로 받아짐)
│   └── CatGame-v1.rbxlx          ← 같은 내용의 XML 버전 (git diff가 읽힘)
├── default.project.json          ← Rojo 프로젝트 설정
├── src/
│   ├── ReplicatedStorage/CatConfig.lua              (밸런스·품종 설정)
│   ├── ServerScriptService/CatGameServer.server.lua (서버 게임 로직)
│   └── StarterPlayerScripts/CatGameClient.client.lua (UI)
└── tools/
    ├── build.sh                  ← .rbxlx + .rbxl 한 번에 빌드
    ├── build_rbxlx.py            ← 스크립트를 XML place로 묶기
    └── rbxlx2rbxl/               ← .rbxlx → .rbxl 변환기 (Rust)
```
