--!strict
-- The differentiator: a player-to-player marketplace for house designs.
--
-- Flow:
--   1. A builder decorates their plot, hits Publish, names it, sets a design fee.
--   2. The blueprint (items + meta) is written to global DataStores.
--   3. Any player on any server browses Top/New, pays the design fee once,
--      then pays material cost to stamp the house onto their own plot.
--   4. The creator gets RoyaltyRate of every sale - online or offline
--      (earnings inbox) - and climbs the Top Sellers chart.
--
-- This pulls the real-world Bloxburg commission economy (Fiverr et al.)
-- inside the game loop.

local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local BlueprintCodec = require(Shared.BlueprintCodec)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local BuildService = require(script.Parent.BuildService)
local EconomyService = require(script.Parent.EconomyService)

local BlueprintMarketService = {}

local BP = Config.Blueprint

local dataStore = nil -- blueprint item data (immutable once published)
local metaStore = nil -- listing metadata (name, price, sales, ...)
local topStore = nil -- OrderedDataStore: sales count
local newStore = nil -- OrderedDataStore: publish timestamp
pcall(function()
	local v = Config.DataStoreVersion
	dataStore = DataStoreService:GetDataStore("BPH_Blueprints_" .. v)
	metaStore = DataStoreService:GetDataStore("BPH_BlueprintMeta_" .. v)
	topStore = DataStoreService:GetOrderedDataStore("BPH_TopSales_" .. v)
	newStore = DataStoreService:GetOrderedDataStore("BPH_Newest_" .. v)
end)

-- in-memory caches so browsing doesn't hammer DataStores
local metaCache: { [string]: { meta: any, at: number } } = {}
local dataCache: { [string]: { data: any, at: number } } = {}

local function storesReady(): boolean
	return dataStore ~= nil and metaStore ~= nil and topStore ~= nil and newStore ~= nil
end

local function filterName(player: Player, raw: string): string
	local filtered: string? = nil
	local ok = pcall(function()
		local result = TextService:FilterStringAsync(raw, player.UserId)
		filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	if ok and filtered then
		return filtered
	end
	-- filtering is unavailable in offline Studio tests; never ship raw text otherwise
	return RunService:IsStudio() and raw or "Blueprint"
end

local function getMeta(id: string): any?
	local cached = metaCache[id]
	if cached and os.clock() - cached.at < BP.MetaCacheSeconds then
		return cached.meta
	end
	if not metaStore then
		return nil
	end
	local ok, meta = Util.retry(2, 0.5, function()
		return (metaStore :: any):GetAsync(id)
	end)
	if ok and type(meta) == "table" then
		metaCache[id] = { meta = meta, at = os.clock() }
		return meta
	end
	return nil
end

local function getData(id: string): any?
	local cached = dataCache[id]
	if cached and os.clock() - cached.at < BP.DataCacheSeconds then
		return cached.data
	end
	if not dataStore then
		return nil
	end
	local ok, data = Util.retry(2, 0.5, function()
		return (dataStore :: any):GetAsync(id)
	end)
	if ok and type(data) == "table" then
		dataCache[id] = { data = data, at = os.clock() }
		return data
	end
	return nil
end

local function publishSlots(player: Player): number
	return EconomyService.HasPass(player, "ProBuilder") and BP.ProPublishSlots or BP.FreePublishSlots
end

-- // handlers -----------------------------------------------------------

function BlueprintMarketService.Publish(player: Player, name: any, price: any)
	if BuildService.RateLimited(player, "PublishBlueprint") then
		return { ok = false, err = "slow-down" }
	end
	if not storesReady() then
		return { ok = false, err = "market-offline" }
	end
	if type(name) ~= "string" or not Util.isInteger(price) then
		return { ok = false, err = "bad-request" }
	end
	name = name:sub(1, BP.NameMaxLength)
	if #name < 2 then
		return { ok = false, err = "name-too-short" }
	end
	if price < BP.MinPrice or price > BP.MaxPrice then
		return { ok = false, err = "bad-price" }
	end

	local profile = DataService.Get(player)
	local plot = PlotService.Get(player)
	if not profile or not plot then
		return { ok = false, err = "bad-request" }
	end
	if #profile.published >= publishSlots(player) then
		return { ok = false, err = "no-slots" }
	end

	local build = BlueprintCodec.serialize(plot.items)
	if #build.items < BP.MinItemsToPublish then
		return { ok = false, err = "too-few-items" }
	end
	local okValidate, items, materialCost = BlueprintCodec.validate(build)
	if not okValidate then
		return { ok = false, err = "bad-build" }
	end

	local id = HttpService:GenerateGUID(false)
	local meta = {
		id = id,
		name = filterName(player, name),
		price = price,
		materialCost = materialCost,
		itemCount = #items,
		creatorId = player.UserId,
		creatorName = player.DisplayName,
		pro = EconomyService.HasPass(player, "ProBuilder"),
		sales = 0,
		created = os.time(),
	}

	local okWrite = Util.retry(3, 1, function()
		(dataStore :: any):SetAsync(id, { v = 1, items = items });
		(metaStore :: any):SetAsync(id, meta);
		(topStore :: any):SetAsync(id, 0);
		(newStore :: any):SetAsync(id, os.time())
		return true
	end)
	if not okWrite then
		return { ok = false, err = "store-error" }
	end

	metaCache[id] = { meta = meta, at = os.clock() }
	table.insert(profile.published, id)
	profile.ownedBlueprints[id] = true
	DataService.Save(player)
	return { ok = true, meta = meta }
end

function BlueprintMarketService.GetMarket(player: Player, tab: any)
	if BuildService.RateLimited(player, "GetMarket") then
		return { ok = false, err = "slow-down" }
	end
	if not storesReady() then
		return { ok = false, err = "market-offline" }
	end
	local ordered = (tab == "new") and newStore or topStore

	local okPage, page = Util.retry(2, 0.5, function()
		local pages = (ordered :: any):GetSortedAsync(false, BP.MarketPageSize)
		return pages:GetCurrentPage()
	end)
	if not okPage then
		return { ok = false, err = "store-error" }
	end

	local profile = DataService.Get(player)
	local listings = {}
	for _, entry in ipairs(page) do
		local meta = getMeta(entry.key)
		if meta then
			local item = Util.deepCopy(meta)
			item.owned = profile and profile.ownedBlueprints[meta.id] == true or false
			item.mine = meta.creatorId == player.UserId
			table.insert(listings, item)
		end
	end
	return { ok = true, listings = listings }
end

function BlueprintMarketService.Buy(player: Player, id: any)
	if BuildService.RateLimited(player, "BuyBlueprint") then
		return { ok = false, err = "slow-down" }
	end
	if type(id) ~= "string" then
		return { ok = false, err = "bad-request" }
	end
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, err = "bad-request" }
	end
	if profile.ownedBlueprints[id] then
		return { ok = false, err = "already-owned" }
	end
	local meta = getMeta(id)
	if not meta then
		return { ok = false, err = "not-found" }
	end
	if meta.creatorId == player.UserId then
		return { ok = false, err = "own-blueprint" }
	end
	if not DataService.TryDebit(player, meta.price) then
		return { ok = false, err = "no-money" }
	end

	profile.ownedBlueprints[id] = true

	-- pay the creator their cut, wherever they are
	local royalty = math.floor(meta.price * BP.RoyaltyRate)
	DataService.CreditToUser(meta.creatorId, royalty, "blueprint-sale")

	-- bump sales counters (best-effort; chart lag is acceptable)
	task.spawn(function()
		local newSales = meta.sales + 1
		pcall(function()
			(metaStore :: any):UpdateAsync(id, function(old)
				if type(old) ~= "table" then
					return old
				end
				old.sales = (old.sales or 0) + 1
				newSales = old.sales
				return old
			end)
		end)
		pcall(function()
			(topStore :: any):SetAsync(id, newSales)
		end)
		meta.sales = newSales
	end)

	DataService.Save(player)
	return { ok = true, money = DataService.GetMoney(player) }
