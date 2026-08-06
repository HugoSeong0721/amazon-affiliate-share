--!strict
-- Builds the open world: a spawn plaza and 38 themed photo zones of varied
-- sizes scattered along a winding candy road. Layout is generated from a
-- fixed seed so every server is identical (sign stickers persist at world
-- positions). Kept in its own Script so the world always exists even if the
-- game-logic script errors.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local COLOR_FLOOR = Color3.fromRGB(255, 214, 231)
local COLOR_ROAD = Color3.fromRGB(255, 245, 250)

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
-- Ground + invisible borders
----------------------------------------------------------------------

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.Position = Vector3.new(0, 0.5, 20)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Transparency = 1
spawnLocation.CanCollide = true
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = workspace


part({
	Name = "Floor",
	Size = Vector3.new(900, 1, 900),
	Position = Vector3.new(0, 0, 0),
	Color = COLOR_FLOOR,
	Material = Enum.Material.SmoothPlastic,
	Reflectance = 0.08,
})

for _, spec in {
	{ Vector3.new(900, 60, 2), Vector3.new(0, 30, -450) },
	{ Vector3.new(900, 60, 2), Vector3.new(0, 30, 450) },
	{ Vector3.new(2, 60, 900), Vector3.new(-450, 30, 0) },
	{ Vector3.new(2, 60, 900), Vector3.new(450, 30, 0) },
} do
	part({
		Name = "Border",
		Size = spec[1],
		Position = spec[2],
		Transparency = 1,
	})
end

----------------------------------------------------------------------
-- Zone themes (cycled across the 38 zones)
----------------------------------------------------------------------

type Theme = {
	name: string,
	backdrop: Color3,
	neonA: Color3,
	neonB: Color3,
	pad: Color3,
}

local THEMES: { Theme } = {
	{ name = "STAGE \u{1F3A4}", backdrop = Color3.fromRGB(40, 20, 60), neonA = Color3.fromRGB(255, 89, 158), neonB = Color3.fromRGB(120, 220, 255), pad = Color3.fromRGB(255, 89, 158) },
	{ name = "CLOUDS \u{2601}", backdrop = Color3.fromRGB(143, 215, 255), neonA = Color3.fromRGB(255, 255, 255), neonB = Color3.fromRGB(255, 158, 203), pad = Color3.fromRGB(143, 215, 255) },
	{ name = "RETRO \u{1F352}", backdrop = Color3.fromRGB(255, 209, 102), neonA = Color3.fromRGB(255, 123, 84), neonB = Color3.fromRGB(255, 90, 90), pad = Color3.fromRGB(255, 181, 77) },
	{ name = "BLOSSOM \u{1F338}", backdrop = Color3.fromRGB(255, 201, 222), neonA = Color3.fromRGB(255, 105, 180), neonB = Color3.fromRGB(255, 255, 255), pad = Color3.fromRGB(255, 170, 205) },
	{ name = "OCEAN \u{1F30A}", backdrop = Color3.fromRGB(28, 80, 140), neonA = Color3.fromRGB(90, 220, 255), neonB = Color3.fromRGB(255, 255, 255), pad = Color3.fromRGB(90, 200, 240) },
	{ name = "SPACE \u{1FA90}", backdrop = Color3.fromRGB(18, 14, 40), neonA = Color3.fromRGB(170, 120, 255), neonB = Color3.fromRGB(90, 220, 255), pad = Color3.fromRGB(150, 110, 255) },
	{ name = "CANDY \u{1F36D}", backdrop = Color3.fromRGB(255, 170, 210), neonA = Color3.fromRGB(140, 240, 210), neonB = Color3.fromRGB(255, 255, 255), pad = Color3.fromRGB(255, 140, 190) },
	{ name = "FOREST \u{1F33F}", backdrop = Color3.fromRGB(52, 110, 70), neonA = Color3.fromRGB(180, 240, 120), neonB = Color3.fromRGB(255, 230, 140), pad = Color3.fromRGB(120, 200, 120) },
	{ name = "ICE \u{2744}", backdrop = Color3.fromRGB(200, 235, 250), neonA = Color3.fromRGB(120, 200, 255), neonB = Color3.fromRGB(255, 255, 255), pad = Color3.fromRGB(170, 225, 250) },
	{ name = "SUNSET \u{1F305}", backdrop = Color3.fromRGB(255, 140, 90), neonA = Color3.fromRGB(255, 90, 130), neonB = Color3.fromRGB(255, 210, 120), pad = Color3.fromRGB(255, 150, 110) },
	{ name = "NEON CITY \u{1F303}", backdrop = Color3.fromRGB(24, 22, 38), neonA = Color3.fromRGB(255, 70, 160), neonB = Color3.fromRGB(70, 255, 200), pad = Color3.fromRGB(255, 90, 170) },
	{ name = "RAINBOW \u{1F308}", backdrop = Color3.fromRGB(250, 250, 255), neonA = Color3.fromRGB(255, 100, 100), neonB = Color3.fromRGB(100, 140, 255), pad = Color3.fromRGB(255, 200, 90) },
}

----------------------------------------------------------------------
-- Zone builder (scaled, oriented)
----------------------------------------------------------------------

local pulsePads: { Part } = {}

