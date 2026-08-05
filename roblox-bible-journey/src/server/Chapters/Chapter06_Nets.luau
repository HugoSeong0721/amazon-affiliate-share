--!strict
-- Chapter 6 — 그물을 던져라 (누가복음 5).
--
-- The obedience archetype. The first cast MUST fail — the empty net is an
-- objective, not a punishment, because the failure is the story: they had fished
-- all night and caught nothing, and the full net only comes after doing what the
-- voice says. The deep pier does not even exist until the empty cast has
-- happened; the world itself enforces the story's order.
--
-- Per DESIGN.md 1-1 the voice belongs to a warm light on the shore, never to a
-- character model. It appears when it speaks and it stays behind the player —
-- followed, not examined.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Verses = require(ReplicatedStorage.Shared.Verses)
local Build = require(script.Parent.Parent.greybox.Build)

local Chapter = {
	id = "ch06_nets",
	reference = "누가복음 5:5",
	fragments = Verses.fragmentIdsFor("ch06_nets"),
	requires = { "ch05_wilderness" },
	minPlayers = 1,
	estimatedMinutes = 8,
	objectives = { "empty_net", "cast_deep" },
}

-- Shore sits at positive Z; the pier runs out over the water toward -Z.
local PIER_TOP_Y = 4
local SHALLOW_END_Z = -48
local DEEP_END_Z = -108

local function castSpot(base: Vector3, z: number): Part
	return Build.glow({
		Name = "CastSpot",
		Size = Vector3.new(5, 1.2, 5),
		CFrame = CFrame.new(base + Vector3.new(0, PIER_TOP_Y + 0.6, z)),
		Color = Color3.fromRGB(190, 226, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	}, 1.5, 18)
end

function Chapter.start(session: Types.Session)
	local base = session.origin.Position
	local claim = Build.debouncePerPlayer(0.8)

	local shore = Build.part({
		Name = "Shore",
		Size = Vector3.new(90, 2, 44),
		CFrame = CFrame.new(base + Vector3.new(0, 2, 24)),
		Color = Color3.fromRGB(198, 178, 138),
		Material = Enum.Material.Sand,
	})
	session:track(shore)

	-- Solid, and 3 studs under the pier: falling off costs a short wade back to
	-- shore, never a respawn (failure is never punished, DESIGN.md 4-4). Walking
	-- ON water is chapter 11's image, not this one's — so the surface sits low
	-- enough to read as wading, not walking.
	local water = Build.part({
		Name = "Water",
		Size = Vector3.new(180, 1, 160),
		CFrame = CFrame.new(base + Vector3.new(0, 1, -76)),
		Color = Color3.fromRGB(58, 110, 148),
		Material = Enum.Material.Water,
	})
	session:track(water)

	local pier = Build.part({
		Name = "Pier",
		Size = Vector3.new(6, 1, 56),
		CFrame = CFrame.new(base + Vector3.new(0, PIER_TOP_Y - 0.5, -24)),
		Color = Color3.fromRGB(126, 100, 72),
		Material = Enum.Material.WoodPlanks,
	})
	session:track(pier)

	local shallowSpot = castSpot(base, SHALLOW_END_Z)
	session:track(shallowSpot)

	session:bind(shallowSpot.Touched, function(hit: BasePart)
		local player = Build.playerFromHit(hit)
		if player and claim(player) then
			session:setObjective("empty_net", true)
		end
	end)

	local spots = {
		Vector3.new(-30, 5, 30), -- on the shore
		Vector3.new(8, PIER_TOP_Y + 2, -20), -- beside the pier
		Vector3.new(-10, 3, -70), -- out in the shallows, a small wade
	}
	for index, fragmentId in Chapter.fragments do
		local orb = Build.glow({
			Name = fragmentId,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(base + (spots[index] or Vector3.new(0, 5, 0))),
			Color = Color3.fromRGB(168, 214, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, 2, 24)
		session:track(orb)

		session:bind(orb.Touched, function(hit: BasePart)
			local player = Build.playerFromHit(hit)
			if player then
				session:grantFragment(player, fragmentId)
			end
		end)
	end

	session:say("ch06.castShallow")
	session:point(base + Vector3.new(0, PIER_TOP_Y, SHALLOW_END_Z))
end

function Chapter.onObjective(session: Types.Session, objectiveId: string)
	local base = session.origin.Position

	if objectiveId == "empty_net" then
		session:say("ch06.emptyNet")
		session:point(nil)

		-- The voice arrives as light on the shore, behind the player.
		local shoreLight = Build.glow({
			Name = "ShoreLight",
			Size = Vector3.new(2, 14, 2),
			CFrame = CFrame.new(base + Vector3.new(0, 9, 40)),
			Color = Color3.fromRGB(255, 236, 190),
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
		}, 3, 60)
		session:track(shoreLight)

		-- Only now does the way into the deep exist.
		local deepPier = Build.part({
			Name = "DeepPier",
			Size = Vector3.new(6, 1, 62),
			CFrame = CFrame.new(base + Vector3.new(0, PIER_TOP_Y - 0.5, -81)),
			Color = Color3.fromRGB(126, 100, 72),
			Material = Enum.Material.WoodPlanks,
		})
		session:track(deepPier)

		local deepSpot = castSpot(base, DEEP_END_Z)
		session:track(deepSpot)

		local claim = Build.debouncePerPlayer(0.8)
		session:bind(deepSpot.Touched, function(hit: BasePart)
			local player = Build.playerFromHit(hit)
			if player and claim(player) then
				session:setObjective("cast_deep", true)
			end
		end)

		task.delay(2.5, function()
			session:say("ch06.goDeeper")
			session:point(base + Vector3.new(0, PIER_TOP_Y, DEEP_END_Z))
		end)
	elseif objectiveId == "cast_deep" then
		-- The catch: a burst of leaping fish around the deep end. Pure spectacle,
		-- and the session cleans them up with everything else.
		local scatter = Random.new(56)
		for index = 1, 12 do
			local fish = Build.glow({
				Name = `Fish{index}`,
				Size = Vector3.new(1.2, 0.8, 2.4),
				CFrame = CFrame.new(base + Vector3.new(
					scatter:NextNumber(-9, 9),
					2 + scatter:NextNumber(0, 3),
					DEEP_END_Z + scatter:NextNumber(-9, 9)
				)),
				Color = Color3.fromRGB(214, 236, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, 1, 10)
			session:track(fish)
		end

		session:say("ch06.fullNet")
	end
end

-- Everything went through session:track / session:bind.
function Chapter.cleanup(_session: Types.Session) end

return Chapter :: Types.Chapter
