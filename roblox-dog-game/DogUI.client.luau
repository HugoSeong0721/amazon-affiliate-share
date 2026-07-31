--[[
	🐶 멍멍 하우스! 강아지 키우기 — UI 로컬 스크립트 (DogUI)

	넣는 위치: Roblox Studio > 탐색기(Explorer) > StarterPlayer > StarterPlayerScripts
	           마우스 우클릭 > Insert Object > LocalScript 를 만들고
	           이 파일 내용을 전부 붙여넣으세요.

	이 스크립트가 하는 일 (전부 코드로 UI를 생성하므로 GUI 에셋 불필요):
	  - 뼈다귀 코인 / 강아지 이름·레벨 / 경험치 바 표시
	  - 배고픔·행복·에너지 상태 바
	  - 밥 / 간식 / 쓰다듬기 / 공놀이 버튼 (쿨타임 표시 포함)
	  - 품종 상점, 이름 바꾸기 창, 알림 토스트
	  - 모바일/PC 둘 다 동작
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("DogRemotes")
local reAction = remotes:WaitForChild("Action")
local reState = remotes:WaitForChild("State")
local reNotify = remotes:WaitForChild("Notify")
local rfRename = remotes:WaitForChild("Rename")

-- =====================================================================
-- 색상 팔레트
-- =====================================================================
local COLOR = {
	panel = Color3.fromRGB(255, 250, 240),
	ink = Color3.fromRGB(92, 62, 32),
	inkSoft = Color3.fromRGB(150, 118, 86),
	orange = Color3.fromRGB(240, 148, 54),
	orangeDeep = Color3.fromRGB(206, 112, 24),
	green = Color3.fromRGB(88, 190, 120),
	pink = Color3.fromRGB(244, 114, 150),
	sky = Color3.fromRGB(96, 176, 244),
	bad = Color3.fromRGB(226, 88, 88),
	shadow = Color3.fromRGB(60, 40, 20),
}

-- 인스턴스 생성 도우미
local function new(className, props, parent)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

local function round(obj, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, obj)
	return obj
end

-- =====================================================================
-- 화면 뼈대
-- =====================================================================
local gui = new("ScreenGui", {
	Name = "DogUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- 코인 바 (왼쪽 위)
local coinBar = round(new("Frame", {
	Size = UDim2.fromOffset(150, 44),
	Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = COLOR.panel,
}, gui), 22)
new("UIStroke", { Color = COLOR.orange, Thickness = 3 }, coinBar)
local coinLabel = new("TextLabel", {
	Size = UDim2.new(1, -16, 1, 0),
	Position = UDim2.new(0, 8, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = COLOR.ink,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🦴 0",
}, coinBar)

-- 강아지 이름 + 레벨 + 경험치 (가운데 위)
local infoCard = round(new("Frame", {
	Size = UDim2.fromOffset(240, 62),
	Position = UDim2.new(0.5, 0, 0, 10),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = COLOR.panel,
}, gui), 16)
new("UIStroke", { Color = COLOR.orange, Thickness = 3 }, infoCard)
local nameLabel = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.new(0, 10, 0, 4),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = COLOR.ink,
	Text = "멍멍이 · Lv.1",
}, infoCard)
local expBack = round(new("Frame", {
	Size = UDim2.new(1, -24, 0, 12),
	Position = UDim2.new(0, 12, 0, 40),
	BackgroundColor3 = Color3.fromRGB(236, 222, 202),
}, infoCard), 6)
local expFill = round(new("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = COLOR.sky,
}, expBack), 6)

-- 상태 바 패널 (왼쪽)
local statPanel = round(new("Frame", {
	Size = UDim2.fromOffset(190, 128),
	Position = UDim2.new(0, 12, 0, 68),
	BackgroundColor3 = COLOR.panel,
	BackgroundTransparency = 0.1,
}, gui), 16)
new("UIStroke", { Color = COLOR.orange, Thickness = 2 }, statPanel)

local statBars = {}
local statDefs = {
	{ key = "hunger", label = "🍖 배고픔", color = COLOR.orange },
	{ key = "happiness", label = "💖 행복", color = COLOR.pink },
	{ key = "energy", label = "⚡ 에너지", color = COLOR.green },
}
for index, def in ipairs(statDefs) do
	local row = new("Frame", {
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.new(0, 10, 0, 8 + (index - 1) * 38),
		BackgroundTransparency = 1,
	}, statPanel)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = COLOR.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = def.label,
	}, row)
	local back = round(new("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 0, 19),
		BackgroundColor3 = Color3.fromRGB(236, 222, 202),
	}, row), 6)
	local fill = round(new("Frame", {
		Size = UDim2.new(0.8, 0, 1, 0),
		BackgroundColor3 = def.color,
	}, back), 6)
	statBars[def.key] = fill
end

-- =====================================================================
-- 행동 버튼 (아래 가운데)
-- =====================================================================
local buttonRow = new("Frame", {
	Size = UDim2.fromOffset(500, 96),
	Position = UDim2.new(0.5, 0, 1, -14),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 10),
}, buttonRow)

