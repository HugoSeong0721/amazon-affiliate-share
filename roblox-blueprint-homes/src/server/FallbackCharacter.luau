--!strict
-- A character rig built from plain Parts, used only when the place is
-- unpublished (PlaceId 0).
--
-- Why this exists: the default avatar is R15, whose body parts are MeshParts
-- streamed from Roblox asset delivery. An unpublished place gets HTTP 403 for
-- every asset request, so those meshes never arrive and the player renders as
-- nothing. The avatar rig type (R6/R15) is a platform-side game setting, not a
-- property stored in the .rbxl, so it can't be forced from the project file.
--
-- Installing a StarterCharacter sidesteps all of it: Roblox clones this model
-- instead of building an avatar, and every part here is a primitive that needs
-- no download. Standard R6 proportions and Motor6D joints, so the default
-- Humanoid controller drives it normally.

local StarterPlayer = game:GetService("StarterPlayer")

local FallbackCharacter = {}

local SKIN = Color3.fromRGB(245, 205, 95)
local SHIRT = Color3.fromRGB(72, 130, 200)
local PANTS = Color3.fromRGB(70, 90, 120)

local function makeLimb(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false -- the Humanoid needs to move these
	part.CanCollide = true
	part.Parent = parent
	return part
end

local function joint(name: string, part0: Part, part1: Part, c0: CFrame, c1: CFrame)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
end

local function buildRig(): Model
	local model = Instance.new("Model")
	model.Name = "StarterCharacter"

	local torso = makeLimb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), SHIRT, model)
	local head = makeLimb("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), SKIN, model)
	local leftArm = makeLimb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), SKIN, model)
	local rightArm = makeLimb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), SKIN, model)
	local leftLeg = makeLimb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), PANTS, model)
	local rightLeg = makeLimb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), PANTS, model)

	local root = makeLimb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), SHIRT, model)
	root.Transparency = 1
	root.CanCollide = false

	-- Standard R6 joint offsets; the shipped Humanoid animator expects these names.
	local half = math.pi / 2
	joint("RootJoint", root, torso, CFrame.Angles(-half, 0, math.pi), CFrame.Angles(-half, 0, math.pi))
	joint(
		"Neck",
		torso,
		head,
		CFrame.new(0, 1, 0) * CFrame.Angles(-half, 0, math.pi),
		CFrame.new(0, -0.5, 0) * CFrame.Angles(-half, 0, math.pi)
	)
	joint(
		"Right Shoulder",
		torso,
		rightArm,
		CFrame.new(1, 0.5, 0) * CFrame.Angles(0, half, 0),
		CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, half, 0)
	)
	joint(
		"Left Shoulder",
		torso,
		leftArm,
		CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -half, 0),
		CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -half, 0)
	)
	joint(
		"Right Hip",
		torso,
		rightLeg,
		CFrame.new(1, -1, 0) * CFrame.Angles(0, half, 0),
		CFrame.new(0.5, 1, 0) * CFrame.Angles(0, half, 0)
	)
	joint(
		"Left Hip",
		torso,
		leftLeg,
		CFrame.new(-1, -1, 0) * CFrame.Angles(0, -half, 0),
		CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -half, 0)
	)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

-- Returns true if the fallback rig was installed.
function FallbackCharacter.InstallIfUnpublished(): boolean
	if game.PlaceId ~= 0 then
		return false
	end

	local existing = StarterPlayer:FindFirstChild("StarterCharacter")
	if existing then
		existing:Destroy()
	end

	local ok, err = pcall(function()
		buildRig().Parent = StarterPlayer
	end)
	if not ok then
		warn("[BlueprintHomes] could not install fallback character:", err)
		return false
	end

	-- Stop Roblox layering the player's real (undownloadable) appearance on top.
	StarterPlayer.LoadCharacterAppearance = false
	return true
end

return FallbackCharacter
