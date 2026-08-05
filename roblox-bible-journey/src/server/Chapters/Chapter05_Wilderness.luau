--!strict
-- Chapter 5 — 광야의 시험 (마태복음 4).
--
-- The verse-card system's debut (DESIGN.md 3-2). The desert strip is split into
-- three sections by rock gates. Each section hides one verse in fragments; at
-- its far end a dark voice makes its offer, and the only way through the gate is
-- to answer with the right verse — the one the player just picked up off the
-- ground. Collect, then use, a few steps apart: retrieval practice wearing a
-- boss fight's clothes.
--
-- The tempter is a voice and a dark shimmer, never a figure (same rule that
-- keeps Jesus unmodeled, DESIGN.md 1-1 — no face on either side of this story).
-- Wrong answers cost another look at the cards, nothing else, and after three
-- misses the beam just points at the right card. TrialLogic owns those rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Verses = require(ReplicatedStorage.Shared.Verses)
local Build = require(script.Parent.Parent.greybox.Build)
local TrialLogic = require(script.Parent.Parent.greybox.TrialLogic)

local Chapter = {
	id = "ch05_wilderness",
	reference = "마태복음 4:1-11",
	fragments = Verses.fragmentIdsFor("ch05_wilderness"),
	requires = { "ch01_bethlehem" },
	minPlayers = 1,
	estimatedMinutes = 12,
	objectives = { "trial_bread", "trial_leap", "trial_worship" },
}

local TRIALS: { TrialLogic.Trial } = {
	{ id = "trial_bread", answer = "ch05_bread" },
	{ id = "trial_leap", answer = "ch05_test" },
	{ id = "trial_worship", answer = "ch05_worship" },
}

-- Which verse the fragments of each section teach = the answer to that
-- section's trial. The pickup happens a few steps before the question.
local SECTION_VERSE = { "ch05_bread", "ch05_test", "ch05_worship" }

-- Card order per station, hand-placed so the correct card sits middle, left,
-- right across the three trials — position must never become the answer key.
local STATION_CARDS = {
	{ "ch05_test", "ch05_bread", "ch05_worship" },
	{ "ch05_test", "ch05_worship", "ch05_bread" },
	{ "ch05_bread", "ch05_test", "ch05_worship" },
}

local SECTION_LENGTH = 62
local STRIP_TOP_Y = 2

local function sectionStartZ(index: number): number
	return -(index - 1) * SECTION_LENGTH
end

local function stationAnchor(base: Vector3, index: number): Vector3
	return base + Vector3.new(0, STRIP_TOP_Y, sectionStartZ(index) - SECTION_LENGTH + 10)
end

