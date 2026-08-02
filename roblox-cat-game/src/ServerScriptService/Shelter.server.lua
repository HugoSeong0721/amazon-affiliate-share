-- Shelter (Script / ServerScriptService)
--
-- 이야기 속 "작은 고양이 쉼터"를 파츠로 짓는다.
-- 빈 벌판에서 쉼터 이야기를 하면 앞뒤가 안 맞으니, 실제로 보이는 장소를 만든다.
-- 여기도 에셋을 하나도 쓰지 않는다 (파츠 + SurfaceGui만).

local WOOD = Color3.fromRGB(154, 112, 74)
local WOOD_DARK = Color3.fromRGB(112, 80, 52)
local ROOF = Color3.fromRGB(178, 88, 74)
local FLOOR = Color3.fromRGB(198, 160, 116)
local BOWL = Color3.fromRGB(232, 122, 102)

local shelter = Instance.new("Model")
shelter.Name = "Shelter"

local function block(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or shelter
	return part
end

---------------------------------------------------------------
-- 쉼터 건물 (앞이 트인 헛간. 스폰 지점을 바라본다)
---------------------------------------------------------------
block("Floor", Vector3.new(24, 1, 14), Vector3.new(0, 0.5, -17), FLOOR)
block("BackWall", Vector3.new(24, 8, 1), Vector3.new(0, 4.5, -23.5), WOOD)
block("LeftWall", Vector3.new(1, 8, 14), Vector3.new(-11.5, 4.5, -17), WOOD)
block("RightWall", Vector3.new(1, 8, 14), Vector3.new(11.5, 4.5, -17), WOOD)
block("Roof", Vector3.new(26, 1, 17), Vector3.new(0, 9, -17.5), ROOF)

-- 앞을 받치는 기둥 두 개
block("PillarLeft", Vector3.new(1, 8, 1), Vector3.new(-11.5, 4.5, -10.5), WOOD_DARK)
block("PillarRight", Vector3.new(1, 8, 1), Vector3.new(11.5, 4.5, -10.5), WOOD_DARK)

-- 안쪽 조명 (밤에도 쉼터가 켜져 있는 느낌)
local lampPart = block("Lamp", Vector3.new(2, 0.4, 2), Vector3.new(0, 8.4, -17), Color3.fromRGB(255, 236, 190))
lampPart.Material = Enum.Material.Neon
local lamp = Instance.new("PointLight")
lamp.Color = Color3.fromRGB(255, 214, 150)
lamp.Range = 26
lamp.Brightness = 1.6
lamp.Parent = lampPart

---------------------------------------------------------------
-- 간판
---------------------------------------------------------------
local sign = block("Sign", Vector3.new(12, 2.6, 0.4), Vector3.new(0, 10.9, -9.4), WOOD_DARK)

local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Back -- 스폰 지점(+Z) 쪽을 향한다
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.PixelsPerStud = 50
signGui.Parent = sign

local signLabel = Instance.new("TextLabel")
signLabel.Size = UDim2.fromScale(1, 1)
signLabel.BackgroundTransparency = 1
signLabel.Text = "🐾  작은 고양이 쉼터"
signLabel.TextColor3 = Color3.fromRGB(255, 240, 214)
signLabel.TextScaled = true
signLabel.Font = Enum.Font.GothamBold
signLabel.Parent = signGui

---------------------------------------------------------------
-- 밥그릇 (밥 주는 곳이 어디인지 눈에 보이게)
---------------------------------------------------------------
for index, offsetX in ipairs({ -3.5, 3.5 }) do
	-- 로블록스 원기둥은 축이 X축이라, Z로 90도 돌려 세워야 납작한 그릇이 된다.
	-- 그래서 Size도 (높이, 지름, 지름) 순서로 준다.
	local bowl = block("Bowl" .. index, Vector3.new(0.7, 2.4, 2.4), Vector3.new(offsetX, 1.35, -12), BOWL)
	bowl.Shape = Enum.PartType.Cylinder
	bowl.Orientation = Vector3.new(0, 0, 90)
	block("Food" .. index, Vector3.new(1.6, 0.25, 1.6), Vector3.new(offsetX, 1.6, -12),
		Color3.fromRGB(226, 186, 122))
end

---------------------------------------------------------------
-- 마당 울타리 (쉼터의 경계가 보이도록)
---------------------------------------------------------------
local YARD_MIN_X, YARD_MAX_X = -30, 30
local YARD_MIN_Z, YARD_MAX_Z = -30, 22
local FENCE_HEIGHT = 3.2

local function fenceRun(fromX, fromZ, toX, toZ)
	local isAlongX = math.abs(toX - fromX) > math.abs(toZ - fromZ)
	local length = isAlongX and math.abs(toX - fromX) or math.abs(toZ - fromZ)
	local midX, midZ = (fromX + toX) / 2, (fromZ + toZ) / 2

	local railSize = isAlongX and Vector3.new(length, 0.35, 0.3) or Vector3.new(0.3, 0.35, length)
	for _, height in ipairs({ 1.4, 2.5 }) do
		block("Rail", railSize, Vector3.new(midX, height, midZ), WOOD)
	end

	local posts = math.floor(length / 6)
	for index = 0, posts do
		local t = posts > 0 and index / posts or 0
		block("Post", Vector3.new(0.5, FENCE_HEIGHT, 0.5), Vector3.new(
			fromX + (toX - fromX) * t,
			FENCE_HEIGHT / 2,
			fromZ + (toZ - fromZ) * t), WOOD_DARK)
	end
end

fenceRun(YARD_MIN_X, YARD_MAX_Z, YARD_MAX_X, YARD_MAX_Z) -- 앞
fenceRun(YARD_MIN_X, YARD_MIN_Z, YARD_MIN_X, YARD_MAX_Z) -- 왼쪽
fenceRun(YARD_MAX_X, YARD_MIN_Z, YARD_MAX_X, YARD_MAX_Z) -- 오른쪽
fenceRun(YARD_MIN_X, YARD_MIN_Z, YARD_MIN_X + 18, YARD_MIN_Z) -- 뒤 (건물 양옆만)
fenceRun(YARD_MAX_X - 18, YARD_MIN_Z, YARD_MAX_X, YARD_MIN_Z)

---------------------------------------------------------------
-- 마당 나무 몇 그루
---------------------------------------------------------------
for _, spot in ipairs({
	Vector3.new(-22, 0, 10),
	Vector3.new(23, 0, 6),
	Vector3.new(-19, 0, -20),
	Vector3.new(21, 0, -21),
}) do
	block("Trunk", Vector3.new(1.4, 7, 1.4), spot + Vector3.new(0, 3.5, 0), Color3.fromRGB(112, 82, 58))
	local leaves = block("Leaves", Vector3.new(7, 7, 7), spot + Vector3.new(0, 8.5, 0),
		Color3.fromRGB(96, 158, 84))
	leaves.Shape = Enum.PartType.Ball
end

shelter.Parent = workspace
