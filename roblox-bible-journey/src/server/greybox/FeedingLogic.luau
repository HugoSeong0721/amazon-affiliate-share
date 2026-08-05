--!strict
-- The feeding-of-the-5000 rules (DESIGN.md, chapter 10), kept pure so the one
-- mechanic that carries the chapter's meaning is provable without a map.
--
-- The rules ARE the story:
--   * The basket starts empty. Nothing moves until someone gives up their lunch.
--   * A lunch, once given, is gone — contributing is not a purchase, and there is
--     no way to take it back.
--   * After that, the basket never runs dry. The miracle is not that giving is
--     repaid; it is that one small gift becomes enough for everyone.
--   * Every extra person who shares raises how much everyone can carry per trip.
--     Solo works; sharing together is visibly better. That gap — not a locked
--     door — is the co-op pull.
--
-- Player keys are opaque (UserId, name, anything stable) so tests need no
-- Player instances.

local FeedingLogic = {}
FeedingLogic.__index = FeedingLogic

-- John 6:13. The count is the point, so it is a constant, not a parameter.
FeedingLogic.LEFTOVER_BASKETS = 12

type Key = any

type Fields = {
	_needs: { number },
	_contributed: { [Key]: boolean },
	_contributors: number,
	_carrying: { [Key]: number },
	_carryPerContributor: number,
}

export type FeedingLogic = typeof(setmetatable({} :: Fields, FeedingLogic))

function FeedingLogic.new(groupNeeds: { number }, carryPerContributor: number): FeedingLogic
	assert(#groupNeeds > 0, "at least one crowd group")
	assert(carryPerContributor > 0, "carry amount must be positive")

	return setmetatable({
		_needs = table.clone(groupNeeds),
		_contributed = {},
		_contributors = 0,
		_carrying = {},
		_carryPerContributor = carryPerContributor,
	}, FeedingLogic)
end

-- True only the first time: a lunch can be given once and never taken back.
function FeedingLogic.contribute(self: FeedingLogic, key: Key): boolean
	if self._contributed[key] then
		return false
	end
	self._contributed[key] = true
	self._contributors += 1
	return true
end

function FeedingLogic.hasContributed(self: FeedingLogic, key: Key): boolean
	return self._contributed[key] == true
end

function FeedingLogic.contributorCount(self: FeedingLogic): number
	return self._contributors
end

function FeedingLogic.carryCapacity(self: FeedingLogic): number
	return self._carryPerContributor * self._contributors
end

function FeedingLogic.carryingOf(self: FeedingLogic, key: Key): number
	return self._carrying[key] or 0
end

-- Loads the player up from the basket. Returns how much they now carry:
-- 0 means "not yet" — either nobody has shared, or their hands are still full.
function FeedingLogic.pickUp(self: FeedingLogic, key: Key): number
	if self._contributors == 0 then
		return 0
	end
	if (self._carrying[key] or 0) > 0 then
		return 0
	end

	local amount = self:carryCapacity()
	self._carrying[key] = amount
	return amount
end

-- Hands food to one group. Returns how many servings landed (0 if the carrier
-- is empty-handed, the group is already full, or the index is bad).
function FeedingLogic.deliver(self: FeedingLogic, key: Key, groupIndex: number): number
	local carrying = self._carrying[key] or 0
	local need = self._needs[groupIndex]
	if carrying <= 0 or need == nil or need <= 0 then
		return 0
	end

	local fed = math.min(carrying, need)
	self._needs[groupIndex] = need - fed
	self._carrying[key] = carrying - fed
	return fed
end

function FeedingLogic.groupNeed(self: FeedingLogic, groupIndex: number): number
	return self._needs[groupIndex] or 0
end

function FeedingLogic.remainingTotal(self: FeedingLogic): number
	local total = 0
	for _, need in self._needs do
		total += need
	end
	return total
end

function FeedingLogic.isEveryoneFed(self: FeedingLogic): boolean
	return self:remainingTotal() == 0
end

return FeedingLogic