local cooldowns = { feed = 12, treat = 6, pet = 3, fetch = 8 } -- 서버 값으로 갱신됨
local treatPrice = 15

local function makeActionButton(emoji, text, order)
	local btn = round(new("TextButton", {
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = COLOR.panel,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = order,
	}, buttonRow), 18)
	new("UIStroke", { Color = COLOR.orange, Thickness = 3 }, btn)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 34,
		Text = emoji,
	}, btn)
	local caption = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = COLOR.ink,
		Text = text,
	}, btn)
	local cdCover = round(new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = COLOR.shadow,
		BackgroundTransparency = 0.45,
		Font = Enum.Font.GothamBold,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
		Visible = false,
	}, btn), 18)
	return btn, caption, cdCover
end

local function startCooldown(cover, seconds)
	task.spawn(function()
		cover.Visible = true
		local remaining = seconds
		while remaining > 0 do
			cover.Text = tostring(math.ceil(remaining))
			task.wait(0.5)
			remaining = remaining - 0.5
		end
		cover.Visible = false
	end)
end

local feedBtn, _, feedCd = makeActionButton("🍖", "밥주기", 1)
local treatBtn, treatCaption, treatCd = makeActionButton("🦴", "간식 15🦴", 2)
local petBtn, _, petCd = makeActionButton("🤚", "쓰다듬기", 3)
local fetchBtn, _, fetchCd = makeActionButton("🎾", "공놀이", 4)
local shopBtn = round(new("TextButton", {
	Size = UDim2.fromOffset(88, 88),
	BackgroundColor3 = COLOR.orange,
	AutoButtonColor = true,
	Text = "",
	LayoutOrder = 5,
}, buttonRow), 18)
new("UIStroke", { Color = COLOR.orangeDeep, Thickness = 3 }, shopBtn)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 6),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 34, Text = "🏪",
}, shopBtn)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -32),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 255, 255), Text = "상점",
}, shopBtn)

feedBtn.Activated:Connect(function()
	reAction:FireServer("feed")
	startCooldown(feedCd, cooldowns.feed)
end)
treatBtn.Activated:Connect(function()
	reAction:FireServer("treat")
	startCooldown(treatCd, cooldowns.treat)
end)
petBtn.Activated:Connect(function()
	reAction:FireServer("pet")
	startCooldown(petCd, cooldowns.pet)
end)
fetchBtn.Activated:Connect(function()
	reAction:FireServer("fetch")
	startCooldown(fetchCd, cooldowns.fetch)
end)

-- =====================================================================
-- 모달(상점 / 이름 바꾸기) 공통 틀
-- =====================================================================
local veil = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(40, 26, 12),
	BackgroundTransparency = 0.45,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 10,
}, gui)

local modal = round(new("Frame", {
	Size = UDim2.fromOffset(320, 380),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLOR.panel,
	ZIndex = 11,
}, veil), 20)
new("UIStroke", { Color = COLOR.orange, Thickness = 4 }, modal)

local modalTitle = new("TextLabel", {
	Size = UDim2.new(1, -60, 0, 40),
	Position = UDim2.new(0, 16, 0, 8),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = COLOR.ink,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	ZIndex = 12,
}, modal)

local closeBtn = round(new("TextButton", {
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(1, -44, 0, 10),
	BackgroundColor3 = COLOR.bad,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "✕",
	ZIndex = 12,
}, modal), 18)

local modalBody = new("Frame", {
	Size = UDim2.new(1, -24, 1, -64),
	Position = UDim2.new(0, 12, 0, 54),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, modal)

local function closeModal()
	veil.Visible = false
	for _, child in ipairs(modalBody:GetChildren()) do
		child:Destroy()
	end
end
closeBtn.Activated:Connect(closeModal)
veil.Activated:Connect(closeModal)

-- 모달 내용 클릭이 배경 클릭으로 새지 않게
local modalBlock = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 11,
}, modal)
modalBlock.Activated:Connect(function() end)

-- =====================================================================
-- 상점
-- =====================================================================
local lastState = nil

