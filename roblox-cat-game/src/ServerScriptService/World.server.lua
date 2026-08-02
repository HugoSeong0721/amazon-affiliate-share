-- World (Script / ServerScriptService)
--
-- 구역 다섯 곳을 일렬로 짓는다. 구역마다:
--   · 바닥 발판과 이름 간판
--   · 상자 받침대 (E를 누르면 뽑기)
--   · 다음 구역으로 가는 문 (E를 누르면 코인 내고 해금)
--
-- 에셋 없이 파츠 + SurfaceGui/BillboardGui 만 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))
local BigNumber = require(ReplicatedStorage:WaitForChild("BigNumber"))

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

local ZONE_TINTS = {
	Yard = Color3.fromRGB(120, 174, 96),
	Alley = Color3.fromRGB(104, 104, 116),
	Park = Color3.fromRGB(94, 166, 120),
	Harbor = Color3.fromRGB(96, 138, 156),
	Rooftop = Color3.fromRGB(78, 74, 112),
}

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
	part.Parent = parent or world
	return part
end

local function billboard(parent, height, text, color, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size or 260, 70)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

---------------------------------------------------------------
-- 구역별 건설
---------------------------------------------------------------
local gateLabels = {} -- zoneId → 문 위 안내문 (해금되면 지운다)
local gateParts = {}

for index, zone in ipairs(CatConfig.Zones) do
	local tint = ZONE_TINTS[zone.Id] or Color3.fromRGB(120, 120, 120)

	-- 바닥
	block("Ground_" .. zone.Id, Vector3.new(110, 2, 110), zone.Origin + Vector3.new(0, -1, 0), tint)

	-- 구역 이름 간판
	local signPost = block("Sign_" .. zone.Id, Vector3.new(1, 9, 1),
		zone.Origin + Vector3.new(-46, 4.5, 46), Color3.fromRGB(90, 68, 48))
	billboard(signPost, 6, ("%s"):format(zone.Name), Color3.fromRGB(255, 240, 200), 300)

	-- 상자 받침대
	local pedestal = block("EggPedestal_" .. zone.Id, Vector3.new(8, 3, 8),
		zone.Origin + Vector3.new(0, 1.5, 0), Color3.fromRGB(86, 74, 66))
	local egg = block("Egg_" .. zone.Id, Vector3.new(5, 5, 5),
		zone.Origin + Vector3.new(0, 5.6, 0), Color3.fromRGB(236, 222, 196))
	egg.Shape = Enum.PartType.Ball

	billboard(egg, 4.6, ("📦 %s\n%s 코인"):format(zone.EggName, BigNumber.Short(zone.EggCost)),
		Color3.fromRGB(255, 236, 180), 320)

	local hatchPrompt = Instance.new("ProximityPrompt")
	hatchPrompt.ObjectText = zone.EggName
	hatchPrompt.ActionText = "상자 열기"
	hatchPrompt.HoldDuration = 0
	hatchPrompt.MaxActivationDistance = 16
	hatchPrompt.RequiresLineOfSight = false
	hatchPrompt.Parent = egg

	hatchPrompt.Triggered:Connect(function(player)
		if _G.CatGame and _G.CatGame.HatchEgg then
			_G.CatGame.HatchEgg(player, zone.Id, 1)
		end
	end)

	-- 다음 구역으로 가는 문
	local nextZone = CatConfig.Zones[index + 1]
	if nextZone then
		local midpoint = (zone.Origin + nextZone.Origin) * 0.5
		local gate = block("Gate_" .. nextZone.Id, Vector3.new(30, 14, 3),
			midpoint + Vector3.new(0, 7, 0), Color3.fromRGB(58, 52, 62))
		gate.Transparency = 0.25

		local label = billboard(gate, 9,
			("🔒 %s\n%s 코인"):format(nextZone.Name, BigNumber.Short(nextZone.UnlockCost)),
			Color3.fromRGB(255, 198, 120), 340)

		local unlockPrompt = Instance.new("ProximityPrompt")
		unlockPrompt.ObjectText = nextZone.Name
		unlockPrompt.ActionText = "문 열기"
		unlockPrompt.HoldDuration = 0
		unlockPrompt.MaxActivationDistance = 18
		unlockPrompt.RequiresLineOfSight = false
		unlockPrompt.Parent = gate

		unlockPrompt.Triggered:Connect(function(player)
			if _G.CatGame and _G.CatGame.UnlockZone then
				_G.CatGame.UnlockZone(player, nextZone.Id)
			end
		end)

		gateLabels[nextZone.Id] = label
		gateParts[nextZone.Id] = gate
	end
end

---------------------------------------------------------------
-- 해금 상태에 맞춰 문을 열어준다
--
-- 문은 플레이어마다 상태가 다르므로, 서버에서 전부 없앨 수는 없다.
-- 대신 잠긴 사람에게만 막힌 것처럼 보이도록 충돌만 조절한다.
-- (1인 데모 기준. 여러 명이면 구역별 개인 서버나 로컬 처리로 바꿔야 한다)
---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.5)
		for zoneId, gate in pairs(gateParts) do
			local anyoneUnlocked = false
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = _G.CatGame and _G.CatGame.GetProfile and _G.CatGame.GetProfile(player)
				if profile and profile.Zones[zoneId] then
					anyoneUnlocked = true
					break
				end
			end

			gate.CanCollide = not anyoneUnlocked
			gate.Transparency = anyoneUnlocked and 0.85 or 0.25
			local label = gateLabels[zoneId]
			if label then
				local zone = CatConfig.GetZone(zoneId)
				label.Text = anyoneUnlocked
					and ("✅ %s"):format(zone.Name)
					or ("🔒 %s\n%s 코인"):format(zone.Name, BigNumber.Short(zone.UnlockCost))
			end
		end
	end
end)
