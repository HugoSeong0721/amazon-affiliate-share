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
	Size = UDim2.fromOffset(190, 46),
	Position = UDim2.new(0.5, -95, 0, 10),
	BackgroundColor3 = Color3.fromRGB(45, 36, 26),
	BackgroundTransparency = 0.15,
	Text = "🪙 0",
	TextColor3 = Color3.fromRGB(255, 216, 92),
	TextSize = 26,
	Font = Enum.Font.GothamBold,
}, gui)
round(coinLabel, 14)

-- 조작 힌트 (화면 아래)
local hint = make("TextLabel", {
	Size = UDim2.new(0, 460, 0, 30),
	Position = UDim2.new(0.5, -230, 1, -42),
	BackgroundTransparency = 1,
	Text = "고양이 근처에서 [E] 키로 밥을 줄 수 있어요! 밥을 주면 코인과 경험치를 받아요 🍚",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	TextSize = 16,
	Font = Enum.Font.GothamMedium,
}, gui)
hint.TextWrapped = true

---------------------------------------------------------------
-- 알림 토스트
---------------------------------------------------------------
local toast = make("TextLabel", {
	Size = UDim2.new(0, 420, 0, 40),
	Position = UDim2.new(0.5, -210, 0, 64),
	BackgroundColor3 = Color3.fromRGB(45, 36, 26),
	BackgroundTransparency = 0.15,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
round(toast, 12)

local toastToken = 0
notifyRemote.OnClientEvent:Connect(function(message)
	toastToken = toastToken + 1
	local myToken = toastToken
	toast.Text = tostring(message)
	toast.Visible = true
	task.delay(2.5, function()
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
		Size = UDim2.fromOffset(340, 420),
		Position = UDim2.new(0.5, -170, 0.5, -210),
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
		TextSize = 24,
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

local function makeRow(list, order)
	local row = make("Frame", {
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = Color3.fromRGB(255, 238, 214),
		LayoutOrder = order,
	}, list)
	round(row, 12)
	return row
end

local shopPanel, shopList = makePanel("🛒 고양이 상점")
local invPanel, invList = makePanel("🐱 내 고양이")

---------------------------------------------------------------
-- 상점: 품종 목록은 고정이라 한 번만 만든다
---------------------------------------------------------------
for order, breed in ipairs(CatConfig.Breeds) do
	if breed.Price > 0 then
		local row = makeRow(shopList, order)

		local swatch = make("Frame", {
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.fromOffset(12, 12),
			BackgroundColor3 = breed.BodyColor,
		}, row)
		round(swatch, 10)

		make("TextLabel", {
			Size = UDim2.new(1, -160, 0, 26),
			Position = UDim2.fromOffset(62, 8),
			BackgroundTransparency = 1,
			Text = breed.Name,
			TextColor3 = COLOR_TEXT,
			TextSize = 19,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		make("TextLabel", {
			Size = UDim2.new(1, -160, 0, 20),
			Position = UDim2.fromOffset(62, 34),
			BackgroundTransparency = 1,
			Text = "🪙 " .. breed.Price,
			TextColor3 = Color3.fromRGB(180, 140, 60),
			TextSize = 16,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local buyButton = make("TextButton", {
			Size = UDim2.fromOffset(76, 40),
			Position = UDim2.new(1, -88, 0, 12),
			BackgroundColor3 = COLOR_BUTTON,
			Text = "입양",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 18,
			Font = Enum.Font.GothamBold,
		}, row)
		round(buyButton, 10)
		buyButton.Activated:Connect(function()
			buyCatRemote:FireServer(breed.Id)
		end)
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
			local row = makeRow(invList, index)

			local swatch = make("Frame", {
				Size = UDim2.fromOffset(40, 40),
				Position = UDim2.fromOffset(12, 12),
				BackgroundColor3 = breed.BodyColor,
			}, row)
			round(swatch, 10)

			make("TextLabel", {
				Size = UDim2.new(1, -180, 0, 26),
				Position = UDim2.fromOffset(62, 8),
				BackgroundTransparency = 1,
				Text = string.format("%s Lv.%d", breed.Name, cat.Level),
				TextColor3 = COLOR_TEXT,
				TextSize = 19,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)

			make("TextLabel", {
				Size = UDim2.new(1, -180, 0, 20),
				Position = UDim2.fromOffset(62, 34),
				BackgroundTransparency = 1,
				Text = string.format("경험치 %d / %d", cat.Xp, CatConfig.XpForLevel(cat.Level)),
				TextColor3 = Color3.fromRGB(180, 140, 60),
				TextSize = 15,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)

			local equipButton = make("TextButton", {
				Size = UDim2.fromOffset(96, 40),
				Position = UDim2.new(1, -108, 0, 12),
				BackgroundColor3 = cat.Equipped and COLOR_BUTTON_OFF or COLOR_BUTTON,
				Text = cat.Equipped and "쉬게 하기" or "데려가기",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 16,
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
	coinLabel.Text = "🪙 " .. tostring(data.Coins)
	rebuildInventory(data.Cats)
end)

---------------------------------------------------------------
-- 패널 열기 버튼 (화면 왼쪽)
---------------------------------------------------------------
local function makeSideButton(text, offsetY, panelToOpen, panelToClose)
	local button = make("TextButton", {
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

makeSideButton("🛒 상점", -56, shopPanel, invPanel)
makeSideButton("🐱 내 고양이", 4, invPanel, shopPanel)

-- UI 준비 완료 → 서버에 첫 데이터 요청
requestDataRemote:FireServer()
