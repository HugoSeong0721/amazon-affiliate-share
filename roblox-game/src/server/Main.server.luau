--!strict
-- Server for Comeback! K-pop Dress Up.
-- Owns player data (coins / owned items / equipped outfit), validates every
-- purchase and equip request, and rebuilds outfits on respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function makeRemoteFunction(name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local buyRemote = makeRemoteFunction("BuyItem")
local equipRemote = makeRemoteFunction("EquipItem")
local photoRemote = makeRemoteFunction("TakePhoto")
local stateRemote = makeRemoteFunction("GetState")

local coinsChanged = Instance.new("RemoteEvent")
coinsChanged.Name = "CoinsChanged"
coinsChanged.Parent = remotesFolder

local dailyReward = Instance.new("RemoteEvent")
dailyReward.Name = "DailyReward"
dailyReward.Parent = remotesFolder

----------------------------------------------------------------------
-- Player data
----------------------------------------------------------------------

type PlayerData = {
	coins: number,
	owned: { [string]: boolean },
	equipped: { [string]: number },
	lastDaily: number,
}

-- GetDataStore throws in Studio when the place isn't published; the game
-- must still run (just without saving).
local dataStoreOk, dataStore = pcall(function()
	return DataStoreService:GetDataStore("Comeback_v1")
end)
if not dataStoreOk then
	dataStore = nil
	warn("[Comeback] DataStore unavailable (unpublished place?) — progress will not save.")
end
local sessions: { [Player]: PlayerData } = {}
local photoTimestamps: { [Player]: number } = {}

local function defaultData(): PlayerData
	return {
		coins = Config.StartingCoins,
		owned = {},
		equipped = {},
		lastDaily = 0,
	}
end

local function loadData(player: Player): PlayerData
	local data: PlayerData? = nil
	local ok, stored = pcall(function()
		return dataStore and dataStore:GetAsync(`player_{player.UserId}`)
	end)
	if ok and type(stored) == "table" then
		data = stored :: PlayerData
	end
	local result = data or defaultData()
	result.coins = result.coins or Config.StartingCoins
	result.owned = result.owned or {}
	result.equipped = result.equipped or {}
	result.lastDaily = result.lastDaily or 0
	return result
end

local function saveData(player: Player)
	local data = sessions[player]
	if not data then
		return
	end
	pcall(function()
		if dataStore then
			dataStore:SetAsync(`player_{player.UserId}`, data)
		end
	end)
end

local function pushCoins(player: Player)
	local data = sessions[player]
	if data then
		coinsChanged:FireClient(player, data.coins)
	end
end

----------------------------------------------------------------------
-- Asset validation (kids can only equip the categories we allow)
----------------------------------------------------------------------

local assetTypeCache: { [number]: number? } = {}

local function assetTypeIdOf(assetId: number): number?
	if assetTypeCache[assetId] ~= nil then
		return assetTypeCache[assetId]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)
	local typeId = ok and info and info.AssetTypeId or nil
	assetTypeCache[assetId] = typeId
	return typeId
end

local function isValidForCategory(assetId: number, categoryKey: string): boolean
	local category = Config.categoryByKey(categoryKey)
	if not category or not category.assetTypeIds then
		return false
	end
	local typeId = assetTypeIdOf(assetId)
	if not typeId then
		return false
	end
	for _, allowed in category.assetTypeIds do
		if allowed == typeId then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- Outfit application
----------------------------------------------------------------------

local function applyOutfitNow(player: Player)
	local data = sessions[player]
	local character = player.Character
	if not data or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not description then
		return
	end

	for categoryKey, assetId in data.equipped do
		if categoryKey == "Skin" then
			local tone = Config.SkinTones[assetId]
			if tone then
				description.HeadColor = tone
				description.TorsoColor = tone
				description.LeftArmColor = tone
				description.RightArmColor = tone
				description.LeftLegColor = tone
				description.RightLegColor = tone
			end
			continue
		end
		local typeId = assetTypeIdOf(assetId)
		if not typeId then
			continue
		end
		local accessoryField = Config.AccessoryFields[typeId]
		local clothingField = Config.ClassicClothingFields[typeId]
		if accessoryField then
			(description :: any)[accessoryField] = tostring(assetId)
		elseif clothingField then
			(description :: any)[clothingField] = assetId
		end
	end

	local ok2 = pcall(function()
		humanoid:ApplyDescription(description)
	end)
	if not ok2 then
		-- A failed apply can leave the character half-built; retry once.
		task.wait(0.5)
		pcall(function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid:ApplyDescription(description)
			end
		end)
	end
