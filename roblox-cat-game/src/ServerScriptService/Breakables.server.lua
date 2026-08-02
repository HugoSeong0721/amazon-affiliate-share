-- Breakables (Script / ServerScriptService)
--
-- 게임의 심장. 구역마다 부술 물건을 깔아두고, 근처 플레이어의 고양이들이
-- 자동으로 그걸 때린다. 다 부수면 코인이 나오고 잠시 뒤 다시 생긴다.
--
-- 플레이어의 총 파워와 현재 구역은 CatGameServer가 Player 속성에 올려둔 값을 읽는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))

local folder = Instance.new("Folder")
folder.Name = "Breakables"
folder.Parent = workspace

---------------------------------------------------------------
-- 물건 만들기
---------------------------------------------------------------
local breakables = {} -- { part, zone, maxHp, hp, alive, respawnAt, baseSize, label }

local function makeBreakable(zone, index)
	local skin = CatConfig.BreakableSkins[zone.Id] or CatConfig.BreakableSkins.Yard
	local count = zone.BreakableCount

	-- 구역 원점 주위에 둥글게 배치
	local angle = (index - 1) / count * math.pi * 2
	local radius = 22 + (index % 3) * 7
	local position = zone.Origin + Vector3.new(math.cos(angle) * radius, skin.Size / 2 + 0.5, math.sin(angle) * radius)

	local part = Instance.new("Part")
	part.Name = skin.Name
	part.Size = Vector3.new(skin.Size, skin.Size, skin.Size)
	part.Position = position
	part.Color = skin.Color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Name = "HpTag"
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffset = Vector3.new(0, skin.Size * 0.8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local record = {
		Part = part,
		Label = label,
		Zone = zone,
		MaxHp = zone.BreakableHp,
		Hp = zone.BreakableHp,
		Alive = true,
		RespawnAt = 0,
		BaseSize = part.Size,
		BasePosition = position,
	}
	table.insert(breakables, record)
	return record
end

for _, zone in ipairs(CatConfig.Zones) do
	for index = 1, zone.BreakableCount do
		makeBreakable(zone, index)
	end
end

---------------------------------------------------------------
-- 표시 갱신
---------------------------------------------------------------
local BigNumber = require(ReplicatedStorage:WaitForChild("BigNumber"))

local function refreshVisual(record)
	if not record.Alive then
		return
	end
	local ratio = math.clamp(record.Hp / record.MaxHp, 0, 1)
	record.Label.Text = BigNumber.Short(record.Hp)
	-- 체력이 닳을수록 작아져서 부서지는 느낌을 준다
	local shrink = 0.45 + ratio * 0.55
	record.Part.Size = record.BaseSize * shrink
	record.Part.Position = record.BasePosition
end

local function breakIt(record, player)
	record.Alive = false
	record.RespawnAt = os.clock() + CatConfig.BreakableRespawn
	record.Part.Transparency = 1
	record.Part.CanCollide = false
	record.Label.Text = ""

	if player and _G.CatGame then
		_G.CatGame.AwardCoins(player, record.Zone.Reward)
	end
end

local function respawn(record)
	record.Alive = true
	record.Hp = record.MaxHp
	record.Part.Transparency = 0
	record.Part.CanCollide = true
	refreshVisual(record)
end

for _, record in ipairs(breakables) do
	refreshVisual(record)
end

---------------------------------------------------------------
-- 공격 루프
---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(CatConfig.AttackInterval)
		local now = os.clock()

		-- 되살아날 때가 된 물건 처리
		for _, record in ipairs(breakables) do
			if not record.Alive and now >= record.RespawnAt then
				respawn(record)
			end
		end

		for _, player in ipairs(Players:GetPlayers()) do
			local power = player:GetAttribute("TotalPower") or 0
			local zoneId = player:GetAttribute("ZoneId")
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")

			if power > 0 and zoneId and rootPart then
				local origin = rootPart.Position

				-- 사거리 안에서 가장 가까운, 살아있는, 같은 구역의 물건
				local target, targetDistance = nil, math.huge
				for _, record in ipairs(breakables) do
					if record.Alive and record.Zone.Id == zoneId then
						local distance = (record.Part.Position - origin).Magnitude
						if distance <= CatConfig.AttackRange and distance < targetDistance then
							target, targetDistance = record, distance
						end
					end
				end

				if target then
					target.Hp -= power * CatConfig.AttackInterval
					if target.Hp <= 0 then
						breakIt(target, player)
					else
						refreshVisual(target)
					end
				end
			end
		end
	end
end)
