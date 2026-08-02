-- CatConfig (ModuleScript / ReplicatedStorage)
-- 게임 밸런스와 고양이 품종 정보를 한곳에서 관리한다.
-- 숫자만 바꿔도 게임 난이도/속도가 달라진다.

local CatConfig = {}

CatConfig.MaxEquipped = 3 -- 동시에 데리고 다닐 수 있는 고양이 수
CatConfig.FeedCooldown = 1.5 -- 밥 주기 쿨타임(초)
CatConfig.FeedXp = 10 -- 밥 한 번당 경험치
CatConfig.FeedCoins = 4 -- 밥 줄 때마다 받는 코인
-- 쿨타임과 코인은 "처음 2분 안에 새 고양이를 한 마리 사본다"를 기준으로 맞췄다.
-- 더 천천히 크는 게임으로 만들고 싶으면 쿨타임을 올리고 코인을 낮추면 된다.
CatConfig.StartCoins = 50 -- 새 플레이어 시작 코인
CatConfig.PassiveIncomeInterval = 10 -- 자동 코인 지급 주기(초)
-- 자동 코인 = 데리고 다니는 고양이들의 레벨 합계 (주기마다)

-- 상점에 표시되는 순서대로. Price가 0이면 시작 고양이(구매 불가).
CatConfig.Breeds = {
	{
		Id = "Cheese",
		Name = "치즈냥이",
		Price = 0,
		BodyColor = Color3.fromRGB(255, 184, 82),
		AccentColor = Color3.fromRGB(255, 231, 171),
	},
	{
		Id = "Black",
		Name = "까망냥이",
		Price = 100,
		BodyColor = Color3.fromRGB(48, 48, 58),
		AccentColor = Color3.fromRGB(95, 95, 110),
	},
	{
		Id = "White",
		Name = "하양냥이",
		Price = 250,
		BodyColor = Color3.fromRGB(242, 242, 242),
		AccentColor = Color3.fromRGB(255, 195, 207),
	},
	{
		Id = "Calico",
		Name = "삼색냥이",
		Price = 600,
		BodyColor = Color3.fromRGB(232, 227, 214),
		AccentColor = Color3.fromRGB(154, 92, 42),
	},
	{
		Id = "Golden",
		Name = "황금냥이",
		Price = 2000,
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
