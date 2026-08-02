-- CatTutorial (LocalScript / StarterPlayer > StarterPlayerScripts)
--
-- 처음 들어온 사람이 뭘 해야 하는지 몰라서 헤매지 않도록, 4단계로 손을 잡아준다.
--   1. 움직여 보기      → 고양이가 따라온다는 걸 알게 된다
--   2. 밥 주기          → E 키와 코인/경험치를 알게 된다
--   3. 레벨 올리기      → 고양이가 커진다는 걸 보게 된다
--   4. 새 고양이 입양   → 상점 사용법을 알게 된다
--
-- 각 단계는 "말로 설명"이 아니라 "실제로 해내면" 넘어간다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("CatGameRemotes")
local dataChangedRemote = remotes:WaitForChild("DataChanged")
local requestDataRemote = remotes:WaitForChild("RequestData")
local completeTutorialRemote = remotes:WaitForChild("CompleteTutorial")

local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("CatGameGui")
local shopButton = gameGui:WaitForChild("ShopButton")
local bottomHint = gameGui:WaitForChild("Hint")

---------------------------------------------------------------
-- UI 헬퍼 (CatGameClient와 같은 톤)
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
local COLOR_SUB = Color3.fromRGB(160, 130, 90)
local COLOR_BUTTON = Color3.fromRGB(255, 166, 61)

---------------------------------------------------------------
-- 단계 정의
---------------------------------------------------------------
local STEPS = {
	{
		Title = "먼저 움직여 볼까요?",
		Hint = "W A S D 키로 이동  ·  고양이가 옆에 붙어서 따라와요",
		ShowArrow = true,
	},
	{
		Title = "고양이에게 밥을 주세요",
		Hint = "고양이 근처에서 [E] 키  ·  코인 +2, 경험치 +10",
		ShowArrow = true,
	},
	{
		Title = "밥을 더 줘서 Lv.2 를 만들어 보세요",
		Hint = "레벨이 오르면 고양이가 눈에 띄게 커져요",
		ShowArrow = true,
	},
	{
		Title = "코인을 모아 새 고양이를 입양해 보세요",
		Hint = "왼쪽 [🛒 상점] → 까망냥이 100 코인",
		HighlightShop = true,
	},
}

---------------------------------------------------------------
-- 튜토리얼 UI
---------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "CatTutorialGui",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	Enabled = false,
}, playerGui)

-- 시작 안내창 -------------------------------------------------
local backdrop = make("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Visible = false,
}, gui)

local welcome = make("Frame", {
	Size = UDim2.fromOffset(440, 320),
	Position = UDim2.new(0.5, -220, 0.5, -160),
	BackgroundColor3 = COLOR_PANEL,
}, backdrop)
round(welcome, 18)

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 64),
	Position = UDim2.fromOffset(0, 18),
	BackgroundTransparency = 1,
	Text = "🐱",
	TextSize = 52,
	Font = Enum.Font.GothamBold,
}, welcome)

make("TextLabel", {
	Size = UDim2.new(1, -40, 0, 34),
	Position = UDim2.fromOffset(20, 82),
	BackgroundTransparency = 1,
	Text = "고양이 키우기",
	TextColor3 = COLOR_TITLE,
	TextSize = 28,
	Font = Enum.Font.GothamBold,
}, welcome)

local welcomeBody = make("TextLabel", {
	Size = UDim2.new(1, -56, 0, 100),
	Position = UDim2.fromOffset(28, 124),
	BackgroundTransparency = 1,
	Text = "고양이에게 밥을 주면 코인과 경험치를 받아요.\n"
		.. "레벨이 오르면 고양이가 점점 커지고,\n"
		.. "코인을 모으면 새 고양이를 입양할 수 있어요.",
	TextColor3 = COLOR_TEXT,
	TextSize = 17,
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
}, welcome)
welcomeBody.LineHeight = 1.35

local startButton = make("TextButton", {
	Size = UDim2.fromOffset(200, 48),
	Position = UDim2.new(0.5, -100, 1, -78),
	BackgroundColor3 = COLOR_BUTTON,
	Text = "시작하기",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 20,
	Font = Enum.Font.GothamBold,
}, welcome)
round(startButton, 12)

