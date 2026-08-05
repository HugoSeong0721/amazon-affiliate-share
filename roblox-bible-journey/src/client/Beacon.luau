--!strict
-- The guiding light. This is the objective UI (DESIGN.md 5-5): a pillar of light
-- in the world, not a line of text at the top of the screen. An eight-year-old
-- who can barely read still knows exactly where to go.
--
-- Client-local, so each player sees their own current objective.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beacon = {}

local pillar: Part? = nil
local bobStart = os.clock()

local function ensurePillar(): Part
	if pillar and pillar.Parent then
		return pillar
	end

	local part = Instance.new("Part")
	part.Name = "ObjectiveBeacon"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(60, 6, 6)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 0.55
	part.Color = Color3.fromRGB(255, 244, 198)
	part.Material = Enum.Material.Neon
	-- Cylinders are built along X, so stand it up.
	part.CFrame = CFrame.new(0, -500, 0) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = Workspace

	pillar = part
	return part
end

function Beacon.setTarget(position: Vector3?)
	if not position then
		if pillar then
			pillar:Destroy()
			pillar = nil
		end
		return
	end

	local part = ensurePillar()
	part.CFrame = CFrame.new(position + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

function Beacon.start()
	RunService.RenderStepped:Connect(function()
		local part = pillar
		if not part or not part.Parent then
			return
		end
		-- A slow breathing pulse reads as "come here" without any animation assets.
		local phase = (os.clock() - bobStart) * 1.6
		part.Transparency = 0.5 + 0.12 * math.sin(phase)
	end)
end

return Beacon
