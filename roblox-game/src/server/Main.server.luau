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
local wishRemote = makeRemoteFunction("SendWish")

local coinsChanged = Instance.new("RemoteEvent")
coinsChanged.Name = "CoinsChanged"
coinsChanged.Parent = remotesFolder

local dailyReward = Instance.new("RemoteEvent")
dailyReward.Name = "DailyReward"
dailyReward.Parent = remotesFolder

local showNews = Instance.new("RemoteEvent")
showNews.Name = "ShowNews"
showNews.Parent = remotesFolder

local serverToast = Instance.new("RemoteEvent")
serverToast.Name = "ServerToast"
serverToast.Parent = remotesFolder

----------------------------------------------------------------------
-- Player data
----------------------------------------------------------------------

type PlayerData = {
	coins: number,
	owned: { [string]: boolean },
	equipped: { [string]: any },
	lastDaily: number,
	newsSeen: number?,
	signed: boolean?,
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
	result.newsSeen = result.newsSeen or 0
	return result
end

----------------------------------------------------------------------
-- Wish Board (kid-safe structured feedback with requester names)
----------------------------------------------------------------------

local wishStoreOk, wishStore = pcall(function()
	return DataStoreService:GetDataStore("ComebackWishes_v1")
end)
if not wishStoreOk then
	wishStore = nil
end

local wishVoted: { [Player]: { [string]: boolean } } = {}

wishRemote.OnServerInvoke = function(player: Player, wishKey: unknown)
	if type(wishKey) ~= "string" then
		return { ok = false }
	end
	local valid = false
	for _, wish in Config.Wishes do
		if wish.key == wishKey then
			valid = true
			break
		end
	end
	if not valid then
		return { ok = false }
	end
	local voted = wishVoted[player] or {}
	wishVoted[player] = voted
	if voted[wishKey] then
		return { ok = true, already = true }
	end
	voted[wishKey] = true
	task.spawn(function() -- persist the vote off the hot path
		pcall(function()
			if wishStore then
				wishStore:UpdateAsync(`wish_{wishKey}`, function(old)
					old = old or { count = 0, names = {}, ids = {} }
					old.count += 1
					old.names = old.names or {}
					old.ids = old.ids or {}
					if not table.find(old.names, player.Name) then
						table.insert(old.names, player.Name)
						while #old.names > 50 do
							table.remove(old.names, 1)
						end
					end
					if not table.find(old.ids, player.UserId) then
						table.insert(old.ids, player.UserId)
						while #old.ids > 200 do
							table.remove(old.ids, 1)
						end
					end
					return old
				end)
			end
		end)
	end)
	return { ok = true }
end

-- When an update fulfills a wish, load who voted for it so they get a
-- personal congrats + thank-you gift on their next visit.
local fulfilledVoters: { [number]: boolean } = {}
if Config.News.fulfilledWish ~= "" then
	task.spawn(function()
		pcall(function()
			if wishStore then
				local entry = wishStore:GetAsync(`wish_{Config.News.fulfilledWish}`)
				if entry and entry.ids then
					for _, userId in entry.ids do
						fulfilledVoters[userId] = true
					end
				end
			end
		end)
	end)
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
-- Hand-held props (our own part-built models, welded to the right hand)
----------------------------------------------------------------------

local function propPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function weldPair(a: BasePart, b: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = a
end

local propBuilders: { [string]: () -> Model } = {
	lightstick = function()
		local model = Instance.new("Model")
		local handle = propPart({
			Name = "Handle",
			Size = Vector3.new(0.25, 1.1, 0.25),
			Color = Color3.fromRGB(55, 50, 65),
		})
		handle.Parent = model
		local head = propPart({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.75, 0.75, 0.75),
			Color = Color3.fromRGB(255, 105, 180),
			Material = Enum.Material.Neon,
		})
		head.CFrame = CFrame.new(0, 0.9, 0)
		head.Parent = model
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 130, 190)
		glow.Range = 8
		glow.Brightness = 1.2
		glow.Parent = head
		weldPair(handle, head)
		model.PrimaryPart = handle
		return model
	end,
	mic = function()
		local model = Instance.new("Model")
		local handle = propPart({
			Name = "Handle",
			Size = Vector3.new(0.22, 0.95, 0.22),
			Color = Color3.fromRGB(45, 40, 60),
		})
		handle.Parent = model
		local band = propPart({
			Name = "Band",
			Size = Vector3.new(0.26, 0.1, 0.26),
			Color = Color3.fromRGB(255, 197, 49),
			Material = Enum.Material.Metal,
		})
		band.CFrame = CFrame.new(0, 0.45, 0)
		band.Parent = model
		local head = propPart({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.55, 0.55),
			Color = Color3.fromRGB(70, 65, 90),
			Material = Enum.Material.DiamondPlate,
		})
		head.CFrame = CFrame.new(0, 0.72, 0)
		head.Parent = model
		weldPair(handle, band)
		weldPair(handle, head)
		model.PrimaryPart = handle
		return model
	end,
	phone = function()
		local model = Instance.new("Model")
		local handle = propPart({
			Name = "Handle",
			Size = Vector3.new(0.5, 0.95, 0.09),
			Color = Color3.fromRGB(240, 200, 220),
		})
		handle.Parent = model
		local screen = propPart({
			Name = "Screen",
			Size = Vector3.new(0.42, 0.82, 0.03),
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
		})
		screen.CFrame = CFrame.new(0, 0, -0.05)
		screen.Parent = model
		weldPair(handle, screen)
		model.PrimaryPart = handle
		return model
	end,
}

