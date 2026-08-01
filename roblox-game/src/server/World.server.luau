--!strict
-- Builds the dressing room. Kept in its own Script so the room always
-- exists even if the game-logic script hits an error.

local COLOR_FLOOR = Color3.fromRGB(255, 214, 231)
local COLOR_WALL = Color3.fromRGB(244, 226, 255)
local COLOR_ACCENT = Color3.fromRGB(255, 89, 158)
local COLOR_NEON_B = Color3.fromRGB(120, 220, 255)

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

part({
	Name = "Floor",
	Size = Vector3.new(64, 1, 64),
	Position = Vector3.new(0, 0, 0),
	Color = COLOR_FLOOR,
	Material = Enum.Material.SmoothPlastic,
})

local wallSpecs = {
	{ Vector3.new(64, 20, 1), Vector3.new(0, 10, -32) },
	{ Vector3.new(64, 20, 1), Vector3.new(0, 10, 32) },
	{ Vector3.new(1, 20, 64), Vector3.new(-32, 10, 0) },
	{ Vector3.new(1, 20, 64), Vector3.new(32, 10, 0) },
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

local backdrop = part({
	Name = "PhotoBackdrop",
	Size = Vector3.new(18, 12, 0.5),
	Position = Vector3.new(0, 6.5, -31),
	Color = Color3.fromRGB(40, 20, 60),
	Material = Enum.Material.SmoothPlastic,
})
local frameSpecs = {
	{ Vector3.new(18.8, 0.6, 0.7), Vector3.new(0, 12.6, -31) },
	{ Vector3.new(18.8, 0.6, 0.7), Vector3.new(0, 0.9, -31) },
	{ Vector3.new(0.6, 12.4, 0.7), Vector3.new(-9.2, 6.7, -31) },
	{ Vector3.new(0.6, 12.4, 0.7), Vector3.new(9.2, 6.7, -31) },
}
for index, spec in frameSpecs do
	part({
		Name = "PhotoFrameNeon",
		Size = spec[1],
		Position = spec[2],
		Color = index % 2 == 0 and COLOR_ACCENT or COLOR_NEON_B,
		Material = Enum.Material.Neon,
	})
end

part({
	Name = "PhotoSpot",
	Size = Vector3.new(6, 0.1, 6),
	Position = Vector3.new(0, 0.55, -27),
	Color = COLOR_ACCENT,
	Material = Enum.Material.Neon,
	Transparency = 0.4,
})

local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.CanvasSize = Vector2.new(900, 600)
signGui.Parent = backdrop
local signLabel = Instance.new("TextLabel")
signLabel.Size = UDim2.fromScale(1, 0.4)
signLabel.Position = UDim2.fromScale(0, 0.05)
signLabel.BackgroundTransparency = 1
signLabel.Text = "COMEBACK! \u{2728}"
signLabel.Font = Enum.Font.FredokaOne
signLabel.TextScaled = true
signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
signLabel.Parent = signGui

local lightPart = part({
	Name = "SpotlightAnchor",
	Size = Vector3.new(1, 1, 1),
	Position = Vector3.new(0, 16, -24),
	Transparency = 1,
	CanCollide = false,
})
local spot = Instance.new("SpotLight")
spot.Angle = 70
spot.Brightness = 3
spot.Range = 30
spot.Face = Enum.NormalId.Bottom
spot.Color = Color3.fromRGB(255, 235, 245)
spot.Parent = lightPart

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(0, 0.5, 10)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Transparency = 1
spawnLocation.CanCollide = true
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = workspace
