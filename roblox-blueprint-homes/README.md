# Blueprint Homes 🏠 — Roblox 집짓기 게임 (플레이어블 MVP)

> **한 줄 컨셉:** Bloxburg의 검증된 집짓기 공식은 그대로, 딱 하나만 완전히 다르게 —
> **유저가 만든 집 설계도(블루프린트)를 게임 안에서 사고파는 마켓**.

## 왜 이 차별화인가 (리서치 근거)

집짓기/생활 장르는 Roblox에서 가장 돈이 되는 장르 중 하나다:

| 게임 | 지표 |
|---|---|
| Welcome to Bloxburg | 누적 방문 100억+, **Embracer Group이 약 $1억에 인수** |
| Brookhaven RP | 추정 월 매출 $6–12M, 누적 방문 790억+ |
| Adopt Me! | 추정 연 매출 $50M+ |

그리고 결정적인 시장 갭:

- Bloxburg에는 "잘 짓는 사람"과 "예쁜 집은 갖고 싶지만 못 짓는 사람"이 공존하는데,
  게임 안에 이 둘을 연결하는 장치가 **없다**.
- 그래서 그 수요가 게임 **밖**으로 새어나가 Fiverr에서 실제 돈으로 거래된다:
  집 한 채 커미션 **$5–$500+ (평균 ~$25)**, 전문 빌더 수십 명, 납기 3–7일.
- 즉, "남이 지어준 드림하우스"에 대한 지불 의사는 이미 **실증**됐다.
  우리는 그 거래를 게임 안의 코어 루프로 흡수한다.

상세 수치와 출처: [`docs/market-research.md`](docs/market-research.md)

## 차별화 포인트: 블루프린트 마켓

```
빌더           마켓              구매자
────           ────              ──────
집을 짓는다 →  퍼블리시(설계비 책정) →  Top/New 차트에서 브라우징
                                      → 설계비 결제(빌더에게 70% 로열티, 오프라인이어도 지급)
                                      → 자재비 결제 → 내 플롯에 원클릭 시공 ✔
빌더는 판매 순위(Top Sellers)를 타고 유명해짐 → 더 많이 팔림 → UGC 플라이휠
```

- **빌더에게:** 건축 실력이 곧 수입. 판매 차트 = 명예 시스템. Pro Builder 패스로 슬롯 확장.
- **일반 유저에게:** 못 지어도 드림하우스를 가질 수 있다. 현금 팩 수요가 자연 발생.
- **개발자(우리)에게:** 설계비의 30%가 화폐 싱크 → 인플레 제어 + 현금 상품 판매 동력.

나머지(플롯, 그리드 건축, 가구 카탈로그, 데일리 보너스, 게임패스 구조)는
검증된 공식을 그대로 따른다. **새로운 것은 딱 하나, 마켓뿐.**

## 바로 받기 (툴체인 불필요)