local function openShop()
	if not lastState then return end
	closeModal()
	veil.Visible = true
	modalTitle.Text = "🏪 강아지 상점"

	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, #lastState.catalog * 62),
		ScrollBarThickness = 6,
		ZIndex = 12,
	}, modalBody)
	new("UIListLayout", { Padding = UDim.new(0, 8) }, list)

	for _, item in ipairs(lastState.catalog) do
		local row = round(new("Frame", {
			Size = UDim2.new(1, -8, 0, 54),
			BackgroundColor3 = Color3.fromRGB(250, 240, 224),
			ZIndex = 12,
		}, list), 12)

		local swatch = round(new("Frame", {
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(item.rgb[1], item.rgb[2], item.rgb[3]),
			ZIndex = 13,
		}, row), 19)
		new("UIStroke", { Color = COLOR.inkSoft, Thickness = 2 }, swatch)

		new("TextLabel", {
			Size = UDim2.new(0, 120, 1, 0),
			Position = UDim2.new(0, 54, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = COLOR.ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = item.label,
			ZIndex = 13,
		}, row)

		local isCurrent = lastState.breed == item.id
		local isOwned = lastState.owned[item.id] == true
		local btnText, btnColor
		if isCurrent then
			btnText = "함께하는 중"
			btnColor = COLOR.inkSoft
		elseif isOwned then
			btnText = "데려오기"
			btnColor = COLOR.sky
		else
			btnText = item.price .. "🦴 입양"
			btnColor = COLOR.green
		end

		local buyBtn = round(new("TextButton", {
			Size = UDim2.fromOffset(108, 38),
			Position = UDim2.new(1, -116, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = btnColor,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = btnText,
			ZIndex = 13,
		}, row), 12)
		if not isCurrent then
			buyBtn.Activated:Connect(function()
				reAction:FireServer("buy", item.id)
				task.wait(0.2)
				openShop() -- 최신 상태로 다시 그림
			end)
		end
	end
end
shopBtn.Activated:Connect(openShop)

-- =====================================================================
-- 이름 바꾸기 (이름표를 누르면 열림)
-- =====================================================================
local function openRename()
	closeModal()
	veil.Visible = true
	modalTitle.Text = "✏️ 이름 바꾸기"

	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLOR.inkSoft,
		Text = "강아지의 새 이름을 지어주세요 (1~12자)",
		ZIndex = 12,
	}, modalBody)

	local box = round(new("TextBox", {
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 0, 40),
		BackgroundColor3 = Color3.fromRGB(250, 240, 224),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = COLOR.ink,
		PlaceholderText = "예: 초코, 보리, 콩이...",
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 12,
	}, modalBody), 12)
	new("UIStroke", { Color = COLOR.orange, Thickness = 2 }, box)

	local confirm = round(new("TextButton", {
		Size = UDim2.new(1, -20, 0, 48),
		Position = UDim2.new(0, 10, 0, 100),
		BackgroundColor3 = COLOR.green,
		Font = Enum.Font.GothamBold,
		TextSize = 19,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "이름 정하기 🐾",
		ZIndex = 12,
	}, modalBody), 14)

	confirm.Activated:Connect(function()
		local result = rfRename:InvokeServer(box.Text)
		if result and result.ok then
			closeModal()
		elseif result then
			box.Text = ""
			box.PlaceholderText = result.msg
		end
	end)
end
-- 이름 카드 누르면 이름 바꾸기
local nameButton = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
}, infoCard)
nameButton.Activated:Connect(openRename)

-- =====================================================================
-- 알림 토스트
-- =====================================================================
local toast = round(new("TextLabel", {
	Size = UDim2.fromOffset(340, 44),
	Position = UDim2.new(0.5, 0, 0, -60),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = COLOR.ink,
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "",
	ZIndex = 20,
	Visible = false,
}, gui), 22)

local toastTween = nil
reNotify.OnClientEvent:Connect(function(message, kind)
	toast.Text = message
	toast.BackgroundColor3 = kind == "warn" and COLOR.bad or COLOR.ink
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 0, -60)
	if toastTween then toastTween:Cancel() end
	toastTween = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0, 78),
	})
	toastTween:Play()
	task.delay(2.4, function()
		if toast.Text == message then
			local out = TweenService:Create(toast, TweenInfo.new(0.25), {
				Position = UDim2.new(0.5, 0, 0, -60),
			})
			out:Play()
			out.Completed:Wait()
			if toast.Text == message then toast.Visible = false end
		end
	end)
end)

-- =====================================================================
-- 서버 상태 반영
-- =====================================================================
local function tweenBar(bar, ratio)
	TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0),
	}):Play()
end

reState.OnClientEvent:Connect(function(state)
	lastState = state
	coinLabel.Text = "🦴 " .. state.coins
	nameLabel.Text = state.name .. " · Lv." .. state.level
	tweenBar(expFill, state.exp / state.expNext)
	tweenBar(statBars.hunger, state.hunger / 100)
	tweenBar(statBars.happiness, state.happiness / 100)
	tweenBar(statBars.energy, state.energy / 100)

	-- 수치가 위험하면 바가 빨갛게
	statBars.hunger.BackgroundColor3 = state.hunger < 30 and COLOR.bad or COLOR.orange
	statBars.happiness.BackgroundColor3 = state.happiness < 30 and COLOR.bad or COLOR.pink
	statBars.energy.BackgroundColor3 = state.energy < 25 and COLOR.bad or COLOR.green

	if state.cooldowns then
		cooldowns = state.cooldowns
	end
	if state.prices and state.prices.treat then
		treatPrice = state.prices.treat
		treatCaption.Text = "간식 " .. treatPrice .. "🦴"
	end
end)

print("[DogUI] 🐶 강아지 키우기 UI 준비 완료!")