function Chapter.start(session: Types.Session)
	local base = session.origin.Position
	local logic = TrialLogic.new(TRIALS)

	local strip = Build.part({
		Name = "DesertPath",
		Size = Vector3.new(60, 2, 3 * SECTION_LENGTH + 40),
		CFrame = CFrame.new(base + Vector3.new(0, 1, -(3 * SECTION_LENGTH) / 2)),
		Color = Color3.fromRGB(188, 158, 112),
		Material = Enum.Material.Sandstone,
	})
	session:track(strip)

	-- Rock gates after sections 1 and 2. They crumble on a right answer; until
	-- then the desert simply has no way forward.
	local gates: { [number]: Part } = {}
	for index = 1, 2 do
		local gate = Build.part({
			Name = `RockGate{index}`,
			Size = Vector3.new(60, 16, 4),
			CFrame = CFrame.new(base + Vector3.new(0, 9, sectionStartZ(index) - SECTION_LENGTH)),
			Color = Color3.fromRGB(124, 106, 84),
			Material = Enum.Material.Rock,
		})
		session:track(gate)
		gates[index] = gate
	end

	-- Verse fragments: three per section, always before that section's trial.
	local fragmentOffsets = { Vector3.new(-18, 4, -14), Vector3.new(14, 4, -26), Vector3.new(-6, 4, -38) }
	for sectionIndex, verseId in SECTION_VERSE do
		local verse = Verses.get(verseId)
		assert(verse, `no verse "{verseId}"`)

		for fragmentIndex, fragment in verse.fragments do
			local offset = fragmentOffsets[fragmentIndex] or Vector3.new(0, 4, -20)
			local orb = Build.glow({
				Name = fragment.id,
				Size = Vector3.new(2.5, 2.5, 2.5),
				Shape = Enum.PartType.Ball,
				CFrame = CFrame.new(base + Vector3.new(offset.X, offset.Y, sectionStartZ(sectionIndex) + offset.Z)),
				Color = Color3.fromRGB(168, 214, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, 2, 24)
			session:track(orb)

			session:bind(orb.Touched, function(hit: BasePart)
				local player = Build.playerFromHit(hit)
				if player then
					session:grantFragment(player, fragment.id)
				end
			end)
		end
	end

	local spawnStation: (index: number) -> ()

	function spawnStation(index: number)
		local trial = TRIALS[index]
		local anchor = stationAnchor(base, index)

		-- The dark voice: a shimmer, not a figure.
		local shadow = Build.glow({
			Name = `Shadow{index}`,
			Size = Vector3.new(4, 4, 4),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(anchor + Vector3.new(0, 6, -6)),
			Color = Color3.fromRGB(72, 52, 96),
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = false,
		}, 0.6, 20)
		session:track(shadow)

		local cardPositions = {
			anchor + Vector3.new(-9, 4, 6),
			anchor + Vector3.new(0, 4, 8),
			anchor + Vector3.new(9, 4, 6),
		}
		local cards: { Part } = {}
		local correctPosition = anchor

		for slot, verseId in STATION_CARDS[index] do
			local card = Build.glow({
				Name = `VerseCard_{trial.id}_{slot}`,
				Size = Vector3.new(5.5, 7, 0.8),
				CFrame = CFrame.new(cardPositions[slot]),
				Color = Color3.fromRGB(236, 222, 184),
				Material = Enum.Material.Neon,
				Transparency = 0.1,
			}, 0.8, 12)
			card:SetAttribute("VerseCardId", verseId)
			session:track(card)
			table.insert(cards, card)

			if verseId == trial.answer then
				correctPosition = cardPositions[slot]
			end

			local claim = Build.debouncePerPlayer(1)
			session:bind(card.Touched, function(hit: BasePart)
				local player = Build.playerFromHit(hit)
				if not player or not claim(player) then
					return
				end

				local result = logic:answer(trial.id, verseId)
				if result == "correct" then
					shadow:Destroy()
					for _, spent in cards do
						spent:Destroy()
					end
					session:say("ch05.correct")
					session:point(nil)

					local gate = gates[index]
					if gate then
						gate:Destroy()
					end
					if index < #TRIALS then
						spawnStation(index + 1)
					end
					session:setObjective(trial.id, true)
				elseif result == "wrong" then
					-- Escalating help, never a penalty: nudge, then hint, then just
					-- point at the answer. A stuck kid is a leaving kid.
					local attempts = logic:attempts(trial.id)
					if attempts == 1 then
						session:sayTo(player, "ch05.wrong")
					elseif attempts == 2 then
						session:sayTo(player, "ch05.hint")
					end
					if logic:shouldReveal(trial.id) then
						session:say("ch05.reveal")
						session:point(correctPosition + Vector3.new(0, 4, 0))
					end
				end
			end)
		end

		-- The temptation speaks when the player first steps into the station.
		local approach = Build.part({
			Name = `TrialZone{index}`,
			Size = Vector3.new(60, 10, 8),
			CFrame = CFrame.new(anchor + Vector3.new(0, 5, 16)),
			Transparency = 1,
			CanCollide = false,
			CastShadow = false,
		})
		session:track(approach)

		local announced = false
		session:bind(approach.Touched, function(hit: BasePart)
			if announced or not Build.playerFromHit(hit) then
				return
			end
			announced = true
			session:say(`ch05.{trial.id}`)
			task.delay(3, function()
				if logic:current() == trial.id then
					session:say("ch05.chooseCard")
				end
			end)
		end)
	end

	spawnStation(1)

	session:say("ch05.walkPath")
	session:point(stationAnchor(base, 1) + Vector3.new(0, 4, 0))
end

-- Everything went through session:track / session:bind; TrialLogic dies with
-- the start closure.
function Chapter.cleanup(_session: Types.Session) end

return Chapter :: Types.Chapter
