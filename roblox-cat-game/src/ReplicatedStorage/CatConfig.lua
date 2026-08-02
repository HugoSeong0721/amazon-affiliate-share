-- CatConfig (ModuleScript / ReplicatedStorage)
--
-- 게임의 모든 수치와 내용이 여기 모여 있다.
--
-- 게임 구조는 Pet Simulator 계열을 따른다:
--   고양이가 주변 물건을 자동으로 부순다 → 코인이 나온다
--   → 코인으로 상자를 열어 더 센 고양이를 뽑는다
--   → 센 고양이로 더 좋은 구역을 해금한다 → 반복
--   → 끝까지 가면 환생해서 영구 배율을 얻고 다시 시작한다

local CatConfig = {}

---------------------------------------------------------------
-- 기본 규칙
---------------------------------------------------------------
CatConfig.MaxEquipped = 4 -- 동시에 데리고 다니는 고양이 수
CatConfig.StartCoins = 0
CatConfig.AttackInterval = 0.25 -- 고양이가 물건을 때리는 주기(초)
CatConfig.AttackRange = 26 -- 이 거리 안의 물건만 때린다
CatConfig.RebirthPowerBonus = 0.25 -- 환생 1회당 파워 +25%

---------------------------------------------------------------
-- 등급
---------------------------------------------------------------
CatConfig.Rarities = {
	Common = { Name = "일반", Color = Color3.fromRGB(178, 178, 178), Order = 1 },
	Uncommon = { Name = "고급", Color = Color3.fromRGB(108, 196, 118), Order = 2 },
	Rare = { Name = "희귀", Color = Color3.fromRGB(86, 152, 232), Order = 3 },
	Epic = { Name = "영웅", Color = Color3.fromRGB(170, 110, 226), Order = 4 },
	Legendary = { Name = "전설", Color = Color3.fromRGB(255, 186, 58), Order = 5 },
}

---------------------------------------------------------------
-- 고양이
--   Power = 초당 부수는 힘. 이 숫자가 게임의 전부다.
---------------------------------------------------------------
CatConfig.Cats = {
	{ Id = "Cheese", Name = "치즈냥이", Rarity = "Common", Power = 5,
	  Body = Color3.fromRGB(255, 184, 82), Accent = Color3.fromRGB(255, 231, 171) },
	{ Id = "Tabby", Name = "고등어냥이", Rarity = "Common", Power = 9,
	  Body = Color3.fromRGB(128, 134, 142), Accent = Color3.fromRGB(78, 84, 92) },
	{ Id = "Black", Name = "까망냥이", Rarity = "Uncommon", Power = 22,
	  Body = Color3.fromRGB(48, 48, 58), Accent = Color3.fromRGB(95, 95, 110) },
	{ Id = "White", Name = "하양냥이", Rarity = "Uncommon", Power = 55,
	  Body = Color3.fromRGB(242, 242, 242), Accent = Color3.fromRGB(255, 195, 207) },
	{ Id = "Calico", Name = "삼색냥이", Rarity = "Rare", Power = 200,
	  Body = Color3.fromRGB(232, 227, 214), Accent = Color3.fromRGB(154, 92, 42) },
	{ Id = "Tuxedo", Name = "턱시도냥이", Rarity = "Rare", Power = 480,
	  Body = Color3.fromRGB(32, 32, 38), Accent = Color3.fromRGB(248, 248, 248) },
	{ Id = "Siamese", Name = "샴냥이", Rarity = "Epic", Power = 2200,
	  Body = Color3.fromRGB(232, 214, 186), Accent = Color3.fromRGB(92, 66, 54) },
	{ Id = "Bengal", Name = "벵갈냥이", Rarity = "Epic", Power = 5500,
	  Body = Color3.fromRGB(214, 158, 74), Accent = Color3.fromRGB(70, 52, 32) },
	{ Id = "Golden", Name = "황금냥이", Rarity = "Legendary", Power = 30000,
	  Body = Color3.fromRGB(255, 199, 44), Accent = Color3.fromRGB(255, 240, 130) },
	{ Id = "Rainbow", Name = "무지개냥이", Rarity = "Legendary", Power = 120000,
	  Body = Color3.fromRGB(255, 126, 182), Accent = Color3.fromRGB(126, 214, 255) },
}

