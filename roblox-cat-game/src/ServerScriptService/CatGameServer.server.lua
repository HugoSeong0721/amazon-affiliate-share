-- CatGameServer (Script / ServerScriptService)
--
-- 플레이어 데이터와 고양이를 담당한다.
--   · 저장/불러오기
--   · 고양이 장착(최대 4마리)과 따라다니기
--   · 상자 뽑기, 합성, 구역 해금, 환생
--   · 총 파워를 계산해서 Breakables 스크립트가 읽을 수 있게 올려둔다
--
-- 물건을 실제로 부수는 건 Breakables.server.lua 가 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))

---------------------------------------------------------------
-- 리모트
---------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "CatGameRemotes"

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local hatchRemote = makeRemote("HatchEgg")
local toggleEquipRemote = makeRemote("ToggleEquip")
local fuseRemote = makeRemote("FuseCats")
local unlockZoneRemote = makeRemote("UnlockZone")
local rebirthRemote = makeRemote("Rebirth")
local requestDataRemote = makeRemote("RequestData")
local completeTutorialRemote = makeRemote("CompleteTutorial")

local dataChangedRemote = makeRemote("DataChanged")
local notifyRemote = makeRemote("Notify")
local hatchResultRemote = makeRemote("HatchResult") -- 뽑기 연출용
local rewardRemote = makeRemote("Reward") -- 물건을 부쉈을 때 튀는 숫자
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------
-- 저장
---------------------------------------------------------------
local dataStore
pcall(function()
	dataStore = DataStoreService:GetDataStore("CatSim_v1")
end)

local profiles = {}

local function newProfile()
	return {
		Coins = CatConfig.StartCoins,
		Cats = { { Uid = 1, Id = "Cheese", Golden = false } },
		NextUid = 2,
		Equipped = { 1 },
		Zones = { Yard = true },
		Rebirths = 0,
		TutorialDone = false,
	}
end

local function isValidProfile(data)
	return type(data) == "table"
		and type(data.Coins) == "number"
		and type(data.Cats) == "table" and #data.Cats > 0
		and type(data.Equipped) == "table"
		and type(data.Zones) == "table"
end

