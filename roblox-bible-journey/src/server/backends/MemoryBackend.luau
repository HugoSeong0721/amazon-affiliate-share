--!strict
-- In-memory progress. Survives rejoining the same server, dies with it.
-- This is the Studio / test backend. It is NOT a fallback you ship: a kid who
-- loses their journey does not come back, so shipping without ProfileStore
-- would quietly undo the whole retention design.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local ProgressLogic = require(script.Parent.Parent.ProgressLogic)

local store: { [number]: Types.ProgressData } = {}

local MemoryBackend = {
	name = "memory",
}

function MemoryBackend.load(player: Player): Types.ProgressData?
	local existing = store[player.UserId]
	if existing then
		return existing
	end

	local fresh = ProgressLogic.template()
	store[player.UserId] = fresh
	return fresh
end

function MemoryBackend.flush(_player: Player) end

function MemoryBackend.release(_player: Player) end

-- Test hook only.
function MemoryBackend.wipe()
	table.clear(store)
end

return MemoryBackend