local function attachProp(player: Player)
	local data = sessions[player]
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("ComebackProp")
	if old then
		old:Destroy()
	end
	local key = data and data.equipped.Props
	if type(key) ~= "string" then
		return
	end
	local builder = propBuilders[key]
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not builder or not rightHand or not rightHand:IsA("BasePart") then
		return
	end
	local model = builder()
	model.Name = "ComebackProp"
	model:PivotTo(rightHand.CFrame * CFrame.new(0, -0.05, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = character
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
		if categoryKey == "Props" then
			continue -- held props are welded separately after the rebuild
		end
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
	-- The rebuild strips welded props, so put the held prop back on.
	attachProp(player)
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
	if not data or type(categoryKey) ~= "string" then
		return { ok = false, message = "Try again!" }
	end
	if categoryKey == "Props" then
		if type(assetId) ~= "string" or not propBuilders[assetId] then
			return { ok = false }
		end
		if data.owned[`prop_{assetId}`] then
			return { ok = true, coins = data.coins }
		end
		local propPrice = Config.propPriceFor(assetId)
		if data.coins < propPrice then
			return { ok = false, message = "Not enough hearts yet!" }
		end
		data.coins -= propPrice
		data.owned[`prop_{assetId}`] = true
		pushCoins(player)
		return { ok = true, coins = data.coins }
	end
	if type(assetId) ~= "number" then
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

	if categoryKey == "Props" then
		if assetId == nil then
			data.equipped.Props = nil
			attachProp(player)
			return { ok = true }
		end
		if type(assetId) ~= "string" or not propBuilders[assetId] then
			return { ok = false }
		end
		if Config.propPriceFor(assetId) > 0 and not data.owned[`prop_{assetId}`] then
			return { ok = false, message = "Buy it first!" }
		end
		data.equipped.Props = assetId
		attachProp(player)
		return { ok = true }
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

	if (data.newsSeen or 0) < Config.News.version then
		data.newsSeen = Config.News.version
		local personal = fulfilledVoters[player.UserId] == true
		local bonus = 0
		if personal then
			bonus = Config.WishThanksCoins
			data.coins += bonus
		end
		task.delay(6, function()
			if sessions[player] then
				showNews:FireClient(player, {
					title = Config.News.title,
					lines = Config.News.lines,
					credits = Config.News.credits,
					personal = personal,
					bonus = bonus,
				})
				pushCoins(player)
			end
		end)
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
	wishVoted[player] = nil
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
-- Guest book: visitors sign the wall and their name stays forever
----------------------------------------------------------------------

local guestStoreOk, guestStore = pcall(function()
	return DataStoreService:GetDataStore("ComebackGuestbook_v1")
end)
if not guestStoreOk then
	guestStore = nil
end

local signatures: { string } = {}

local guestBoard = Instance.new("Part")
guestBoard.Name = "GuestBoard"
guestBoard.Anchored = true
guestBoard.Size = Vector3.new(44, 12, 0.4)
guestBoard.Position = Vector3.new(-62, 8, 34.4)
guestBoard.Color = Color3.fromRGB(58, 34, 84)
guestBoard.Material = Enum.Material.SmoothPlastic
guestBoard.TopSurface = Enum.SurfaceType.Smooth
guestBoard.BottomSurface = Enum.SurfaceType.Smooth
guestBoard.Parent = workspace

local boardLabels: { TextLabel } = {}
-- Text on both faces so it reads no matter the part's orientation.
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(1400, 380)
	gui.Parent = guestBoard
	local header = Instance.new("TextLabel")
	header.Size = UDim2.fromScale(1, 0.28)
	header.BackgroundTransparency = 1
	header.Text = "\u{270D} GUEST BOOK"
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.TextColor3 = Color3.fromRGB(255, 214, 74)
	header.Parent = gui
	local names = Instance.new("TextLabel")
	names.Size = UDim2.fromScale(1, 0.68)
	names.Position = UDim2.fromScale(0, 0.3)
	names.BackgroundTransparency = 1
	names.Text = "Be the first to sign! \u{2B50}"
	names.Font = Enum.Font.FredokaOne
	names.TextSize = 44
	names.TextWrapped = true
	names.TextColor3 = Color3.fromRGB(255, 255, 255)
	names.TextYAlignment = Enum.TextYAlignment.Top
	names.Parent = gui
	table.insert(boardLabels, names)
end

local function renderBoard()
	local text = #signatures == 0 and "Be the first to sign! \u{2B50}"
		or `{#signatures} stars visited \u{2B50}  {table.concat(signatures, "  \u{00B7}  ")}`
	for _, label in boardLabels do
		label.Text = text
	end
end

task.spawn(function()
	pcall(function()
		if guestStore then
			local stored = guestStore:GetAsync("signatures")
			if type(stored) == "table" then
				signatures = stored
				renderBoard()
			end
		end
	end)
end)

local signPrompt = Instance.new("ProximityPrompt")
signPrompt.ActionText = "Sign \u{270D}"
signPrompt.ObjectText = "Guest Book"
signPrompt.HoldDuration = 0.3
signPrompt.MaxActivationDistance = 14
signPrompt.RequiresLineOfSight = false
signPrompt.Parent = guestBoard

signPrompt.Triggered:Connect(function(player)
	local data = sessions[player]
	if not data then
		return
	end
	if data.signed then
		serverToast:FireClient(player, "You already signed \u{1F49C}")
		return
	end
	data.signed = true
	data.coins += 10
	pushCoins(player)
	table.insert(signatures, player.DisplayName)
	while #signatures > 200 do
		table.remove(signatures, 1)
	end
	renderBoard()
	serverToast:FireClient(player, "Signed! +10 \u{1F496}")
	task.spawn(function()
		pcall(function()
			if guestStore then
				guestStore:UpdateAsync("signatures", function(old)
					old = type(old) == "table" and old or {}
					table.insert(old, player.DisplayName)
					while #old > 200 do
						table.remove(old, 1)
					end
					return old
				end)
			end
		end)
	end)
end)