local function loadProfile(player)
	if dataStore then
		local ok, saved = pcall(function()
			return dataStore:GetAsync("p_" .. player.UserId)
		end)
		if ok and isValidProfile(saved) then
			saved.Rebirths = saved.Rebirths or 0
			saved.NextUid = saved.NextUid or (#saved.Cats + 1)
			return saved
		end
	end
	return newProfile()
end

local function saveProfile(player)
	local profile = profiles[player]
	if not (dataStore and profile) then
		return
	end
	pcall(function()
		dataStore:SetAsync("p_" .. player.UserId, {
			Coins = profile.Coins,
			Cats = profile.Cats,
			NextUid = profile.NextUid,
			Equipped = profile.Equipped,
			Zones = profile.Zones,
			Rebirths = profile.Rebirths,
			TutorialDone = profile.TutorialDone,
		})
	end)
end

---------------------------------------------------------------
-- 계산
---------------------------------------------------------------
local function findCat(profile, uid)
	for index, entry in ipairs(profile.Cats) do
		if entry.Uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

local function isEquipped(profile, uid)
	for _, equippedUid in ipairs(profile.Equipped) do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

-- 새로 얻은 고양이를 알아서 끼워준다.
-- 자리가 있으면 그냥 넣고, 꽉 찼으면 가장 약한 아이와 바꾼다.
-- (이게 없으면 처음 하는 사람은 4마리를 채운 뒤 파워가 영영 안 오른다)
local function tryAutoEquip(profile, entry)
	if #profile.Equipped < CatConfig.MaxEquipped then
		table.insert(profile.Equipped, entry.Uid)
		return true
	end

	local weakestIndex, weakestPower = nil, math.huge
	for index, uid in ipairs(profile.Equipped) do
		local equipped = findCat(profile, uid)
		local equippedPower = equipped and CatConfig.PowerOf(equipped) or 0
		if equippedPower < weakestPower then
			weakestIndex, weakestPower = index, equippedPower
		end
	end

	if weakestIndex and CatConfig.PowerOf(entry) > weakestPower then
		profile.Equipped[weakestIndex] = entry.Uid
		return true
	end
	return false
end

local function rebirthMultiplier(profile)
	return 1 + profile.Rebirths * CatConfig.RebirthPowerBonus
end

local function totalPower(profile)
	local power = 0
	for _, uid in ipairs(profile.Equipped) do
		local entry = findCat(profile, uid)
		if entry then
			power += CatConfig.PowerOf(entry)
		end
	end
	return power * rebirthMultiplier(profile)
end

-- 해금한 구역 중 플레이어와 가장 가까운 곳
local function currentZone(player, profile)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local position = rootPart and rootPart.Position or Vector3.new(0, 0, 0)

	local best, bestDistance = nil, math.huge
	for _, zone in ipairs(CatConfig.Zones) do
		if profile.Zones[zone.Id] then
			local distance = (zone.Origin - Vector3.new(position.X, 0, position.Z)).Magnitude
			if distance < bestDistance then
				best, bestDistance = zone, distance
			end
		end
	end
	return best or CatConfig.Zones[1]
end

---------------------------------------------------------------
-- 고양이 모델 (파츠로 조립. 에셋을 쓰지 않는다)
---------------------------------------------------------------
local function buildCatModel(player, entry)
	local cat = CatConfig.GetCat(entry.Id)
	local scale = entry.Golden and 1.35 or 1
	local body = entry.Golden and Color3.fromRGB(255, 214, 92) or cat.Body
	local accent = entry.Golden and Color3.fromRGB(255, 246, 196) or cat.Accent

	local model = Instance.new("Model")
	model.Name = cat.Name
	model:SetAttribute("CatOwnerUserId", player.UserId)
	model:SetAttribute("CatUid", entry.Uid)

	local function addPart(name, size, color, offset)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * scale
		part.Color = color
		part.Material = entry.Golden and Enum.Material.Metal or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new(offset * scale)
		part.Parent = model
		return part
	end

	local dark = Color3.fromRGB(25, 25, 25)
	local torso = addPart("Body", Vector3.new(1.5, 1.1, 2.1), body, Vector3.new(0, 0, 0))
	addPart("Head", Vector3.new(1.2, 1.0, 1.0), body, Vector3.new(0, 0.75, -1.2))
	addPart("LeftEar", Vector3.new(0.3, 0.45, 0.18), accent, Vector3.new(-0.35, 1.4, -1.2))
	addPart("RightEar", Vector3.new(0.3, 0.45, 0.18), accent, Vector3.new(0.35, 1.4, -1.2))
	addPart("Tail", Vector3.new(0.25, 0.25, 1.2), accent, Vector3.new(0, 0.55, 1.5))
	addPart("LeftEye", Vector3.new(0.16, 0.24, 0.06), dark, Vector3.new(-0.28, 0.88, -1.71))
	addPart("RightEye", Vector3.new(0.16, 0.24, 0.06), dark, Vector3.new(0.28, 0.88, -1.71))
	addPart("Nose", Vector3.new(0.2, 0.12, 0.06), Color3.fromRGB(255, 120, 140), Vector3.new(0, 0.62, -1.71))
	model.PrimaryPart = torso

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(190, 40)
	tag.StudsOffset = Vector3.new(0, 2.4 * scale, 0)
	tag.AlwaysOnTop = true
	tag.Parent = torso

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = (entry.Golden and "✨ " or "") .. cat.Name
	label.TextColor3 = CatConfig.Rarities[cat.Rarity].Color
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = tag

	return model
end

local function clearCatModels(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, model in pairs(profile.models or {}) do
		model:Destroy()
	end
	profile.models = {}
end

local function refreshCatModels(player)
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

	for slot, uid in ipairs(profile.Equipped) do
		local entry = findCat(profile, uid)
		if entry then
			local model = buildCatModel(player, entry)
			model:PivotTo(CFrame.new(rootPart.Position + Vector3.new(0, 1, 2 + slot)))
			model.Parent = workspace
			profile.models[uid] = model
		end
	end
end

---------------------------------------------------------------
-- 클라이언트로 보내기
---------------------------------------------------------------
local function pushData(player)
	local profile = profiles[player]
	if not profile then
		return
	end

	local power = totalPower(profile)
	player:SetAttribute("TotalPower", power)
	player:SetAttribute("ZoneId", currentZone(player, profile).Id)

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats["코인"].Value = math.min(profile.Coins, 2 ^ 31 - 1)
		stats["환생"].Value = profile.Rebirths
	end

	dataChangedRemote:FireClient(player, {
		Coins = profile.Coins,
		Cats = profile.Cats,
		Equipped = profile.Equipped,
		Zones = profile.Zones,
		Rebirths = profile.Rebirths,
		TutorialDone = profile.TutorialDone,
		Power = power,
	})
end

-- Breakables 스크립트가 부순 결과를 알려줄 때 부른다
local function awardCoins(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Coins += amount
	rewardRemote:FireClient(player, amount)
	pushData(player)
end

-- 다른 서버 스크립트(Breakables, World)가 쓰는 창구.
-- 아래에서 정의되는 함수들은 나중에 채워 넣는다.
_G.CatGame = {
	AwardCoins = awardCoins,
	CurrentZone = function(player)
		local profile = profiles[player]
		return profile and currentZone(player, profile) or nil
	end,
	GetProfile = function(player)
		return profiles[player]
	end,
}

---------------------------------------------------------------
-- 상자 뽑기
---------------------------------------------------------------
local function rollFromPool(pool)
	local total = 0
	for _, weight in pairs(pool) do
		total += weight
	end
	local roll = math.random() * total
	local accumulated = 0
	local fallback = nil
	for catId, weight in pairs(pool) do
		fallback = fallback or catId
		accumulated += weight
		if roll <= accumulated then
			return catId
		end
	end
	return fallback
end

-- 월드의 상자 앞에서 E를 눌러도, UI 버튼을 눌러도 같은 함수를 탄다
local function doHatch(player, zoneId, count)
	local profile = profiles[player]
	if not profile then
		return
	end
	local zone = CatConfig.GetZone(zoneId)
	if not zone or not profile.Zones[zone.Id] then
		notifyRemote:FireClient(player, "아직 열지 않은 구역이에요")
		return
	end

	count = math.clamp(tonumber(count) or 1, 1, 10)
	local cost = zone.EggCost * count
	if profile.Coins < cost then
		notifyRemote:FireClient(player, ("코인이 부족해요 (%d 필요)"):format(cost))
		return
	end

	profile.Coins -= cost
	local hatched = {}
	for _ = 1, count do
		local catId = rollFromPool(zone.EggPool)
		local entry = { Uid = profile.NextUid, Id = catId, Golden = false }
		profile.NextUid += 1
		table.insert(profile.Cats, entry)
		table.insert(hatched, catId)

		tryAutoEquip(profile, entry)
	end

	hatchResultRemote:FireClient(player, hatched)
	refreshCatModels(player)
	pushData(player)
end

hatchRemote.OnServerEvent:Connect(doHatch)

---------------------------------------------------------------
-- 장착 / 합성
---------------------------------------------------------------
toggleEquipRemote.OnServerEvent:Connect(function(player, uid)
	local profile = profiles[player]
	if not profile or type(uid) ~= "number" then
		return
	end
	if not findCat(profile, uid) then
		return
	end

	if isEquipped(profile, uid) then
		for index, equippedUid in ipairs(profile.Equipped) do
			if equippedUid == uid then
				table.remove(profile.Equipped, index)
				break
			end
		end
	else
		if #profile.Equipped >= CatConfig.MaxEquipped then
			notifyRemote:FireClient(player, ("고양이는 최대 %d마리까지 데리고 다닐 수 있어요"):format(CatConfig.MaxEquipped))
			return
		end
		table.insert(profile.Equipped, uid)
	end

	refreshCatModels(player)
	pushData(player)
end)

-- 같은 종류의 일반 고양이 3마리 → 골든 1마리
fuseRemote.OnServerEvent:Connect(function(player, catId)
	local profile = profiles[player]
	if not profile or type(catId) ~= "string" then
		return
	end

	local matches = {}
	for _, entry in ipairs(profile.Cats) do
		if entry.Id == catId and not entry.Golden then
			table.insert(matches, entry.Uid)
			if #matches == CatConfig.FuseCount then
				break
			end
		end
	end

	if #matches < CatConfig.FuseCount then
		notifyRemote:FireClient(player, ("합성하려면 같은 고양이 %d마리가 필요해요"):format(CatConfig.FuseCount))
		return
	end

	local removing = {}
	for _, uid in ipairs(matches) do
		removing[uid] = true
	end

	for index = #profile.Cats, 1, -1 do
		if removing[profile.Cats[index].Uid] then
			table.remove(profile.Cats, index)
		end
	end
	for index = #profile.Equipped, 1, -1 do
		if removing[profile.Equipped[index]] then
			table.remove(profile.Equipped, index)
		end
	end

	local golden = { Uid = profile.NextUid, Id = catId, Golden = true }
	profile.NextUid += 1
	table.insert(profile.Cats, golden)
	tryAutoEquip(profile, golden)

	notifyRemote:FireClient(player, ("✨ 골든 %s 완성! 파워 %d배"):format(
		CatConfig.GetCat(catId).Name, CatConfig.GoldenMultiplier))
	refreshCatModels(player)
	pushData(player)
end)

---------------------------------------------------------------
-- 구역 해금 / 환생
---------------------------------------------------------------
local function doUnlockZone(player, zoneId)
	local profile = profiles[player]
	if not profile or type(zoneId) ~= "string" then
		return
	end
	local zone, index = CatConfig.GetZone(zoneId)
	if not zone or profile.Zones[zone.Id] then
		return
	end

	-- 바로 앞 구역부터 순서대로만 열 수 있다
	local previous = CatConfig.Zones[index - 1]
	if previous and not profile.Zones[previous.Id] then
		notifyRemote:FireClient(player, ("먼저 %s를 열어야 해요"):format(previous.Name))
		return
	end

	if profile.Coins < zone.UnlockCost then
		notifyRemote:FireClient(player, ("%s는 %d 코인이 필요해요"):format(zone.Name, zone.UnlockCost))
		return
	end

	profile.Coins -= zone.UnlockCost
	profile.Zones[zone.Id] = true
	notifyRemote:FireClient(player, ("🔓 %s 해금! 더 단단한 물건이 기다려요"):format(zone.Name))
	pushData(player)
end

unlockZoneRemote.OnServerEvent:Connect(doUnlockZone)

rebirthRemote.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local lastZone = CatConfig.Zones[#CatConfig.Zones]
	if not profile.Zones[lastZone.Id] then
		notifyRemote:FireClient(player, ("환생하려면 먼저 %s까지 열어야 해요"):format(lastZone.Name))
		return
	end
	if profile.Coins < CatConfig.RebirthCost then
		notifyRemote:FireClient(player, ("환생에는 %d 코인이 필요해요"):format(CatConfig.RebirthCost))
		return
	end

	-- 고양이는 그대로 두고, 코인과 구역만 초기화한다
	profile.Coins = 0
	profile.Zones = { Yard = true }
	profile.Rebirths += 1

	notifyRemote:FireClient(player, ("🌟 환생 %d회! 모든 고양이의 파워가 %d%% 늘었어요"):format(
		profile.Rebirths, math.floor(profile.Rebirths * CatConfig.RebirthPowerBonus * 100)))
	pushData(player)
end)

-- 월드에 설치된 상자/문에서도 부를 수 있게 열어둔다
_G.CatGame.HatchEgg = doHatch
_G.CatGame.UnlockZone = doUnlockZone

requestDataRemote.OnServerEvent:Connect(pushData)

completeTutorialRemote.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profile.TutorialDone = true
	end
end)

---------------------------------------------------------------
-- 고양이가 주인 주위를 맴돈다
---------------------------------------------------------------
local SLOT_OFFSETS = {
	Vector3.new(-2.6, 1.2, 2.4),
	Vector3.new(2.6, 1.2, 2.4),
	Vector3.new(-1.4, 1.2, 4.0),
	Vector3.new(1.4, 1.2, 4.0),
}

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * 6)
	for player, profile in pairs(profiles) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			for slot, uid in ipairs(profile.Equipped) do
				local model = profile.models and profile.models[uid]
				if model and model.PrimaryPart then
					local offset = SLOT_OFFSETS[(slot - 1) % #SLOT_OFFSETS + 1]
					local bob = math.sin(now * 4 + slot * 1.7) * 0.3
					local goal = CFrame.new(rootPart.Position + offset + Vector3.new(0, bob, 0))
					model:PivotTo(model:GetPivot():Lerp(goal, alpha))
				end
			end
		end
	end
end)

---------------------------------------------------------------
-- 현재 구역/파워를 주기적으로 갱신
--
-- 걸어서 다른 구역으로 넘어가면 현재 구역도 바뀌어야 한다.
-- 이걸 "코인을 벌 때"에만 갱신하면 교착이 생긴다:
--   구역을 옮김 → 아직 옛 구역으로 잡혀 있음 → 때릴 물건을 못 찾음
--   → 코인을 못 범 → 갱신이 안 됨 → 영영 그대로
---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, profile in pairs(profiles) do
			player:SetAttribute("TotalPower", totalPower(profile))
			player:SetAttribute("ZoneId", currentZone(player, profile).Id)
		end
	end
end)

---------------------------------------------------------------
-- 입장 / 퇴장
---------------------------------------------------------------
local function onPlayerAdded(player)
	local profile = loadProfile(player)
	profile.models = {}
	profiles[player] = profile

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "코인"
	coins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "환생"
	rebirths.Parent = stats
	stats.Parent = player

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
	saveProfile(player)
	clearCatModels(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveProfile(player)
	end
end)
