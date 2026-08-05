--!strict
-- Pure progress rules. No Players, no DataStores, no Instances — so this is the
-- part that gets unit tested (see tests/ProgressLogic.spec.luau). Persistence
-- and replication live in ProgressService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local FRAGMENTS_PER_LAMP = 3
local CURRENT_SCHEMA = 1

local ProgressLogic = {}

ProgressLogic.FRAGMENTS_PER_LAMP = FRAGMENTS_PER_LAMP
ProgressLogic.CURRENT_SCHEMA = CURRENT_SCHEMA

function ProgressLogic.template(): Types.ProgressData
	return {
		schema = CURRENT_SCHEMA,
		completedChapters = {},
		fragments = {},
		guideCount = 0,
		lastSeedAt = 0,
		locale = "ko",
	}
end

-- The seam that lets chapter structure change later without wiping kids'
-- progress. Add a branch per schema bump; never delete an old branch.
function ProgressLogic.migrate(data: Types.ProgressData): Types.ProgressData
	local template: any = ProgressLogic.template()
	local target: any = data
	for key, value in pairs(template) do
		if target[key] == nil then
			target[key] = value
		end
	end
	data.schema = CURRENT_SCHEMA
	return data
end

function ProgressLogic.countFragments(data: Types.ProgressData): number
	local count = 0
	for _, owned in data.fragments do
		if owned then
			count += 1
		end
	end
	return count
end

function ProgressLogic.lampLevel(data: Types.ProgressData): number
	return math.floor(ProgressLogic.countFragments(data) / FRAGMENTS_PER_LAMP)
end

function ProgressLogic.hasFragment(data: Types.ProgressData, fragmentId: string): boolean
	return data.fragments[fragmentId] == true
end

-- Returns true only the first time, so callers can tell "found!" from "already had it".
function ProgressLogic.grantFragment(data: Types.ProgressData, fragmentId: string): boolean
	if data.fragments[fragmentId] then
		return false
	end
	data.fragments[fragmentId] = true
	return true
end

function ProgressLogic.isChapterComplete(data: Types.ProgressData, chapterId: string): boolean
	return data.completedChapters[chapterId] ~= nil
end

-- Timestamp is passed in rather than read from os.time() so tests stay deterministic.
function ProgressLogic.markChapterComplete(data: Types.ProgressData, chapterId: string, at: number): boolean
	if data.completedChapters[chapterId] then
		return false
	end
	data.completedChapters[chapterId] = at
	return true
end

function ProgressLogic.completedCount(data: Types.ProgressData): number
	local count = 0
	for _ in data.completedChapters do
		count += 1
	end
	return count
end

-- What the client needs to draw the road and the lamp. Deliberately small: the
-- client never receives anything it could rewrite into an advantage.
function ProgressLogic.snapshot(data: Types.ProgressData, order: { string }): { [string]: any }
	return {
		order = order,
		completedChapters = table.clone(data.completedChapters),
		fragments = table.clone(data.fragments),
		lampLevel = ProgressLogic.lampLevel(data),
		guideCount = data.guideCount,
		locale = data.locale,
	}
end

return ProgressLogic
