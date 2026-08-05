--!strict
-- Authoritative build system: placing, deleting, loading saved builds,
-- applying blueprints. All spatial validation happens here - the client
-- preview is cosmetic only.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local GridUtil = require(Shared.GridUtil)
local ItemModels = require(Shared.ItemModels)
local BlueprintCodec = require(Shared.BlueprintCodec)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local BuildService = {}

-- Every remote handler answers with this shape, so the client can branch on
-- `ok` and show `err` without guessing which fields are present.
export type Result = {
	ok: boolean,
	err: string?,
	money: number?,
	materialCost: number?,
}

-- // rate limiting ------------------------------------------------------

local lastCall: { [Player]: { [string]: number } } = {}

local function rateLimited(player: Player, key: string): boolean
	local minInterval = Config.RateLimits[key]
	if not minInterval then
		return false
	end
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	if calls[key] and now - calls[key] < minInterval then
		return true
	end
	calls[key] = now
	return false
end

BuildService.RateLimited = rateLimited

-- // undo / redo --------------------------------------------------------
-- Snapshot based: each entry is the whole build plus the balance at that
-- moment. Restoring both together means undo can never mint money - undoing a
-- sale takes back the refund, undoing a purchase returns exactly what was paid.

type Snapshot = { items: { BlueprintCodec.ItemRecord }, money: number }

local history: { [Player]: { past: { Snapshot }, future: { Snapshot } } } = {}

local function historyFor(player: Player)
	local entry = history[player]
	if not entry then
		entry = { past = {}, future = {} }
		history[player] = entry
	end
	return entry
end

local function snapshotOf(player: Player, plot: PlotService.Plot): Snapshot
	return { items = BlueprintCodec.serialize(plot.items).items, money = DataService.GetMoney(player) }
end

-- Call immediately before any mutation that should be undoable.
function BuildService.Snapshot(player: Player)
	local plot = PlotService.Get(player)
	if not plot then
		return
	end
	local entry = historyFor(player)
	table.insert(entry.past, snapshotOf(player, plot))
	while #entry.past > Config.UndoDepth do
		table.remove(entry.past, 1)
	end
	entry.future = {} -- a fresh edit invalidates the redo branch
end

function BuildService.ForgetPlayer(player: Player)
	lastCall[player] = nil
	history[player] = nil
end

-- // internals ----------------------------------------------------------

local function occupyCells(plot: PlotService.Plot, layer: string, keys: { string }, value: boolean)
	local layerMap = plot.occupancy[layer]
	for _, key in ipairs(keys) do
		layerMap[key] = value or nil
	end
end

local function cellsFree(plot: PlotService.Plot, layer: string, keys: { string }): boolean
	local layerMap = plot.occupancy[layer]
	for _, key in ipairs(keys) do
		if layerMap[key] then
			return false
		end
	end
	return true
end

-- Instantiates the model + records state. Assumes validation already passed.
local function spawnItem(plot: PlotService.Plot, def: any, x: number, z: number, r: number): number
	local uid = plot.nextUid
	plot.nextUid += 1

	local model = ItemModels.build(def)
	model:PivotTo(GridUtil.itemPivot(plot.origin, x, z, def.w, def.d, r))
	model:SetAttribute("Uid", uid)
	model:SetAttribute("ItemId", def.id)
	model:SetAttribute("X", x)
	model:SetAttribute("Z", z)
	model:SetAttribute("R", r)
	model.Parent = plot.itemsFolder

	plot.items[uid] = { uid = uid, id = def.id, x = x, z = z, r = r, model = model }
	occupyCells(plot, def.layer, GridUtil.cellKeys(x, z, def.w, def.d, r), true)
	return uid
end

local function syncProfileBuild(player: Player, plot: PlotService.Plot)
	local profile = DataService.Get(player)
	if profile then
		profile.build = BlueprintCodec.serialize(plot.items)
	end
end

-- // public API ---------------------------------------------------------

-- Wipes the plot and rebuilds it from a snapshot, restoring the balance too.
local function restore(player: Player, plot: PlotService.Plot, snapshot: Snapshot)
	for _, rec in pairs(plot.items) do
		if rec.model then
			rec.model:Destroy()
		end
	end
	plot.items = {}
	plot.occupancy = { floor = {}, object = {} }
	for _, rec in ipairs(snapshot.items) do
		local def = Catalog.ById[rec.id]
		if def then
			spawnItem(plot, def, rec.x, rec.z, rec.r)
		end
	end
	DataService.SetMoney(player, snapshot.money)
	syncProfileBuild(player, plot)
