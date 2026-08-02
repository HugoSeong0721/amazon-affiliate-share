-- CatGameServer (Script / ServerScriptService)
-- 고양이 키우기 게임의 서버 로직 전부:
--   고양이 모델 생성(파츠 조립), 주인 따라다니기, 밥 주기/레벨업,
--   상점 구매, 장착/해제, 코인 지급, DataStore 저장/불러오기

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))

---------------------------------------------------------------
-- 리모트 이벤트 (클라이언트 UI와 통신)
---------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "CatGameRemotes"

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local buyCatRemote = makeRemote("BuyCat") -- 클라 → 서버: 품종 Id
local toggleEquipRemote = makeRemote("ToggleEquip") -- 클라 → 서버: 고양이 번호
local requestDataRemote = makeRemote("RequestData") -- 클라 → 서버: UI 준비 완료
local completeTutorialRemote = makeRemote("CompleteTutorial") -- 클라 → 서버: 튜토리얼 끝
local dataChangedRemote = makeRemote("DataChanged") -- 서버 → 클라: 데이터 스냅샷
local notifyRemote = makeRemote("Notify") -- 서버 → 클라: 알림 메시지
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------
-- 데이터 저장 (Studio에서는 API 접근을 켜야 저장된다. README 참고)
---------------------------------------------------------------
local dataStore
pcall(function()
	dataStore = DataStoreService:GetDataStore("CatGame_v1")
end)

local profiles = {} -- [Player] = { Coins, Cats, lastFeed, models }
-- Cats 항목: { Breed = "Cheese", Level = 1, Xp = 0, Equipped = true }

local function newDefaultData()
	return {
		Coins = CatConfig.StartCoins,
		TutorialDone = false,
		Cats = {
			{ Breed = "Cheese", Level = 1, Xp = 0, Equipped = true },
		},
	}
end

local function loadData(player)
	if dataStore then
		local ok, saved = pcall(function()
			return dataStore:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" and type(saved.Cats) == "table" and #saved.Cats > 0 and type(saved.Coins) == "number" then
			return saved
		end
	end
	return newDefaultData()
end

local function saveData(player)
	local profile = profiles[player]
	if not (dataStore and profile) then
		return
	end
	local payload = {
		Coins = profile.Coins,
		Cats = profile.Cats,
		TutorialDone = profile.TutorialDone == true,
	}
	pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, payload)
	end)
end

---------------------------------------------------------------
-- 헬퍼
---------------------------------------------------------------
local feedCat -- 아래에서 정의 (모델의 밥 주기 프롬프트가 참조)
local refreshCatModels

local function countEquipped(profile)
	local count = 0
	for _, cat in ipairs(profile.Cats) do
		if cat.Equipped then
			count = count + 1
		end
	end
	return count
end

