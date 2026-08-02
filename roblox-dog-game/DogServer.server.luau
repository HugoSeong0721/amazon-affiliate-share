--[[
	🐶 멍멍 하우스! 강아지 키우기 — 서버 스크립트 (DogServer)

	넣는 위치: Roblox Studio > 탐색기(Explorer) > ServerScriptService
	           마우스 우클릭 > Insert Object > Script 를 만들고
	           이 파일 내용을 전부 붙여넣으세요.

	이 스크립트가 하는 일:
	  - 플레이어가 들어오면 파트(Part)만으로 강아지 모델을 조립해서 스폰 (에셋 불필요!)
	  - 강아지가 주인을 졸졸 따라다님 + 꼬리 흔들기
	  - 배고픔/행복/에너지 수치가 시간에 따라 줄어듦
	  - 밥주기 / 간식 / 쓰다듬기 / 공놀이(가져오기) / 산책 보상
	  - 레벨업하면 강아지가 조금씩 커짐 + 뼈다귀 코인 보상
	  - 상점에서 품종 교체 (시바견, 웰시코기, 푸들, 달마시안)
	  - DataStore 저장 (Studio에서는 Game Settings > Security >
	    "Enable Studio Access to API Services" 를 켜야 저장됩니다)

	게임 밸런스를 바꾸고 싶으면 아래 CONFIG 숫자만 만지면 됩니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

-- =====================================================================
-- 설정 (여기 숫자를 바꿔서 밸런스 조절)
-- =====================================================================
local CONFIG = {
	StartCoins = 100,       -- 시작 뼈다귀 코인
	TickSeconds = 5,        -- 수치가 변하는 주기(초)
	HungerDecay = 1.2,      -- 주기마다 줄어드는 배고픔
	HappyDecay = 0.7,       -- 주기마다 줄어드는 행복
	EnergyRegen = 1.5,      -- 주기마다 회복되는 에너지

	Actions = {
		feed  = { cooldown = 12, hunger = 30, exp = 2 },                          -- 밥 (무료)
		treat = { cooldown = 6,  cost = 15, hunger = 12, happy = 12, exp = 5 },   -- 간식 (코인 사용)
		pet   = { cooldown = 3,  happy = 6, exp = 3 },                            -- 쓰다듬기
		fetch = { cooldown = 8,  energyCost = 6, happy = 12, exp = 10, coins = 8 }, -- 공놀이
	},

	WalkRewardStuds = 60,   -- 함께 걸은 거리(스터드)마다 산책 보상
	WalkCoins = 2,
	WalkExp = 4,

	ExpPerLevel = 80,       -- 레벨업에 필요한 경험치 = 레벨 x 이 값
	LevelCoins = 30,        -- 레벨업 보상 코인
	ScalePerLevel = 0.04,   -- 레벨당 강아지 크기 증가
	MaxScale = 1.5,

	FollowDistance = 5,     -- 이 거리보다 멀면 따라옴
	TeleportDistance = 60,  -- 이 거리보다 멀면 순간이동
	WalkSpeed = 14,
	TiredSpeed = 8,         -- 에너지 25 미만일 때 속도
}

-- 품종 목록 (여기에 항목을 추가하면 상점에도 자동으로 나옵니다)
local BREEDS = {
	mix = {
		label = "믹스견", price = 0,
		body = Color3.fromRGB(154, 110, 70), ear = Color3.fromRGB(120, 82, 48),
		muzzle = Color3.fromRGB(214, 181, 143), patch = Color3.fromRGB(240, 228, 208),
		earStyle = "floppy", legScale = 1,
	},
	shiba = {
		label = "시바견", price = 250,
		body = Color3.fromRGB(226, 144, 68), ear = Color3.fromRGB(196, 114, 46),
		muzzle = Color3.fromRGB(248, 234, 212), patch = Color3.fromRGB(250, 240, 224),
		earStyle = "pointy", legScale = 1,
	},
	corgi = {
		label = "웰시코기", price = 400,
		body = Color3.fromRGB(235, 168, 84), ear = Color3.fromRGB(210, 136, 56),
		muzzle = Color3.fromRGB(250, 242, 226), patch = Color3.fromRGB(252, 246, 234),
		earStyle = "pointy", legScale = 0.6,
	},
	poodle = {
		label = "푸들", price = 600,
		body = Color3.fromRGB(238, 220, 190), ear = Color3.fromRGB(222, 198, 160),
		muzzle = Color3.fromRGB(246, 234, 212), patch = Color3.fromRGB(252, 244, 228),
		earStyle = "floppy", legScale = 1,
	},
	dalmatian = {
		label = "달마시안", price = 900,
		body = Color3.fromRGB(245, 245, 245), ear = Color3.fromRGB(40, 40, 40),
		muzzle = Color3.fromRGB(250, 250, 250), patch = Color3.fromRGB(255, 255, 255),
		earStyle = "floppy", legScale = 1, spots = true,
	},
}
local BREED_ORDER = { "mix", "shiba", "corgi", "poodle", "dalmatian" }

-- =====================================================================
-- 충돌 그룹: 강아지가 플레이어를 밀지 않게
-- =====================================================================
pcall(function() PhysicsService:RegisterCollisionGroup("Dogs") end)
pcall(function() PhysicsService:RegisterCollisionGroup("PlayerChars") end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("Dogs", "PlayerChars", false)
	PhysicsService:CollisionGroupSetCollidable("Dogs", "Dogs", false)
end)

local function setCharacterGroup(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "PlayerChars"
		end
	end
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.CollisionGroup = "PlayerChars"
		end
	end)
end

-- =====================================================================
-- 리모트 (클라이언트 UI와 통신)
-- =====================================================================
local remotes = Instance.new("Folder")
remotes.Name = "DogRemotes"
remotes.Parent = ReplicatedStorage

local reAction = Instance.new("RemoteEvent")   -- 클라 → 서버: 행동 요청
reAction.Name = "Action"
reAction.Parent = remotes

local reState = Instance.new("RemoteEvent")    -- 서버 → 클라: 상태 전송
reState.Name = "State"
reState.Parent = remotes

local reNotify = Instance.new("RemoteEvent")   -- 서버 → 클라: 알림 토스트
reNotify.Name = "Notify"
reNotify.Parent = remotes

local rfRename = Instance.new("RemoteFunction") -- 클라 → 서버: 이름 바꾸기
rfRename.Name = "Rename"
rfRename.Parent = remotes

local dogFolder = Instance.new("Folder")
dogFolder.Name = "Dogs"
dogFolder.Parent = workspace

-- =====================================================================
-- DataStore 저장/불러오기 (실패해도 게임은 계속 돌아가게 전부 pcall)
-- =====================================================================
local dogStore = nil
pcall(function()
	dogStore = DataStoreService:GetDataStore("DogGame_v1")
end)

local function defaultData()
	return {
		coins = CONFIG.StartCoins,
		dog = { name = "멍멍이", breed = "mix", level = 1, exp = 0 },
		stats = { hunger = 80, happiness = 80, energy = 100 },
		owned = { mix = true },
	}
end

-- 불러오기를 여러 번 재시도한다.
-- 반환: ok(통신 성공 여부), stored(저장본 또는 nil = 신규 플레이어)
--
-- ⚠️ ok 와 "저장본 없음"을 반드시 구분해야 한다.
--    통신 실패를 신규 플레이어로 착각하면, 잠시 뒤 자동 저장이
--    플레이어가 키우던 강아지를 새 강아지로 덮어써 버린다.
local LOAD_RETRIES = 4

local function fetchSave(userId)
	for attempt = 1, LOAD_RETRIES do
		local ok, result = pcall(function()
			return dogStore:GetAsync("player_" .. userId)
		end)
		if ok then return true, result end
		if attempt < LOAD_RETRIES then
			task.wait(attempt * 1.5) -- 1.5s, 3s, 4.5s 뒤 재시도
		end
	end
	return false, nil
end

-- 반환: data, loadOk
local function loadData(player)
	local stored, loadOk = nil, true
	if dogStore then
		loadOk, stored = fetchSave(player.UserId)
	end

	local data = type(stored) == "table" and stored or defaultData()

	-- 예전 저장본에 빠진 칸이 있으면 기본값으로 채움
	local base = defaultData()
	for key, value in pairs(base) do
		if data[key] == nil then data[key] = value end
	end
	for key, value in pairs(base.dog) do
		if data.dog[key] == nil then data.dog[key] = value end
	end
	for key, value in pairs(base.stats) do
		if data.stats[key] == nil then data.stats[key] = value end
	end
	if not BREEDS[data.dog.breed] then data.dog.breed = "mix" end
	return data, loadOk
end

local function saveData(player, info)
	if not dogStore or not info or not info.data then return end
	-- 불러오기가 실패했던 세션은 절대 저장하지 않는다 (기존 저장본 보호)
	if info.saveBlocked then return end
	pcall(function()
		dogStore:SetAsync("player_" .. player.UserId, info.data)
	end)
end

-- =====================================================================
-- 강아지 모델 조립 (파트만 사용, 에셋 없음)
-- =====================================================================
local function makePart(props, parent)
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = parent
	return part
end

local function weldTo(root, part, offsetCF)
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = part
	weld.C0 = offsetCF
	weld.C1 = CFrame.new()
	weld.Parent = root
	return weld
end

local function tailBaseCF()
	-- 꼬리가 몸 뒤쪽 위에 비스듬히 붙는 위치
	return CFrame.new(0, 0.45, 1.35) * CFrame.Angles(-0.6, 0, 0)
end

local function buildDogModel(breedId)
	local breed = BREEDS[breedId] or BREEDS.mix
	local legScale = breed.legScale or 1

	local model = Instance.new("Model")
	model.Name = "Dog"

	-- 루트 (보이지 않는 몸통 크기 파트, 휴머노이드가 이걸 움직임)
	local root = makePart({
		Name = "HumanoidRootPart",
		Size = Vector3.new(1.6, 1.2, 2.8),
		Transparency = 1,
		CanCollide = true,
		CanQuery = true,
	}, model)
	root.CollisionGroup = "Dogs"
	model.PrimaryPart = root

	-- 몸통
	makePart({ Name = "Body", Size = Vector3.new(1.6, 1.2, 2.8), Color = breed.body }, model)
	weldTo(root, model.Body, CFrame.new())

	-- 가슴 무늬
	local chest = makePart({ Name = "Chest", Size = Vector3.new(1.0, 0.8, 0.2), Color = breed.patch }, model)
	weldTo(root, chest, CFrame.new(0, -0.15, -1.35))

	-- 다리 4개 (코기는 legScale 로 짧아짐)
	local legLen = 0.9 * legScale
	for _, pos in ipairs({
		Vector3.new(-0.55, 0, -1.0), Vector3.new(0.55, 0, -1.0),
		Vector3.new(-0.55, 0, 1.0), Vector3.new(0.55, 0, 1.0),
	}) do
		local leg = makePart({ Name = "Leg", Size = Vector3.new(0.45, legLen, 0.45), Color = breed.body }, model)
		weldTo(root, leg, CFrame.new(pos.X, -0.6 - legLen / 2, pos.Z))
	end

	-- 머리 / 주둥이 / 코 / 혀
	local head = makePart({ Name = "Head", Size = Vector3.new(1.3, 1.1, 1.1), Color = breed.body }, model)
	weldTo(root, head, CFrame.new(0, 0.95, -1.6))

	local snout = makePart({ Name = "Snout", Size = Vector3.new(0.55, 0.4, 0.5), Color = breed.muzzle }, model)
	weldTo(root, snout, CFrame.new(0, 0.78, -2.3))

	local nose = makePart({ Name = "Nose", Size = Vector3.new(0.24, 0.18, 0.12), Color = Color3.fromRGB(35, 30, 30) }, model)
	weldTo(root, nose, CFrame.new(0, 0.88, -2.56))

	local tongue = makePart({ Name = "Tongue", Size = Vector3.new(0.3, 0.06, 0.4), Color = Color3.fromRGB(255, 130, 150) }, model)
	weldTo(root, tongue, CFrame.new(0, 0.56, -2.42) * CFrame.Angles(-0.25, 0, 0))

	-- 눈
	for _, x in ipairs({ -0.3, 0.3 }) do
		local eye = makePart({ Name = "Eye", Size = Vector3.new(0.16, 0.24, 0.08), Color = Color3.fromRGB(25, 22, 22) }, model)
		weldTo(root, eye, CFrame.new(x, 1.12, -2.16))
	end

	-- 귀 (품종별로 접힌 귀 / 쫑긋 귀)
	if breed.earStyle == "pointy" then
		for _, x in ipairs({ -0.42, 0.42 }) do
			local ear = makePart({ Name = "Ear", Size = Vector3.new(0.3, 0.55, 0.22), Color = breed.ear }, model)
			weldTo(root, ear, CFrame.new(x, 1.68, -1.5) * CFrame.Angles(0, 0, x < 0 and 0.15 or -0.15))
		end
	else
		for _, x in ipairs({ -0.68, 0.68 }) do
			local ear = makePart({ Name = "Ear", Size = Vector3.new(0.28, 0.62, 0.5), Color = breed.ear }, model)
			weldTo(root, ear, CFrame.new(x, 1.25, -1.55) * CFrame.Angles(0, 0, x < 0 and 0.4 or -0.4))
		end
	end

	-- 달마시안 점무늬
	if breed.spots then
		local spotSpots = {
			CFrame.new(-0.5, 0.45, -0.4), CFrame.new(0.55, 0.5, 0.3),
			CFrame.new(-0.35, 0.4, 0.9), CFrame.new(0.3, 0.55, -0.9),
			CFrame.new(0.45, 1.35, -1.45),
		}
		for _, cf in ipairs(spotSpots) do
			local spot = makePart({ Name = "Spot", Size = Vector3.new(0.34, 0.1, 0.34), Color = Color3.fromRGB(40, 40, 40) }, model)
			weldTo(root, spot, cf)
		end
	end

	-- 꼬리 (살랑살랑 흔들 예정)
	local tail = makePart({ Name = "Tail", Size = Vector3.new(0.28, 0.28, 0.95), Color = breed.ear }, model)
	local tailWeld = Instance.new("Weld")
	tailWeld.Part0 = root
	tailWeld.Part1 = tail
	tailWeld.C0 = tailBaseCF()
	tailWeld.C1 = CFrame.new(0, 0, -0.45) -- 꼬리 뿌리를 축으로 회전하게
	tailWeld.Parent = root

	-- 쓰다듬을 때 나오는 반짝이
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "PetSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 150, 190))
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.Rate = 0
	sparkle.Enabled = false
	sparkle.Parent = head

	-- 이름표
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 160, 0, 56)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DogName"
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextStrokeColor3 = Color3.fromRGB(90, 60, 30)
	nameLabel.Parent = billboard

	local moodLabel = Instance.new("TextLabel")
	moodLabel.Name = "Mood"
	moodLabel.Size = UDim2.new(1, 0, 0.45, 0)
	moodLabel.Position = UDim2.new(0, 0, 0.55, 0)
	moodLabel.BackgroundTransparency = 1
	moodLabel.Font = Enum.Font.GothamBold
	moodLabel.TextScaled = true
	moodLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	moodLabel.Parent = billboard

	-- 휴머노이드 (걷기 담당)
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = legLen + 0.05
	humanoid.WalkSpeed = CONFIG.WalkSpeed
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayName = ""
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = model

	return {
		model = model,
		root = root,
		humanoid = humanoid,
		tailWeld = tailWeld,
		sparkle = sparkle,
		nameLabel = nameLabel,
		moodLabel = moodLabel,
	}
end

-- =====================================================================
-- 플레이어별 강아지 관리
-- =====================================================================
local dogs = {}      -- [player] = { data, rig, state, cooldowns, ... }

local function moodEmoji(stats)
	if stats.hunger < 30 then return "🍖..?" end
	if stats.energy < 25 then return "😴" end
	if stats.happiness < 30 then return "😢" end
	if stats.happiness > 80 then return "😆" end
	return "🙂"
end

local function sendState(player)
	local info = dogs[player]
	if not info then return end
	local dog = info.data.dog
	local catalog = {}
	for _, id in ipairs(BREED_ORDER) do
		local breed = BREEDS[id]
		table.insert(catalog, {
			id = id,
			label = breed.label,
			price = breed.price,
			rgb = { math.floor(breed.body.R * 255), math.floor(breed.body.G * 255), math.floor(breed.body.B * 255) },
		})
	end
	reState:FireClient(player, {
		coins = info.data.coins,
		name = dog.name,
		breed = dog.breed,
		level = dog.level,
		exp = dog.exp,
		expNext = dog.level * CONFIG.ExpPerLevel,
		hunger = info.data.stats.hunger,
		happiness = info.data.stats.happiness,
		energy = info.data.stats.energy,
		owned = info.data.owned,
		catalog = catalog,
		cooldowns = {
			feed = CONFIG.Actions.feed.cooldown,
			treat = CONFIG.Actions.treat.cooldown,
			pet = CONFIG.Actions.pet.cooldown,
			fetch = CONFIG.Actions.fetch.cooldown,
		},
		prices = { treat = CONFIG.Actions.treat.cost },
	})
end

local function notify(player, message, kind)
	reNotify:FireClient(player, message, kind or "good")
end

local function updateBillboard(info)
	local dog = info.data.dog
	info.rig.nameLabel.Text = dog.name .. " · Lv." .. dog.level
	info.rig.moodLabel.Text = moodEmoji(info.data.stats)
end

local function dogScale(level)
	return math.min(1 + (level - 1) * CONFIG.ScalePerLevel, CONFIG.MaxScale)
end

local function applyScale(info)
	local scale = dogScale(info.data.dog.level)
	pcall(function()
		info.rig.model:ScaleTo(scale)
	end)
	info.scale = scale
end

local function addExp(player, amount)
	local info = dogs[player]
	if not info then return end
	local dog = info.data.dog
	dog.exp = dog.exp + amount
	local need = dog.level * CONFIG.ExpPerLevel
	while dog.exp >= need do
		dog.exp = dog.exp - need
		dog.level = dog.level + 1
		info.data.coins = info.data.coins + CONFIG.LevelCoins
		need = dog.level * CONFIG.ExpPerLevel
		applyScale(info)
		info.rig.humanoid.Jump = true
		info.rig.sparkle:Emit(20)
		notify(player, "🎉 " .. dog.name .. " 레벨 " .. dog.level .. " 달성! +" .. CONFIG.LevelCoins .. "🦴")
	end
	updateBillboard(info)
end

local function spawnDog(player, breedId)
	local info = dogs[player]
	if not info then return end

	-- 기존 모델 제거
	if info.rig and info.rig.model then
		info.rig.model:Destroy()
	end

	local rig = buildDogModel(breedId)
	rig.model.Name = "Dog_" .. player.UserId
	info.rig = rig
	info.state = "follow"
	if info.ball then
		info.ball:Destroy()
		info.ball = nil
	end

	-- 주인 옆에 스폰
	local character = player.Character
	local ownerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local spawnCF = CFrame.new(0, 5, 0)
	if ownerRoot then
		spawnCF = ownerRoot.CFrame * CFrame.new(3, 1, 2)
	end
	rig.model:PivotTo(spawnCF)
	rig.model.Parent = dogFolder
	rig.root:SetNetworkOwner(nil) -- 서버가 강아지 움직임 담당

	applyScale(info)
	updateBillboard(info)
end

-- =====================================================================
-- 행동 처리 (밥 / 간식 / 쓰다듬기 / 공놀이 / 품종 구매)
-- =====================================================================
local function onCooldown(info, action)
	local now = os.clock()
	local last = info.cooldowns[action] or 0
	local cd = CONFIG.Actions[action] and CONFIG.Actions[action].cooldown or 1
	if now - last < cd then return true end
	info.cooldowns[action] = now
	return false
end

local function clampStats(stats)
	stats.hunger = math.clamp(stats.hunger, 0, 100)
	stats.happiness = math.clamp(stats.happiness, 0, 100)
	stats.energy = math.clamp(stats.energy, 0, 100)
end

local function throwBall(player, info)
	local character = player.Character
	local ownerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not ownerRoot then return end

	local ball = makePart({
		Name = "FetchBall",
		Size = Vector3.new(1, 1, 1),
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(255, 89, 89),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		Massless = false,
	}, workspace)
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.4, 0.55)
	ball.CFrame = ownerRoot.CFrame * CFrame.new(0, 2, -3)
	ball.AssemblyLinearVelocity = ownerRoot.CFrame.LookVector * 42 + Vector3.new(0, 24, 0)
	ball:SetNetworkOwner(nil)

	info.ball = ball
	info.state = "chase"
	info.chaseStart = os.clock()