function CatConfig.GetCat(id)
	for _, cat in ipairs(CatConfig.Cats) do
		if cat.Id == id then
			return cat
		end
	end
	return nil
end

-- 같은 고양이 3마리를 합치면 골든이 된다 (파워 5배)
CatConfig.FuseCount = 3
CatConfig.GoldenMultiplier = 5

function CatConfig.PowerOf(entry)
	local cat = CatConfig.GetCat(entry.Id)
	if not cat then
		return 0
	end
	return cat.Power * (entry.Golden and CatConfig.GoldenMultiplier or 1)
end

---------------------------------------------------------------
-- 구역
--   부술 물건의 체력과 보상이 구역마다 한 단계씩 뛴다.
--   해금 비용은 "이전 구역에서 잠깐 모으면 닿는" 수준으로 잡았다.
---------------------------------------------------------------
CatConfig.Zones = {
	{
		Id = "Yard", Name = "우리집 마당", UnlockCost = 0,
		Origin = Vector3.new(0, 0, 0),
		BreakableHp = 10, Reward = 8, BreakableCount = 10,
		EggName = "낡은 상자", EggCost = 50,
		EggPool = { Cheese = 70, Tabby = 25, Black = 5 },
	},
	{
		Id = "Alley", Name = "뒷골목", UnlockCost = 320,
		Origin = Vector3.new(0, 0, -130),
		BreakableHp = 400, Reward = 60, BreakableCount = 12,
		EggName = "종이 상자", EggCost = 300,
		EggPool = { Tabby = 45, Black = 35, White = 18, Calico = 2 },
	},
	{
		Id = "Park", Name = "공원", UnlockCost = 2400,
		Origin = Vector3.new(0, 0, -260),
		BreakableHp = 1600, Reward = 900, BreakableCount = 14,
		EggName = "소풍 바구니", EggCost = 4500,
		EggPool = { White = 40, Calico = 35, Tuxedo = 22, Siamese = 3 },
	},
	{
		Id = "Harbor", Name = "항구", UnlockCost = 36000,
		Origin = Vector3.new(0, 0, -390),
		BreakableHp = 12000, Reward = 14000, BreakableCount = 16,
		EggName = "생선 궤짝", EggCost = 70000,
		EggPool = { Tuxedo = 38, Siamese = 36, Bengal = 24, Golden = 2 },
	},
	{
		Id = "Rooftop", Name = "달빛 옥상", UnlockCost = 560000,
		Origin = Vector3.new(0, 0, -520),
		BreakableHp = 100000, Reward = 220000, BreakableCount = 18,
		EggName = "별빛 상자", EggCost = 1100000,
		EggPool = { Bengal = 45, Golden = 40, Rainbow = 15 },
	},
}

function CatConfig.GetZone(id)
	for index, zone in ipairs(CatConfig.Zones) do
		if zone.Id == id then
			return zone, index
		end
	end
	return nil, nil
end

CatConfig.BreakableRespawn = 3 -- 부순 물건이 다시 나타나기까지(초)

-- 구역마다 부술 물건의 생김새
CatConfig.BreakableSkins = {
	Yard = { Name = "털뭉치", Color = Color3.fromRGB(226, 142, 168), Size = 3.2 },
	Alley = { Name = "사료 포대", Color = Color3.fromRGB(178, 148, 96), Size = 3.6 },
	Park = { Name = "장난감 상자", Color = Color3.fromRGB(126, 186, 232), Size = 4.0 },
	Harbor = { Name = "생선 궤짝", Color = Color3.fromRGB(122, 158, 148), Size = 4.4 },
	Rooftop = { Name = "별조각", Color = Color3.fromRGB(214, 178, 255), Size = 4.8 },
}

---------------------------------------------------------------
-- 환생
---------------------------------------------------------------
CatConfig.RebirthCost = 50000000 -- 마지막 구역을 열고 이만큼 더 모으면 환생 가능

---------------------------------------------------------------
-- 이야기 (안내창에 쓰인다)
---------------------------------------------------------------
CatConfig.Intro = {
	"고양이들은 부술 게 있으면 못 참습니다.",
	"털뭉치든 상자든, 눈에 띄면 일단 달려들죠.",
	"그 습성을 이용해 온 동네의 물건을 부수고 코인을 모으세요.",
}
CatConfig.IntroGoal = "더 센 고양이를 뽑아서, 달빛 옥상까지 올라가는 게 목표예요."

return CatConfig
