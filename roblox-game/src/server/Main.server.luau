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
	photos: number?,
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

-- Defined by the social layer near the bottom of this script.
local announcePhoto: (host: Player) -> ()
local updateNameTag: (player: Player) -> ()

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
-- Rideable mounts (part-built, welded under the player; speed per mount)
----------------------------------------------------------------------

local function ridePart(model: Model, root: BasePart, props: { [string]: any }, localCf: CFrame): Part
	local p = propPart(props)
	p.CFrame = root.CFrame * localCf
	weldPair(root, p)
	p.Parent = model
	return p
end

local function rideBase(): (Model, BasePart)
	local model = Instance.new("Model")
	local root = propPart({ Name = "RideRoot", Size = Vector3.new(1, 1, 1), Transparency = 1 })
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local function addEyes(model: Model, root: BasePart, headCf: CFrame, spread: number)
	for _, side in { -1, 1 } do
		ridePart(model, root, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.28, 0.28, 0.28),
			Color = Color3.fromRGB(25, 25, 30),
		}, headCf * CFrame.new(side * spread, 0.15, -0.45))
	end
end

type RideSpec = {
	build: () -> Model,
	lift: number,
	speed: number,
	jump: number,
	trail: boolean?,
}

local RIDE_SPECS: { [string]: RideSpec } = {
	donkey = {
		lift = 1.6,
		speed = 9,
		jump = 5,
		build = function()
			local model, root = rideBase()
			local gray = Color3.fromRGB(160, 150, 155)
			ridePart(model, root, { Name = "Body", Size = Vector3.new(1.3, 1.3, 3), Color = gray }, CFrame.new(0, -0.4, 0))
			local headCf = CFrame.new(0, 0.5, -1.8)
			ridePart(model, root, { Name = "Head", Size = Vector3.new(0.9, 1, 1.3), Color = gray }, headCf)
			ridePart(model, root, { Name = "Muzzle", Size = Vector3.new(0.7, 0.5, 0.5), Color = Color3.fromRGB(220, 205, 210) }, headCf * CFrame.new(0, -0.2, -0.8))
			for _, side in { -1, 1 } do
				ridePart(model, root, { Name = "Ear", Size = Vector3.new(0.25, 1.1, 0.4), Color = gray }, headCf * CFrame.new(side * 0.3, 0.9, 0))
				for _, front in { -1, 1 } do
					ridePart(model, root, { Name = "Leg", Size = Vector3.new(0.45, 1.6, 0.45), Color = gray }, CFrame.new(side * 0.45, -1.5, front * 1.1))
				end
			end
			ridePart(model, root, { Name = "Tail", Size = Vector3.new(0.2, 1, 0.2), Color = Color3.fromRGB(110, 100, 105) }, CFrame.new(0, -0.5, 1.6))
			addEyes(model, root, headCf, 0.3)
			return model
		end,
	},
	horse = {
		lift = 2.2,
		speed = 34,
		jump = 9,
		build = function()
			local model, root = rideBase()
			local brown = Color3.fromRGB(150, 96, 55)
			local dark = Color3.fromRGB(90, 55, 30)
			ridePart(model, root, { Name = "Body", Size = Vector3.new(1.6, 1.6, 3.8), Color = brown }, CFrame.new(0, -0.3, 0))
			ridePart(model, root, { Name = "Neck", Size = Vector3.new(0.9, 1.6, 0.9), Color = brown }, CFrame.new(0, 0.6, -1.9) * CFrame.Angles(math.rad(-25), 0, 0))
			local headCf = CFrame.new(0, 1.45, -2.5)
			ridePart(model, root, { Name = "Head", Size = Vector3.new(0.9, 1, 1.5), Color = brown }, headCf)
			ridePart(model, root, { Name = "Mane", Size = Vector3.new(0.3, 1.6, 1), Color = dark }, CFrame.new(0, 1, -1.7))
			for _, side in { -1, 1 } do
				ridePart(model, root, { Name = "Ear", Size = Vector3.new(0.25, 0.6, 0.3), Color = brown }, headCf * CFrame.new(side * 0.3, 0.7, 0.3))
				for _, front in { -1, 1 } do
					ridePart(model, root, { Name = "Leg", Size = Vector3.new(0.5, 2.2, 0.5), Color = brown }, CFrame.new(side * 0.5, -1.9, front * 1.4))
				end
			end
			ridePart(model, root, { Name = "Tail", Size = Vector3.new(0.35, 1.5, 0.35), Color = dark }, CFrame.new(0, -0.6, 2.1) * CFrame.Angles(math.rad(20), 0, 0))
			addEyes(model, root, headCf, 0.32)
			return model
		end,
	},
	dino = {
		lift = 2.8,
		speed = 26,
		jump = 12,
		build = function()
			local model, root = rideBase()
			local green = Color3.fromRGB(90, 170, 100)
			local belly = Color3.fromRGB(200, 230, 170)
			ridePart(model, root, { Name = "Body", Size = Vector3.new(2.2, 2.2, 4.4), Color = green }, CFrame.new(0, -0.2, 0))
			ridePart(model, root, { Name = "Belly", Size = Vector3.new(1.6, 1.2, 3.4), Color = belly }, CFrame.new(0, -0.8, -0.2))
			local headCf = CFrame.new(0, 1.5, -2.9)
			ridePart(model, root, { Name = "Head", Size = Vector3.new(1.5, 1.4, 1.9), Color = green }, headCf)
			ridePart(model, root, { Name = "Jaw", Size = Vector3.new(1.3, 0.5, 1.5), Color = belly }, headCf * CFrame.new(0, -0.55, -0.2))
			ridePart(model, root, { Name = "Tail1", Size = Vector3.new(1.4, 1.4, 1.8), Color = green }, CFrame.new(0, -0.3, 2.8))
			ridePart(model, root, { Name = "Tail2", Size = Vector3.new(0.9, 0.9, 1.6), Color = green }, CFrame.new(0, -0.4, 4.2))
			for i = 0, 3 do
				ridePart(model, root, { Name = "Spike", Size = Vector3.new(0.4, 0.7, 0.7), Color = Color3.fromRGB(60, 120, 70) }, CFrame.new(0, 1, -0.8 + i * 1.1) * CFrame.Angles(0, 0, math.rad(45)))
			end
			for _, side in { -1, 1 } do
				for _, front in { -1, 1 } do
					ridePart(model, root, { Name = "Leg", Size = Vector3.new(0.8, 2.4, 0.9), Color = green }, CFrame.new(side * 0.8, -1.9, front * 1.3))
				end
			end
			addEyes(model, root, headCf, 0.5)
			return model
		end,
	},
	bird = {
		lift = 1.8,
		speed = 65,
		jump = 16,
		trail = true,
		build = function()
			local model, root = rideBase()
			local pink = Color3.fromRGB(255, 143, 192)
			ridePart(model, root, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 2.4, 2.8), Color = pink }, CFrame.new(0, -0.5, 0))
			local headCf = CFrame.new(0, 0.9, -1.6)
			ridePart(model, root, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Color = pink }, headCf)
			ridePart(model, root, { Name = "Beak", Size = Vector3.new(0.4, 0.3, 0.8), Color = Color3.fromRGB(255, 190, 80) }, headCf * CFrame.new(0, -0.05, -0.95))
			ridePart(model, root, { Name = "Crest", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(120, 220, 255) }, headCf * CFrame.new(0, 0.8, 0))
			for _, side in { -1, 1 } do
				ridePart(model, root, { Name = "Wing", Size = Vector3.new(0.25, 1, 2.2), Color = Color3.fromRGB(255, 180, 215) }, CFrame.new(side * 1.5, -0.3, 0.1) * CFrame.Angles(0, 0, math.rad(side * 20)))
				ridePart(model, root, { Name = "Foot", Size = Vector3.new(0.4, 0.9, 0.4), Color = Color3.fromRGB(255, 190, 80) }, CFrame.new(side * 0.5, -1.9, 0.2))
			end
			ridePart(model, root, { Name = "TailFeather", Size = Vector3.new(1.2, 0.25, 1.4), Color = Color3.fromRGB(255, 180, 215) }, CFrame.new(0, -0.3, 1.7) * CFrame.Angles(math.rad(15), 0, 0))
			return model
		end,
	},
}

