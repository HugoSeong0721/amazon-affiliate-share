--!strict
-- The hub is the whole progression UI (DESIGN.md 1-2). One road, one segment per
-- chapter, mist over what hasn't been walked yet.
--
-- The geometry is built once on the server for everyone. The *state* — which
-- segments are misted, which lamps are lit — is applied per player on the client
-- (see src/client/RoadView.luau), because progress differs per player and Roblox
-- has no per-player visibility for replicated instances.

local Build = require(script.Parent.Build)

local SEGMENT_LENGTH = 48
local SEGMENT_WIDTH = 18
local HUB_SIZE = Vector3.new(96, 2, 96)
local ROAD_START_Z = -56

local HubBuilder = {}

export type Hub = {
	model: Folder,
	spawn: CFrame,
	pads: { [BasePart]: string },
}

function HubBuilder.build(parent: Instance, order: { string }): Hub
	local existing = parent:FindFirstChild("Hub")
	if existing then
		existing:Destroy()
	end

	local hub = Build.folder("Hub", parent)

	local ground = Build.part({
		Name = "HubGround",
		Size = HUB_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(96, 104, 88),
		Material = Enum.Material.Grass,
	})
	ground.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 1.5, 24)
	spawn.Color = Color3.fromRGB(216, 200, 160)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = hub

	local segments = Build.folder("Segments", hub)
	local pads: { [BasePart]: string } = {}

	for index, chapterId in order do
		local centerZ = ROAD_START_Z - (index - 1) * SEGMENT_LENGTH
		local segment = Build.folder(chapterId, segments)
		segment:SetAttribute("Index", index)

		local road = Build.part({
			Name = "Road",
			Size = Vector3.new(SEGMENT_WIDTH, 1, SEGMENT_LENGTH),
			CFrame = CFrame.new(0, 0.5, centerZ),
			Color = Color3.fromRGB(120, 110, 96),
			Material = Enum.Material.Cobblestone,
		})
		road.Parent = segment

		-- Lamp for a walked segment. Starts dark; the client lights it.
		local lamp = Build.glow({
			Name = "Lamp",
			Size = Vector3.new(1, 10, 1),
			CFrame = CFrame.new(SEGMENT_WIDTH / 2 - 1, 5.5, centerZ),
			Color = Color3.fromRGB(255, 214, 140),
			Material = Enum.Material.Neon,
		}, 0, 24)
		lamp.Parent = segment

		-- The diorama pedestal: a re-entry point for a chapter already walked.
		local pad = Build.part({
			Name = "Pad",
			Size = Vector3.new(10, 1, 10),
			CFrame = CFrame.new(0, 1.2, centerZ),
			Color = Color3.fromRGB(180, 168, 140),
			Material = Enum.Material.Sandstone,
		})
		pad:SetAttribute("ChapterId", chapterId)
		pad.Parent = segment
		pads[pad] = chapterId

		-- The mist. Not a lock icon: kids should be curious, not blocked.
		local fog = Build.part({
			Name = "Fog",
			Size = Vector3.new(SEGMENT_WIDTH + 12, 26, SEGMENT_LENGTH),
			CFrame = CFrame.new(0, 13, centerZ),
			Color = Color3.fromRGB(206, 212, 224),
			Material = Enum.Material.ForceField,
			Transparency = 0.35,
			CanCollide = false,
			CastShadow = false,
		})
		fog.Parent = segment
	end

	return {
		model = hub,
		spawn = CFrame.new(spawn.Position + Vector3.new(0, 4, 0)),
		pads = pads,
	}
end

return HubBuilder