end

-- Validated placement paid for by the player.
function BuildService.PlaceItem(player: Player, itemId: any, x: any, z: any, r: any): Result
	if rateLimited(player, "PlaceItem") then
		return { ok = false, err = "slow-down" }
	end
	if type(itemId) ~= "string" or not (Util.isInteger(x) and Util.isInteger(z) and Util.isInteger(r)) then
		return { ok = false, err = "bad-request" }
	end
	if r < 0 or r > 3 then
		return { ok = false, err = "bad-request" }
	end
	local plot = PlotService.Get(player)
	local def = Catalog.ById[itemId]
	if not plot or not def then
		return { ok = false, err = "bad-request" }
	end
	if not GridUtil.inBounds(x, z, def.w, def.d, r) then
		return { ok = false, err = "out-of-bounds" }
	end
	local keys = GridUtil.cellKeys(x, z, def.w, def.d, r)
	if not cellsFree(plot, def.layer, keys) then
		return { ok = false, err = "occupied" }
	end
	local count = 0
	for _ in pairs(plot.items) do
		count += 1
	end
	if count >= Config.Blueprint.MaxItems then
		return { ok = false, err = "plot-full" }
	end
	-- Check affordability before snapshotting: the snapshot has to record the
	-- pre-purchase balance for undo to refund correctly, and a rejected call
	-- must not push history at all.
	if DataService.GetMoney(player) < def.price then
		return { ok = false, err = "no-money" }
	end
	BuildService.Snapshot(player)
	if not DataService.TryDebit(player, def.price) then
		return { ok = false, err = "no-money" }
	end
	spawnItem(plot, def, x, z, r)
	syncProfileBuild(player, plot)
	return { ok = true, money = DataService.GetMoney(player) }
end

function BuildService.RemoveItem(player: Player, uid: any): Result
	if rateLimited(player, "RemoveItem") then
		return { ok = false, err = "slow-down" }
	end
	if not Util.isInteger(uid) then
		return { ok = false, err = "bad-request" }
	end
	local plot = PlotService.Get(player)
	if not plot then
		return { ok = false, err = "bad-request" }
	end
	local rec = plot.items[uid]
	if not rec then
		return { ok = false, err = "not-found" }
	end
	local def = Catalog.ById[rec.id]

	BuildService.Snapshot(player)
	plot.items[uid] = nil
	if def then
		occupyCells(plot, def.layer, GridUtil.cellKeys(rec.x, rec.z, def.w, def.d, rec.r), false)
		DataService.Credit(player, math.floor(def.price * Config.SellRefundRate))
	end
	if rec.model then
		rec.model:Destroy()
	end
	syncProfileBuild(player, plot)
	return { ok = true, money = DataService.GetMoney(player) }
end

-- Repositions an item already on the plot. Free, like Bloxburg's move tool:
-- rearranging a room you already paid for should not cost anything.
function BuildService.MoveItem(player: Player, uid: any, x: any, z: any, r: any): Result
	if rateLimited(player, "MoveItem") then
		return { ok = false, err = "slow-down" }
	end
	if not (Util.isInteger(uid) and Util.isInteger(x) and Util.isInteger(z) and Util.isInteger(r)) then
		return { ok = false, err = "bad-request" }
	end
	if r < 0 or r > 3 then
		return { ok = false, err = "bad-request" }
	end
	local plot = PlotService.Get(player)
	if not plot then
		return { ok = false, err = "bad-request" }
	end
	local rec = plot.items[uid]
	if not rec then
		return { ok = false, err = "not-found" }
	end
	local def = Catalog.ById[rec.id]
	if not def then
		return { ok = false, err = "bad-request" }
	end
	if not GridUtil.inBounds(x, z, def.w, def.d, r) then
		return { ok = false, err = "out-of-bounds" }
	end

	-- Free the item's own cells first, so sliding it one cell over - or turning
	-- it in place - is not blocked by where it currently stands.
	local oldKeys = GridUtil.cellKeys(rec.x, rec.z, def.w, def.d, rec.r)
	occupyCells(plot, def.layer, oldKeys, false)

	local newKeys = GridUtil.cellKeys(x, z, def.w, def.d, r)
	if not cellsFree(plot, def.layer, newKeys) then
		occupyCells(plot, def.layer, oldKeys, true) -- put it back
		return { ok = false, err = "occupied" }
	end

	BuildService.Snapshot(player)
	occupyCells(plot, def.layer, newKeys, true)
	rec.x, rec.z, rec.r = x, z, r
	if rec.model then
		rec.model:PivotTo(GridUtil.itemPivot(plot.origin, x, z, def.w, def.d, r))
		rec.model:SetAttribute("X", x)
		rec.model:SetAttribute("Z", z)
		rec.model:SetAttribute("R", r)
	end
	syncProfileBuild(player, plot)
	return { ok = true, money = DataService.GetMoney(player) }