end

-- ApplyDescription rebuilds the whole character and errors if two calls
-- overlap (which visually "deletes" the avatar). Serialize applies per
-- player: while one is running, remember that another is wanted and run
-- it right after.
local applying: { [Player]: boolean } = {}
local applyAgain: { [Player]: boolean } = {}

local function applyOutfit(player: Player)
	if applying[player] then
		applyAgain[player] = true
		return
	end
	applying[player] = true
	task.spawn(function()
		repeat
			applyAgain[player] = false
			applyOutfitNow(player)
		until not applyAgain[player] or not sessions[player]
		applying[player] = nil
	end)
end

----------------------------------------------------------------------
-- Remote handlers
----------------------------------------------------------------------

buyRemote.OnServerInvoke = function(player: Player, assetId: unknown, categoryKey: unknown)
	local data = sessions[player]
	if not data or type(assetId) ~= "number" or type(categoryKey) ~= "string" then
		return { ok = false, message = "Try again!" }
	end
	assetId = math.floor(assetId)
	if data.owned[tostring(assetId)] then
		return { ok = true, coins = data.coins }
	end
	if not isValidForCategory(assetId, categoryKey) then
		return { ok = false, message = "That item can't be used here." }
	end
	local price = Config.priceFor(assetId)
	if data.coins < price then
		return { ok = false, message = "Not enough coins yet!" }
	end
	data.coins -= price
	data.owned[tostring(assetId)] = true
	pushCoins(player)
	return { ok = true, coins = data.coins }
end

equipRemote.OnServerInvoke = function(player: Player, assetId: unknown, categoryKey: unknown)
	local data = sessions[player]
	if not data or type(categoryKey) ~= "string" then
		return { ok = false }
	end

	if categoryKey == "Skin" then
		if type(assetId) ~= "number" or not Config.SkinTones[assetId] then
			return { ok = false }
		end
		data.equipped.Skin = assetId
		applyOutfit(player)
		return { ok = true }
	end

	-- assetId == nil means "take it off".
	if assetId == nil then
		data.equipped[categoryKey] = nil
		applyOutfit(player)
		return { ok = true }
	end

	if type(assetId) ~= "number" then
		return { ok = false }
	end
	assetId = math.floor(assetId)
	local isFree = Config.priceFor(assetId) == 0
	if not data.owned[tostring(assetId)] and not isFree then
		return { ok = false, message = "Buy it first!" }
	end
	if not isValidForCategory(assetId, categoryKey) then
		return { ok = false, message = "That item can't be used here." }
	end
	data.equipped[categoryKey] = assetId
	applyOutfit(player)
	return { ok = true }
end

stateRemote.OnServerInvoke = function(player: Player)
	-- The client can ask before this player's data finishes loading; wait
	-- briefly instead of answering nil.
	local startedAt = os.clock()
	while not sessions[player] and os.clock() - startedAt < 10 do
		task.wait(0.2)
	end
	local data = sessions[player]
	if not data then
		return nil
	end
	return {
		coins = data.coins,
		owned = data.owned,
		equipped = data.equipped,
	}
end

photoRemote.OnServerInvoke = function(player: Player)
	local data = sessions[player]
	if not data then
		return { ok = false }
	end
	local now = os.clock()
	local last = photoTimestamps[player]
	if last and now - last < Config.PhotoCooldownSeconds then
		return { ok = true, coins = data.coins, rewarded = false }
	end
	photoTimestamps[player] = now
	data.coins += Config.PhotoRewardCoins
	pushCoins(player)
	return { ok = true, coins = data.coins, rewarded = true }
end

