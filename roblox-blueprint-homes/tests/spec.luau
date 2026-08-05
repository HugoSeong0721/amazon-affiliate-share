-- Server-logic suite. Runs the shipped modules against the mock in
-- tests/roblox_mock.luau; see tests/run.py for how the chunk is assembled.
--
-- Scope: grid math, blueprint validation, build/economy rules, and the
-- marketplace flow end to end (publish -> buy -> royalty -> apply), including
-- the offline earnings inbox. Client rendering and input are out of scope.

local PASS, FAIL = 0, 0
local failures = {}

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		PASS += 1
	else
		FAIL += 1
		table.insert(failures, ("%s\n      %s"):format(name, tostring(err)))
		print(("  FAIL  %s"):format(name))
		return
	end
	print(("  ok    %s"):format(name))
end

local function eq(actual: any, expected: any, what: string?)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function truthy(value: any, what: string?)
	if not value then
		error(("%s: expected truthy, got %s"):format(what or "value", tostring(value)), 2)
	end
end

-- // modules under test --------------------------------------------------

local Config = req("Config")
local Catalog = req("Catalog")
local GridUtil = req("GridUtil")
local Util = req("Util")
local BlueprintCodec = req("BlueprintCodec")
local DataService = req("DataService")
local PlotService = req("PlotService")
local BuildService = req("BuildService")
local EconomyService = req("EconomyService")
local Market = req("BlueprintMarketService")

PlotService.GenerateMap()

-- Rate limits exist to stop remote spam; they would make every second call in
-- a test fail, so the fake clock is nudged past the window before each call.
local function unthrottle()
	MOCK.advance(60)
end

local function join(name: string)
	local player = MOCK.newPlayer(name)
	DataService.Load(player)
	local plot = PlotService.Assign(player)
	truthy(plot, "plot assigned to " .. name)
	return player, plot
end

local function leave(player)
	BuildService.ForgetPlayer(player)
	DataService.Remove(player)
	PlotService.Release(player)
	MOCK.removePlayer(player)
end

-- Plots are a finite server resource, so a test that needs one gives it back
-- even when the body fails.
local function plotTest(name: string, playerName: string, body: (any, any) -> ())
	test(name, function()
		local player, plot = join(playerName)
		local ok, err = pcall(body, player, plot)
		leave(player)
		if not ok then
			error(err, 0)
		end
	end)
end

local function place(player, itemId: string, x: number, z: number, r: number?)
	unthrottle()
	return BuildService.PlaceItem(player, itemId, x, z, r or 0)
end

print("\nGridUtil")

test("rotation swaps the footprint on odd quarter turns", function()
	local w, d = GridUtil.rotatedFootprint(2, 1, 0)
	eq(w, 2, "w at r=0")
	eq(d, 1, "d at r=0")
	w, d = GridUtil.rotatedFootprint(2, 1, 1)
	eq(w, 1, "w at r=1")
	eq(d, 2, "d at r=1")
	w, d = GridUtil.rotatedFootprint(2, 1, 2)
	eq(w, 2, "w at r=2")
end)

test("inBounds rejects a footprint hanging off the far edge", function()
	local n = Config.PlotSizeCells
	truthy(GridUtil.inBounds(0, 0, 2, 1, 0), "origin fits")
	truthy(GridUtil.inBounds(n - 2, n - 1, 2, 1, 0), "flush with the far corner fits")
	eq(GridUtil.inBounds(n - 1, 0, 2, 1, 0), false, "one cell over the edge")
	eq(GridUtil.inBounds(-1, 0, 1, 1, 0), false, "negative anchor")
	-- rotation must be accounted for: 2x1 rotated is 1x2
	eq(GridUtil.inBounds(0, n - 1, 2, 1, 1), false, "rotated footprint over the edge")
end)