end

local function handleAction(player, action, arg)
	local info = dogs[player]
	if not info or not info.rig then return end
	local stats = info.data.stats
	local dog = info.data.dog

	if action == "feed" then
		if onCooldown(info, "feed") then return end
		local cfg = CONFIG.Actions.feed
		stats.hunger = stats.hunger + cfg.hunger
		clampStats(stats)
		info.rig.humanoid.Jump = true
		notify(player, "🍖 냠냠! " .. dog.name .. "가 맛있게 먹었어요")
		addExp(player, cfg.exp)

	elseif action == "treat" then
		if onCooldown(info, "treat") then return end
		local cfg = CONFIG.Actions.treat
		if info.data.coins < cfg.cost then
			notify(player, "뼈다귀 코인이 부족해요! 산책과 공놀이로 모아보세요", "warn")
			return
		end
		info.data.coins = info.data.coins - cfg.cost
		stats.hunger = stats.hunger + cfg.hunger
		stats.happiness = stats.happiness + cfg.happy
		clampStats(stats)
		info.rig.sparkle:Emit(10)
		notify(player, "🦴 간식 냠냠! " .. dog.name .. "가 정말 좋아해요")
		addExp(player, cfg.exp)

	elseif action == "pet" then
		if onCooldown(info, "pet") then return end
		local cfg = CONFIG.Actions.pet
		stats.happiness = stats.happiness + cfg.happy
		clampStats(stats)
		info.rig.humanoid.Jump = true
		info.rig.sparkle:Emit(8)
		notify(player, "🤍 " .. dog.name .. "를 쓰다듬었어요")
		addExp(player, cfg.exp)

	elseif action == "fetch" then
		if info.state ~= "follow" then return end
		if onCooldown(info, "fetch") then return end
		local cfg = CONFIG.Actions.fetch
		if stats.energy < cfg.energyCost then
			notify(player, "😴 " .. dog.name .. "가 너무 피곤해요. 조금 쉬게 해주세요", "warn")
			return
		end
		stats.energy = stats.energy - cfg.energyCost
		clampStats(stats)
		throwBall(player, info)
		notify(player, "🎾 공을 던졌어요! " .. dog.name .. "가 달려갑니다")

	elseif action == "buy" then
		local breed = BREEDS[arg]
		if not breed then return end
		if info.data.owned[arg] then
			if dog.breed ~= arg then
				dog.breed = arg
				spawnDog(player, arg)
				notify(player, "🐶 " .. breed.label .. "(으)로 변신!")
			end
		else
			if info.data.coins < breed.price then
				notify(player, "코인이 부족해요! (" .. breed.price .. "🦴 필요)", "warn")
				return
			end
			info.data.coins = info.data.coins - breed.price
			info.data.owned[arg] = true
			dog.breed = arg
			spawnDog(player, arg)
			notify(player, "🎉 " .. breed.label .. " 입양 완료!")
		end
	end

	updateBillboard(info)
	sendState(player)