-- 클라이언트 UI와 leaderstats에 최신 상태를 반영
local function pushData(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats["후원금"].Value = profile.Coins
		stats["고양이"].Value = #profile.Cats
	end
	dataChangedRemote:FireClient(player, {
		Coins = profile.Coins,
		Cats = profile.Cats,
		TutorialDone = profile.TutorialDone == true,
	})
end

---------------------------------------------------------------
-- 고양이 모델: 별도 에셋 없이 파츠를 코드로 조립한다
---------------------------------------------------------------
local function buildCatModel(player, catIndex, cat)
	local breed = CatConfig.GetBreed(cat.Breed) or CatConfig.Breeds[1]
	local scale = CatConfig.ScaleForLevel(cat.Level)

	local model = Instance.new("Model")
	model.Name = breed.Name .. " (" .. player.Name .. ")"
	-- 튜토리얼이 "내 고양이"를 찾아 화살표를 띄울 때 쓴다
	model:SetAttribute("CatOwnerUserId", player.UserId)

	-- 모든 파츠는 Anchored + 충돌 없음 → 물리 대신 매 프레임 PivotTo로 이동
	local function addPart(name, size, color, offset, tiltX)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * scale
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new(offset * scale) * CFrame.Angles(tiltX or 0, 0, 0)
		part.Parent = model
		return part
	end

	local dark = Color3.fromRGB(25, 25, 25)
	local body = addPart("Body", Vector3.new(1.5, 1.1, 2.1), breed.BodyColor, Vector3.new(0, 0, 0))
	local head = addPart("Head", Vector3.new(1.2, 1.0, 1.0), breed.BodyColor, Vector3.new(0, 0.75, -1.2))
	addPart("LeftEar", Vector3.new(0.3, 0.45, 0.18), breed.AccentColor, Vector3.new(-0.35, 1.4, -1.2))
	addPart("RightEar", Vector3.new(0.3, 0.45, 0.18), breed.AccentColor, Vector3.new(0.35, 1.4, -1.2))
	addPart("Tail", Vector3.new(0.25, 0.25, 1.2), breed.AccentColor, Vector3.new(0, 0.55, 1.5), 0.5)
	addPart("LeftEye", Vector3.new(0.16, 0.24, 0.06), dark, Vector3.new(-0.28, 0.88, -1.71))
	addPart("RightEye", Vector3.new(0.16, 0.24, 0.06), dark, Vector3.new(0.28, 0.88, -1.71))
	addPart("Nose", Vector3.new(0.2, 0.12, 0.06), Color3.fromRGB(255, 120, 140), Vector3.new(0, 0.62, -1.71))
	model.PrimaryPart = body

	-- 이름표
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(200, 44)
	tag.StudsOffset = Vector3.new(0, 1.7 * scale + 0.6, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 1
	tagLabel.Text = string.format("%s Lv.%d", breed.Name, cat.Level)
	tagLabel.TextColor3 = Color3.new(1, 1, 1)
	tagLabel.TextStrokeTransparency = 0.3
	tagLabel.TextScaled = true
	tagLabel.Font = Enum.Font.GothamBold
	tagLabel.Parent = tag

	-- 가까이 가서 E 키(모바일은 버튼)로 밥 주기
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = breed.Name
	prompt.ActionText = "밥 주기"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = head

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer == player then
			feedCat(player, catIndex)
		end
	end)

	return model
end

local function clearCatModels(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, model in pairs(profile.models) do
		model:Destroy()
	end
	profile.models = {}
end

-- 장착 중인 고양이 모델을 전부 다시 만든다 (구매/장착/레벨업/리스폰 시)
refreshCatModels = function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	clearCatModels(player)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local slot = 0
	for index, cat in ipairs(profile.Cats) do
		if cat.Equipped then
			slot = slot + 1
			local model = buildCatModel(player, index, cat)
			model:PivotTo(rootPart.CFrame * CFrame.new(0, 0, 2 + slot))
			model.Parent = workspace
			profile.models[index] = model
		end
	end
end

---------------------------------------------------------------
-- 밥 주기 → 경험치/코인, 레벨업하면 더 커진다
---------------------------------------------------------------
feedCat = function(player, catIndex)
	local profile = profiles[player]
	if not profile then
		return
	end
	local cat = profile.Cats[catIndex]
	if not (cat and cat.Equipped) then
		return
	end

	local now = os.clock()
	if now - (profile.lastFeed or 0) < CatConfig.FeedCooldown then
		return
	end
	profile.lastFeed = now

	cat.Xp = cat.Xp + CatConfig.FeedXp
	profile.Coins = profile.Coins + CatConfig.FeedCoins

	local leveledUp = false
	while cat.Xp >= CatConfig.XpForLevel(cat.Level) do
		cat.Xp = cat.Xp - CatConfig.XpForLevel(cat.Level)
		cat.Level = cat.Level + 1
		leveledUp = true
	end

	if leveledUp then
		local breed = CatConfig.GetBreed(cat.Breed)
		notifyRemote:FireClient(player, string.format("%s가 Lv.%d이 되었어요! 🎉", breed.Name, cat.Level))
		refreshCatModels(player) -- 커진 모습으로 다시 생성
	end
	pushData(player)
end

---------------------------------------------------------------
-- 상점 구매 / 장착 토글
---------------------------------------------------------------
buyCatRemote.OnServerEvent:Connect(function(player, breedId)
	local profile = profiles[player]
	if not profile or type(breedId) ~= "string" then
		return
	end
	local breed = CatConfig.GetBreed(breedId)
	if not breed or breed.Price <= 0 then
		return
	end
	-- 이미 데려온 아이는 다시 데려올 수 없다 (쉼터에 한 마리씩)
	for _, cat in ipairs(profile.Cats) do
		if cat.Breed == breed.Id then
			notifyRemote:FireClient(player, breed.Name .. "는 이미 쉼터에 있어요 🏠")
			return
		end
	end

	if profile.Coins < breed.Price then
		notifyRemote:FireClient(player, string.format(
			"구조 비용이 %d 모자라요. 고양이를 돌보면 후원금이 쌓여요 🪙",
			breed.Price - profile.Coins))
		return
	end

	profile.Coins = profile.Coins - breed.Price
	table.insert(profile.Cats, {
		Breed = breed.Id,
		Level = 1,
		Xp = 0,
		Equipped = countEquipped(profile) < CatConfig.MaxEquipped,
	})
	notifyRemote:FireClient(player, breed.Name .. "가 쉼터에 왔어요! " .. breed.Story .. " 🐱")
	refreshCatModels(player)
	pushData(player)

	if #profile.Cats >= #CatConfig.Breeds then
		task.delay(3, function()
			if profiles[player] then
				notifyRemote:FireClient(player, CatConfig.EndingMessage)
			end
		end)
	end
end)

toggleEquipRemote.OnServerEvent:Connect(function(player, catIndex)
	local profile = profiles[player]
	if not profile or type(catIndex) ~= "number" then
		return
	end
	local cat = profile.Cats[catIndex]
	if not cat then
		return
	end

	if cat.Equipped then
		cat.Equipped = false
	else
		if countEquipped(profile) >= CatConfig.MaxEquipped then
			notifyRemote:FireClient(player, string.format("고양이는 최대 %d마리까지 데리고 다닐 수 있어요!", CatConfig.MaxEquipped))
			return
		end
		cat.Equipped = true
	end
	refreshCatModels(player)
	pushData(player)
end)

requestDataRemote.OnServerEvent:Connect(pushData)

completeTutorialRemote.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profile.TutorialDone = true
	end
end)

---------------------------------------------------------------
-- 고양이가 주인을 따라다니며 둥둥 떠다니는 연출
---------------------------------------------------------------
local SLOT_OFFSETS = {
	Vector3.new(-2.2, 0.8, 2.2),
	Vector3.new(2.2, 0.8, 2.2),
	Vector3.new(0, 0.8, 3.4),
}

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * 6) -- 프레임 무관 부드러운 추적
	for player, profile in pairs(profiles) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local slot = 0
			for index, cat in ipairs(profile.Cats) do
				local model = profile.models[index]
				if cat.Equipped and model and model.PrimaryPart then
					slot = slot + 1
					local offset = SLOT_OFFSETS[(slot - 1) % #SLOT_OFFSETS + 1]
					local bob = math.sin(now * 4 + slot * 2) * 0.25
					local targetPos = (rootPart.CFrame * CFrame.new(offset + Vector3.new(0, bob, 0))).Position
					local goal = CFrame.lookAt(targetPos, targetPos + rootPart.CFrame.LookVector)
					model:PivotTo(model:GetPivot():Lerp(goal, alpha))
				end
			end
		end
	end
end)

