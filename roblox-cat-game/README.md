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

## Roblox Studio에 넣는 방법

### 방법 1 — place 파일 바로 열기 (가장 쉬움)

1. [Roblox Studio](https://create.roblox.com/) 설치 후 실행
2. `CatGame.rbxlx` 파일을 다운로드해서 더블클릭 (또는 Studio에서 *File > Open from File*)
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
rojo build -o CatGame.rbxlx    # place 파일 생성
rojo serve                     # 또는 Studio 플러그인으로 실시간 동기화
```

`CatGame.rbxlx`를 직접 다시 만들고 싶다면 Rojo 없이도 됩니다:

```sh
python3 tools/build_rbxlx.py
```

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
├── CatGame.rbxlx                 ← Studio에서 바로 여는 완성 place 파일
├── default.project.json          ← Rojo 프로젝트 설정
├── src/
│   ├── ReplicatedStorage/CatConfig.lua              (밸런스·품종 설정)
│   ├── ServerScriptService/CatGameServer.server.lua (서버 게임 로직)
│   └── StarterPlayerScripts/CatGameClient.client.lua (UI)
└── tools/build_rbxlx.py          ← 스크립트를 rbxlx로 묶는 빌드 도구
```