**⬇️ [BlueprintHomes-v2.rbxl 다운로드](https://github.com/HugoSeong0721/amazon-affiliate-share/raw/claude/roblox-house-building-game-sxuk4g/roblox-blueprint-homes/build/BlueprintHomes-v2.rbxl)**

받아서 Roblox Studio로 열고 **Play(F5)** 누르면 스폰 광장에서 시작한다.
Studio에서 파일을 열었을 때 Workspace가 비어 보이는 건 정상이다 — 동네 맵(도로,
플롯 8개, 스폰 광장)은 서버 스크립트가 런타임에 생성한다.

| 버전 | 변경 |
|---|---|
| v2 | 맵 생성 전 캐릭터가 빈 공간에 스폰돼 낙사하던 문제 수정, 스폰 광장 추가, 플롯 간판 크기를 스터드 기준으로 변경(거리별 축소) |
| v1 | 최초 빌드 |

> 마켓의 블루프린트 저장·거래를 테스트하려면 Studio에서
> **Game Settings → Security → Enable Studio Access to API Services**를 켤 것.
> 꺼져 있어도 건축·경제는 인메모리로 전부 동작한다(마켓 영속만 비활성).

## 소스에서 빌드 / 개발

이 저장소는 [Rojo](https://rojo.space) 프로젝트다. 맵/아이템 전부 코드로 생성되므로
외부 에셋 의존성이 없다.

```bash
# 툴체인 설치 (한 번만)
aftman install        # rojo 7.4.4

# A) 코드를 고치면서 개발 — Studio의 Rojo 플러그인으로 Connect
rojo serve

# B) 배포용 .rbxl 재빌드 (위 다운로드 파일을 만든 명령)
rojo build default.project.json -o build/BlueprintHomes-v2.rbxl
```

서버당 플롯이 8개이므로 퍼블리시할 때 place 설정에서 **최대 플레이어 8명**으로 맞출 것.

## 조작

| 입력 | 동작 |
|---|---|
| BUILD 버튼 | 건축 모드 (자기 플롯에만 설치 가능, 서버 검증) |
| 마우스 이동 | 고스트 프리뷰 (초록 = 가능 / 빨강 = 불가) |
| 클릭 | 설치 (연속 설치 지원) |
| `R` | 90° 회전 |
| `X` | 삭제 모드 (75% 환불) |
| `Q` | 건축 모드 종료 |
| MARKET 버튼 | 블루프린트 마켓 (Top Sellers / Newest / Mine) |
| PUBLISH 버튼 | 현재 플롯을 설계도로 마켓에 등록 |

## 폴더 구조

```
default.project.json      Rojo 매핑
src/shared/               서버·클라 공용 (검증 로직 공유가 치트 방지의 핵심)
  Config.luau             모든 밸런스 수치
  Catalog.luau            아이템 34종 (프리미티브 파츠 조합 → 에셋 의존성 0)
  GridUtil.luau           그리드 수학 (서버 판정 = 클라 프리뷰 동일 보장)
  BlueprintCodec.luau     빌드 직렬화 + 엄격 검증 (DataStore발 데이터 불신 원칙)
  ItemModels.luau         파츠 스펙 → Model 빌더 (+고스트 변형)
  Net.luau                리모트 레지스트리
src/server/
  init.server.luau        부트스트랩 + 플레이어 라이프사이클
  DataService.luau        프로필 저장 + 크로스서버 로열티 인박스(오프라인 정산)
  PlotService.luau        동네 맵 런타임 생성 + 플롯 배정
  BuildService.luau       설치/삭제 서버 판정 (전 입력 타입·경계·점유·잔액 검증)
  BlueprintMarketService.luau  퍼블리시/브라우징/구매/시공 + 판매 차트
  EconomyService.luau     수입 루프 + 게임패스/개발자상품 훅
src/client/
  BuildController.luau    고스트 프리뷰, 회전, 설치/삭제 입력
  UI.luau                 HUD, 카탈로그, 마켓 창, 퍼블리시 다이얼로그, 토스트
docs/                     시장 리서치 + 게임 디자인 문서
```

## 로드맵 (MVP 이후)

1. **소프트런치 전:** 게임패스 실제 ID 연결(`Config.GamePasses`), 현금 팩 상품 등록,
   블루프린트 썸네일(ViewportFrame), 마켓 페이지네이션·검색
2. **리텐션:** 다층 건축(Multiple Floors 패스 — Bloxburg 최고 매출 패스), 벽지/바닥 색상
   커스텀, 방문·좋아요 시스템(잘 지은 집 구경 = 무료 콘텐츠)
3. **차별화 심화:** 커미션 보드(원하는 집 공고 → 빌더 입찰), 시즌 건축 콘테스트
   (우승작 = 공식 추천 블루프린트), 모더레이션 큐(신고 시 블루프린트 비공개)
4. **스케일:** ProfileService 세션락 도입, MemoryStore 기반 실시간 차트, 모바일 카메라·
   제스처 전용 UX

## 알려진 MVP 한계

- 단층 건축만 지원 (다층은 프로토콜에 자리만 확보 — `Config.GamePasses.MultipleFloors`)
- 마켓 목록은 첫 페이지(25개)만, 미리보기는 스펙 텍스트만 제공
- 프로필 저장은 last-writer-wins (다중 접속 세션락 없음 — 로드맵 4 참고)
