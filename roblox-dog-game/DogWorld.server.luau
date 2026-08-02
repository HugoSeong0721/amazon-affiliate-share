--[[
	🐶 멍멍 하우스! 강아지 키우기 — 월드 생성 스크립트 (DogWorld)

	넣는 위치: ServerScriptService (DogServer와 같은 곳, 별도 Script)
	※ build/*.rbxl 파일로 열었다면 이미 들어있습니다.

	공원 맵(잔디밭, 스폰, 나무, 꽃, 강아지 집, 안내판)을 파트만으로 만듭니다.
	게임 로직(DogServer)과 분리되어 있어서, 한쪽이 에러 나도
	다른 쪽은 계속 동작합니다.
]]

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = workspace
	return p
end

local function wedge(props)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		w[key] = value
	end
	w.Parent = workspace
	return w
end

----------------------------------------------------------------------
-- 잔디밭 + 보이지 않는 울타리
----------------------------------------------------------------------
part({
	Name = "Ground",
	Size = Vector3.new(560, 2, 560),
	Position = Vector3.new(0, -1, 0),
	Color = Color3.fromRGB(108, 180, 88),
	Material = Enum.Material.Grass,
})

for _, spec in ipairs({
	{ Vector3.new(560, 50, 2), Vector3.new(0, 25, -280) },
	{ Vector3.new(560, 50, 2), Vector3.new(0, 25, 280) },
	{ Vector3.new(2, 50, 560), Vector3.new(-280, 25, 0) },
	{ Vector3.new(2, 50, 560), Vector3.new(280, 25, 0) },
}) do
	part({
		Name = "Border",
		Size = spec[1],
		Position = spec[2],
		Transparency = 1,
	})
end

----------------------------------------------------------------------
-- 스폰 광장
----------------------------------------------------------------------
part({
	Name = "Plaza",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.4, 26, 26),
	CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(238, 220, 178),
})

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "Spawn"
spawnLocation.Size = Vector3.new(10, 1, 10)
spawnLocation.Position = Vector3.new(0, 0.9, 0)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.Color = Color3.fromRGB(250, 236, 200)
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = workspace

----------------------------------------------------------------------
-- 나무 (기둥 + 잎 뭉치)
----------------------------------------------------------------------
local function tree(x, z, size)
	size = size or 1
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(2 * size, 8 * size, 2 * size),
		Position = Vector3.new(x, 4 * size, z),
		Color = Color3.fromRGB(121, 85, 58),
		Material = Enum.Material.Wood,
	})
	for _, offset in ipairs({
		Vector3.new(0, 9.5, 0), Vector3.new(2.4, 8, 0.6),
		Vector3.new(-2.2, 8.2, -0.8), Vector3.new(0.4, 8, 2.3),
	}) do
		part({
			Name = "TreeLeaf",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(6 * size, 6 * size, 6 * size),
			Position = Vector3.new(x, 0, z) + offset * size,
			Color = Color3.fromRGB(84, 158, 72),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

for _, pos in ipairs({
	{ -40, -35, 1.2 }, { 45, -25, 1 }, { -55, 30, 1 }, { 60, 45, 1.3 },
	{ -25, 65, 0.9 }, { 30, -70, 1.1 }, { 90, -5, 1 }, { -90, -15, 1.2 },
	{ 15, 95, 1 }, { -70, -75, 1 }, { 100, 80, 1.2 }, { -110, 60, 1 },
}) do
	tree(pos[1], pos[2], pos[3])
end

----------------------------------------------------------------------
-- 꽃밭 (알록달록 점점이)
----------------------------------------------------------------------
local flowerColors = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 200, 80),
	Color3.fromRGB(160, 130, 255), Color3.fromRGB(255, 140, 90),
	Color3.fromRGB(255, 255, 255),
}
math.randomseed(42) -- 모든 서버가 똑같은 배치
for i = 1, 60 do
	local angle = math.random() * math.pi * 2
	local dist = 20 + math.random() * 110
	part({
		Name = "Flower",
		Size = Vector3.new(0.7, 0.9, 0.7),
		Position = Vector3.new(math.cos(angle) * dist, 0.45, math.sin(angle) * dist),
		Color = flowerColors[(i % #flowerColors) + 1],
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

----------------------------------------------------------------------
-- 강아지 집 (빨간 지붕)
----------------------------------------------------------------------
local houseCenter = Vector3.new(20, 0, -14)
part({
	Name = "DogHouseBody",
	Size = Vector3.new(9, 6, 9),
	Position = houseCenter + Vector3.new(0, 3, 0),
	Color = Color3.fromRGB(222, 170, 110),
	Material = Enum.Material.Wood,
})
part({
	Name = "DogHouseDoor",
	Size = Vector3.new(3.4, 4.2, 0.3),
	Position = houseCenter + Vector3.new(0, 2.1, -4.5),
	Color = Color3.fromRGB(64, 44, 28),
})
wedge({
	Name = "DogHouseRoofA",
	Size = Vector3.new(10, 3, 5.5),
	CFrame = CFrame.new(houseCenter + Vector3.new(0, 7.5, -2.75)) * CFrame.Angles(0, math.rad(180), 0),
	Color = Color3.fromRGB(196, 74, 62),
})
wedge({
	Name = "DogHouseRoofB",
	Size = Vector3.new(10, 3, 5.5),
	CFrame = CFrame.new(houseCenter + Vector3.new(0, 7.5, 2.75)),
	Color = Color3.fromRGB(196, 74, 62),
})

----------------------------------------------------------------------
-- 환영 안내판
----------------------------------------------------------------------
part({
	Name = "SignPost",
	Size = Vector3.new(0.8, 5, 0.8),
	Position = Vector3.new(-13, 2.5, -10),
	Color = Color3.fromRGB(121, 85, 58),
	Material = Enum.Material.Wood,
})
local board = part({
	Name = "SignBoard",
	Size = Vector3.new(11, 4.4, 0.6),
	Position = Vector3.new(-13, 6.4, -10),
	Color = Color3.fromRGB(250, 240, 214),
})

local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.PixelsPerStud = 42
signGui.Parent = board

local signText = Instance.new("TextLabel")
signText.Size = UDim2.new(1, 0, 1, 0)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.GothamBold
signText.TextScaled = true
signText.TextColor3 = Color3.fromRGB(92, 62, 32)
signText.Text = "🐶 멍멍 하우스!\n강아지를 쓰다듬고, 밥 주고,\n공놀이로 뼈다귀를 모아보세요!"
signText.Parent = signGui

local signGuiBack = signGui:Clone()
signGuiBack.Face = Enum.NormalId.Back
signGuiBack.Parent = board

print("[DogWorld] 🌳 공원 준비 완료!")
