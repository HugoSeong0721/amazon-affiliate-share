-- CatConfig (ModuleScript / ReplicatedStorage)
-- 게임의 이야기, 밸런스, 고양이 정보를 한곳에서 관리한다.
-- 숫자만 바꿔도 게임 난이도/속도가 달라진다.

local CatConfig = {}

---------------------------------------------------------------
-- 이야기
--
-- 플레이어는 작은 길고양이 쉼터의 주인이다.
-- 이 설정이 게임의 모든 규칙을 설명해준다.
--   밥을 준다      → 고양이가 건강해진다 (레벨)
--   돌보는 걸 본다 → 이웃이 후원금을 놓고 간다 (코인이 생기는 이유)
--   후원금을 모은다 → 거리의 다음 고양이를 데려올 구조 비용이 된다
--   전부 모으면    → 쉼터가 가득 찬다 (목표)
---------------------------------------------------------------
CatConfig.Intro = {
	"비가 몹시 오던 밤, 쉼터 문 앞에 상자 하나가 놓여 있었습니다.",
	"안에는 치즈색 새끼 고양이 한 마리.",
	"오늘부터 당신은 이 작은 쉼터의 주인입니다.",
}

CatConfig.IntroGoal = "거리에는 아직 네 마리가 더 기다리고 있어요."

-- 후원금이 왜 생기는지 UI에서 설명할 때 쓰는 문구
CatConfig.CurrencyName = "후원금"
CatConfig.FeedReason = "밥 주는 모습을 본 이웃이 후원금을 놓고 갔어요"
CatConfig.PassiveReason = "쉼터를 찾아온 손님들이 후원금을 두고 갔어요"
CatConfig.EndingMessage = "거리의 고양이들이 모두 쉼터로 왔어요. 이제 여기가 이 아이들의 집입니다. 🏠"

CatConfig.MaxEquipped = 3 -- 동시에 데리고 다닐 수 있는 고양이 수
CatConfig.FeedCooldown = 1.5 -- 밥 주기 쿨타임(초)
CatConfig.FeedXp = 10 -- 밥 한 번당 경험치
CatConfig.FeedCoins = 4 -- 밥 줄 때마다 받는 코인
-- 쿨타임과 코인은 "처음 2분 안에 새 고양이를 한 마리 사본다"를 기준으로 맞췄다.
-- 더 천천히 크는 게임으로 만들고 싶으면 쿨타임을 올리고 코인을 낮추면 된다.
CatConfig.StartCoins = 50 -- 새 플레이어 시작 코인
CatConfig.PassiveIncomeInterval = 10 -- 자동 코인 지급 주기(초)
-- 자동 코인 = 데리고 다니는 고양이들의 레벨 합계 (주기마다)

-- 구조 순서대로. Price가 0이면 이야기 속 첫 고양이(이미 쉼터에 있다).
-- Price는 "구조 비용"이다 — 병원비, 이동장, 첫 달 사료값.
CatConfig.Breeds = {
	{
		Id = "Cheese",
		Name = "치즈냥이",
		Price = 0,
		Story = "비 오는 밤, 상자에 담겨 쉼터 문 앞에 놓여 있던 아이",
		BodyColor = Color3.fromRGB(255, 184, 82),
		AccentColor = Color3.fromRGB(255, 231, 171),
	},
	{
		Id = "Black",
		Name = "까망냥이",
		Price = 80,
		Story = "불 꺼진 폐가에서 혼자 겨울을 난 아이",
		BodyColor = Color3.fromRGB(48, 48, 58),
		AccentColor = Color3.fromRGB(95, 95, 110),
	},
	{
		Id = "White",
		Name = "하양냥이",
		Price = 250,
		Story = "눈밭에 웅크리고 있어 하마터면 못 볼 뻔한 아이",
		BodyColor = Color3.fromRGB(242, 242, 242),
		AccentColor = Color3.fromRGB(255, 195, 207),
	},
	{
		Id = "Calico",
		Name = "삼색냥이",
		Price = 600,
		Story = "시장 골목 생선가게 앞을 매일 지키던 아이",
		BodyColor = Color3.fromRGB(232, 227, 214),
		AccentColor = Color3.fromRGB(154, 92, 42),
	},
	{
		Id = "Golden",
		Name = "황금냥이",
		Price = 2000,
		Story = "해질녘에만 보인다는, 소문으로만 돌던 아이",
		BodyColor = Color3.fromRGB(255, 199, 44),
		AccentColor = Color3.fromRGB(255, 240, 130),
	},
}

function CatConfig.GetBreed(id)
	for _, breed in ipairs(CatConfig.Breeds) do
		if breed.Id == id then
			return breed
		end
	end
	return nil
end

-- 다음 레벨까지 필요한 경험치
function CatConfig.XpForLevel(level)
	return 20 + (level - 1) * 15
end

-- 레벨에 따라 고양이가 커진다 (최대 2.5배)
function CatConfig.ScaleForLevel(level)
	return math.min(1 + (level - 1) * 0.08, 2.5)
end

return CatConfig
