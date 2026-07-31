--!strict
-- Serialize / validate builds. The same format is used for plot persistence
-- and for market blueprints: { v = 1, items = { {id, x, z, r}, ... } }.
-- validate() is strict because blueprint data can come from DataStores written
-- by other servers/versions — never trust it blindly.

local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local GridUtil = require(script.Parent.GridUtil)
local Util = require(script.Parent.Util)

local BlueprintCodec = {}

export type ItemRecord = { id: string, x: number, z: number, r: number }
export type BuildData = { v: number, items: { ItemRecord } }

-- plotItems: map uid -> {id, x, z, r, ...} (server-side plot state)
function BlueprintCodec.serialize(plotItems: { [number]: any }): BuildData
	local items = {}
	for _, rec in pairs(plotItems) do
		table.insert(items, { id = rec.id, x = rec.x, z = rec.z, r = rec.r })
	end
	-- deterministic order keeps saves/diffs stable
	table.sort(items, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		return a.id < b.id
	end)
	return { v = 1, items = items }
end

-- Returns (ok, itemsOrError, materialCost).
-- On success items are clean copies containing only known fields.
function BlueprintCodec.validate(data: any): (boolean, any, number)
	if type(data) ~= "table" or data.v ~= 1 or type(data.items) ~= "table" then
		return false, "bad-format", 0
	end
	if #data.items > Config.Blueprint.MaxItems then
		return false, "too-many-items", 0
	end

	local occupancy: { [string]: { [string]: boolean } } = { floor = {}, object = {} }
	local clean: { ItemRecord } = {}
	local materialCost = 0

	for _, rec in ipairs(data.items) do
		if type(rec) ~= "table" or type(rec.id) ~= "string" then
			return false, "bad-item", 0
		end
		local def = Catalog.ById[rec.id]
		if not def then
			-- item removed from catalog in a later version: skip, don't reject
			continue
		end
		if not (Util.isInteger(rec.x) and Util.isInteger(rec.z) and Util.isInteger(rec.r)) then
			return false, "bad-item", 0
		end
		if rec.r < 0 or rec.r > 3 then
			return false, "bad-item", 0
		end
		if not GridUtil.inBounds(rec.x, rec.z, def.w, def.d, rec.r) then
			return false, "out-of-bounds", 0
		end
		local layerMap = occupancy[def.layer]
		local keys = GridUtil.cellKeys(rec.x, rec.z, def.w, def.d, rec.r)
		for _, key in ipairs(keys) do
			if layerMap[key] then
				return false, "overlap", 0
			end
		end
		for _, key in ipairs(keys) do
			layerMap[key] = true
		end
		materialCost += def.price
		table.insert(clean, { id = rec.id, x = rec.x, z = rec.z, r = rec.r })
	end

	return true, clean, materialCost
end

function BlueprintCodec.materialCost(items: { ItemRecord }): number
	local total = 0
	for _, rec in ipairs(items) do
		local def = Catalog.ById[rec.id]
		if def then
			total += def.price
		end
	end
	return total
end

return BlueprintCodec
