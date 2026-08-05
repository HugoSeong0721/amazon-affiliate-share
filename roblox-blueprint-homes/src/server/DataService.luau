--!strict
-- Player profiles (money, saved build, blueprint library) + the cross-server
-- earnings inbox that pays creators royalties even while they're offline.
--
-- Degrades gracefully when DataStores are unavailable (e.g. an unpublished
-- Studio session): everything runs in-memory so the game stays testable.
--
-- Production note: for very large scale, swap the profile layer for
-- ProfileService/ProfileStore to get session locking. The save path here is
-- deliberately simple (last-writer-wins) and never saves a profile that
-- failed to load, which prevents the classic data-wipe failure mode.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local DataService = {}

local moneyChanged = Net.event("MoneyChanged")
local notify = Net.event("Notify")

local profileStore = nil
local earningsStore = nil
pcall(function()
	profileStore = DataStoreService:GetDataStore("BPH_Profiles_" .. Config.DataStoreVersion)
	earningsStore = DataStoreService:GetDataStore("BPH_Earnings_" .. Config.DataStoreVersion)
end)

local profiles: { [Player]: any } = {}

local function defaultProfile()
	return {
		money = Config.StartingMoney,
		build = nil, -- BlueprintCodec.BuildData
		ownedBlueprints = {}, -- [blueprintId] = true
		published = {}, -- array of blueprintIds
		lastDailyBonus = 0,
		totalRoyalties = 0,
		loadedOk = true, -- false -> never overwrite the stored copy
	}
end

local function profileKey(userId: number): string
	return "p_" .. userId
end

-- // Public API =========================================================

function DataService.Load(player: Player)
	local profile = defaultProfile()
	if profileStore then
		local ok, stored = Util.retry(3, 1, function()
			return (profileStore :: any):GetAsync(profileKey(player.UserId))
		end)
		if ok then
			if type(stored) == "table" then
				for k, v in pairs(stored) do
					profile[k] = v
				end
				profile.loadedOk = true
			end
		else
			warn("[DataService] load failed for", player.Name, stored)
			profile.loadedOk = false
			notify:FireClient(player, "Data could not load - progress won't save this session.", "bad")
		end
	end
	profiles[player] = profile
	moneyChanged:FireClient(player, profile.money)
	DataService.ClaimEarnings(player)
	return profile
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loadedOk or not profileStore then
		return
	end
	local snapshot = Util.deepCopy(profile)
	snapshot.loadedOk = nil
	local ok, err = Util.retry(3, 1, function()
		(profileStore :: any):UpdateAsync(profileKey(player.UserId), function()
			return snapshot
		end)
		return true
	end)
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
	end
end

function DataService.Remove(player: Player)
	DataService.Save(player)
	profiles[player] = nil
end

-- // Money ==============================================================

function DataService.GetMoney(player: Player): number
	local profile = profiles[player]
	return profile and profile.money or 0
end

function DataService.Credit(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.money += math.floor(amount)
	moneyChanged:FireClient(player, profile.money)
end

-- Used by undo/redo, which restores an exact earlier balance rather than
-- applying a delta.
function DataService.SetMoney(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.money = math.max(0, math.floor(amount))
	moneyChanged:FireClient(player, profile.money)
end

function DataService.TryDebit(player: Player, amount: number): boolean
	local profile = profiles[player]
	amount = math.floor(amount)
	if not profile or amount < 0 then
		return false
	end
	if profile.money < amount then
		return false
	end
	profile.money -= amount
	moneyChanged:FireClient(player, profile.money)
	return true
end

-- // Royalty inbox ======================================================
-- Credits land in a per-user inbox via atomic UpdateAsync, so a sale on any
-- server pays the creator whether or not they're online. Online sessions
-- claim their inbox on load and on a slow poll.

function DataService.CreditToUser(userId: number, amount: number, reason: string?)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	-- same-server shortcut
	local online = Players:GetPlayerByUserId(userId)
	if online and profiles[online] then
		local profile = profiles[online]
		profile.totalRoyalties += amount
		DataService.Credit(online, amount)
		notify:FireClient(online, ("Blueprint sold! +%s"):format(Util.money(amount)), "good")
		-- Persist now: the buyer already owns the blueprint, so a crash before
		-- the next autosave would take the creator's cut with it.
		DataService.Save(online)
		return
	end
	if not earningsStore then
		return
	end
	local ok, err = Util.retry(3, 1, function()
		(earningsStore :: any):UpdateAsync("e_" .. userId, function(old)
			return (type(old) == "number" and old or 0) + amount
		end)
		return true
	end)
	if not ok then
		warn("[DataService] failed to credit earnings inbox for", userId, err)
	end
end

function DataService.ClaimEarnings(player: Player)
	local profile = profiles[player]
	if not profile or not earningsStore then
		return
	end
	-- Claiming empties the inbox, so never claim into a profile that cannot be
	-- written back: the credit would vanish with the session.
	if not profile.loadedOk then
		return
	end
	local claimed = 0
	local ok = pcall(function()
		(earningsStore :: any):UpdateAsync("e_" .. player.UserId, function(old)
			claimed = type(old) == "number" and old or 0
			return 0
		end)
	end)
	if ok and claimed > 0 then
		profile.totalRoyalties += claimed
		DataService.Credit(player, claimed)
		notify:FireClient(player, ("Your blueprints sold while you were away! +%s"):format(Util.money(claimed)), "good")
		-- The inbox is already zeroed; make the credit durable before anything
		-- else can end the session.
		DataService.Save(player)
	end
end

-- // Lifecycle ==========================================================

function DataService.Init()
	Net.func("GetBalance").OnServerInvoke = function(player)
		return DataService.GetMoney(player)
	end

	-- autosave
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(profiles) do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	-- claim offline earnings periodically while online
	task.spawn(function()
		while true do
			task.wait(Config.EarningsClaimInterval)
			for player in pairs(profiles) do
				task.spawn(DataService.ClaimEarnings, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in pairs(profiles) do
			DataService.Save(player)
		end
	end)
end

return DataService
