--!strict
-- Builds the studio world: a large dressing hall with four themed photo
-- zones along the back wall. Kept in its own Script so the world always
-- exists even if the game-logic script hits an error.

local COLOR_FLOOR = Color3.fromRGB(255, 214, 231)
local COLOR_WALL = Color3.fromRGB(244, 226, 255)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = workspace
	return p
end

----------------------------------------------------------------------
-- Hall: floor + walls
----------------------------------------------------------------------

part({
	Name = "Floor",
	Size = Vector3.new(200, 1, 70),
	Position = Vector3.new(0, 0, 0),
	Color = COLOR_FLOOR,
	Material = Enum.Material.SmoothPlastic,
})

local wallSpecs = {
	{ Vector3.new(200, 24, 1), Vector3.new(0, 12, -35) },
	{ Vector3.new(200, 24, 1), Vector3.new(0, 12, 35) },
	{ Vector3.new(1, 24, 70), Vector3.new(-100, 12, 0) },
	{ Vector3.new(1, 24, 70), Vector3.new(100, 12, 0) },
}
for _, spec in wallSpecs do
	part({
		Name = "Wall",
		Size = spec[1],
		Position = spec[2],
		Color = COLOR_WALL,
		Material = Enum.Material.SmoothPlastic,
	})
end

----------------------------------------------------------------------
-- Themed photo zones
----------------------------------------------------------------------

type Zone = {
	x: number,
	sign: string,
	backdrop: Color3,
	neonA: Color3,
	neonB: Color3,
	pad: Color3,
	deco: ((x: number) -> ())?,
}

local function decoClouds(x: number)
	local spots = {
		{ x - 6, 9.5, -32.5, 4 },
		{ x - 3.5, 10.5, -32, 3 },
		{ x + 5, 5, -32.5, 3.5 },
		{ x + 7, 6.5, -32, 2.5 },
	}
	for _, s in spots do
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s[4], s[4], s[4]),
			Position = Vector3.new(s[1], s[2], s[3]),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
end

