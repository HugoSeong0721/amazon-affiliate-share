--!strict
-- Chapter 1's greybox: a dark field, a pen, five sheep, a star over the stable,
-- and three verse fragments tucked where a curious kid will wander.

local Verses = require(game:GetService("ReplicatedStorage").Shared.Verses)
local Build = require(script.Parent.Build)

local GROUND_SIZE = Vector3.new(220, 2, 220)
local GROUND_Y = 1
local SHEEP_Y = 3
local SHEEP_COUNT = 5

local BethlehemBuilder = {}

export type Scene = {
	sheep: { BasePart },
	penCenter: Vector3,
	penSize: Vector3,
	boundsCenter: Vector3,
	boundsSize: Vector3,
	groundY: number,
	stableZone: BasePart,
	star: BasePart,
	fragments: { BasePart },
}

function BethlehemBuilder.build(origin: CFrame, parent: Instance): Scene
	local base = origin.Position

	local ground = Build.part({
		Name = "Field",
		Size = GROUND_SIZE,
		CFrame = CFrame.new(base),
		Color = Color3.fromRGB(58, 62, 52),
		Material = Enum.Material.Ground,
	})
	ground.Parent = parent

	-- Stable: three walls and a gap, so the flock can only be walked in from the field.
	local penCenter = base + Vector3.new(0, 0, -70)
	local penSize = Vector3.new(40, 20, 34)
	local pen = Build.folder("Pen", parent)

	local walls = {
		{ size = Vector3.new(penSize.X, 10, 2), offset = Vector3.new(0, 5, -penSize.Z / 2) },
		{ size = Vector3.new(2, 10, penSize.Z), offset = Vector3.new(-penSize.X / 2, 5, 0) },
		{ size = Vector3.new(2, 10, penSize.Z), offset = Vector3.new(penSize.X / 2, 5, 0) },
	}
	for index, wall in walls do
		local part = Build.part({
			Name = `Wall{index}`,
			Size = wall.size,
			CFrame = CFrame.new(penCenter + wall.offset),
			Color = Color3.fromRGB(122, 96, 68),
			Material = Enum.Material.WoodPlanks,
		})
		part.Parent = pen
	end

	local stableZone = Build.part({
		Name = "StableZone",
		Size = Vector3.new(penSize.X, 8, penSize.Z),
		CFrame = CFrame.new(penCenter + Vector3.new(0, 4, 0)),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	stableZone.Parent = pen

	-- The star. This is the only navigation instruction the chapter gives.
	local star = Build.glow({
		Name = "Star",
		Size = Vector3.new(6, 6, 6),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(penCenter + Vector3.new(0, 62, 0)),
		Color = Color3.fromRGB(255, 250, 214),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, 3, 90)
	star.Parent = parent

	local flock = Build.folder("Flock", parent)
	local sheep: { BasePart } = {}
	local scatter = Random.new(1102)
	for index = 1, SHEEP_COUNT do
		local part = Build.part({
			Name = `Sheep{index}`,
			Size = Vector3.new(3, 3, 4),
			CFrame = CFrame.new(base + Vector3.new(scatter:NextNumber(-70, 70), SHEEP_Y, scatter:NextNumber(10, 80))),
			Color = Color3.fromRGB(226, 222, 210),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		part.Parent = flock
		table.insert(sheep, part)
	end

	local fragmentFolder = Build.folder("Fragments", parent)
	local fragmentSpots = {
		Vector3.new(-86, 4, 40),
		Vector3.new(84, 4, -20),
		Vector3.new(-30, 4, -96),
	}

	local fragments: { BasePart } = {}
	for index, fragmentId in Verses.fragmentIdsFor("ch01_bethlehem") do
		local spot = fragmentSpots[index] or Vector3.new(0, 4, 0)
		local orb = Build.glow({
			Name = fragmentId,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(base + spot),
			Color = Color3.fromRGB(168, 214, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, 2, 26)
		orb:SetAttribute("FragmentId", fragmentId)
		orb.Parent = fragmentFolder
		table.insert(fragments, orb)
	end

	return {
		sheep = sheep,
		penCenter = penCenter,
		penSize = Vector3.new(penSize.X - 4, penSize.Y, penSize.Z - 4),
		boundsCenter = base,
		boundsSize = Vector3.new(GROUND_SIZE.X - 12, 0, GROUND_SIZE.Z - 12),
		groundY = base.Y + SHEEP_Y,
		stableZone = stableZone,
		star = star,
		fragments = fragments,
	}
end

return BethlehemBuilder