end

reAction.OnServerEvent:Connect(function(player, action, arg)
	if type(action) ~= "string" then return end
	handleAction(player, action, arg)
end)

-- 이름 바꾸기 (다른 플레이어에게도 보이므로 텍스트 필터링 필수)
rfRename.OnServerInvoke = function(player, newName)
	local info = dogs[player]
	if not info then return { ok = false, msg = "잠시 후 다시 시도해주세요" } end
	if type(newName) ~= "string" then return { ok = false, msg = "이름이 올바르지 않아요" } end
	newName = newName:gsub("^%s+", ""):gsub("%s+$", "")
	local length = utf8.len(newName)
	if not length or length < 1 or length > 12 then
		return { ok = false, msg = "이름은 1~12자로 해주세요" }
	end

	local filtered = newName
	local ok = pcall(function()
		local result = TextService:FilterStringAsync(newName, player.UserId)
		filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		-- 필터 서버 오류 시 원래 이름 유지 (Studio 오프라인 등)
		filtered = newName
	end

	info.data.dog.name = filtered
	updateBillboard(info)
	sendState(player)
	return { ok = true, name = filtered }
end

-- =====================================================================
-- 강아지 AI 루프: 따라오기 / 공 쫓기 / 돌아오기 / 산책 보상
-- =====================================================================
local function runDogLoop(player)
	local walkAccum = 0
	local lastOwnerPos = nil

	while dogs[player] do
		local info = dogs[player]
		if not info then break end
		local rig = info.rig
		local character = player.Character
		local ownerRoot = character and character:FindFirstChild("HumanoidRootPart")

		if rig and rig.model.Parent and ownerRoot then
			local dogPos = rig.root.Position
			local ownerPos = ownerRoot.Position

			-- 산책 보상: 강아지가 근처에 있을 때 함께 걸은 거리 적립
			if lastOwnerPos then
				local moved = (ownerPos - lastOwnerPos).Magnitude
				if moved > 0.1 and moved < 30 and (ownerPos - dogPos).Magnitude < 30 then
					walkAccum = walkAccum + moved
					if walkAccum >= CONFIG.WalkRewardStuds then
						walkAccum = walkAccum - CONFIG.WalkRewardStuds
						info.data.coins = info.data.coins + CONFIG.WalkCoins
						info.data.stats.happiness = math.clamp(info.data.stats.happiness + 2, 0, 100)
						addExp(player, CONFIG.WalkExp)
						notify(player, "🐾 산책 보상! +" .. CONFIG.WalkCoins .. "🦴")
						sendState(player)
					end
				end
			end
			lastOwnerPos = ownerPos

			-- 상태별 움직임
			if info.state == "chase" and info.ball and info.ball.Parent then
				rig.humanoid:MoveTo(info.ball.Position)
				if (info.ball.Position - dogPos).Magnitude < 3.5 then
					info.ball:Destroy()
					info.ball = nil
					info.state = "return"
				elseif os.clock() - (info.chaseStart or 0) > 12 then
					info.ball:Destroy()
					info.ball = nil
					info.state = "follow"
					notify(player, "공을 놓쳐버렸어요...", "warn")
				end
			elseif info.state == "return" then
				rig.humanoid:MoveTo(ownerPos)
				if (ownerPos - dogPos).Magnitude < 6 then
					info.state = "follow"
					local cfg = CONFIG.Actions.fetch
					info.data.coins = info.data.coins + cfg.coins
					info.data.stats.happiness = math.clamp(info.data.stats.happiness + cfg.happy, 0, 100)
					rig.humanoid.Jump = true
					rig.sparkle:Emit(12)
					addExp(player, cfg.exp)
					notify(player, "🎾 물어왔어요! +" .. cfg.coins .. "🦴")
					sendState(player)
				end
			else
				-- 기본: 주인 따라다니기
				local distance = (ownerPos - dogPos).Magnitude
				if distance > CONFIG.TeleportDistance then
					rig.model:PivotTo(ownerRoot.CFrame * CFrame.new(3, 1, 2))
				elseif distance > CONFIG.FollowDistance then
					local target = (ownerRoot.CFrame * CFrame.new(2.5, 0, 2.5)).Position
					rig.humanoid:MoveTo(target)
				end
			end

			-- 피곤하면 느려짐
			rig.humanoid.WalkSpeed = info.data.stats.energy < 25 and CONFIG.TiredSpeed or CONFIG.WalkSpeed
		end

		task.wait(0.25)
	end
end

-- 꼬리 흔들기: 행복할수록 살랑살랑 빨라짐
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, info in pairs(dogs) do
		local rig = info.rig
		if rig and rig.tailWeld and rig.tailWeld.Parent then
			local happiness = info.data.stats.happiness
			local speed = 3 + happiness / 12
			local swing = math.sin(now * speed) * 0.55
			local scale = info.scale or 1
			local base = CFrame.new(0, 0.45 * scale, 1.35 * scale) * CFrame.Angles(-0.6, 0, 0)
			rig.tailWeld.C0 = base * CFrame.Angles(0, swing, 0)
		end
	end
end)

