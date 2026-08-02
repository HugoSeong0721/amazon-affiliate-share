-- CatTutorial (LocalScript / StarterPlayer > StarterPlayerScripts)
--
-- 처음 들어온 사람이 "부순다 → 코인 → 상자 → 더 센 고양이 → 다음 구역"
-- 이 흐름을 몸으로 익히도록 4단계로 안내한다.
-- 각 단계는 설명을 읽는 게 아니라 실제로 해내야 넘어간다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local CatConfig = require(ReplicatedStorage:WaitForChild("CatConfig"))
local BigNumber = require(ReplicatedStorage:WaitForChild("BigNumber"))

local remotes = ReplicatedStorage:WaitForChild("CatGameRemotes")
local dataChangedRemote = remotes:WaitForChild("DataChanged")
local requestDataRemote = remotes:WaitForChild("RequestData")
local completeTutorialRemote = remotes:WaitForChild("CompleteTutorial")

local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("CatGameGui")
local zonesButton = gameGui:WaitForChild("ZonesButton")
local bottomHint = gameGui:WaitForChild("Hint")

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

local PANEL = Color3.fromRGB(248, 244, 238)
local TEXT = Color3.fromRGB(52, 46, 40)
local SUB = Color3.fromRGB(140, 128, 116)
local ACCENT = Color3.fromRGB(255, 158, 56)

local firstZone = CatConfig.Zones[1]
local secondZone = CatConfig.Zones[2]
local POWER_GOAL = 30

---------------------------------------------------------------
-- 단계
---------------------------------------------------------------
local STEPS = {
	{
		Title = "가만히 서 있어 보세요",
		Hint = "고양이가 알아서 주변 물건을 부숩니다. 코인이 저절로 쌓여요.",
		PointAt = "Breakable",
	},
	{
		Title = ("%s를 열어 새 고양이를 뽑으세요"):format(firstZone.EggName),
		Hint = "",
		PointAt = "Egg",
		Progress = "Egg",
	},
	{
		Title = "파워를 키우세요",
		Hint = "",
		Progress = "Power",
	},
	{
		Title = ("%s로 가는 문을 여세요"):format(secondZone.Name),
		Hint = "",
		PointAt = "Gate",
		Progress = "Unlock",
		HighlightZones = true,
	},
}

---------------------------------------------------------------
-- UI
---------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "CatTutorialGui",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	Enabled = false,
}, playerGui)

local backdrop = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Visible = false,
}, gui)

local welcome = make("Frame", {
	Size = UDim2.fromOffset(520, 400),
	Position = UDim2.new(0.5, -260, 0.5, -200),
	BackgroundColor3 = PANEL,
}, backdrop)
round(welcome, 18)

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 54),
	Position = UDim2.fromOffset(0, 16),
	BackgroundTransparency = 1,
	Text = "🐱💥",
	TextSize = 40,
	Font = Enum.Font.GothamBold,
}, welcome)

make("TextLabel", {
	Size = UDim2.new(1, -40, 0, 34),
	Position = UDim2.fromOffset(20, 68),
	BackgroundTransparency = 1,
	Text = "고양이 시뮬레이터",
	TextColor3 = TEXT,
	TextSize = 27,
	Font = Enum.Font.GothamBold,
}, welcome)

local story = make("TextLabel", {
	Size = UDim2.new(1, -64, 0, 84),
	Position = UDim2.fromOffset(32, 108),
	BackgroundTransparency = 1,
	Text = table.concat(CatConfig.Intro, "\n"),
	TextColor3 = TEXT,
	TextSize = 15,
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
}, welcome)
story.LineHeight = 1.4

local rules = make("TextLabel", {
	Size = UDim2.new(1, -64, 0, 96),
	Position = UDim2.fromOffset(32, 196),
	BackgroundTransparency = 1,
	Text = "💥  고양이가 알아서 물건을 부숩니다 (조작 안 해도 돼요)\n"
		.. "🪙  부수면 코인이 나옵니다\n"
		.. "📦  코인으로 상자를 열면 더 센 고양이가 나옵니다\n"
		.. "🗺️  세지면 더 단단한 구역을 열 수 있습니다",
	TextColor3 = Color3.fromRGB(112, 98, 84),
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
}, welcome)
rules.LineHeight = 1.5

