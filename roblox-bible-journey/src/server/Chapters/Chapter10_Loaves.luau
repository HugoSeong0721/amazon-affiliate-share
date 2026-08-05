--!strict
-- Chapter 10 — 오병이어 (요한복음 6).
--
-- The sharing archetype, and the first chapter whose rules are social. All the
-- meaning lives in FeedingLogic (see that file); this module is the map and the
-- touch wiring around it.
--
-- minPlayers stays 1 for now: the chapter is completable alone, but every extra
-- player who shares their lunch raises everyone's carry capacity, so a group
-- finishes visibly faster than a loner. Whether to hard-gate this at 4 players
-- (DESIGN.md 3-3) is a P1 playtest decision — measure how often solo kids hit it
-- before locking the door.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Verses = require(ReplicatedStorage.Shared.Verses)
local Build = require(script.Parent.Parent.greybox.Build)
local FeedingLogic = require(script.Parent.Parent.greybox.FeedingLogic)

local Chapter = {
	id = "ch10_loaves",
	reference = "요한복음 6:9",
	fragments = Verses.fragmentIdsFor("ch10_loaves"),
	requires = { "ch06_nets" },
	minPlayers = 1,
	estimatedMinutes = 10,
	objectives = { "share_a_lunch", "feed_everyone" },
}

-- 5 groups of 12 servings: 5 trips solo, 2-3 together. Long enough to feel the
-- work of serving, short enough that a solo kid does not stall out.
local GROUP_NEEDS = { 12, 12, 12, 12, 12 }
local CARRY_PER_CONTRIBUTOR = 12

local GROUP_SPOTS = {
	Vector3.new(-60, 0, -30),
	Vector3.new(-30, 0, -70),
	Vector3.new(25, 0, -75),
	Vector3.new(60, 0, -35),
	Vector3.new(0, 0, -110),
}

-- Returns the touch zone and the hunger mat (dim → gold when the group is fed).
local function buildCrowdGroup(base: Vector3, spot: Vector3, index: number, session: Types.Session): (BasePart, BasePart)
	local center = base + spot

	-- A ring of seated figures ("떼로 앉히라" — they sit in groups). Static
	-- blocks are enough for the greybox to read as people waiting.
	local ring = Random.new(100 + index)
	for seat = 1, 8 do
		local angle = (seat / 8) * math.pi * 2
		local person = Build.part({
			Name = `Person{index}_{seat}`,
			Size = Vector3.new(1.6, 2.2, 1.6),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 7, 2.1, math.sin(angle) * 7)),
			Color = Color3.fromRGB(
				150 + ring:NextInteger(0, 60),
				120 + ring:NextInteger(0, 50),
				90 + ring:NextInteger(0, 40)
			),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		session:track(person)
	end

	local mat = Build.part({
		Name = `GroupMat{index}`,
		Size = Vector3.new(18, 0.4, 18),
		CFrame = CFrame.new(center + Vector3.new(0, 1.2, 0)),
		Color = Color3.fromRGB(110, 104, 92),
		Material = Enum.Material.Fabric,
	})
	session:track(mat)

	local zone = Build.part({
		Name = `GroupZone{index}`,
		Size = Vector3.new(18, 8, 18),
		CFrame = CFrame.new(center + Vector3.new(0, 5, 0)),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	zone:SetAttribute("GroupIndex", index)
	session:track(zone)

	return zone, mat
end

function Chapter.start(session: Types.Session)
	local base = session.origin.Position
	local logic = FeedingLogic.new(GROUP_NEEDS, CARRY_PER_CONTRIBUTOR)

	local hill = Build.part({
		Name = "Hillside",
		Size = Vector3.new(220, 2, 260),
		CFrame = CFrame.new(base + Vector3.new(0, 0, -40)),
		Color = Color3.fromRGB(104, 128, 84),
		Material = Enum.Material.Grass,
	})
	session:track(hill)

	local basket = Build.glow({
		Name = "Basket",
		Size = Vector3.new(4, 3, 4),
		CFrame = CFrame.new(base + Vector3.new(0, 2.5, -12)),
		Color = Color3.fromRGB(210, 168, 96),
		Material = Enum.Material.Neon,
	}, 1.5, 24)
	session:track(basket)

	local mats: { [number]: BasePart } = {}

	local basketClaim = Build.debouncePerPlayer(0.8)
	session:bind(basket.Touched, function(hit: BasePart)
		local player = Build.playerFromHit(hit)
		if not player or not basketClaim(player) then
			return
		end

		-- First touch gives; every later touch draws. Giving cannot be undone —
		-- the same rule the story runs on.
		if logic:contribute(player.UserId) then
			session:sayTo(player, "ch10.shared")
			session:setObjective("share_a_lunch", true)
			return
		end

		if logic:pickUp(player.UserId) > 0 then
			session:sayTo(player, "ch10.pickedUp")
		elseif logic:carryingOf(player.UserId) > 0 then
			session:sayTo(player, "ch10.handsFull")
		else
			session:sayTo(player, "ch10.basketWaits")
		end
	end)

	for index, spot in GROUP_SPOTS do
		local zone, mat = buildCrowdGroup(base, spot, index, session)
		mats[index] = mat

		local zoneClaim = Build.debouncePerPlayer(0.8)
		session:bind(zone.Touched, function(hit: BasePart)
			local player = Build.playerFromHit(hit)
			if not player or not zoneClaim(player) then
				return
			end
			if logic:groupNeed(index) <= 0 then
				return
			end

			if logic:carryingOf(player.UserId) <= 0 then
				session:sayTo(player, "ch10.needBread")
				session:point(basket.Position)
				return
			end

			logic:deliver(player.UserId, index)

			if logic:groupNeed(index) <= 0 then
				session:say("ch10.groupFed")
				local mat = mats[index]
				if mat then
					mat.Color = Color3.fromRGB(232, 198, 120)
					mat.Material = Enum.Material.Neon
				end
			end

			if logic:isEveryoneFed() then
				session:say("ch10.leftovers")
				task.delay(2.5, function()
					session:setObjective("feed_everyone", true)
				end)
			end
		end)
	end

	local fragmentSpots = {
		Vector3.new(-90, 4, 20),
		Vector3.new(92, 4, -80),
		Vector3.new(-40, 4, -140),
	}
	for index, fragmentId in Chapter.fragments do
		local orb = Build.glow({
			Name = fragmentId,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(base + (fragmentSpots[index] or Vector3.new(0, 4, 0))),
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

	session:say("ch10.shareLunch")
	session:point(basket.Position)
end

function Chapter.onObjective(session: Types.Session, objectiveId: string)
	if objectiveId == "share_a_lunch" then
		-- The basket is full now; the work is out among the groups. Drop the beam
		-- and let the crowd rings pull the eye — five of them, all dim, all waiting.
		session:point(nil)
	end
end

-- Everything went through session:track / session:bind; FeedingLogic state lives
-- in the start closure and dies with it.
function Chapter.cleanup(_session: Types.Session) end

return Chapter :: Types.Chapter
