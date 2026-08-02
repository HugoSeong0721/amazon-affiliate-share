-- CatGameClient (LocalScript / StarterPlayer > StarterPlayerScripts)
--
-- 화면 UI 전부를 코드로 만든다.
--   위      : 코인 · 파워 · 현재 구역
--   왼쪽    : 고양이 / 구역 / 환생 버튼
--   가운데  : 패널 (열었을 때만)
--   부술 때 : 화면에 코인이 튀어오르는 표시

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))
local BigNumber = require(ReplicatedStorage:WaitForChild("BigNumber"))

local remotes = ReplicatedStorage:WaitForChild("CatGameRemotes")
local hatchRemote = remotes:WaitForChild("HatchEgg")
local toggleEquipRemote = remotes:WaitForChild("ToggleEquip")
local fuseRemote = remotes:WaitForChild("FuseCats")
local unlockZoneRemote = remotes:WaitForChild("UnlockZone")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local requestDataRemote = remotes:WaitForChild("RequestData")
local dataChangedRemote = remotes:WaitForChild("DataChanged")
local notifyRemote = remotes:WaitForChild("Notify")
local hatchResultRemote = remotes:WaitForChild("HatchResult")
local rewardRemote = remotes:WaitForChild("Reward")

---------------------------------------------------------------
-- UI 헬퍼
---------------------------------------------------------------
local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local DARK = Color3.fromRGB(32, 30, 40)
local PANEL = Color3.fromRGB(248, 244, 238)
local ROW = Color3.fromRGB(236, 230, 222)
local TEXT = Color3.fromRGB(52, 46, 40)
local SUB = Color3.fromRGB(140, 128, 116)
local ACCENT = Color3.fromRGB(255, 158, 56)
local OFF = Color3.fromRGB(186, 178, 170)

