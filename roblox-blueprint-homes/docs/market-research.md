# 시장 리서치 — Roblox 집짓기/생활 장르 (2026-07 기준)

## 1. 장르가 돈이 된다는 증거

| 게임 | 방문수 | 매출 신호 | 출처 |
|---|---|---|---|
| **Welcome to Bloxburg** | 100억+ (2026-07), 즐겨찾기 1,380만 | Embracer Group이 개발사(1인 개발 Shortcake AB)를 **$100M에 인수**(2022, 다수 매체 보도) | [Sportskeeda](https://www.sportskeeda.com/roblox-news/news-popular-roblox-game-welcome-bloxburg-reportedly-acquired-embracer-group-100-million-deal), [Pocket Tactics](https://www.pockettactics.com/roblox/bloxburg-embracer-acquisition), [GameFAQs](https://gamefaqs.gamespot.com/news?id=63509), [Roblox Wiki](https://roblox.fandom.com/wiki/Bloxburg_Development/Welcome_to_Bloxburg) |
| **Brookhaven RP** | 790억+ (역대 최다) | 추정 월 $6–12M, 누적 추정 $634M | [RoWatcher](https://rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026-and-what-they-mean-for-the-platform), [profitable.app](https://profitable.app/roblox) |
| **Adopt Me!** | 424억+ | 추정 연 $50M+ | [RobloxDB](https://robloxdb.com/blog/post/what-roblox-games-make-the-most-money) |

- Bloxburg 동접: 평시 ~9K, 이벤트 피크 48K. 88% 긍정 평가(626만 표) —
  10년 된 게임이 여전히 상위권. ([ggaid CCU 트래커](https://www.ggaid.com/roblox/games/welcome-to-bloxburg-88070565))
- 장르 공통 수익 구조: 꾸미기·집·아바타에 돈을 쓰는 **자기표현형 과금**
  (전투 밸런스 부담 없음 → 낮은 이탈 리스크).

## 2. 결정적 시장 갭: 커미션 경제가 게임 밖에 있다

Bloxburg 집 건축 대행은 **실제 화폐로 거래되는 성숙한 외부 시장**이다:

- Fiverr에 전용 카테고리가 있을 정도의 규모: 기본 주택 $5–15, 평균 ~$25,
  대형/상업 건축 $500+, 납기 3–7일.
  ([Fiverr Bloxburg 카테고리](https://www.fiverr.com/categories/lifestyle/buy/ingame-creation/ingame-architecture/bloxburg),
  [빌더 고용 가이드](https://memvers.com/blog/hire-bloxburg-builder-guide-2026))
- 인테리어만 별도 의뢰하는 세분화($10–30)까지 진행됨 — 수요가 깊다는 신호.
- 그런데 Bloxburg **게임 안**에는 설계 거래·대행·공유 기능이 전무하다.
  플레이어는 에스크로도 없는 외부 플랫폼으로 나가서 거래한다.

**시사점:** "남이 설계한 집"에 대한 지불 의사는 이미 검증됐다. 이 거래를 게임 내
재화로 옮기면 (1) 거래가 코어 루프가 되고 (2) 인게임 화폐 수요가 생기며
(3) 그 화폐를 Robux로 파는 우리가 최종 수혜자가 된다.

## 3. 경쟁 구도에서 우리의 위치

| | 자유 건축 | 프리셋/설계 구매 | 유저 간 설계 거래 |
|---|---|---|---|
| Bloxburg | ✅ 깊음 | ❌ | ❌ (외부 Fiverr로 유출) |
| Brookhaven / Berry Avenue | ❌ (프리셋 집 선택) | ✅ 개발자 제작만 | ❌ |
| 소형 "Build a House"류 | 부분적 | ✅ 개발자 제작만 | ❌ |
| **Blueprint Homes (우리)** | ✅ | ✅ | **✅ 유일 — 핵심 차별화** |

- Brookhaven류의 교훈: 대다수 유저는 **직접 짓기보다 고르기**를 원한다 (프리셋 집
  게임들의 압도적 방문수가 증거). 우리는 "고르기"의 공급을 개발자가 아니라
  **유저 빌더**에게 맡긴다 → 콘텐츠 생산 비용 0, 공급 무한.
- Bloxburg의 교훈: 건축 덕후는 소수지만 과몰입한다. 이들에게 **수입과 명예**
  (판매 차트)를 주면 이탈하지 않는 콘텐츠 공급자가 된다.

## 4. 리스크와 대응

| 리스크 | 대응 |
|---|---|
| 설계 도용(남의 집 베껴 퍼블리시) | 판매 차트 선점 효과 + 이후 유사도 검사/신고 큐 (로드맵) |
| 부적절한 이름/건축물 | 이름은 TextService 필터 적용(구현됨), 건축물은 신고→비공개 큐 (로드맵) |
| 화폐 인플레 | 설계비의 30% 싱크 + 자재비 전액 싱크 (구현됨) |
| 초기 마켓 콜드스타트 | 개발자 시드 블루프린트 10~20개 등록 후 시작 |