local rideBaseHip: { [Player]: number } = {}

local function attachRide(player: Player)
	local data = sessions[player]
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local old = character:FindFirstChild("ComebackRide")
	if old then
		old:Destroy()
	end
	if rideBaseHip[player] then
		humanoid.HipHeight = rideBaseHip[player]
		rideBaseHip[player] = nil
	end
	humanoid.WalkSpeed = 16
	humanoid.JumpHeight = 7.2
	humanoid:SetAttribute("RideSpeed", nil)

	local key = data and data.equipped.Ride
	local spec = type(key) == "string" and RIDE_SPECS[key] or nil
	if not spec then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local model = spec.build()
	model.Name = "ComebackRide"
	model:PivotTo(rootPart.CFrame * CFrame.new(0, -1.6, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	if spec.trail then
		local body = model:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 1, 0)
			a0.Parent = body
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -1, 0)
			a1.Parent = body
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 143, 192))
			trail.Transparency = NumberSequence.new(0.3, 1)
			trail.Lifetime = 0.35
			trail.Parent = body
		end
	end
	model.Parent = character

	rideBaseHip[player] = humanoid.HipHeight
	humanoid.HipHeight += spec.lift
	humanoid.WalkSpeed = spec.speed
	humanoid.JumpHeight = spec.jump
	humanoid:SetAttribute("RideSpeed", spec.speed)
	if updateNameTag then
		updateNameTag(player)
	end
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

	local ok, applied = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not applied then
		return
	end
	local description = applied:Clone()

	for categoryKey, assetId in data.equipped do
		if categoryKey == "Props" or categoryKey == "Ride" then
			continue -- props and rides are welded separately after the rebuild
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
		-- Asset delivery can fail mid-rebuild and leave the avatar invisible;
		-- put the previous look back so the player is never a ghost.
		pcall(function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid:ApplyDescription(applied)
			end
		end)
	end
	-- The rebuild strips welded models, so put the prop and ride back on.
	attachProp(player)
	attachRide(player)
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
	if categoryKey == "Rides" then
		if type(assetId) ~= "string" or not RIDE_SPECS[assetId] then
			return { ok = false }
		end
		if data.owned[`ride_{assetId}`] then
			return { ok = true, coins = data.coins }
		end
		local ridePrice = Config.ridePriceFor(assetId)
		if data.coins < ridePrice then
			return { ok = false, message = "Not enough hearts yet!" }
		end
		data.coins -= ridePrice
		data.owned[`ride_{assetId}`] = true
		pushCoins(player)
		return { ok = true, coins = data.coins }
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

	if categoryKey == "Rides" then
		if assetId == nil then
			data.equipped.Ride = nil
			attachRide(player)
			return { ok = true }
		end
		if type(assetId) ~= "string" or not RIDE_SPECS[assetId] then
			return { ok = false }
		end
		if Config.ridePriceFor(assetId) > 0 and not data.owned[`ride_{assetId}`] then
			return { ok = false, message = "Buy it first!" }
		end
		data.equipped.Ride = assetId
		attachRide(player)
		return { ok = true }
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
	data.photos = (data.photos or 0) + 1
	pushCoins(player)
	if announcePhoto then
		task.spawn(announcePhoto, player)
	end
	if updateNameTag then
		task.spawn(updateNameTag, player)
	end
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
guestBoard.Position = Vector3.new(-45, 8, 50)
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
	local entry = `{player.DisplayName} \u{00B7} {os.date("!%b %d")}`
	table.insert(signatures, entry)
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
					table.insert(old, entry)
					while #old > 200 do
						table.remove(old, 1)
					end
					return old
				end)
			end
		end)
	end)