---------------------------------------------------------------
-- 자동 코인: 데리고 다니는 고양이 레벨 합만큼 주기적으로 지급
---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(CatConfig.PassiveIncomeInterval)
		for player, profile in pairs(profiles) do
			local income = 0
			for _, cat in ipairs(profile.Cats) do
				if cat.Equipped then
					income = income + cat.Level
				end
			end
			if income > 0 then
				profile.Coins = profile.Coins + income
				pushData(player)
			end
		end
	end
end)

---------------------------------------------------------------
-- 입장 / 퇴장
---------------------------------------------------------------
local function onPlayerAdded(player)
	local profile = loadData(player)
	profile.models = {}
	profile.lastFeed = 0
	profiles[player] = profile

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "후원금"
	coins.Value = profile.Coins
	coins.Parent = stats
	local catCount = Instance.new("IntValue")
	catCount.Name = "고양이"
	catCount.Value = #profile.Cats
	catCount.Parent = stats
	stats.Parent = player

	-- 캐릭터는 CharacterSetup 스크립트가 직접 스폰시키므로, 이 스크립트가 늦게
	-- 실행돼 이미 스폰이 끝났을 수도 있다. 두 경우 모두 처리한다.
	local function onCharacter(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refreshCatModels(player)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	pushData(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	clearCatModels(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)