local function buildZone(index: number, theme: Theme, cf: CFrame, scale: number)
	local w = 18 * scale
	local h = 12 * scale

	local backdrop = part({
		Name = "PhotoBackdrop",
		Size = Vector3.new(w, h, 0.5),
		CFrame = cf * CFrame.new(0, h / 2 + 0.5, 0),
		Color = theme.backdrop,
		Material = Enum.Material.SmoothPlastic,
	})

	local frameSpecs = {
		{ Vector3.new(w + 0.8, 0.6, 0.7), CFrame.new(0, h + 0.6, 0) },
		{ Vector3.new(w + 0.8, 0.6, 0.7), CFrame.new(0, 0.9, 0) },
		{ Vector3.new(0.6, h + 0.4, 0.7), CFrame.new(-w / 2 - 0.2, h / 2 + 0.7, 0) },
		{ Vector3.new(0.6, h + 0.4, 0.7), CFrame.new(w / 2 + 0.2, h / 2 + 0.7, 0) },
	}
	for i, spec in frameSpecs do
		part({
			Name = "PhotoFrameNeon",
			Size = spec[1],
			CFrame = cf * spec[2],
			Color = i % 2 == 0 and theme.neonA or theme.neonB,
			Material = Enum.Material.Neon,
		})
	end

	local pad = part({
		Name = "PhotoSpot",
		Size = Vector3.new(7 * scale, 0.1, 7 * scale),
		CFrame = cf * CFrame.new(0, 0.55, 5 * scale),
		Color = theme.pad,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})
	table.insert(pulsePads, pad)
	pad:SetAttribute("ZoneIndex", index)
	pad:SetAttribute("ZoneName", `#{index} {theme.name}`)
	game:GetService("CollectionService"):AddTag(pad, "PhotoZone")

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(900, 600)
	signGui.Parent = backdrop
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 0.3)
	signLabel.Position = UDim2.fromScale(0, 0.04)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = `#{index} {theme.name}`
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeColor3 = Color3.fromRGB(60, 40, 80)
	signLabel.TextStrokeTransparency = 0.4
	signLabel.Parent = signGui

	local lightPart = part({
		Name = "SpotlightAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, h + 5, 6 * scale),
		Transparency = 1,
		CanCollide = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Angle = 70
	spot.Brightness = 1
	spot.Range = 22 + 14 * scale
	spot.Face = Enum.NormalId.Bottom
	spot.Color = Color3.fromRGB(255, 240, 248)
	spot.Parent = lightPart

	local sparkleAnchor = part({
		Name = "ZoneSparkleAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 2, 5 * scale),
		Transparency = 1,
		CanCollide = false,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = sparkleAnchor
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 1.5
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 240))
	emitter.Parent = attachment
end

----------------------------------------------------------------------
-- Winding road with 38 zones (fixed seed = identical on every server)
----------------------------------------------------------------------

local MIN_ZONE_GAP = 62

local rng = Random.new(38)
local position = Vector2.new(0, -70)
local heading = math.rad(-90) -- start walking away from the plaza

-- The road can curve back on itself, so every zone site is checked against
-- the ones already placed (and the spawn plaza) before it is accepted.
local placed: { Vector2 } = { Vector2.new(0, 0), Vector2.new(0, 20) }

local function isClear(candidate: Vector2): boolean
	for _, other in placed do
		if (candidate - other).Magnitude < MIN_ZONE_GAP then
			return false
		end
	end
	return true
end

local previous = Vector2.new(0, -20)
for index = 1, 38 do
	local candidate = position
	for attempt = 1, 16 do
		local tryHeading = heading + rng:NextNumber(-0.65, 0.65)
		-- steer back toward the middle when drifting too far out
		if position.Magnitude > 340 then
			tryHeading = math.atan2(-position.Y, -position.X) + rng:NextNumber(-0.35, 0.35)
		end
		local step = rng:NextNumber(56, 88) + attempt * 5
		candidate = position + Vector2.new(math.cos(tryHeading), math.sin(tryHeading)) * step
		if isClear(candidate) then
			heading = tryHeading
			break
		end
	end
	position = candidate
	table.insert(placed, position)

	-- candy road segment
	local from = Vector3.new(previous.X, 0.53, previous.Y)
	local to = Vector3.new(position.X, 0.53, position.Y)
	local length = (to - from).Magnitude
	part({
		Name = "Road",
		Size = Vector3.new(6, 0.08, length + 6),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = COLOR_ROAD,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

	local scale = rng:NextNumber(0.55, 1.9)
	local theme = THEMES[(index - 1) % #THEMES + 1]
	-- zone sits beside the road point, backdrop facing the arriving road
	local zoneCf = CFrame.lookAt(Vector3.new(position.X, 0, position.Y), Vector3.new(previous.X, 0, previous.Y))
	buildZone(index, theme, zoneCf * CFrame.Angles(0, math.pi, 0), scale)

	previous = position
end

----------------------------------------------------------------------
-- Spawn plaza: logo, disco ball, spawn point
----------------------------------------------------------------------

local logoWall = part({
	Name = "LogoWall",
	Size = Vector3.new(60, 10, 0.6),
	Position = Vector3.new(0, 14, 50),
	Color = Color3.fromRGB(58, 34, 84),
	Material = Enum.Material.SmoothPlastic,
})
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
	local logoGui = Instance.new("SurfaceGui")
	logoGui.Face = face
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
end

----------------------------------------------------------------------
-- Post-processing + disco ball + neon pulse (tuned, not blinding)
----------------------------------------------------------------------

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

local disco = part({
	Name = "DiscoBall",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(7, 7, 7),
	Position = Vector3.new(0, 19, 20),
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

task.spawn(function()
	while true do
		for _, pad in pulsePads do
			TweenService:Create(pad, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Transparency = 0.65 }):Play()
		end
		task.wait(1.15)
		for _, pad in pulsePads do
			TweenService:Create(pad, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Transparency = 0.4 }):Play()
		end
		task.wait(1.15)
	end
end)