end)

----------------------------------------------------------------------
-- Sign-anywhere stickers: hide your name (+date) on any surface
----------------------------------------------------------------------

local placeSignRemote = makeRemoteFunction("PlaceSign")

type StickerEntry = {
	u: number,
	n: string,
	d: string,
	px: number,
	py: number,
	pz: number,
	nx: number,
	ny: number,
	nz: number,
}

local stickers: { { entry: StickerEntry, part: Part } } = {}
local placeCooldown: { [Player]: number } = {}
local MAX_STICKERS_PER_PLAYER = 3
local MAX_STICKERS_TOTAL = 400

local function buildStickerPart(entry: StickerEntry): Part
	local pos = Vector3.new(entry.px, entry.py, entry.pz)
	local normal = Vector3.new(entry.nx, entry.ny, entry.nz)
	if normal.Magnitude < 0.5 then
		normal = Vector3.new(0, 1, 0)
	end
	normal = normal.Unit
	local up = math.abs(normal.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local part = Instance.new("Part")
	part.Name = "SignSticker"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = Vector3.new(4.2, 1.1, 0.1)
	part.Transparency = 1
	part.CFrame = CFrame.lookAt(pos + normal * 0.06, pos + normal, up)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(420, 110)
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bg.BackgroundTransparency = 0.25
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 24)
	corner.Parent = bg
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = `\u{270D} {entry.n} \u{00B7} {entry.d}`
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(226, 58, 130)
	label.Parent = bg
	part.Parent = workspace
	return part