-- 수치 감소/회복 틱
task.spawn(function()
	while true do
		task.wait(CONFIG.TickSeconds)
		for player, info in pairs(dogs) do
			local stats = info.data.stats
			stats.hunger = stats.hunger - CONFIG.HungerDecay
			-- 배고프면 행복이 더 빨리 떨어짐
			local happyDecay = stats.hunger <= 0 and CONFIG.HappyDecay * 3 or CONFIG.HappyDecay
			stats.happiness = stats.happiness - happyDecay
			-- 공놀이 중이 아니면 에너지 회복
			if info.state == "follow" then
				stats.energy = stats.energy + CONFIG.EnergyRegen
			end
			clampStats(stats)

			if info.rig then
				updateBillboard(info)
			end
			sendState(player)

			if stats.hunger < 25 and not info.warnedHunger then
				info.warnedHunger = true
				notify(player, "🍖 " .. info.data.dog.name .. "가 배고파해요!", "warn")
			elseif stats.hunger >= 40 then
				info.warnedHunger = false
			end
		end
	end
end)

-- 2분마다 자동 저장
task.spawn(function()
	while true do
		task.wait(120)
		for player, info in pairs(dogs) do
			saveData(player, info)
		end
	end
end)

-- =====================================================================
-- 입장 / 퇴장
-- =====================================================================
local function onPlayerAdded(player)
	local data, loadOk = loadData(player)
	dogs[player] = {
		data = data,
		saveBlocked = not loadOk,
		rig = nil,
		state = "follow",
		cooldowns = {},
		ball = nil,
		scale = 1,
	}

	player.CharacterAdded:Connect(function(character)
		setCharacterGroup(character)
		task.wait(0.5)
		local info = dogs[player]
		if info then
			if info.rig and info.rig.model.Parent then
				-- 리스폰하면 강아지를 옆으로 데려오기
				local ownerRoot = character:WaitForChild("HumanoidRootPart", 5)
				if ownerRoot then
					info.rig.model:PivotTo(ownerRoot.CFrame * CFrame.new(3, 1, 2))
				end
			else
				spawnDog(player, info.data.dog.breed)
			end
		end
	end)

	if player.Character then
		setCharacterGroup(player.Character)
	end

	-- 캐릭터 준비되면 강아지 스폰
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 10)
		if dogs[player] and not dogs[player].rig then
			spawnDog(player, data.dog.breed)
		end
		sendState(player)
		notify(player, "🐶 " .. data.dog.name .. "가 반겨줍니다! 멍멍!")
		if not loadOk then
			-- 저장본을 못 읽었다. 덮어쓰기를 막았으니 진행 상황은 안전하지만,
			-- 이번 판의 플레이는 저장되지 않는다는 걸 반드시 알려준다.
			task.wait(2)
			notify(player, "⚠️ 저장 정보를 불러오지 못했어요. 이번 판은 저장되지 않습니다 (기존 강아지는 안전해요)", "warn")
		end
		task.spawn(runDogLoop, player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local info = dogs[player]
	if info then
		saveData(player, info)
		if info.ball then info.ball:Destroy() end
		if info.rig and info.rig.model then info.rig.model:Destroy() end
		dogs[player] = nil
	end
end)

-- 서버가 꺼질 때 마지막 저장
game:BindToClose(function()
	for player, info in pairs(dogs) do
		saveData(player, info)
	end
	task.wait(2)
end)

print("[DogServer] 🐶 강아지 키우기 서버 시작!")