local function decoBlossom(x: number)
	part({
		Name = "BlossomTrunk",
		Size = Vector3.new(1.6, 9, 1.6),
		Position = Vector3.new(x - 10, 4.5, -31),
		Color = Color3.fromRGB(110, 76, 58),
		Material = Enum.Material.Wood,
	})
	local puffs = {
		{ x - 10, 10.5, -31, 6 },
		{ x - 13, 9, -31, 4.5 },
		{ x - 7, 9.2, -31, 4.5 },
	}
	for _, s in puffs do
		part({
			Name = "BlossomPuff",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s[4], s[4], s[4]),
			Position = Vector3.new(s[1], s[2], s[3]),
			Color = Color3.fromRGB(255, 170, 205),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

local function decoRetro(x: number)
	for i = 0, 2 do
		part({
			Name = "RetroRing",
			Size = Vector3.new(0.05, 10 - i * 3, 10 - i * 3),
			Position = Vector3.new(x, 0.56 + i * 0.03, -28),
			Color = i % 2 == 0 and Color3.fromRGB(255, 123, 84) or Color3.fromRGB(255, 209, 102),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Shape = Enum.PartType.Cylinder,
			Orientation = Vector3.new(0, 0, 90),
		})
	end
end

local ZONES: { Zone } = {
	{
		x = -75, sign = "STAGE \u{1F3A4}",
		backdrop = Color3.fromRGB(40, 20, 60),
		neonA = Color3.fromRGB(255, 89, 158), neonB = Color3.fromRGB(120, 220, 255),
		pad = Color3.fromRGB(255, 89, 158),
	},
	{
		x = -25, sign = "CLOUDS \u{2601}",
		backdrop = Color3.fromRGB(143, 215, 255),
		neonA = Color3.fromRGB(255, 255, 255), neonB = Color3.fromRGB(255, 158, 203),
		pad = Color3.fromRGB(143, 215, 255),
		deco = decoClouds,
	},
	{
		x = 25, sign = "RETRO \u{1F352}",
		backdrop = Color3.fromRGB(255, 209, 102),
		neonA = Color3.fromRGB(255, 123, 84), neonB = Color3.fromRGB(255, 90, 90),
		pad = Color3.fromRGB(255, 181, 77),
		deco = decoRetro,
	},
	{
		x = 75, sign = "BLOSSOM \u{1F338}",
		backdrop = Color3.fromRGB(255, 201, 222),
		neonA = Color3.fromRGB(255, 105, 180), neonB = Color3.fromRGB(255, 255, 255),
		pad = Color3.fromRGB(255, 170, 205),
		deco = decoBlossom,
	},
}

for _, zone in ZONES do
	local backdrop = part({
		Name = "PhotoBackdrop",
		Size = Vector3.new(18, 12, 0.5),
		Position = Vector3.new(zone.x, 6.5, -34.2),
		Color = zone.backdrop,
		Material = Enum.Material.SmoothPlastic,
	})

	local frameSpecs = {
		{ Vector3.new(18.8, 0.6, 0.7), Vector3.new(zone.x, 12.6, -34.2) },
		{ Vector3.new(18.8, 0.6, 0.7), Vector3.new(zone.x, 0.9, -34.2) },
		{ Vector3.new(0.6, 12.4, 0.7), Vector3.new(zone.x - 9.2, 6.7, -34.2) },
		{ Vector3.new(0.6, 12.4, 0.7), Vector3.new(zone.x + 9.2, 6.7, -34.2) },
	}
	for index, spec in frameSpecs do
		part({
			Name = "PhotoFrameNeon",
			Size = spec[1],
			Position = spec[2],
			Color = index % 2 == 0 and zone.neonA or zone.neonB,
			Material = Enum.Material.Neon,
		})
	end

	part({
		Name = "PhotoSpot",
		Size = Vector3.new(7, 0.1, 7),
		Position = Vector3.new(zone.x, 0.55, -29),
		Color = zone.pad,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(900, 600)
	signGui.Parent = backdrop
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 0.3)
	signLabel.Position = UDim2.fromScale(0, 0.04)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = zone.sign
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeColor3 = Color3.fromRGB(60, 40, 80)
	signLabel.TextStrokeTransparency = 0.4
	signLabel.Parent = signGui

	local lightPart = part({
		Name = "SpotlightAnchor",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(zone.x, 18, -26),
		Transparency = 1,
		CanCollide = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Angle = 70
	spot.Brightness = 1
	spot.Range = 32
	spot.Face = Enum.NormalId.Bottom
	spot.Color = Color3.fromRGB(255, 240, 248)
	spot.Parent = lightPart

	if zone.deco then
		zone.deco(zone.x)
	end
end

----------------------------------------------------------------------
-- Big logo on the front wall + spawn
----------------------------------------------------------------------

local logoWall = part({
	Name = "LogoWall",
	Size = Vector3.new(60, 10, 0.4),
	Position = Vector3.new(0, 14, 34.4),
	Color = Color3.fromRGB(58, 34, 84),
	Material = Enum.Material.SmoothPlastic,
})
local logoGui = Instance.new("SurfaceGui")
logoGui.Face = Enum.NormalId.Back
logoGui.CanvasSize = Vector2.new(1800, 300)
logoGui.Parent = logoWall
local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.fromScale(1, 1)
logoLabel.BackgroundTransparency = 1
logoLabel.Text = "COMEBACK! \u{2728} K-pop Dress Up"
logoLabel.Font = Enum.Font.FredokaOne
logoLabel.TextScaled = true
logoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
logoLabel.Parent = logoGui

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(0, 0.5, 15)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Transparency = 1
spawnLocation.CanCollide = true
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = workspace

----------------------------------------------------------------------
-- Juice pass: post-processing, glossy stage, disco ball, neon pulse
----------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3
bloom.Size = 24
bloom.Threshold = 2
bloom.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation = 0.08
colorCorrection.Contrast = 0.02
colorCorrection.TintColor = Color3.fromRGB(255, 248, 252)
colorCorrection.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.1
atmosphere.Color = Color3.fromRGB(226, 198, 231)
atmosphere.Decay = Color3.fromRGB(150, 100, 160)
atmosphere.Haze = 0.5
atmosphere.Parent = Lighting

-- Glossy stage floor
local floor = workspace:FindFirstChild("Floor")
if floor and floor:IsA("BasePart") then
	floor.Reflectance = 0.14
end

-- Disco ball over the middle of the hall
local disco = part({
	Name = "DiscoBall",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(7, 7, 7),
	Position = Vector3.new(0, 19, 0),
	Color = Color3.fromRGB(220, 230, 255),
	Material = Enum.Material.Glass,
	Reflectance = 0.6,
	CanCollide = false,
})
local discoLight = Instance.new("PointLight")
discoLight.Color = Color3.fromRGB(255, 170, 220)
discoLight.Brightness = 0.7
discoLight.Range = 34
discoLight.Parent = disco
local discoAttachment = Instance.new("Attachment")
discoAttachment.Parent = disco
local discoSparkle = Instance.new("ParticleEmitter")
discoSparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
discoSparkle.Rate = 6
discoSparkle.Speed = NumberRange.new(2, 5)
discoSparkle.Lifetime = NumberRange.new(1, 2)
discoSparkle.SpreadAngle = Vector2.new(180, 180)
discoSparkle.Color = ColorSequence.new(Color3.fromRGB(255, 200, 235), Color3.fromRGB(160, 220, 255))
discoSparkle.Parent = discoAttachment
task.spawn(function()
	while disco.Parent do
		disco.CFrame = disco.CFrame * CFrame.Angles(0, math.rad(1.2), 0)
		task.wait(0.05)
	end
end)

-- Ambient rising sparkles at each photo spot
for _, zoneX in { -75, -25, 25, 75 } do
	local anchor = part({
		Name = "ZoneSparkleAnchor",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(zoneX, 2, -29),
		Transparency = 1,
		CanCollide = false,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 2.5
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 240))
	emitter.Parent = attachment
end

-- Neon frames breathe
task.spawn(function()
	local frames = {}
	for _, child in workspace:GetChildren() do
		if child.Name == "PhotoFrameNeon" and child:IsA("BasePart") then
			table.insert(frames, child)
		end
	end
	while true do
		for _, frame in frames do
			TweenService:Create(frame, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Transparency = 0.35 }):Play()
		end
		task.wait(1.15)
		for _, frame in frames do
			TweenService:Create(frame, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
		end
		task.wait(1.15)
	end
end)
