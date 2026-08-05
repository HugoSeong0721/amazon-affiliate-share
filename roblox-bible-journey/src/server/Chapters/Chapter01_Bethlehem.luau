--!strict
-- Chapter 1 — 베들레헴의 밤.
--
-- The player is a shepherd child, not the centre of the story. They arrive after
-- the star does, and their job is to get the flock home. The whole chapter is one
-- lesson delivered through the control scheme: charging at sheep scatters them,
-- walking gathers them.
--
-- Fragments are optional. The chapter completes without them, because "collect
-- everything" pressure is the fastest way to make a kid stop enjoying a story.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local Verses = require(ReplicatedStorage.Shared.Verses)
local Build = require(script.Parent.Parent.greybox.Build)
local BethlehemBuilder = require(script.Parent.Parent.greybox.BethlehemBuilder)
local SheepController = require(script.Parent.Parent.greybox.SheepController)

local Chapter = {
	id = "ch01_bethlehem",
	reference = "누가복음 2:11",
	fragments = Verses.fragmentIdsFor("ch01_bethlehem"),
	requires = { "ch00_waiting" },
	minPlayers = 1,
	estimatedMinutes = 9,
	objectives = { "find_the_stable", "pen_all_sheep" },
}

local function herdersFrom(players: { Player }): { SheepController.Herder }
	local herders = {}
	for _, player in players do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local velocity = root.AssemblyLinearVelocity
			table.insert(herders, {
				position = root.Position,
				speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude,
			})
		end
	end
	return herders
end

function Chapter.start(session: Types.Session)
	local scene = BethlehemBuilder.build(session.origin, session.world)
	local claim = Build.debouncePerPlayer(0.5)

	local flock = SheepController.new({
		sheep = scene.sheep,
		penCenter = scene.penCenter,
		penSize = scene.penSize,
		boundsCenter = scene.boundsCenter,
		boundsSize = scene.boundsSize,
		groundY = scene.groundY,
	})

	session:bind(scene.stableZone.Touched, function(hit: BasePart)
		local player = Build.playerFromHit(hit)
		if player and claim(player) then
			session:setObjective("find_the_stable", true)
		end
	end)

	for _, orb in scene.fragments do
		local fragmentId = orb:GetAttribute("FragmentId")
		session:bind(orb.Touched, function(hit: BasePart)
			local player = Build.playerFromHit(hit)
			if player and typeof(fragmentId) == "string" then
				session:grantFragment(player, fragmentId)
			end
		end)
	end

	local announced = 0
	session:bind(RunService.Heartbeat, function(dt: number)
		flock:step(dt, herdersFrom(session.players))

		local penned = flock:pennedCount()
		if penned == announced then
			return
		end
		announced = penned

		if penned == flock:total() then
			session:say("ch01.allPenned")
			session:setObjective("pen_all_sheep", true)
		elseif session:isObjectiveDone("find_the_stable") then
			session:say("ch01.sheepLeft")
		end
	end)

	session:say("ch01.findStable")
	session:point(Vector3.new(scene.penCenter.X, scene.groundY, scene.penCenter.Z))
end

function Chapter.onObjective(session: Types.Session, objectiveId: string)
	if objectiveId == "find_the_stable" then
		session:say("ch01.penSheep")
		-- Stop pointing. From here the star is the only hint, and the sheep are
		-- wherever the player scattered them — the map is the puzzle now.
		session:point(nil)
	end
end

-- Nothing to undo by hand: every part went into session.world and every
-- connection went through session:bind, so Session:destroy covers this chapter.
function Chapter.cleanup(_session: Types.Session) end

return Chapter :: Types.Chapter