end

local function persistStickers()
	task.spawn(function()
		pcall(function()
			if guestStore then
				local list = {}
				for _, sticker in stickers do
					table.insert(list, sticker.entry)
				end
				guestStore:SetAsync("stickers", list)
			end
		end)
	end)
end

task.spawn(function()
	pcall(function()
		if guestStore then
			local stored = guestStore:GetAsync("stickers")
			if type(stored) == "table" then
				for _, entry in stored do
					table.insert(stickers, { entry = entry, part = buildStickerPart(entry) })
				end
			end
		end
	end)
end)

placeSignRemote.OnServerInvoke = function(player: Player, pos: unknown, normal: unknown)
	if typeof(pos) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return { ok = false }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - pos).Magnitude > 40 then
		return { ok = false, message = "Too far away!" }
	end
	local now = os.clock()
	local last = placeCooldown[player]
	if last and now - last < 3 then
		return { ok = false }
	end
	placeCooldown[player] = now

	-- Keep at most a few per player: placing a new one moves your oldest.
	local mine = 0
	for _, sticker in stickers do
		if sticker.entry.u == player.UserId then
			mine += 1
		end
	end
	if mine >= MAX_STICKERS_PER_PLAYER then
		for index, sticker in stickers do
			if sticker.entry.u == player.UserId then
				sticker.part:Destroy()
				table.remove(stickers, index)
				break
			end
		end
	end
	while #stickers >= MAX_STICKERS_TOTAL do
		stickers[1].part:Destroy()
		table.remove(stickers, 1)
	end

	local unitNormal = (normal :: Vector3)
	local position = pos :: Vector3
	local entry: StickerEntry = {
		u = player.UserId,
		n = player.DisplayName,
		d = os.date("!%b %d") :: any,
		px = position.X,
		py = position.Y,
		pz = position.Z,
		nx = unitNormal.X,
		ny = unitNormal.Y,
		nz = unitNormal.Z,
	}
	table.insert(stickers, { entry = entry, part = buildStickerPart(entry) })
	persistStickers()
	return { ok = true }
end

Players.PlayerRemoving:Connect(function(player)
	placeCooldown[player] = nil
end)

----------------------------------------------------------------------
-- Social layer: live feed, photo shoutouts, group photos, gather events
----------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")

local feedRemote = Instance.new("RemoteEvent")
feedRemote.Name = "FeedEvent"
feedRemote.Parent = remotesFolder

local photoInviteRemote = Instance.new("RemoteEvent")
photoInviteRemote.Name = "PhotoInvite"
photoInviteRemote.Parent = remotesFolder

local eventStateRemote = Instance.new("RemoteEvent")
eventStateRemote.Name = "EventState"
eventStateRemote.Parent = remotesFolder

local joinPhotoRemote = makeRemoteFunction("JoinPhoto")

local function broadcastFeed(icon: string, text: string)
	feedRemote:FireAllClients(icon, text)
end

