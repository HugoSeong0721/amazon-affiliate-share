--!strict
-- The wilderness trial rules (DESIGN.md 3-2) — the retrieval-practice engine the
-- whole learning design leans on, kept pure like FeedingLogic so it is provable
-- without a map.
--
-- The rules ARE the pedagogy:
--   * A trial is answered by choosing a verse, and the only way out is through —
--     there is no damage, no timer, no fail state. Getting it wrong costs one
--     more look at the cards, never progress.
--   * Trials come in order. The story's order (bread → leap → worship) is the
--     spacing of the retrieval practice.
--   * After REVEAL_AFTER wrong tries the game gives the answer away (the beam
--     points at the right card). A stuck eight-year-old stops being taught and
--     starts being punished; the mercy rule is the difference.

local TrialLogic = {}
TrialLogic.__index = TrialLogic

TrialLogic.REVEAL_AFTER = 3

export type Trial = {
	id: string,
	answer: string, -- verse id that turns this temptation away
}

type Fields = {
	_trials: { Trial },
	_current: number,
	_attempts: { [string]: number },
}

export type TrialLogic = typeof(setmetatable({} :: Fields, TrialLogic))

export type Result = "correct" | "wrong" | "already_solved" | "not_current" | "unknown_trial"

function TrialLogic.new(trials: { Trial }): TrialLogic
	assert(#trials > 0, "at least one trial")

	local seen: { [string]: boolean } = {}
	local attempts: { [string]: number } = {}
	for _, trial in trials do
		assert(not seen[trial.id], `duplicate trial id "{trial.id}"`)
		seen[trial.id] = true
		attempts[trial.id] = 0
	end

	return setmetatable({
		_trials = table.clone(trials),
		_current = 1,
		_attempts = attempts,
	}, TrialLogic)
end

local function indexOf(self: TrialLogic, trialId: string): number?
	for index, trial in self._trials do
		if trial.id == trialId then
			return index
		end
	end
	return nil
end

-- The trial the player is facing now, nil once all are done.
function TrialLogic.current(self: TrialLogic): string?
	local trial = self._trials[self._current]
	return if trial then trial.id else nil
end

function TrialLogic.answer(self: TrialLogic, trialId: string, verseId: string): Result
	local index = indexOf(self, trialId)
	if not index then
		return "unknown_trial"
	end
	if index < self._current then
		return "already_solved"
	end
	if index > self._current then
		return "not_current"
	end

	if self._trials[index].answer == verseId then
		self._current += 1
		return "correct"
	end

	self._attempts[trialId] += 1
	return "wrong"
end

-- Wrong tries on this trial. Solved trials keep their count — it is playtest
-- data (which temptation confuses kids), not a score shown to anyone.
function TrialLogic.attempts(self: TrialLogic, trialId: string): number
	return self._attempts[trialId] or 0
end

-- True when the current trial has frustrated the player long enough that the
-- game should just point at the right card.
function TrialLogic.shouldReveal(self: TrialLogic, trialId: string): boolean
	return self:current() == trialId and self:attempts(trialId) >= TrialLogic.REVEAL_AFTER
end

function TrialLogic.answerFor(self: TrialLogic, trialId: string): string?
	local index = indexOf(self, trialId)
	return if index then self._trials[index].answer else nil
end

function TrialLogic.isComplete(self: TrialLogic): boolean
	return self._current > #self._trials
end

return TrialLogic