end

function BlueprintMarketService.Apply(player: Player, id: any)
	if BuildService.RateLimited(player, "ApplyBlueprint") then
		return { ok = false, err = "slow-down" }
	end
	if type(id) ~= "string" then
		return { ok = false, err = "bad-request" }
	end
	local profile = DataService.Get(player)
	local plot = PlotService.Get(player)
	if not profile or not plot then
		return { ok = false, err = "bad-request" }
	end
	if not profile.ownedBlueprints[id] then
		return { ok = false, err = "not-owned" }
	end
	local data = getData(id)
	if not data then
		return { ok = false, err = "not-found" }
	end
	local okValidate, items, materialCost = BlueprintCodec.validate(data)
	if not okValidate then
		return { ok = false, err = "bad-build" }
	end

	-- charge materials first; then clearing refunds the old furniture
	if not DataService.TryDebit(player, materialCost) then
		return { ok = false, err = "no-money", materialCost = materialCost }
	end
	BuildService.ClearPlot(player, true)
	BuildService.BuildItems(player, items)
	DataService.Save(player)
	return { ok = true, money = DataService.GetMoney(player), materialCost = materialCost }
end

function BlueprintMarketService.GetMine(player: Player)
	if BuildService.RateLimited(player, "GetMyBlueprints") then
		return { ok = false, err = "slow-down" }
	end
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, err = "bad-request" }
	end
	local published = {}
	for _, id in ipairs(profile.published) do
		local meta = getMeta(id)
		if meta then
			table.insert(published, meta)
		end
	end
	local owned = {}
	for id in pairs(profile.ownedBlueprints) do
		local meta = getMeta(id)
		if meta and meta.creatorId ~= player.UserId then
			table.insert(owned, meta)
		end
	end
	return { ok = true, published = published, owned = owned, totalRoyalties = profile.totalRoyalties }
end

function BlueprintMarketService.Init()
	Net.func("PublishBlueprint").OnServerInvoke = function(player, name, price)
		return BlueprintMarketService.Publish(player, name, price)
	end
	Net.func("GetMarket").OnServerInvoke = function(player, tab)
		return BlueprintMarketService.GetMarket(player, tab)
	end
	Net.func("BuyBlueprint").OnServerInvoke = function(player, id)
		return BlueprintMarketService.Buy(player, id)
	end
	Net.func("ApplyBlueprint").OnServerInvoke = function(player, id)
		return BlueprintMarketService.Apply(player, id)
	end
	Net.func("GetMyBlueprints").OnServerInvoke = function(player)
		return BlueprintMarketService.GetMine(player)
	end
end

return BlueprintMarketService
