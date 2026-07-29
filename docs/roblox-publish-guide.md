# Comeback! K-pop Dress Up — Roblox 배포 가이드

코딩 없이 아래 순서대로만 하면 게임이 Roblox에 올라갑니다. (약 15~20분)

## 준비물
- Windows 또는 Mac 컴퓨터
- Roblox 계정 (roblox.com 에서 무료 가입)

## 1단계. Roblox Studio 설치
1. https://create.roblox.com 접속 → 로그인
2. **Start Creating** 버튼 → Roblox Studio 다운로드 & 설치

## 2단계. 게임 파일 열기
1. 이 저장소의 `roblox-game/build/Comeback.rbxl` 파일을 컴퓨터에 다운로드
2. 파일을 더블클릭 → Roblox Studio가 자동으로 열림

## 3단계. 테스트 해보기
1. Studio 상단 가운데 **▶ Play** 버튼 클릭
2. 확인할 것:
   - 분홍 드레스룸에 캐릭터가 스폰되는지
   - 왼쪽 아래 **👗 Closet** 버튼 → 옷장이 열리고 아이템이 로드되는지
   - 아이템 클릭 → 무료(FREE)는 바로 착용, 유료는 구매 팝업이 뜨는지
   - **📸 Photo** 버튼 → 카운트다운 후 포토카드 연출이 나오는지
3. 끝나면 **■ Stop**

> 참고: Studio 테스트에서는 코인 저장이 안 될 수 있습니다(정상). 게시 후 4단계 설정을 하면 실제 게임에서는 저장됩니다.

## 4단계. 게시 (Publish)
1. **File → Publish to Roblox** 클릭
2. 정보 입력:
   - **Name**: `Comeback! K-pop Dress Up ✨`
   - **Description**: `Make your own K-pop star! Dress up, take photocards, collect outfits! 💖`
   - **Genre**: Fashion 또는 Town and City
   - **Devices**: Computer, Phone, Tablet 모두 체크
3. **Create** 클릭

## 5단계. 게시 후 필수 설정 (한 번만)
1. https://create.roblox.com → **Creations** → 방금 만든 게임 클릭
2. **Settings(설정)** 에서:
   - **Security** → **Enable Studio Access to API Services** 켜기 (코인 저장에 필요)
   - **Permissions** → **Public** 으로 변경 (이걸 켜야 남들이 플레이 가능)
3. **Audience(연령)** 설문 작성 — 폭력/공포 없음으로 답하면 전체이용가 등급이 나옴

## 6단계. 배경음악 넣기 (선택, 무료)
1. Studio 왼쪽 **Toolbox** 창 → **Audio** 탭 → "kpop" 또는 "pop music" 검색
2. 마음에 드는 **무료** 트랙 클릭 → 우클릭 → **Copy Asset ID**
3. 왼쪽 **Explorer** 창 → **SoundService** → **BGM** 클릭
4. 아래 **Properties** 창의 **SoundId** 칸에 복사한 ID 붙여넣기
5. 다시 **File → Publish to Roblox** (덮어쓰기)

> Toolbox의 오디오는 Roblox가 라이선스를 확보한 것이라 무료로 합법 사용 가능합니다.
> 실제 K-pop 곡(커버 포함)은 절대 사용하지 마세요.

## 자주 묻는 것

**Q. 옷장 아이템은 어디서 오나요?**
Roblox 공식 카탈로그에서 실시간으로 검색해 채워집니다 (검색어: "kpop idol hair", "y2k aesthetic" 등).
검색어를 바꾸고 싶으면 `roblox-game/src/shared/Config.luau`의 `searches` 부분을 수정하면 됩니다.

**Q. 게임 속 코인은 진짜 돈인가요?**
아니요. 플레이로만 얻는 무료 재화입니다. 실제 결제(Robux)는 아직 없습니다 — MVP 검증 후 붙일 예정.

**Q. 수정하고 싶은 게 생기면?**
이 저장소에서 코드를 수정 → Rojo로 다시 빌드한 `Comeback.rbxl`을 열어 다시 Publish 하면 됩니다.
(Claude에게 "이 부분 바꿔줘"라고 하면 됩니다)

## 게임에 들어있는 기능 (MVP v1)
- 드레스룸: 헤어 / 상의 / 하의 / 모자 / 피부톤(12종) 커스터마이징
- 옷장: Roblox 카탈로그 실시간 검색, 6개 중 1개는 무료, 나머지는 코인 구매
- 포토부스: 카운트다운 → 포토카드 프레임 → 기기 갤러리 저장 + 코인 보상 (60초 쿨타임)
- 경제: 시작 코인 100 / 포토카드 +15 / 일일 접속 보상 +50
- 저장: 코인·보유 아이템·착용 상태가 계정별로 자동 저장
- 안전: 자유 채팅 없음(Roblox 기본 필터만), 개인정보 수집 없음, 실존 아이돌 IP 없음
