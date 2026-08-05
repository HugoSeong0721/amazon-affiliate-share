--!strict
-- Chapter 0 — 기다림. The tutorial, dressed as the long wait before the promise.
-- Teaches walk / jump / touch by putting a light where the player should go and
-- saying nothing else (DESIGN.md 5-5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Verses = require(ReplicatedStorage.Shared.Verses)
local Build = require(script.Parent.Parent.greybox.Build)

local Chapter = {
	id = "ch00_waiting",
	reference = "이사야 9:6",
	fragments = Verses.fragmentIdsFor("ch00_waiting"),
	requires = {},
	minPlayers = 1,
	estimatedMinutes = 4,
	objectives = { "learn_walk", "learn_jump", "learn_touch" },
}

local LAMP_Z = -30
local LEDGE_Z = -78
local SCROLL_Z = -110

local function zone(name: string, position: Vector3, size: Vector3): BasePart
	return Build.part({
		Name = name,
		Size = size,
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
end

function Chapter.start(session: Types.Session)
	local base = session.origin.Position
	local claim = Build.debouncePerPlayer(0.5)

	local nearPlate = Build.part({
		Name = "PathStart",
		Size = Vector3.new(60, 2, 80),
		CFrame = CFrame.new(base + Vector3.new(0, 0, -20)),
		Color = Color3.fromRGB(74, 70, 62),
		Material = Enum.Material.Slate,
	})
	session:track(nearPlate)

	local farPlate = Build.part({
		Name = "PathEnd",
		Size = Vector3.new(60, 2, 60),
		CFrame = CFrame.new(base + Vector3.new(0, 0, -104)),
		Color = Color3.fromRGB(74, 70, 62),
		Material = Enum.Material.Slate,
	})
	session:track(farPlate)

	-- A forgiving 6-stud ledge under the gap. Missing the jump costs a few seconds,
	-- never a restart — failure is never punished in this game (DESIGN.md 4-4).
	local ledge = Build.part({
		Name = "GapLedge",
		Size = Vector3.new(60, 2, 20),
		CFrame = CFrame.new(base + Vector3.new(0, -6, -67)),
		Color = Color3.fromRGB(52, 50, 46),
		Material = Enum.Material.Slate,
	})
	session:track(ledge)

	local lamp = Build.glow({
		Name = "FirstLamp",
		Size = Vector3.new(1, 9, 1),
		CFrame = CFrame.new(base + Vector3.new(0, 5.5, LAMP_Z)),
		Color = Color3.fromRGB(255, 210, 132),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, 2.5, 30)
	session:track(lamp)

	local scroll = Build.glow({
		Name = "Scroll",
		Size = Vector3.new(3, 4, 1.5),
		CFrame = CFrame.new(base + Vector3.new(0, 4, SCROLL_Z)),
		Color = Color3.fromRGB(240, 226, 176),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, 2.5, 26)
	session:track(scroll)

	local walkZone = zone("WalkZone", base + Vector3.new(0, 4, LAMP_Z), Vector3.new(20, 10, 12))
	session:track(walkZone)

	local jumpZone = zone("JumpZone", base + Vector3.new(0, 4, LEDGE_Z), Vector3.new(56, 10, 8))
	session:track(jumpZone)

	session:bind(walkZone.Touched, function(hit: BasePart)
		local player = Build.playerFromHit(hit)
		if player and claim(player) then
			session:setObjective("learn_walk", true)
		end
	end)

	session:bind(jumpZone.Touched, function(hit: BasePart)
		local player = Build.playerFromHit(hit)
		if player and session:isObjectiveDone("learn_walk") and claim(player) then
			session:setObjective("learn_jump", true)
		end
	end)

	session:bind(scroll.Touched, function(hit: BasePart)
		local player = Build.playerFromHit(hit)
		if player and claim(player) then
			session:setObjective("learn_touch", true)
		end
	end)

	local spots = {
		Vector3.new(-24, 4, -6),
		Vector3.new(26, 4, -46),
		Vector3.new(-22, 4, -122),
	}
	for index, fragmentId in Chapter.fragments do
		local orb = Build.glow({
			Name = fragmentId,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(base + (spots[index] or Vector3.new(0, 4, 0))),
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

	session:say("ch00.walk")
	session:point(base + Vector3.new(0, 8, LAMP_Z))
end

function Chapter.onObjective(session: Types.Session, objectiveId: string)
	local base = session.origin.Position

	if objectiveId == "learn_walk" then
		session:say("ch00.jump")
		session:point(base + Vector3.new(0, 8, LEDGE_Z))
	elseif objectiveId == "learn_jump" then
		session:say("ch00.touch")
		session:point(base + Vector3.new(0, 8, SCROLL_Z))
	elseif objectiveId == "learn_touch" then
		session:point(nil)
	end
end

function Chapter.cleanup(_session: Types.Session) end

return Chapter :: Types.Chapter
