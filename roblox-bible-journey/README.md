# 예수님의 길 — P0 프로토타입

[DESIGN.md](DESIGN.md)의 P0 단계 구현. 허브(안개 낀 길) + 0장(기다림) + 1장(베들레헴의 밤),
그리고 18장까지 확장되는 챕터 계약과 진행도 저장이 들어 있습니다.

전부 그레이박스(색깔 블록)입니다. P0의 목적은 **아이가 어디서 지루해하는지 찾는 것**이고,
아트가 붙으면 그걸 고치는 비용이 올라갑니다.

## 실행

```bash
# 1. Rojo 설치 (https://rojo.space)
rojo serve roblox-bible-journey/default.project.json

# 2. Roblox Studio > 새 Baseplate > Rojo 플러그인 > Connect
# 3. Play
```

Play 하면:

1. 허브 잔디밭에 스폰. 앞으로 길이 뻗어 있고 안개가 덮여 있습니다.
2. 첫 번째 안개(0장 = 기다림)의 발판을 밟으면 챕터로 이동합니다.
3. 빛기둥을 따라 걷기 → 점프 → 두루마리 만지기 → 완료 후 허브 복귀.
4. 허브로 돌아오면 첫 구간의 안개가 걷히고 등불이 켜집니다. 그게 진행도 UI 전부입니다.
5. 두 번째 구간(베들레헴)이 열립니다. 별을 따라가 마구간을 찾고, 양 5마리를 우리로 몰면 완료.

**양 몰이 감각을 꼭 직접 확인해 보세요.** 뛰어서 다가가면 양이 흩어지고, 걸어서 다가가면 모입니다.
챕터의 주제(목자)가 텍스트 없이 조작 자체로 전달되는지가 이 챕터의 성패입니다.

## 테스트

Studio에서 Play(또는 Run)하면 `tests/run.server.luau`가 자동으로 돌고 출력 창에 결과가 찍힙니다
(현재 32개). `tests/` 에 `*.spec.luau` 파일을 추가하면 등록 없이 자동 발견됩니다.

커버하는 것 — 맵 없이도 검증 가능한, 그리고 틀리면 치명적인 부분들:

| 스펙 | 왜 테스트하는가 |
|---|---|
| `ChapterService.spec` | 여정 순서(`requires` 위상 정렬), 순환·미지 의존성 거부, 잠금/재방문/협동 인원 게이팅 |
| `ProgressLogic.spec` | 조각 중복 획득 방지, 등불 레벨, 완료 시각 덮어쓰기 방지, 스키마 마이그레이션 |
| `Session.spec` | 챕터가 어떻게 끝나도(클리어·이탈·서버 종료·챕터 코드 오류) 맵과 연결이 정리되는지 |
| `SheepController.spec` | 1장의 교훈 그 자체 — 걸으면 모이고 뛰면 흩어진다 |

## 구조

```
src/shared/          클라이언트·서버 공용 (Net, Strings, Verses, Types, Signal)
src/server/
  init.server.luau   부팅 순서: 챕터 로드 → 진행도 → 허브 생성
  ChapterService     챕터 모듈 로드, 여정 그래프 생성, 입장 판정, 세션 수명
  Session            한 챕터의 한 번의 플레이. track/bind로 정리를 보장
  ProgressLogic      순수 진행도 규칙 (테스트 대상)
  ProgressService    로드·저장·복제. 모든 진행도 판정이 여기 서버에서 일어남
  backends/          MemoryBackend (Studio) / ProfileStoreBackend (운영)
  Chapters/          챕터 모듈 하나 = 파일 하나
  greybox/           블록 지오메트리 + 양떼 로직
src/client/          그리기만 함 (HUD 2줄, 빛기둥, 길/안개 렌더, 내레이션)
tests/               의존성 없는 러너 + 스펙
```

### 챕터 추가하기

`src/server/Chapters/` 에 파일 하나를 넣으면 끝입니다. 나머지는 자동입니다 —
`requires`로 여정 순서가 계산되고, 허브에 길 구간이 하나 늘고, 잠금이 걸립니다.

```lua
local Chapter = {
    id = "ch06_nets",
    reference = "누가복음 5:4",
    fragments = Verses.fragmentIdsFor("ch06_nets"),
    requires = { "ch01_bethlehem" },
    minPlayers = 1,
    estimatedMinutes = 10,
    objectives = { "empty_net", "cast_again" },
}

function Chapter.start(session) end          -- session:track / session:bind 만 사용
function Chapter.onObjective(session, id) end -- 다음 목표로 안내
function Chapter.cleanup(session) end
```

필요한 것 둘: `Strings`에 `chapter.ch06_nets.title` / `.intro`, `Verses`에 조각 3개.
빠지면 서버 부팅 때 assert로 바로 잡힙니다.

## 출시 전에 반드시 해야 할 것

- [ ] **ProfileStore 설치.** 지금은 `MemoryBackend`로 돌아서 서버가 재시작되면 진행도가 사라집니다.
      `src/server/Vendor/ProfileStore.luau`에 모듈을 넣으면 자동으로 전환됩니다
      (부팅 시 경고가 사라지는지로 확인). 세션 락 없이 출시하면 아이 진행도가 지워집니다.
- [ ] **성경 구절 방침 확정.** `src/shared/Verses.luau`의 모든 문장은 저작권 회피를 위한
      자체 의역이고 장·절만 정확히 인용합니다. 번역본 원문을 쓰려면 대한성서공회 허락이 필요합니다.
- [ ] **내레이션 녹음.** `src/client/Narration.luau`의 에셋 ID 표가 비어 있어서
      지금은 텍스트로만 나옵니다. 주 타겟 연령의 상당수가 문장을 읽지 않습니다.
- [ ] Content Maturity 설문 정직하게 작성, 커스텀 채팅 만들지 않기 (DESIGN.md 6-2).

## 설계에서 코드로 넘어온 결정들

| 설계 결정 | 코드에서의 위치 |
|---|---|
| 플레이어는 예수님이 아니라 따라가는 아이 | 조작 가능한 예수 캐릭터가 없음. 1장에서 플레이어 역할은 목자 아이이고, 별이 유일한 안내자 |
| 폭력 묘사 없음 | 데미지·전투·체력 시스템이 아예 없습니다. 실패 처리는 전부 "다시 해보기"입니다 (0장의 6스터드 안전 발판 참고) |
| 진행도는 길로 보여준다 | `HubBuilder` + `RoadView`. 진행도 숫자 UI가 없습니다 |
| 텍스트가 아니라 빛으로 가르친다 | `Beacon`(빛기둥) + HUD 2줄 제한 |
| 실패를 벌하지 않는다 | 목표는 되돌아가지 않고, 조각 수집은 완료 조건이 아닙니다 |
| 경건함 랭킹 없음 | 리더스탯 자체가 없습니다. 등불은 개인 지표로만 표시 |
| 클리어한 챕터는 영구 재방문 | `entryVerdict`가 완료 챕터를 항상 허용 (`replay = true`) |
| 협동 게이트 | `minPlayers`. 0·1장은 1명이지만 9·10·16장이 4명으로 들어올 자리가 이미 있습니다 |
