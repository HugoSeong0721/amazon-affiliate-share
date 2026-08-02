-- CatGameClient (LocalScript / StarterPlayer > StarterPlayerScripts)
-- 게임 UI 전부를 코드로 만든다: 코인 표시, 상점, 내 고양이 목록, 알림

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))

local remotes = ReplicatedStorage:WaitForChild("CatGameRemotes")
local buyCatRemote = remotes:WaitForChild("BuyCat")
local toggleEquipRemote = remotes:WaitForChild("ToggleEquip")
local requestDataRemote = remotes:WaitForChild("RequestData")
local dataChangedRemote = remotes:WaitForChild("DataChanged")
local notifyRemote = remotes:WaitForChild("Notify")

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

local COLOR_PANEL = Color3.fromRGB(255, 248, 235)
local COLOR_TITLE = Color3.fromRGB(120, 84, 50)
local COLOR_TEXT = Color3.fromRGB(70, 52, 32)
local COLOR_BUTTON = Color3.fromRGB(255, 166, 61)
local COLOR_BUTTON_OFF = Color3.fromRGB(196, 178, 155)

local gui = make("ScreenGui", { Name = "CatGameGui", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------
-- 코인 표시 (화면 위 가운데)
---------------------------------------------------------------
local coinLabel = make("TextLabel", {
	Size = UDim2.fromOffset(250, 46),
	Position = UDim2.new(0.5, -125, 0, 10),
	BackgroundColor3 = Color3.fromRGB(45, 36, 26),
	BackgroundTransparency = 0.15,
	Text = "🪙 후원금 0",
	TextColor3 = Color3.fromRGB(255, 216, 92),
	TextSize = 24,
	Font = Enum.Font.GothamBold,
}, gui)
round(coinLabel, 14)

-- 조작 힌트 (화면 아래). 튜토리얼이 도는 동안에는 튜토리얼이 이걸 숨긴다.
local hint = make("TextLabel", {
	Name = "Hint",
	Size = UDim2.new(0, 520, 0, 30),
	Position = UDim2.new(0.5, -260, 1, -42),
	BackgroundTransparency = 1,
	Text = "고양이 근처에서 [E] 키로 밥을 주세요. 돌보는 걸 본 이웃이 후원금을 놓고 갑니다 🍚",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	TextSize = 16,
	Font = Enum.Font.GothamMedium,
}, gui)
hint.TextWrapped = true

---------------------------------------------------------------
-- 알림 토스트
---------------------------------------------------------------
-- 상점 패널 위로 확실히 보이도록 ZIndex를 높게 잡는다.
-- (예전에는 "구조 비용이 모자라요" 안내가 패널에 가려 버튼이 고장난 것처럼 보였다)
local toast = make("TextLabel", {
	Size = UDim2.new(0, 560, 0, 50),
	Position = UDim2.new(0.5, -280, 0, 62),
	BackgroundColor3 = Color3.fromRGB(45, 36, 26),
	BackgroundTransparency = 0.08,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextWrapped = true,
	ZIndex = 50,
	Visible = false,
}, gui)
round(toast, 12)

local toastToken = 0
notifyRemote.OnClientEvent:Connect(function(message)
	toastToken = toastToken + 1
	local myToken = toastToken
	toast.Text = tostring(message)
	toast.Visible = true
	task.delay(3.5, function()
		if toastToken == myToken then
			toast.Visible = false
		end
	end)
end)

---------------------------------------------------------------
-- 패널 공통 (상점 / 내 고양이)
---------------------------------------------------------------
local function makePanel(titleText)
	local panel = make("Frame", {
		Size = UDim2.fromOffset(420, 440),
		Position = UDim2.new(0.5, -210, 0.5, -220),
		BackgroundColor3 = COLOR_PANEL,
		Visible = false,
	}, gui)
	round(panel, 16)

	make("TextLabel", {
		Size = UDim2.new(1, -60, 0, 48),
		Position = UDim2.fromOffset(20, 4),
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = COLOR_TITLE,
		TextSize = 23,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)

	local closeButton = make("TextButton", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -46, 0, 10),
		BackgroundColor3 = Color3.fromRGB(235, 105, 95),
		Text = "✕",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	}, panel)
	round(closeButton, 10)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = make("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -70),
		Position = UDim2.fromOffset(12, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	}, panel)
	local layout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
	layout.Padding = UDim.new(0, 8)

	return panel, list
end

local function makeRow(list, order, height)
	local row = make("Frame", {
		Size = UDim2.new(1, -8, 0, height or 64),
		BackgroundColor3 = Color3.fromRGB(255, 238, 214),
		LayoutOrder = order,
	}, list)
	round(row, 12)
	return row
end

local shopPanel, shopList = makePanel("🐾 도움이 필요한 고양이들")
local invPanel, invList = makePanel("🏠 쉼터의 고양이들")

---------------------------------------------------------------
-- 구조 목록: 줄 자체는 고정이지만, 버튼은 후원금에 따라 매번 바뀐다.
-- 후원금이 모자라면 "얼마나 더 필요한지"를 버튼에 그대로 적는다.
---------------------------------------------------------------
local rescueRows = {}

for order, breed in ipairs(CatConfig.Breeds) do
	if breed.Price > 0 then
		local row = makeRow(shopList, order, 88)

		local swatch = make("Frame", {
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(12, 14),
			BackgroundColor3 = breed.BodyColor,
		}, row)
		round(swatch, 10)

		make("TextLabel", {
			Size = UDim2.new(1, -180, 0, 24),
			Position = UDim2.fromOffset(66, 8),
			BackgroundTransparency = 1,
			Text = breed.Name,
			TextColor3 = COLOR_TEXT,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local storyLabel = make("TextLabel", {
			Size = UDim2.new(1, -180, 0, 32),
			Position = UDim2.fromOffset(66, 30),
			BackgroundTransparency = 1,
			Text = breed.Story,
			TextColor3 = Color3.fromRGB(150, 122, 90),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}, row)
		storyLabel.LineHeight = 1.15

		make("TextLabel", {
			Size = UDim2.new(1, -180, 0, 18),
			Position = UDim2.fromOffset(66, 64),
			BackgroundTransparency = 1,
			Text = "구조 비용 🪙 " .. breed.Price,
			TextColor3 = Color3.fromRGB(180, 140, 60),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local rescueButton = make("TextButton", {
			Size = UDim2.fromOffset(100, 44),
			Position = UDim2.new(1, -112, 0, 22),
			BackgroundColor3 = COLOR_BUTTON,
			Text = "데려오기",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
		}, row)
		round(rescueButton, 10)
		rescueButton.Activated:Connect(function()
			buyCatRemote:FireServer(breed.Id)
		end)

		table.insert(rescueRows, { Breed = breed, Button = rescueButton })
	end
end

-- 후원금/보유 현황이 바뀔 때마다 버튼 상태를 다시 칠한다
local function refreshRescueButtons(data)
	local alreadyHome = {}
	for _, cat in ipairs(data.Cats) do
		alreadyHome[cat.Breed] = true
	end

	for _, entry in ipairs(rescueRows) do
		local breed, button = entry.Breed, entry.Button
		if alreadyHome[breed.Id] then
			button.Text = "쉼터에 있음"
			button.BackgroundColor3 = Color3.fromRGB(168, 196, 150)
			button.AutoButtonColor = false
		elseif data.Coins >= breed.Price then
			button.Text = "데려오기"
			button.BackgroundColor3 = COLOR_BUTTON
			button.AutoButtonColor = true
		else
			button.Text = string.format("🪙 %d 더", breed.Price - data.Coins)
			button.BackgroundColor3 = COLOR_BUTTON_OFF
			button.AutoButtonColor = true
		end
	end
end

---------------------------------------------------------------
-- 내 고양이: 데이터가 바뀔 때마다 다시 그린다
---------------------------------------------------------------
local function rebuildInventory(cats)
	for _, child in ipairs(invList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, cat in ipairs(cats) do
		local breed = CatConfig.GetBreed(cat.Breed)
		if breed then
			local row = makeRow(invList, index, 76)

			local swatch = make("Frame", {
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.fromOffset(12, 16),
				BackgroundColor3 = breed.BodyColor,
			}, row)
			round(swatch, 10)

			make("TextLabel", {
				Size = UDim2.new(1, -180, 0, 24),
				Position = UDim2.fromOffset(66, 10),
				BackgroundTransparency = 1,
				Text = string.format("%s  Lv.%d", breed.Name, cat.Level),
				TextColor3 = COLOR_TEXT,
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)

			make("TextLabel", {
				Size = UDim2.new(1, -180, 0, 20),
				Position = UDim2.fromOffset(66, 34),
				BackgroundTransparency = 1,
				Text = string.format("건강 %d / %d", cat.Xp, CatConfig.XpForLevel(cat.Level)),
				TextColor3 = Color3.fromRGB(180, 140, 60),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)

			make("TextLabel", {
				Size = UDim2.new(1, -180, 0, 18),
				Position = UDim2.fromOffset(66, 54),
				BackgroundTransparency = 1,
				Text = breed.Story,
				TextColor3 = Color3.fromRGB(170, 145, 115),
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, row)

			local equipButton = make("TextButton", {
				Size = UDim2.fromOffset(100, 42),
				Position = UDim2.new(1, -112, 0, 17),
				BackgroundColor3 = cat.Equipped and COLOR_BUTTON_OFF or COLOR_BUTTON,
				Text = cat.Equipped and "쉬게 하기" or "함께 다니기",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 15,
				Font = Enum.Font.GothamBold,
			}, row)
			round(equipButton, 10)
			equipButton.Activated:Connect(function()
				toggleEquipRemote:FireServer(index)
			end)
		end
	end
end

dataChangedRemote.OnClientEvent:Connect(function(data)
	coinLabel.Text = "🪙 후원금 " .. tostring(data.Coins)
	rebuildInventory(data.Cats)
	refreshRescueButtons(data)
end)

---------------------------------------------------------------
-- 패널 열기 버튼 (화면 왼쪽)
---------------------------------------------------------------
local function makeSideButton(name, text, offsetY, panelToOpen, panelToClose)
	local button = make("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(140, 48),
		Position = UDim2.new(0, 14, 0.5, offsetY),
		BackgroundColor3 = COLOR_BUTTON,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 19,
		Font = Enum.Font.GothamBold,
	}, gui)
	round(button, 12)
	button.Activated:Connect(function()
		panelToClose.Visible = false
		panelToOpen.Visible = not panelToOpen.Visible
	end)
	return button
end

makeSideButton("ShopButton", "🐾 구조하기", -56, shopPanel, invPanel)
makeSideButton("InventoryButton", "🏠 우리 고양이", 4, invPanel, shopPanel)

-- UI 준비 완료 → 서버에 첫 데이터 요청
requestDataRemote:FireServer()