----------------------------------------------------------------------
-- Player lifecycle
----------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local data = loadData(player)
	sessions[player] = data

	if os.time() - data.lastDaily >= Config.DailyCooldownSeconds then
		data.lastDaily = os.time()
		data.coins += Config.DailyRewardCoins
		task.delay(3, function()
			if sessions[player] then
				dailyReward:FireClient(player, Config.DailyRewardCoins)
			end
		end)
	end

	player.CharacterAdded:Connect(function()
		task.wait(1)
		applyOutfit(player)
	end)
	if player.Character then
		task.delay(1, applyOutfit, player)
	end

	pushCoins(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- In Studio playtests the player can join before this script connects the
-- event, so sweep anyone already present.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	sessions[player] = nil
	photoTimestamps[player] = nil
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for _, player in Players:GetPlayers() do
		saveData(player)
	end
end)

-- Autosave every 2 minutes so a server crash loses very little.
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in Players:GetPlayers() do
			saveData(player)
		end
	end
end)

----------------------------------------------------------------------
-- Dressing room world
----------------------------------------------------------------------

local COLOR_FLOOR = Color3.fromRGB(255, 214, 231)
local COLOR_WALL = Color3.fromRGB(244, 226, 255)
local COLOR_ACCENT = Color3.fromRGB(255, 89, 158)
local COLOR_NEON_B = Color3.fromRGB(120, 220, 255)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = workspace
	return p
end

local function buildWorld()
	part({
		Name = "Floor",
		Size = Vector3.new(64, 1, 64),
		Position = Vector3.new(0, 0, 0),
		Color = COLOR_FLOOR,
		Material = Enum.Material.SmoothPlastic,
	})

	-- Walls
	local wallSpecs = {
		{ Vector3.new(64, 20, 1), Vector3.new(0, 10, -32) },
		{ Vector3.new(64, 20, 1), Vector3.new(0, 10, 32) },
		{ Vector3.new(1, 20, 64), Vector3.new(-32, 10, 0) },
		{ Vector3.new(1, 20, 64), Vector3.new(32, 10, 0) },
	}
	for _, spec in wallSpecs do
		part({
			Name = "Wall",
			Size = spec[1],
			Position = spec[2],
			Color = COLOR_WALL,
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Neon photo-zone backdrop against the back wall
	local backdrop = part({
		Name = "PhotoBackdrop",
		Size = Vector3.new(18, 12, 0.5),
		Position = Vector3.new(0, 6.5, -31),
		Color = Color3.fromRGB(40, 20, 60),
		Material = Enum.Material.SmoothPlastic,
	})
	local frameSpecs = {
		{ Vector3.new(18.8, 0.6, 0.7), Vector3.new(0, 12.6, -31) },
		{ Vector3.new(18.8, 0.6, 0.7), Vector3.new(0, 0.9, -31) },
		{ Vector3.new(0.6, 12.4, 0.7), Vector3.new(-9.2, 6.7, -31) },
		{ Vector3.new(0.6, 12.4, 0.7), Vector3.new(9.2, 6.7, -31) },
	}
	for index, spec in frameSpecs do
		part({
			Name = "PhotoFrameNeon",
			Size = spec[1],
			Position = spec[2],
			Color = index % 2 == 0 and COLOR_ACCENT or COLOR_NEON_B,
			Material = Enum.Material.Neon,
		})
	end

	-- Photo-zone floor marker
	part({
		Name = "PhotoSpot",
		Size = Vector3.new(6, 0.1, 6),
		Position = Vector3.new(0, 0.55, -27),
		Color = COLOR_ACCENT,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})

	-- Logo sign on the backdrop
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(900, 600)
	signGui.Parent = backdrop
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 0.4)
	signLabel.Position = UDim2.fromScale(0, 0.05)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "COMEBACK! \u{2728}"
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.Parent = signGui

	-- Soft spotlight over the photo zone
	local lightPart = part({
		Name = "SpotlightAnchor",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 16, -24),
		Transparency = 1,
		CanCollide = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Angle = 70
	spot.Brightness = 3
	spot.Range = 30
	spot.Face = Enum.NormalId.Bottom
	spot.Color = Color3.fromRGB(255, 235, 245)
	spot.Parent = lightPart

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Position = Vector3.new(0, 0.5, 10)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = true
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = workspace
end

buildWorld()