make("TextLabel", {
	Size = UDim2.new(1, -64, 0, 22),
	Position = UDim2.fromOffset(32, 292),
	BackgroundTransparency = 1,
	Text = CatConfig.IntroGoal,
	TextColor3 = ACCENT,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, welcome)

local startButton = make("TextButton", {
	Size = UDim2.fromOffset(220, 46),
	Position = UDim2.new(0.5, -110, 1, -74),
	BackgroundColor3 = ACCENT,
	Text = "시작하기",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 19,
	Font = Enum.Font.GothamBold,
}, welcome)
round(startButton, 12)

local skipWelcome = make("TextButton", {
	Size = UDim2.fromOffset(220, 22),
	Position = UDim2.new(0.5, -110, 1, -26),
	BackgroundTransparency = 1,
	Text = "튜토리얼 건너뛰기",
	TextColor3 = SUB,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
}, welcome)

-- 단계 카드
local card = make("Frame", {
	Size = UDim2.fromOffset(560, 116),
	Position = UDim2.new(0.5, -280, 1, -170),
	BackgroundColor3 = PANEL,
	Visible = false,
}, gui)
round(card, 16)

local stepCounter = make("TextLabel", {
	Size = UDim2.fromOffset(200, 22),
	Position = UDim2.fromOffset(22, 12),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = SUB,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

local skipButton = make("TextButton", {
	Size = UDim2.fromOffset(80, 24),
	Position = UDim2.new(1, -96, 0, 10),
	BackgroundTransparency = 1,
	Text = "건너뛰기",
	TextColor3 = SUB,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
}, card)

local stepTitle = make("TextLabel", {
	Size = UDim2.new(1, -44, 0, 30),
	Position = UDim2.fromOffset(22, 36),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = TEXT,
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

local stepHint = make("TextLabel", {
	Size = UDim2.new(1, -44, 0, 22),
	Position = UDim2.fromOffset(22, 70),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = SUB,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)

local dots = {}
for index = 1, #STEPS do
	dots[index] = make("Frame", {
		Size = UDim2.fromOffset(24, 5),
		Position = UDim2.new(1, -34 - (#STEPS - index) * 30, 1, -18),
		BackgroundColor3 = SUB,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	}, card)
	round(dots[index], 3)
end

local zonesStroke = make("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 0,
	Transparency = 0.1,
}, zonesButton)

---------------------------------------------------------------
-- 월드 화살표
---------------------------------------------------------------
local arrowGui = nil

local function destroyArrow()
	if arrowGui then
		arrowGui:Destroy()
		arrowGui = nil
	end
end

local function findTargetPart(kind)
	local world = workspace:FindFirstChild("World")
	if kind == "Egg" and world then
		return world:FindFirstChild("Egg_" .. firstZone.Id)
	elseif kind == "Gate" and world then
		return world:FindFirstChild("Gate_" .. secondZone.Id)
	elseif kind == "Breakable" then
		local folder = workspace:FindFirstChild("Breakables")
		if folder then
			-- 첫 구역의 살아있는 물건 아무거나
			for _, part in ipairs(folder:GetChildren()) do
				if part.Transparency == 0 then
					return part
				end
			end
		end
	end
	return nil
end

local function updateArrow(kind)
	if not kind then
		destroyArrow()
		return
	end
	local target = findTargetPart(kind)
	if not target then
		destroyArrow()
		return
	end
	if arrowGui and arrowGui.Parent == target then
		return
	end
	destroyArrow()

	arrowGui = make("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(170, 70),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
	}, target)

	make("TextLabel", {
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
-- 진행
---------------------------------------------------------------
local currentStep = 0
local finished = false
local latest = nil
local startPower = nil

local function renderStep()
	local step = STEPS[currentStep]
	if not step then
		return
	end
	stepCounter.Text = ("튜토리얼  %d / %d"):format(currentStep, #STEPS)
	stepTitle.Text = step.Title

	local coins = latest and latest.Coins or 0
	local power = latest and latest.Power or 0

	if step.Progress == "Egg" then
		stepHint.Text = coins >= firstZone.EggCost
			and ("코인 %s / %s  ·  이제 열 수 있어요! 상자 앞에서 [E]"):format(
				BigNumber.Short(coins), BigNumber.Short(firstZone.EggCost))
			or ("코인 %s / %s  ·  조금만 더 기다리면 돼요"):format(
				BigNumber.Short(coins), BigNumber.Short(firstZone.EggCost))
	elseif step.Progress == "Power" then
		stepHint.Text = ("파워 %s / %s  ·  상자를 더 열면 올라가요"):format(
			BigNumber.Short(power), BigNumber.Short(POWER_GOAL))
	elseif step.Progress == "Unlock" then
		stepHint.Text = coins >= secondZone.UnlockCost
			and ("코인 %s / %s  ·  문 앞에서 [E] 또는 왼쪽 [🗺️ 구역]"):format(
				BigNumber.Short(coins), BigNumber.Short(secondZone.UnlockCost))
			or ("코인 %s / %s  ·  %s 더 모으면 돼요"):format(
				BigNumber.Short(coins), BigNumber.Short(secondZone.UnlockCost),
				BigNumber.Short(secondZone.UnlockCost - coins))
	else
		stepHint.Text = step.Hint
	end

	for index, dot in ipairs(dots) do
		dot.BackgroundColor3 = index <= currentStep and ACCENT or SUB
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
	zonesStroke.Thickness = 0
	backdrop.Visible = false
	completeTutorialRemote:FireServer()

	if showCongrats then
		card.Visible = true
		stepCounter.Text = ""
		stepTitle.Text = "이제 혼자서도 할 수 있어요 🎉"
		stepHint.Text = "구역을 하나씩 열면서 달빛 옥상까지 올라가 보세요. 같은 고양이 3마리는 합성!"
		skipButton.Visible = false
		for _, dot in ipairs(dots) do
			dot.BackgroundColor3 = ACCENT
			dot.BackgroundTransparency = 0
		end
		task.delay(7, function()
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
	currentStep += 1
	if currentStep > #STEPS then
		finish(true)
		return
	end
	if currentStep == 3 then
		startPower = latest and latest.Power or 0
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
skipWelcome.Activated:Connect(function() finish(false) end)
skipButton.Activated:Connect(function() finish(false) end)

---------------------------------------------------------------
-- 단계 통과 판정
---------------------------------------------------------------
dataChangedRemote.OnClientEvent:Connect(function(data)
	local firstPayload = (latest == nil)
	latest = data

	if firstPayload then
		if data.TutorialDone then
			gui:Destroy()
			return
		end
		gui.Enabled = true
		backdrop.Visible = true
		return
	end

	if finished or currentStep == 0 then
		return
	end

	if currentStep == 1 and data.Coins > 0 then
		advance()
	elseif currentStep == 2 and #data.Cats >= 2 then
		advance()
	elseif currentStep == 3 and (data.Power or 0) >= POWER_GOAL then
		advance()
	elseif currentStep == 4 and data.Zones[secondZone.Id] then
		advance()
	else
		renderStep()
	end
end)

requestDataRemote:FireServer()

---------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	if finished or currentStep == 0 then
		return
	end
	local step = STEPS[currentStep]
	if not step then
		return
	end

	updateArrow(step.PointAt)
	if arrowGui then
		arrowGui.StudsOffset = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.4, 0)
	end

	zonesStroke.Thickness = step.HighlightZones
		and (2.5 + math.sin(os.clock() * 5) * 1.5)
		or 0
end)