local skipWelcome = make("TextButton", {
	Size = UDim2.fromOffset(200, 24),
	Position = UDim2.new(0.5, -100, 1, -28),
	BackgroundTransparency = 1,
	Text = "튜토리얼 건너뛰기",
	TextColor3 = COLOR_SUB,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
}, welcome)

-- 단계 카드 ---------------------------------------------------
local card = make("Frame", {
	Size = UDim2.fromOffset(540, 118),
	Position = UDim2.new(0.5, -270, 1, -172),
	BackgroundColor3 = COLOR_PANEL,
	Visible = false,
}, gui)
round(card, 16)

local stepCounter = make("TextLabel", {
	Size = UDim2.new(0, 200, 0, 22),
	Position = UDim2.fromOffset(22, 12),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLOR_SUB,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

local skipButton = make("TextButton", {
	Size = UDim2.fromOffset(80, 26),
	Position = UDim2.new(1, -96, 0, 10),
	BackgroundTransparency = 1,
	Text = "건너뛰기",
	TextColor3 = COLOR_SUB,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
}, card)

local stepTitle = make("TextLabel", {
	Size = UDim2.new(1, -44, 0, 32),
	Position = UDim2.fromOffset(22, 38),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLOR_TEXT,
	TextSize = 23,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

local stepHint = make("TextLabel", {
	Size = UDim2.new(1, -44, 0, 22),
	Position = UDim2.fromOffset(22, 72),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLOR_SUB,
	TextSize = 15,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

-- 진행 점
local dots = {}
for index = 1, #STEPS do
	dots[index] = make("Frame", {
		Size = UDim2.fromOffset(24, 5),
		Position = UDim2.new(1, -34 - (#STEPS - index) * 30, 1, -20),
		BackgroundColor3 = COLOR_SUB,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	}, card)
	round(dots[index], 3)
end

-- 상점 버튼 강조용 테두리
local shopStroke = make("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 0,
	Transparency = 0.1,
}, shopButton)

---------------------------------------------------------------
-- 고양이 위 화살표
---------------------------------------------------------------
local function findMyCat()
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model")
			and child:GetAttribute("CatOwnerUserId") == player.UserId
			and child.PrimaryPart
		then
			return child
		end
	end
	return nil
end

local arrowGui = nil

local function destroyArrow()
	if arrowGui then
		arrowGui:Destroy()
		arrowGui = nil
	end
end

-- 고양이는 레벨업할 때 모델이 다시 만들어지므로, 붙어있던 화살표도 같이 사라진다.
-- 매 프레임 확인해서 없으면 새로 붙인다.
local function updateArrow(shouldShow)
	if not shouldShow then
		destroyArrow()
		return
	end
	local cat = findMyCat()
	if not cat then
		destroyArrow()
		return
	end
	if arrowGui and arrowGui.Parent == cat.PrimaryPart then
		return
	end
	destroyArrow()

	arrowGui = make("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(150, 64),
		StudsOffset = Vector3.new(0, 4.2, 0),
		AlwaysOnTop = true,
	}, cat.PrimaryPart)

	make("TextLabel", {
		Name = "Arrow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "여기예요!\n▼",
		TextColor3 = Color3.fromRGB(255, 228, 120),
		TextStrokeTransparency = 0.2,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
	}, arrowGui)
end

---------------------------------------------------------------
-- 진행 상태
---------------------------------------------------------------
local currentStep = 0 -- 0 = 아직 시작 전
local finished = false
local movedDistance = 0
local lastPosition = nil
local lastXpSignature = nil
local latestData = nil

local function xpSignature(cats)
	local total = 0
	for _, cat in ipairs(cats) do
		total = total + cat.Level * 1000000 + cat.Xp
	end
	return total
end

local function maxLevel(cats)
	local best = 0
	for _, cat in ipairs(cats) do
		best = math.max(best, cat.Level)
	end
	return best
end

local function renderStep()
	local step = STEPS[currentStep]
	if not step then
		return
	end
	stepCounter.Text = string.format("튜토리얼  %d / %d", currentStep, #STEPS)
	stepTitle.Text = step.Title
	stepHint.Text = step.Hint
	for index, dot in ipairs(dots) do
		dot.BackgroundColor3 = index <= currentStep and COLOR_BUTTON or COLOR_SUB
		dot.BackgroundTransparency = index <= currentStep and 0 or 0.6
	end
end

local function finish(showCongrats)
	if finished then
		return
	end
	finished = true
	currentStep = 0
	destroyArrow()
	shopStroke.Thickness = 0
	backdrop.Visible = false
	completeTutorialRemote:FireServer()

	if showCongrats then
		card.Visible = true
		stepCounter.Text = ""
		stepTitle.Text = "튜토리얼 완료! 🎉"
		stepHint.Text = "이제 마음껏 키워보세요. 고양이는 최대 3마리까지 데리고 다닐 수 있어요."
		skipButton.Visible = false
		for _, dot in ipairs(dots) do
			dot.BackgroundColor3 = COLOR_BUTTON
			dot.BackgroundTransparency = 0
		end
		task.delay(6, function()
			gui:Destroy()
			bottomHint.Visible = true
		end)
	else
		gui:Destroy()
		bottomHint.Visible = true
	end
end

local function advance()
	if finished then
		return
	end
	currentStep = currentStep + 1
	if currentStep > #STEPS then
		finish(true)
		return
	end
	renderStep()
end

local function beginTutorial()
	backdrop.Visible = false
	card.Visible = true
	bottomHint.Visible = false
	currentStep = 1
	renderStep()
end

startButton.Activated:Connect(beginTutorial)
skipWelcome.Activated:Connect(function()
	finish(false)
end)
skipButton.Activated:Connect(function()
	finish(false)
end)

---------------------------------------------------------------
-- 단계 완료 판정
---------------------------------------------------------------
dataChangedRemote.OnClientEvent:Connect(function(data)
	latestData = data

	-- 첫 데이터를 받은 시점에 튜토리얼을 띄울지 정한다
	if currentStep == 0 and not finished and not gui.Enabled then
		if data.TutorialDone then
			gui:Destroy()
			return
		end
		gui.Enabled = true
		backdrop.Visible = true
		lastXpSignature = xpSignature(data.Cats)
		return
	end

	if finished then
		return
	end

	local signature = xpSignature(data.Cats)
	local fedJustNow = lastXpSignature ~= nil and signature > lastXpSignature
	lastXpSignature = signature

	if currentStep == 2 and fedJustNow then
		advance()
	elseif currentStep == 3 and maxLevel(data.Cats) >= 2 then
		advance()
	elseif currentStep == 4 and #data.Cats >= 2 then
		advance()
	end
end)

-- UI가 늦게 붙었을 수도 있으니 직접 한 번 더 요청한다
requestDataRemote:FireServer()

---------------------------------------------------------------
-- 매 프레임: 이동 거리 측정, 화살표/강조 애니메이션
---------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	if finished or currentStep == 0 then
		return
	end

	local step = STEPS[currentStep]
	updateArrow(step ~= nil and step.ShowArrow == true)

	if arrowGui then
		local bob = math.sin(os.clock() * 4) * 0.35
		arrowGui.StudsOffset = Vector3.new(0, 4.2 + bob, 0)
	end

	if step and step.HighlightShop then
		shopStroke.Thickness = 2.5 + math.sin(os.clock() * 5) * 1.5
	else
		shopStroke.Thickness = 0
	end

	-- 1단계: 실제로 움직였는지
	if currentStep == 1 then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local position = rootPart.Position
			if lastPosition then
				local delta = (Vector3.new(position.X, 0, position.Z)
					- Vector3.new(lastPosition.X, 0, lastPosition.Z)).Magnitude
				if delta < 5 then -- 리스폰으로 순간이동한 경우는 빼고 센다
					movedDistance = movedDistance + delta
				end
			end
			lastPosition = position
			if movedDistance > 14 then
				advance()
			end
		end
	end
end)