local gui = make("ScreenGui", { Name = "CatGameGui", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local latest = { Coins = 0, Cats = {}, Equipped = {}, Zones = {}, Power = 0, Rebirths = 0 }

---------------------------------------------------------------
-- 상단 HUD
---------------------------------------------------------------
local function makeChip(name, x, width, icon, color)
	local frame = make("Frame", {
		Name = name,
		Size = UDim2.fromOffset(width, 44),
		Position = UDim2.new(0.5, x, 0, 10),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.1,
	}, gui)
	round(frame, 12)

	local label = make("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = icon .. " 0",
		TextColor3 = color,
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	}, frame)
	return label
end

local coinLabel = makeChip("CoinChip", -230, 150, "🪙", Color3.fromRGB(255, 214, 92))
local powerLabel = makeChip("PowerChip", -74, 150, "⚡", Color3.fromRGB(255, 138, 138))
local zoneLabel = makeChip("ZoneChip", 82, 150, "📍", Color3.fromRGB(158, 214, 255))

---------------------------------------------------------------
-- 안내 토스트
---------------------------------------------------------------
local toast = make("TextLabel", {
	Name = "Toast",
	Size = UDim2.new(0, 620, 0, 48),
	Position = UDim2.new(0.5, -310, 0, 62),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.08,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextWrapped = true,
	ZIndex = 60,
	Visible = false,
}, gui)
round(toast, 12)

local toastToken = 0
local function showToast(message)
	toastToken += 1
	local token = toastToken
	toast.Text = tostring(message)
	toast.Visible = true
	task.delay(3.5, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

notifyRemote.OnClientEvent:Connect(showToast)

---------------------------------------------------------------
-- 부술 때 튀어오르는 코인 표시
---------------------------------------------------------------
local rewardHolder = make("Frame", {
	Name = "RewardHolder",
	Size = UDim2.fromOffset(300, 200),
	Position = UDim2.new(0.5, 60, 0.5, -100),
	BackgroundTransparency = 1,
}, gui)

rewardRemote.OnClientEvent:Connect(function(amount)
	local label = make("TextLabel", {
		Size = UDim2.fromOffset(220, 34),
		Position = UDim2.fromOffset(math.random(0, 60), 150),
		BackgroundTransparency = 1,
		Text = "+" .. BigNumber.Short(amount),
		TextColor3 = Color3.fromRGB(255, 226, 120),
		TextStrokeTransparency = 0.3,
		TextSize = 26,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, rewardHolder)

	-- 위로 떠오르며 사라진다
	task.spawn(function()
		for step = 1, 18 do
			label.Position = label.Position - UDim2.fromOffset(0, 6)
			label.TextTransparency = step / 18
			task.wait(0.03)
		end
		label:Destroy()
	end)
end)

---------------------------------------------------------------
-- 패널 공통
---------------------------------------------------------------
local panels = {}

local function makePanel(name, titleText)
	local panel = make("Frame", {
		Name = name,
		Size = UDim2.fromOffset(460, 470),
		Position = UDim2.new(0.5, -230, 0.5, -235),
		BackgroundColor3 = PANEL,
		Visible = false,
	}, gui)
	round(panel, 16)

	make("TextLabel", {
		Size = UDim2.new(1, -70, 0, 46),
		Position = UDim2.fromOffset(20, 6),
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = TEXT,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)

	local closeButton = make("TextButton", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -46, 0, 10),
		BackgroundColor3 = Color3.fromRGB(232, 104, 96),
		Text = "✕",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 17,
		Font = Enum.Font.GothamBold,
	}, panel)
	round(closeButton, 10)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = make("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -62),
		Position = UDim2.fromOffset(12, 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	}, panel)
	local layout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
	layout.Padding = UDim.new(0, 8)

	table.insert(panels, panel)
	return panel, list
end

local catsPanel, catsList = makePanel("CatsPanel", "🐱 내 고양이")
local zonesPanel, zonesList = makePanel("ZonesPanel", "🗺️ 구역")
local rebirthPanel, rebirthList = makePanel("RebirthPanel", "🌟 환생")

local function openOnly(target)
	for _, panel in ipairs(panels) do
		panel.Visible = (panel == target) and not panel.Visible or false
	end
end

local function makeRow(list, order, height)
	local row = make("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = ROW,
		LayoutOrder = order,
	}, list)
	round(row, 12)
	return row
end

---------------------------------------------------------------
-- 내 고양이 (장착 / 합성)
---------------------------------------------------------------
local function isEquipped(uid)
	for _, equippedUid in ipairs(latest.Equipped) do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

local function rebuildCats()
	for _, child in ipairs(catsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- 같은 종류끼리 묶어서 보여준다 (마리 수가 금방 많아지기 때문)
	local groups, order = {}, {}
	for _, entry in ipairs(latest.Cats) do
		local key = entry.Id .. (entry.Golden and "_G" or "")
		if not groups[key] then
			groups[key] = { Id = entry.Id, Golden = entry.Golden, Entries = {} }
			table.insert(order, key)
		end
		table.insert(groups[key].Entries, entry)
	end

	table.sort(order, function(a, b)
		return CatConfig.PowerOf(groups[a]) > CatConfig.PowerOf(groups[b])
	end)

	for index, key in ipairs(order) do
		local group = groups[key]
		local cat = CatConfig.GetCat(group.Id)
		local rarity = CatConfig.Rarities[cat.Rarity]
		local row = makeRow(catsList, index, 78)

		local swatch = make("Frame", {
			Size = UDim2.fromOffset(46, 46),
			Position = UDim2.fromOffset(12, 16),
			BackgroundColor3 = group.Golden and Color3.fromRGB(255, 214, 92) or cat.Body,
		}, row)
		round(swatch, 10)
		make("UIStroke", { Color = rarity.Color, Thickness = 2.5 }, swatch)

		make("TextLabel", {
			Size = UDim2.new(1, -230, 0, 24),
			Position = UDim2.fromOffset(70, 10),
			BackgroundTransparency = 1,
			Text = ("%s%s  ×%d"):format(group.Golden and "✨ 골든 " or "", cat.Name, #group.Entries),
			TextColor3 = TEXT,
			TextSize = 17,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		make("TextLabel", {
			Size = UDim2.new(1, -230, 0, 20),
			Position = UDim2.fromOffset(70, 34),
			BackgroundTransparency = 1,
			Text = ("%s  ·  파워 %s"):format(rarity.Name, BigNumber.Short(CatConfig.PowerOf(group))),
			TextColor3 = rarity.Color,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local equippedHere = 0
		for _, entry in ipairs(group.Entries) do
			if isEquipped(entry.Uid) then
				equippedHere += 1
			end
		end

		make("TextLabel", {
			Size = UDim2.new(1, -230, 0, 18),
			Position = UDim2.fromOffset(70, 54),
			BackgroundTransparency = 1,
			Text = equippedHere > 0 and ("데리고 다니는 중 %d마리"):format(equippedHere) or "쉬는 중",
			TextColor3 = SUB,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		-- 장착 토글: 그룹의 첫 마리를 대상으로 한다
		local target = group.Entries[1]
		for _, entry in ipairs(group.Entries) do
			if isEquipped(entry.Uid) then
				target = entry
				break
			end
		end
		local targetEquipped = isEquipped(target.Uid)

		local equipButton = make("TextButton", {
			Size = UDim2.fromOffset(96, 38),
			Position = UDim2.new(1, -212, 0, 20),
			BackgroundColor3 = targetEquipped and OFF or ACCENT,
			Text = targetEquipped and "빼기" or "데려가기",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 15,
			Font = Enum.Font.GothamBold,
		}, row)
		round(equipButton, 9)
		equipButton.Activated:Connect(function()
			toggleEquipRemote:FireServer(target.Uid)
		end)

		-- 합성
		local canFuse = (not group.Golden) and #group.Entries >= CatConfig.FuseCount
		local fuseButton = make("TextButton", {
			Size = UDim2.fromOffset(100, 38),
			Position = UDim2.new(1, -108, 0, 20),
			BackgroundColor3 = canFuse and Color3.fromRGB(196, 148, 255) or OFF,
			Text = canFuse and "✨ 합성" or ("합성 %d/%d"):format(
				math.min(#group.Entries, CatConfig.FuseCount), CatConfig.FuseCount),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
		}, row)
		round(fuseButton, 9)
		fuseButton.Activated:Connect(function()
			if group.Golden then
				showToast("골든끼리는 합성할 수 없어요")
			else
				fuseRemote:FireServer(group.Id)
			end
		end)
	end
end

---------------------------------------------------------------
-- 구역 목록
---------------------------------------------------------------
local function rebuildZones()
	for _, child in ipairs(zonesList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, zone in ipairs(CatConfig.Zones) do
		local unlocked = latest.Zones[zone.Id] == true
		local previous = CatConfig.Zones[index - 1]
		local previousDone = (previous == nil) or (latest.Zones[previous.Id] == true)
		local row = makeRow(zonesList, index, 84)

		make("TextLabel", {
			Size = UDim2.new(1, -140, 0, 24),
			Position = UDim2.fromOffset(16, 10),
			BackgroundTransparency = 1,
			Text = ("%s %s"):format(unlocked and "✅" or "🔒", zone.Name),
			TextColor3 = TEXT,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		make("TextLabel", {
			Size = UDim2.new(1, -140, 0, 20),
			Position = UDim2.fromOffset(16, 34),
			BackgroundTransparency = 1,
			Text = ("물건 체력 %s  ·  개당 %s 코인"):format(
				BigNumber.Short(zone.BreakableHp), BigNumber.Short(zone.Reward)),
			TextColor3 = SUB,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		make("TextLabel", {
			Size = UDim2.new(1, -140, 0, 20),
			Position = UDim2.fromOffset(16, 54),
			BackgroundTransparency = 1,
			Text = ("📦 %s  %s 코인"):format(zone.EggName, BigNumber.Short(zone.EggCost)),
			TextColor3 = Color3.fromRGB(186, 146, 66),
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		if not unlocked then
			local affordable = latest.Coins >= zone.UnlockCost and previousDone
			local button = make("TextButton", {
				Size = UDim2.fromOffset(112, 44),
				Position = UDim2.new(1, -124, 0, 20),
				BackgroundColor3 = affordable and ACCENT or OFF,
				Text = previousDone
					and (affordable and "열기" or ("🪙 " .. BigNumber.Short(zone.UnlockCost - latest.Coins) .. " 더"))
					or "이전 구역 먼저",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
			}, row)
			round(button, 9)
			button.Activated:Connect(function()
				unlockZoneRemote:FireServer(zone.Id)
			end)
		else
			local button = make("TextButton", {
				Size = UDim2.fromOffset(112, 44),
				Position = UDim2.new(1, -124, 0, 20),
				BackgroundColor3 = latest.Coins >= zone.EggCost and ACCENT or OFF,
				Text = "📦 상자 열기",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
			}, row)
			round(button, 9)
			button.Activated:Connect(function()
				hatchRemote:FireServer(zone.Id, 1)
			end)
		end
	end
end

---------------------------------------------------------------
-- 환생
---------------------------------------------------------------
local function rebuildRebirth()
	for _, child in ipairs(rebirthList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local lastZone = CatConfig.Zones[#CatConfig.Zones]
	local reachedEnd = latest.Zones[lastZone.Id] == true
	local canRebirth = reachedEnd and latest.Coins >= CatConfig.RebirthCost

	local info = makeRow(rebirthList, 1, 150)
	local infoLabel = make("TextLabel", {
		Size = UDim2.new(1, -32, 1, -70),
		Position = UDim2.fromOffset(16, 12),
		BackgroundTransparency = 1,
		Text = ("환생하면 코인과 구역이 처음으로 돌아가지만,\n"
			.. "고양이는 그대로 남고 모든 파워가 %d%% 늘어납니다.\n\n"
			.. "지금까지 환생 %d회  ·  현재 배율 %d%%\n"
			.. "조건: %s 해금 + 코인 %s"):format(
			math.floor(CatConfig.RebirthPowerBonus * 100),
			latest.Rebirths,
			100 + math.floor(latest.Rebirths * CatConfig.RebirthPowerBonus * 100),
			lastZone.Name, BigNumber.Short(CatConfig.RebirthCost)),
		TextColor3 = TEXT,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, info)
	infoLabel.LineHeight = 1.3

	local button = make("TextButton", {
		Size = UDim2.new(1, -32, 0, 44),
		Position = UDim2.new(0, 16, 1, -56),
		BackgroundColor3 = canRebirth and Color3.fromRGB(255, 186, 58) or OFF,
		Text = canRebirth and "🌟 환생하기"
			or (reachedEnd and ("🪙 " .. BigNumber.Short(CatConfig.RebirthCost - latest.Coins) .. " 더")
				or (lastZone.Name .. " 먼저 해금")),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
	}, info)
	round(button, 10)
	button.Activated:Connect(function()
		rebirthRemote:FireServer()
	end)
end

---------------------------------------------------------------
-- 뽑기 결과 연출
---------------------------------------------------------------
hatchResultRemote.OnClientEvent:Connect(function(hatched)
	if type(hatched) ~= "table" or #hatched == 0 then
		return
	end
	local names = {}
	for _, catId in ipairs(hatched) do
		local cat = CatConfig.GetCat(catId)
		if cat then
			table.insert(names, ("%s(%s)"):format(cat.Name, CatConfig.Rarities[cat.Rarity].Name))
		end
	end
	showToast("📦 " .. table.concat(names, ", ") .. " 획득!")
end)

---------------------------------------------------------------
-- 데이터 갱신
---------------------------------------------------------------
dataChangedRemote.OnClientEvent:Connect(function(data)
	latest = data
	coinLabel.Text = "🪙 " .. BigNumber.Short(data.Coins)
	powerLabel.Text = "⚡ " .. BigNumber.Short(data.Power or 0)

	local zoneId = player:GetAttribute("ZoneId")
	local zone = zoneId and CatConfig.GetZone(zoneId)
	zoneLabel.Text = "📍 " .. (zone and zone.Name or "?")

	if catsPanel.Visible then rebuildCats() end
	if zonesPanel.Visible then rebuildZones() end
	if rebirthPanel.Visible then rebuildRebirth() end
end)

---------------------------------------------------------------
-- 왼쪽 버튼
---------------------------------------------------------------
local function makeSideButton(name, text, offsetY, panel, rebuild)
	local button = make("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(146, 46),
		Position = UDim2.new(0, 14, 0.5, offsetY),
		BackgroundColor3 = ACCENT,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 17,
		Font = Enum.Font.GothamBold,
	}, gui)
	round(button, 11)
	button.Activated:Connect(function()
		openOnly(panel)
		if panel.Visible then
			rebuild()
		end
	end)
	return button
end

makeSideButton("CatsButton", "🐱 내 고양이", -80, catsPanel, rebuildCats)
makeSideButton("ZonesButton", "🗺️ 구역", -26, zonesPanel, rebuildZones)
makeSideButton("RebirthButton", "🌟 환생", 28, rebirthPanel, rebuildRebirth)

-- 아래쪽 조작 안내 (튜토리얼이 도는 동안에는 숨긴다)
local hint = make("TextLabel", {
	Name = "Hint",
	Size = UDim2.new(0, 600, 0, 30),
	Position = UDim2.new(0.5, -300, 1, -42),
	BackgroundTransparency = 1,
	Text = "고양이가 알아서 부숴요. 상자 앞에서 [E]를 눌러 새 고양이를 뽑으세요 📦",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	TextSize = 16,
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
}, gui)

requestDataRemote:FireServer()