test("cellKeys covers the footprint exactly once", function()
	local keys = GridUtil.cellKeys(3, 4, 2, 2, 0)
	eq(#keys, 4, "cell count")
	local seen = {}
	for _, key in ipairs(keys) do
		eq(seen[key], nil, "duplicate cell " .. key)
		seen[key] = true
	end
	truthy(seen["3:4"] and seen["4:5"], "corners present")
end)

test("worldToAnchor clamps so the footprint stays on the plot", function()
	local origin = Vector3.new(0, 0, 0)
	local far = Config.PlotSizeCells * Config.CellSize + 500
	local x, z = GridUtil.worldToAnchor(origin, Vector3.new(far, 0, far), 2, 2, 0)
	eq(x, Config.PlotSizeCells - 2, "x clamped")
	eq(z, Config.PlotSizeCells - 2, "z clamped")
	x, z = GridUtil.worldToAnchor(origin, Vector3.new(-far, 0, -far), 2, 2, 0)
	eq(x, 0, "x clamped low")
	eq(z, 0, "z clamped low")
end)

print("\nUtil")

test("comma groups thousands and keeps the sign", function()
	eq(Util.comma(0), "0")
	eq(Util.comma(999), "999")
	eq(Util.comma(1000), "1,000")
	eq(Util.comma(1234567), "1,234,567")
	eq(Util.money(-2500), "$-2,500")
end)

test("isInteger rejects floats and non-numbers", function()
	truthy(Util.isInteger(4), "4")
	eq(Util.isInteger(4.5), false, "4.5")
	eq(Util.isInteger("4"), false, "string")
	eq(Util.isInteger(0 / 0), false, "nan")
end)

print("\nBlueprintCodec")

test("serialize is deterministic regardless of table order", function()
	local a = BlueprintCodec.serialize({
		[7] = { id = "wall", x = 5, z = 5, r = 0 },
		[2] = { id = "wall", x = 1, z = 1, r = 0 },
	})
	local b = BlueprintCodec.serialize({
		[1] = { id = "wall", x = 1, z = 1, r = 0 },
		[9] = { id = "wall", x = 5, z = 5, r = 0 },
	})
	eq(#a.items, 2, "item count")
	eq(a.items[1].x, b.items[1].x, "first item matches")
	eq(a.items[2].x, b.items[2].x, "second item matches")
end)

test("validate accepts a clean build and totals material cost", function()
	local ok, items, cost = BlueprintCodec.validate({
		v = 1,
		items = {
			{ id = "wall", x = 0, z = 0, r = 0 },
			{ id = "sofa", x = 4, z = 4, r = 0 },
		},
	})
	truthy(ok, "validate ok")
	eq(#items, 2, "items kept")
	eq(cost, Catalog.ById.wall.price + Catalog.ById.sofa.price, "material cost")
end)

test("validate rejects overlap, out-of-bounds and malformed data", function()
	local overlap = BlueprintCodec.validate({
		v = 1,
		items = { { id = "wall", x = 0, z = 0, r = 0 }, { id = "wall", x = 1, z = 0, r = 0 } },
	})
	eq(overlap, false, "overlapping walls rejected")

	local oob = BlueprintCodec.validate({ v = 1, items = { { id = "wall", x = 999, z = 0, r = 0 } } })
	eq(oob, false, "out-of-bounds rejected")

	eq(BlueprintCodec.validate({ v = 2, items = {} }), false, "wrong version rejected")
	eq(BlueprintCodec.validate("nope"), false, "non-table rejected")
	eq(BlueprintCodec.validate({ v = 1, items = { { id = "wall", x = 0.5, z = 0, r = 0 } } }), false, "float cell rejected")
	eq(BlueprintCodec.validate({ v = 1, items = { { id = "wall", x = 0, z = 0, r = 9 } } }), false, "bad rotation rejected")
end)

test("validate skips items missing from the catalog instead of failing", function()
	local ok, items = BlueprintCodec.validate({
		v = 1,
		items = { { id = "wall", x = 0, z = 0, r = 0 }, { id = "item_from_a_later_version", x = 8, z = 8, r = 0 } },
	})
	truthy(ok, "still valid")
	eq(#items, 1, "unknown item dropped")
end)

test("a floor tile and an object may share the same cells", function()
	local ok = BlueprintCodec.validate({
		v = 1,
		items = { { id = "floor_wood", x = 0, z = 0, r = 0 }, { id = "sofa", x = 0, z = 0, r = 0 } },
	})
	truthy(ok, "layers are independent")
end)

print("\nBuildService")

local alice, alicePlot = join("Alice")

test("placing charges the catalog price and occupies the cells", function()
	local before = DataService.GetMoney(alice)
	local result = place(alice, "sofa", 2, 2)
	truthy(result.ok, "place ok: " .. tostring(result.err))
	eq(DataService.GetMoney(alice), before - Catalog.ById.sofa.price, "money debited")
	eq(result.money, DataService.GetMoney(alice), "result reports balance")

	local count = 0
	for _ in pairs(alicePlot.items) do
		count += 1
	end
	eq(count, 1, "one item on the plot")
	eq(#alicePlot.itemsFolder:GetChildren(), 1, "one model in the plot folder")
end)

test("a second item cannot occupy the same cells", function()
	local blocked = place(alice, "sofa", 2, 2)
	eq(blocked.ok, false, "overlap refused")
	eq(blocked.err, "occupied", "error code")
end)

test("a floor item may sit under an existing object", function()
	local result = place(alice, "floor_wood", 2, 2)
	truthy(result.ok, "floor placed under sofa: " .. tostring(result.err))
end)

test("out-of-bounds and unknown items are refused", function()
	eq(place(alice, "sofa", Config.PlotSizeCells, 0).err, "out-of-bounds", "off-plot")
	eq(place(alice, "not_a_real_item", 0, 0).err, "bad-request", "unknown id")
	eq(place(alice, "sofa", 0.5, 0).err, "bad-request", "fractional cell")
	eq(place(alice, "sofa", 0, 0, 7).err, "bad-request", "bad rotation")
end)

test("placing without enough money is refused and costs nothing", function()
	local profile = DataService.Get(alice)
	profile.money = 10
	local result = place(alice, "sofa", 10, 10)
	eq(result.ok, false, "refused")
	eq(result.err, "no-money", "error code")
	eq(DataService.GetMoney(alice), 10, "balance untouched")
	profile.money = Config.StartingMoney
end)

test("deleting refunds the sell rate and frees the cells", function()
	local uid
	for id in pairs(alicePlot.items) do
		local rec = alicePlot.items[id]
		if rec.id == "sofa" then
			uid = id
		end
	end
	truthy(uid, "sofa found")
	local before = DataService.GetMoney(alice)
	unthrottle()
	local result = BuildService.RemoveItem(alice, uid)
	truthy(result.ok, "remove ok: " .. tostring(result.err))
	local expected = before + math.floor(Catalog.ById.sofa.price * Config.SellRefundRate)
	eq(DataService.GetMoney(alice), expected, "refund credited")

	-- cells are free again
	truthy(place(alice, "sofa", 2, 2).ok, "cells reusable")
end)

test("removing an unknown uid reports not-found", function()
	unthrottle()
	eq(BuildService.RemoveItem(alice, 999999).err, "not-found", "unknown uid")
	unthrottle()
	eq(BuildService.RemoveItem(alice, "abc").err, "bad-request", "non-integer uid")
end)

test("rate limiting rejects a burst on the same remote", function()
	unthrottle()
	truthy(place(alice, "plant", 20, 20).ok, "first call passes")
	local immediate = BuildService.PlaceItem(alice, "plant", 22, 20, 0) -- no clock advance
	eq(immediate.err, "slow-down", "burst refused")
end)

test("the saved profile mirrors the plot after every change", function()
	local profile = DataService.Get(alice)
	truthy(profile.build, "build recorded")
	local count = 0
	for _ in pairs(alicePlot.items) do
		count += 1
	end
	eq(#profile.build.items, count, "serialized item count matches the plot")
end)

print("\nMove and undo")

plotTest("moving an item is free and updates its cells", "Mover", function(mover, plot)
	unthrottle()
	local placed = place(mover, "sofa", 4, 4)
	truthy(placed.ok, "placed: " .. tostring(placed.err))
	local uid = next(plot.items)
	local before = DataService.GetMoney(mover)

	unthrottle()
	local moved = BuildService.MoveItem(mover, uid, 10, 10, 0)
	truthy(moved.ok, "moved: " .. tostring(moved.err))
	eq(DataService.GetMoney(mover), before, "moving costs nothing")
	eq(plot.items[uid].x, 10, "x updated")
	eq(plot.items[uid].z, 10, "z updated")

	-- the vacated cells accept a new item
	unthrottle()
	truthy(place(mover, "sofa", 4, 4).ok, "old cells freed")
	return mover
end)

plotTest("an item can slide by one cell or rotate in place", "Slider", function(slider, plot)
	unthrottle()
	truthy(place(slider, "sofa", 6, 6).ok, "placed")
	local uid = next(plot.items)

	-- overlapping its own footprint must not read as occupied
	unthrottle()
	truthy(BuildService.MoveItem(slider, uid, 7, 6, 0).ok, "slid one cell")
	unthrottle()
	truthy(BuildService.MoveItem(slider, uid, 7, 6, 1).ok, "rotated in place")
	eq(plot.items[uid].r, 1, "rotation stored")
end)

plotTest("a move onto occupied cells is refused and leaves the item put", "Blocker", function(blocker, plot)
	unthrottle()
	truthy(place(blocker, "sofa", 2, 2).ok, "first placed")
	unthrottle()
	truthy(place(blocker, "sofa", 8, 8).ok, "second placed")
	local firstUid
	for uid, rec in pairs(plot.items) do
		if rec.x == 2 then
			firstUid = uid
		end
	end
	unthrottle()
	local refused = BuildService.MoveItem(blocker, firstUid, 8, 8, 0)
	eq(refused.ok, false, "refused")
	eq(refused.err, "occupied", "error code")
	eq(plot.items[firstUid].x, 2, "item did not move")
	-- and the item still owns its original cells
	unthrottle()
	eq(place(blocker, "plant", 2, 2).err, "occupied", "original cells still held")
end)

plotTest("undo reverses a placement and refunds exactly what was paid", "Undoer", function(undoer, plot)
	local start = DataService.GetMoney(undoer)
	unthrottle()
	truthy(place(undoer, "sofa", 3, 3).ok, "placed")
	eq(DataService.GetMoney(undoer), start - Catalog.ById.sofa.price, "charged")

	unthrottle()
	local undone = BuildService.Undo(undoer)
	truthy(undone.ok, "undo ok: " .. tostring(undone.err))
	eq(DataService.GetMoney(undoer), start, "balance restored exactly")
	eq(next(plot.items), nil, "item removed")
	eq(#plot.itemsFolder:GetChildren(), 0, "model removed")
	return undoer
end)

plotTest("undoing a deletion takes the refund back", "Undoer2", function(undoer, plot)
	unthrottle()
	truthy(place(undoer, "sofa", 3, 3).ok, "placed")
	local afterPlace = DataService.GetMoney(undoer)
	local uid = next(plot.items)

	unthrottle()
	truthy(BuildService.RemoveItem(undoer, uid).ok, "removed")
	truthy(DataService.GetMoney(undoer) > afterPlace, "refund credited")

	unthrottle()
	truthy(BuildService.Undo(undoer).ok, "undo ok")
	eq(DataService.GetMoney(undoer), afterPlace, "refund taken back - undo cannot mint money")
	local count = 0
	for _ in pairs(plot.items) do
		count += 1
	end
	eq(count, 1, "item restored")
end)

plotTest("redo replays the undone step, and a new edit clears the redo branch", "Redoer", function(player, plot)
	unthrottle()
	truthy(place(player, "sofa", 5, 5).ok, "placed")
	local afterPlace = DataService.GetMoney(player)

	unthrottle()
	truthy(BuildService.Undo(player).ok, "undone")
	eq(next(plot.items), nil, "gone")

	unthrottle()
	truthy(BuildService.Redo(player).ok, "redone")
	eq(DataService.GetMoney(player), afterPlace, "balance replayed")
	local count = 0
	for _ in pairs(plot.items) do
		count += 1
	end
	eq(count, 1, "item back")

	unthrottle()
	truthy(BuildService.Undo(player).ok, "undone again")
	unthrottle()
	truthy(place(player, "plant", 12, 12).ok, "new edit")
	unthrottle()
	eq(BuildService.Redo(player).err, "nothing-to-redo", "redo branch discarded")
end)

plotTest("undo reports nothing to undo on an untouched plot", "Fresh", function(fresh)
	unthrottle()
	eq(BuildService.Undo(fresh).err, "nothing-to-undo", "empty history")
end)

plotTest("history is capped and dropped when the player leaves", "Historian", function(player)
	for i = 1, Config.UndoDepth + 5 do
		unthrottle()
		place(player, "plant", (i * 2) % 30, math.floor(i / 15))
	end
	local undos = 0
	while true do
		unthrottle()
		if not BuildService.Undo(player).ok then
			break
		end
		undos += 1
		if undos > Config.UndoDepth + 10 then
			error("undo never ran out - history is not capped")
		end
	end
	truthy(undos <= Config.UndoDepth, ("kept %d steps, cap is %d"):format(undos, Config.UndoDepth))

	BuildService.ForgetPlayer(player)
	unthrottle()
	eq(BuildService.Undo(player).err, "nothing-to-undo", "history cleared on leave")
end)

print("\nEconomy")

test("the daily bonus pays once per cooldown window", function()
	local bob = MOCK.newPlayer("Bob")
	DataService.Load(bob)
	local before = DataService.GetMoney(bob)
	EconomyService.OnJoin(bob)
	eq(DataService.GetMoney(bob), before + Config.DailyBonus, "bonus paid")
	EconomyService.OnJoin(bob)
	eq(DataService.GetMoney(bob), before + Config.DailyBonus, "not paid twice")
	MOCK.advance(Config.DailyBonusCooldown + 1)
	EconomyService.OnJoin(bob)
	eq(DataService.GetMoney(bob), before + Config.DailyBonus * 2, "paid again after cooldown")
	MOCK.removePlayer(bob)
end)

test("TryDebit refuses to overdraw", function()
	local profile = DataService.Get(alice)
	profile.money = 100
	eq(DataService.TryDebit(alice, 101), false, "overdraw refused")
	eq(DataService.GetMoney(alice), 100, "balance untouched")
	truthy(DataService.TryDebit(alice, 100), "exact balance allowed")
	eq(DataService.GetMoney(alice), 0, "spent to zero")
	profile.money = 500000
end)

print("\nBlueprint market")

-- Alice needs a publishable house: at least Config.Blueprint.MinItemsToPublish.
local function fillPlot(player, plot)
	local placed = 0
	local x, z = 0, 0
	while placed < Config.Blueprint.MinItemsToPublish + 2 do
		local result = place(player, "wall", x, z)
		if result.ok then
			placed += 1
		end
		x += 2
		if x + 2 > Config.PlotSizeCells then
			x = 0
			z += 1
		end
		if z >= Config.PlotSizeCells then
			break
		end
	end
	return placed
end

local publishedId: string
local publishedMeta: any

test("publishing refuses a house below the item floor", function()
	local carol = MOCK.newPlayer("Carol")
	DataService.Load(carol)
	PlotService.Assign(carol)
	unthrottle()
	place(carol, "wall", 0, 0)
	unthrottle()
	local result = Market.Publish(carol, "Tiny", 1000)
	eq(result.ok, false, "refused")
	eq(result.err, "too-few-items", "error code")
	PlotService.Release(carol)
	MOCK.removePlayer(carol)
end)

test("publishing a filled plot creates a listing with a royalty-bearing price", function()
	truthy(fillPlot(alice, alicePlot) >= Config.Blueprint.MinItemsToPublish, "plot filled")
	unthrottle()
	local result = Market.Publish(alice, "Cozy Modern Villa", 20000)
	truthy(result.ok, "publish ok: " .. tostring(result.err))
	publishedMeta = result.meta
	publishedId = result.meta.id
	eq(result.meta.name, "Cozy Modern Villa", "name kept")
	eq(result.meta.price, 20000, "price kept")
	eq(result.meta.creatorId, alice.UserId, "creator recorded")
	eq(result.meta.sales, 0, "starts with no sales")
	truthy(result.meta.materialCost > 0, "material cost computed")
	truthy(result.meta.itemCount >= Config.Blueprint.MinItemsToPublish, "item count recorded")
end)

test("publishing rejects prices outside the allowed band and blank names", function()
	unthrottle()
	eq(Market.Publish(alice, "Cheap", Config.Blueprint.MinPrice - 1).err, "bad-price", "under floor")
	unthrottle()
	eq(Market.Publish(alice, "Rich", Config.Blueprint.MaxPrice + 1).err, "bad-price", "over ceiling")
	unthrottle()
	eq(Market.Publish(alice, "x", 1000).err, "name-too-short", "one-character name")
end)

test("a free account gets one publish slot; Pro Builder gets five", function()
	unthrottle()
	eq(Market.Publish(alice, "Second House", 5000).err, "no-slots", "second listing refused")

	Config.GamePasses.ProBuilder = 555
	MOCK.gamePasses[alice.UserId] = { [555] = true }
	unthrottle()
	local result = Market.Publish(alice, "Pro House", 5000)
	truthy(result.ok, "Pro Builder slot granted: " .. tostring(result.err))
	truthy(result.meta.pro, "listing flagged PRO")
	MOCK.gamePasses[alice.UserId] = nil
	Config.GamePasses.ProBuilder = 0
end)

test("the market lists newest and top tabs and flags ownership", function()
	unthrottle()
	local newest = Market.GetMarket(alice, "new")
	truthy(newest.ok, "new tab ok: " .. tostring(newest.err))
	truthy(#newest.listings >= 1, "at least one listing")

	unthrottle()
	local top = Market.GetMarket(alice, "top")
	truthy(top.ok, "top tab ok: " .. tostring(top.err))

	local mine = false
	for _, listing in ipairs(newest.listings) do
		if listing.id == publishedId then
			mine = listing.mine
		end
	end
	truthy(mine, "own listing flagged")
end)

test("buying pays the creator the royalty share and sinks the rest", function()
	local dave = MOCK.newPlayer("Dave")
	DataService.Load(dave)
	PlotService.Assign(dave)

	local aliceBefore = DataService.GetMoney(alice)
	local daveBefore = DataService.GetMoney(dave)
	unthrottle()
	local result = Market.Buy(dave, publishedId)
	truthy(result.ok, "buy ok: " .. tostring(result.err))

	local royalty = math.floor(publishedMeta.price * Config.Blueprint.RoyaltyRate)
	eq(DataService.GetMoney(dave), daveBefore - publishedMeta.price, "buyer charged the design fee")
	eq(DataService.GetMoney(alice), aliceBefore + royalty, "creator paid the royalty")
	truthy(royalty < publishedMeta.price, "the remainder is a currency sink")
	truthy(DataService.Get(dave).ownedBlueprints[publishedId], "buyer owns it")
	return dave
end)

local function findPlayer(name: string)
	for _, p in ipairs(MOCK.players.GetPlayers()) do
		if p.Name == name then
			return p
		end
	end
	return nil
end

test("a blueprint cannot be bought twice, or by its own creator", function()
	local buyer = findPlayer("Dave")
	truthy(buyer, "Dave present")
	unthrottle()
	eq(Market.Buy(buyer, publishedId).err, "already-owned", "second purchase refused")
	unthrottle()
	eq(Market.Buy(alice, publishedId).err, "own-blueprint", "creator refused")
	unthrottle()
	eq(Market.Buy(buyer, "does-not-exist").err, "not-found", "missing listing refused")
end)

test("applying a blueprint charges materials, clears the old build and rebuilds", function()
	local buyer = findPlayer("Dave")
	local plot = PlotService.Get(buyer)
	unthrottle()
	place(buyer, "plant", 30, 30) -- something to be cleared and refunded
	local itemsBefore = 0
	for _ in pairs(plot.items) do
		itemsBefore += 1
	end
	eq(itemsBefore, 1, "one item before applying")

	DataService.Get(buyer).money = 10000000
	unthrottle()
	local result = Market.Apply(buyer, publishedId)
	truthy(result.ok, "apply ok: " .. tostring(result.err))
	eq(result.materialCost, publishedMeta.materialCost, "material cost reported")

	local itemsAfter = 0
	for _ in pairs(plot.items) do
		itemsAfter += 1
	end
	eq(itemsAfter, publishedMeta.itemCount, "plot now holds the blueprint's items")
	eq(#plot.itemsFolder:GetChildren(), publishedMeta.itemCount, "models match state")
end)

test("applying is refused without ownership or funds", function()
	local eve = MOCK.newPlayer("Eve")
	DataService.Load(eve)
	PlotService.Assign(eve)
	unthrottle()
	eq(Market.Apply(eve, publishedId).err, "not-owned", "unowned blueprint refused")

	DataService.Get(eve).ownedBlueprints[publishedId] = true
	DataService.Get(eve).money = 1
	unthrottle()
	local broke = Market.Apply(eve, publishedId)
	eq(broke.ok, false, "refused when broke")
	eq(broke.err, "no-money", "error code")
	eq(broke.materialCost, publishedMeta.materialCost, "quote returned so the UI can explain")
	PlotService.Release(eve)
	MOCK.removePlayer(eve)
end)

test("a sale to an offline creator lands in the earnings inbox and pays on return", function()
	-- Frank publishes, leaves, then Grace buys: the royalty must survive.
	local frank = MOCK.newPlayer("Frank")
	DataService.Load(frank)
	local frankPlot = PlotService.Assign(frank)
	fillPlot(frank, frankPlot)
	unthrottle()
	local published = Market.Publish(frank, "Frank Manor", 10000)
	truthy(published.ok, "frank published: " .. tostring(published.err))
	local frankId = published.meta.id
	local frankUserId = frank.UserId

	DataService.Remove(frank)
	PlotService.Release(frank)
	MOCK.removePlayer(frank)

	local grace = MOCK.newPlayer("Grace")
	DataService.Load(grace)
	PlotService.Assign(grace)
	DataService.Get(grace).money = 100000
	unthrottle()
	truthy(Market.Buy(grace, frankId).ok, "grace bought")

	-- Frank comes back on another server: Load claims the inbox.
	local frankAgain = MOCK.newPlayer("Frank")
	frankAgain.UserId = frankUserId
	local profile = DataService.Load(frankAgain)
	local royalty = math.floor(10000 * Config.Blueprint.RoyaltyRate)
	eq(profile.totalRoyalties, royalty, "royalty credited on return")
	truthy(DataService.GetMoney(frankAgain) >= royalty, "balance includes the royalty")

	-- and the inbox is emptied, so it is not paid twice
	local reload = DataService.Load(frankAgain)
	eq(reload.totalRoyalties, royalty, "inbox not double-claimed")
end)

test("sales counters advance so the Top Sellers chart can rank", function()
	MOCK.drain() -- the counter bump runs in a deferred task
	unthrottle()
	local top = Market.GetMarket(alice, "top")
	truthy(top.ok, "top tab ok: " .. tostring(top.err))
	local sold = 0
	for _, listing in ipairs(top.listings) do
		sold += listing.sales or 0
	end
	truthy(sold >= 2, "at least the two purchases counted, saw " .. sold)
end)

test("GetMine separates published listings from purchased ones", function()
	unthrottle()
	local mine = Market.GetMine(alice)
	truthy(mine.ok, "GetMine ok: " .. tostring(mine.err))
	truthy(#mine.published >= 1, "published listings returned")
	for _, meta in ipairs(mine.owned) do
		truthy(meta.creatorId ~= alice.UserId, "owned list excludes own designs")
	end
	truthy(mine.totalRoyalties > 0, "royalty total surfaced")
end)

print("\nPlotService")

test("plots are handed out once and recycled on leave", function()
	local taken = {}
	local players = {}
	for i = 1, Config.PlotsPerServer + 1 do
		local p = MOCK.newPlayer("Filler" .. i)
		DataService.Load(p)
		local plot = PlotService.Assign(p)
		if plot then
			eq(taken[plot.index], nil, "plot " .. plot.index .. " handed out twice")
			taken[plot.index] = true
			table.insert(players, p)
		end
	end
	truthy(#players >= 1, "some plots were free")

	local victim = players[1]
	local plot = PlotService.Get(victim)
	PlotService.Release(victim)
	eq(PlotService.Get(victim), nil, "plot released")
	eq(plot.ownerUserId, nil, "ownership cleared")
	eq(#plot.itemsFolder:GetChildren(), 0, "models cleared")
	eq(next(plot.items), nil, "state cleared")

	local newcomer = MOCK.newPlayer("Newcomer")
	DataService.Load(newcomer)
	eq(PlotService.Assign(newcomer), plot, "released plot reused")
	for _, p in ipairs(players) do
		MOCK.removePlayer(p)
	end
end)

-- // report --------------------------------------------------------------

print("")
if FAIL > 0 then
	print(("%d passed, %d FAILED"):format(PASS, FAIL))
	for _, message in ipairs(failures) do
		print("  - " .. message)
	end
	error("suite failed", 0)
end
print(("%d passed, 0 failed"):format(PASS))