end

function BuildService.Undo(player: Player): Result
	if rateLimited(player, "Undo") then
		return { ok = false, err = "slow-down" }
	end
	local plot = PlotService.Get(player)
	if not plot then
		return { ok = false, err = "bad-request" }
	end
	local entry = historyFor(player)
	local previous = table.remove(entry.past)
	if not previous then
		return { ok = false, err = "nothing-to-undo" }
	end
	table.insert(entry.future, snapshotOf(player, plot))
	restore(player, plot, previous)
	return { ok = true, money = DataService.GetMoney(player) }
end

function BuildService.Redo(player: Player): Result
	if rateLimited(player, "Undo") then
		return { ok = false, err = "slow-down" }
	end
	local plot = PlotService.Get(player)
	if not plot then
		return { ok = false, err = "bad-request" }
	end
	local entry = historyFor(player)
	local next_ = table.remove(entry.future)
	if not next_ then
		return { ok = false, err = "nothing-to-redo" }
	end
	table.insert(entry.past, snapshotOf(player, plot))
	restore(player, plot, next_)
	return { ok = true, money = DataService.GetMoney(player) }
end

-- Deletes everything on the plot. refund=true credits the sell rate for each item.
function BuildService.ClearPlot(player: Player, refund: boolean)
	local plot = PlotService.Get(player)
	if not plot then
		return
	end
	local refundTotal = 0
	for _, rec in pairs(plot.items) do
		local def = Catalog.ById[rec.id]
		if refund and def then
			refundTotal += math.floor(def.price * Config.SellRefundRate)
		end
		if rec.model then
			rec.model:Destroy()
		end
	end
	plot.items = {}
	plot.occupancy = { floor = {}, object = {} }
	if refundTotal > 0 then
		DataService.Credit(player, refundTotal)
	end
	syncProfileBuild(player, plot)
end

-- Builds a validated item list without charging (used by save-load and
-- blueprint apply, which charge separately).
function BuildService.BuildItems(player: Player, items: { BlueprintCodec.ItemRecord })
	local plot = PlotService.Get(player)
	if not plot then
		return
	end
	for _, rec in ipairs(items) do
		local def = Catalog.ById[rec.id]
		if def
			and GridUtil.inBounds(rec.x, rec.z, def.w, def.d, rec.r)
			and cellsFree(plot, def.layer, GridUtil.cellKeys(rec.x, rec.z, def.w, def.d, rec.r))
		then
			spawnItem(plot, def, rec.x, rec.z, rec.r)
		end
	end
	syncProfileBuild(player, plot)
end

-- Restore the player's saved house onto their plot at join.
function BuildService.LoadSavedBuild(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.build then
		return
	end
	local ok, items = BlueprintCodec.validate(profile.build)
	if ok then
		BuildService.BuildItems(player, items)
	else
		warn("[BuildService] saved build invalid for", player.Name, items)
	end
end

function BuildService.Init()
	Net.func("PlaceItem").OnServerInvoke = function(player, itemId, x, z, r)
		return BuildService.PlaceItem(player, itemId, x, z, r)
	end
	Net.func("RemoveItem").OnServerInvoke = function(player, uid)
		return BuildService.RemoveItem(player, uid)
	end
	Net.func("MoveItem").OnServerInvoke = function(player, uid, x, z, r)
		return BuildService.MoveItem(player, uid, x, z, r)
	end
	Net.func("Undo").OnServerInvoke = function(player)
		return BuildService.Undo(player)
	end
	Net.func("Redo").OnServerInvoke = function(player)
		return BuildService.Redo(player)
	end
end

return BuildService