local function worldPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = workspace
	return p
end

----------------------------------------------------------------------
-- Zone lookup (pads are tagged by the world script)
----------------------------------------------------------------------

local function zonePads(): { BasePart }
	local pads: { BasePart } = {}
	for _, instance in CollectionService:GetTagged("PhotoZone") do
		if instance:IsA("BasePart") then
			table.insert(pads, instance)
		end
	end
	table.sort(pads, function(a, b)
		return ((a:GetAttribute("ZoneIndex") :: number?) or 0) < ((b:GetAttribute("ZoneIndex") :: number?) or 0)
	end)
	return pads
end

local function nearestZoneName(position: Vector3): string
	local bestName, bestDistance = "the studio", 95
	for _, pad in zonePads() do
		local distance = (pad.Position - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestName = (pad:GetAttribute("ZoneName") :: string?) or bestName
		end
	end
	return bestName
end

----------------------------------------------------------------------
-- Name tags: who is here, what they ride, how many photos they took
----------------------------------------------------------------------

local function rideIconFor(key: any): string
	if type(key) ~= "string" then
		return ""
	end
	for _, ride in Config.Rides do
		if ride.key == key then
			return ride.icon
		end
	end
	return ""
end

updateNameTag = function(player: Player)
	local data = sessions[player]
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head or not head:IsA("BasePart") then
		return
	end

	local tag = head:FindFirstChild("ComebackTag") :: BillboardGui?
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "ComebackTag"
		tag.Size = UDim2.fromOffset(230, 56)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 140
		tag.Parent = head

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, 0, 0.58, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeColor3 = Color3.fromRGB(226, 58, 130)
		nameLabel.TextStrokeTransparency = 0.1
		nameLabel.Parent = tag

		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Size = UDim2.new(1, 0, 0.42, 0)
		subLabel.Position = UDim2.fromScale(0, 0.58)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.FredokaOne
		subLabel.TextScaled = true
		subLabel.TextColor3 = Color3.fromRGB(255, 232, 245)
		subLabel.TextStrokeColor3 = Color3.fromRGB(90, 40, 110)
		subLabel.TextStrokeTransparency = 0.2
		subLabel.Parent = tag
	end

	local nameLabel = tag:FindFirstChild("NameLabel") :: TextLabel?
	local subLabel = tag:FindFirstChild("SubLabel") :: TextLabel?
	if nameLabel then
		nameLabel.Text = player.DisplayName
	end
	if subLabel then
		local ride = rideIconFor(data.equipped.Ride)
		subLabel.Text = `{ride ~= "" and ride .. " " or ""}\u{1F4F8} {data.photos or 0}`
	end
end

----------------------------------------------------------------------
-- Photo shoutouts + group photos
----------------------------------------------------------------------

local GROUP_RADIUS = 45
local INVITE_SECONDS = 12
local photoInvites: { [Player]: number } = {}

local function photoPop(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local pop = Instance.new("BillboardGui")
	pop.Name = "PhotoPop"
	pop.Size = UDim2.fromOffset(200, 64)
	pop.StudsOffset = Vector3.new(0, 4.4, 0)
	pop.AlwaysOnTop = true
	pop.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "\u{1F4F8} CLICK!"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(226, 58, 130)
	label.TextStrokeTransparency = 0
	label.Parent = pop
	task.delay(3, function()
		pop:Destroy()
	end)
end

announcePhoto = function(host: Player)
	local character = host.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local zoneName = nearestZoneName(root.Position)
	photoPop(host)

	local friends: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other ~= host then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") and (otherRoot.Position - root.Position).Magnitude <= GROUP_RADIUS then
				table.insert(friends, other)
			end
		end
	end

	for _, friend in friends do
		local friendData = sessions[friend]
		if friendData then
			friendData.coins += Config.GroupPhotoBonus
			pushCoins(friend)
			serverToast:FireClient(friend, `Group photo with {host.DisplayName}! +{Config.GroupPhotoBonus} \u{1F496}`)
			photoPop(friend)
		end
	end

	if #friends > 0 then
		broadcastFeed("\u{1F4F8}", `{host.DisplayName} + {#friends} took a group photo at {zoneName}!`)
		return
	end

	broadcastFeed("\u{1F4F8}", `{host.DisplayName} is taking photos at {zoneName}!`)
	photoInvites[host] = os.clock() + INVITE_SECONDS
	for _, other in Players:GetPlayers() do
		if other ~= host then
			photoInviteRemote:FireClient(other, host.UserId, host.DisplayName, zoneName, INVITE_SECONDS)
		end
	end
end

joinPhotoRemote.OnServerInvoke = function(player: Player, hostUserId: unknown)
	if type(hostUserId) ~= "number" then
		return { ok = false }
	end
	local host = Players:GetPlayerByUserId(hostUserId)
	if not host or host == player then
		return { ok = false }
	end
	local expiresAt = photoInvites[host]
	if not expiresAt or os.clock() > expiresAt then
		return { ok = false, message = "Too late! \u{1F97A}" }
	end
	local hostRoot = host.Character and host.Character:FindFirstChild("HumanoidRootPart")
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hostRoot or not hostRoot:IsA("BasePart") or not myRoot or not myRoot:IsA("BasePart") then
		return { ok = false }
	end

	-- Pop in beside the host, facing the same way.
	local side = (math.random(0, 1) == 0) and -1 or 1
	myRoot.CFrame = hostRoot.CFrame * CFrame.new(side * math.random(4, 7), 0, math.random(0, 3))
	local data = sessions[player]
	if data then
		data.coins += Config.GroupPhotoBonus
		pushCoins(player)
	end
	photoPop(player)
	broadcastFeed("\u{1F91D}", `{player.DisplayName} joined {host.DisplayName}'s photo!`)
	return { ok = true }
end

----------------------------------------------------------------------
-- Gather events: everyone to one zone, then a monument stays behind
----------------------------------------------------------------------

local eventStoreOk, eventStore = pcall(function()
	return DataStoreService:GetDataStore("ComebackEvents_v1")
end)
if not eventStoreOk then
	eventStore = nil
end

type EventRecord = { z: number, d: string, c: number }

local eventHistory: { EventRecord } = {}

local function buildEventMonument(record: EventRecord, ordinal: number)
	local pad: BasePart? = nil
	for _, candidate in zonePads() do
		if candidate:GetAttribute("ZoneIndex") == record.z then
			pad = candidate
			break
		end
	end
	if not pad then
		return
	end

	-- Later monuments are taller and brighter, so the world visibly grows.
	local height = math.min(10 + ordinal * 0.8, 30)
	local hue = (ordinal * 0.17) % 1
	local color = Color3.fromHSV(hue, 0.65, 1)
	local lateral = 13 + (ordinal % 3) * 5

	local pillar = worldPart({
		Name = "EventMonument",
		Size = Vector3.new(3, height, 3),
		CFrame = pad.CFrame * CFrame.new(lateral, height / 2, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	worldPart({
		Name = "EventMonumentBase",
		Size = Vector3.new(6, 1, 6),
		CFrame = pad.CFrame * CFrame.new(lateral, 0.5, 0),
		Color = Color3.fromRGB(58, 34, 84),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 90)
	sign.StudsOffset = Vector3.new(0, height / 2 + 3, 0)
	sign.MaxDistance = 220
	sign.Parent = pillar
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = `\u{1F389} EVENT #{ordinal}`
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = Color3.fromRGB(90, 40, 110)
	title.TextStrokeTransparency = 0.1
	title.Parent = sign
	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(1, 0, 0.5, 0)
	detail.Position = UDim2.fromScale(0, 0.5)
	detail.BackgroundTransparency = 1
	detail.Text = `{record.d} \u{00B7} {record.c} stars came`
	detail.Font = Enum.Font.FredokaOne
	detail.TextScaled = true
	detail.TextColor3 = Color3.fromRGB(255, 232, 245)
	detail.TextStrokeColor3 = Color3.fromRGB(90, 40, 110)
	detail.TextStrokeTransparency = 0.25
	detail.Parent = sign

	local attachment = Instance.new("Attachment")
	attachment.Parent = pillar
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = math.min(2 + ordinal, 12)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.Lifetime = NumberRange.new(1.2, 2.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Color = ColorSequence.new(color)
	sparkles.Parent = attachment
end

local function makeBeacon(pad: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "EventBeacon"

	local column = worldPart({
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(180, 12, 12),
		CFrame = pad.CFrame * CFrame.new(0, 90, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 214, 74),
		Material = Enum.Material.Neon,
		Transparency = 0.72,
		CanQuery = false,
	})
	column.Parent = model

	local ring = worldPart({
		Name = "Ring",
		Size = Vector3.new(18, 0.2, 18),
		CFrame = pad.CFrame * CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(255, 214, 74),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanQuery = false,
	})
	ring.Parent = model

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(320, 90)
	sign.StudsOffset = Vector3.new(0, 14, 0)
	sign.AlwaysOnTop = true
	sign.Parent = ring
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "\u{1F389} EVENT HERE!"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(255, 140, 0)
	label.TextStrokeTransparency = 0
	label.Parent = sign

	model.Parent = workspace
	return model
end

local recentZoneIndices: { number } = {}

local function runEvent()
	local pads = zonePads()
	if #pads == 0 then
		return
	end

	local pad: BasePart? = nil
	for _ = 1, 12 do
		local candidate = pads[math.random(1, #pads)]
		local index = (candidate:GetAttribute("ZoneIndex") :: number?) or 0
		if not table.find(recentZoneIndices, index) then
			pad = candidate
			table.insert(recentZoneIndices, index)
			while #recentZoneIndices > 6 do
				table.remove(recentZoneIndices, 1)
			end
			break
		end
	end
	pad = pad or pads[math.random(1, #pads)]
	local activePad = pad :: BasePart
	local zoneName = (activePad:GetAttribute("ZoneName") :: string?) or "a photo zone"

	local beacon = makeBeacon(activePad)
	broadcastFeed("\u{1F389}", `EVENT at {zoneName}! Everyone gather — big hearts!`)
	eventStateRemote:FireAllClients({
		active = true,
		zoneName = zoneName,
		position = activePad.Position,
		seconds = Config.EventDurationSeconds,
	})

	task.wait(Config.EventDurationSeconds)

	local attendees = 0
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - activePad.Position).Magnitude <= 45 then
			attendees += 1
			local data = sessions[player]
			if data then
				data.coins += Config.EventRewardCoins
				pushCoins(player)
				serverToast:FireClient(player, `Event reward! +{Config.EventRewardCoins} \u{1F496}`)
			end
		end
	end

	beacon:Destroy()
	eventStateRemote:FireAllClients({ active = false })

	local record: EventRecord = { z = (activePad:GetAttribute("ZoneIndex") :: number?) or 0, d = os.date("!%b %d") :: any, c = attendees }
	table.insert(eventHistory, record)
	buildEventMonument(record, #eventHistory)
	broadcastFeed("\u{1F3C6}", `Event done at {zoneName} — {attendees} stars came! A monument now stands there.`)

	task.spawn(function()
		pcall(function()
			if eventStore then
				eventStore:UpdateAsync("history", function(old)
					old = type(old) == "table" and old or {}
					table.insert(old, record)
					while #old > 60 do
						table.remove(old, 1)
					end
					return old
				end)
			end
		end)
	end)
end

task.spawn(function()
	-- Rebuild past monuments once the world exists.
	local waited = 0
	while #zonePads() < 38 and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	pcall(function()
		if eventStore then
			local stored = eventStore:GetAsync("history")
			if type(stored) == "table" then
				eventHistory = stored
			end
		end
	end)
	for ordinal, record in eventHistory do
		buildEventMonument(record, ordinal)
	end

	while true do
		task.wait(Config.EventIntervalSeconds)
		if #Players:GetPlayers() > 0 then
			runEvent()
		end
	end
end)

----------------------------------------------------------------------
-- Keep name tags fresh
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1.5)
		updateNameTag(player)
	end)
	broadcastFeed("\u{1F44B}", `{player.DisplayName} arrived!`)
end)

Players.PlayerRemoving:Connect(function(player)
	photoInvites[player] = nil
end)
