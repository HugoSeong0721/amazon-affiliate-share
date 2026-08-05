--!strict
-- Two lines. That is the entire text budget (DESIGN.md 5-5).
--   line 1: where you are
--   line 2: what was just said to you
-- Anything longer belongs in the narration audio, or it belongs nowhere.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Strings = require(ReplicatedStorage.Shared.Strings)
local Verses = require(ReplicatedStorage.Shared.Verses)

local ObjectiveHud = {}

local locale = Strings.DEFAULT
local gui: ScreenGui
local titleLabel: TextLabel
local sayLabel: TextLabel
local lampLabel: TextLabel
local sayToken = 0

local function label(name: string, order: number, size: number, transparency: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -40, 0, size + 10)
	text.LayoutOrder = order
	text.Font = Enum.Font.GothamMedium
	text.TextSize = size
	text.TextColor3 = Color3.fromRGB(255, 252, 240)
	text.TextStrokeTransparency = 0.4
	text.TextStrokeColor3 = Color3.fromRGB(20, 18, 14)
	text.TextTransparency = transparency
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.Text = ""
	return text
end

function ObjectiveHud.start()
	local player = Players.LocalPlayer

	gui = Instance.new("ScreenGui")
	gui.Name = "JourneyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local bottom = Instance.new("Frame")
	bottom.Name = "Lines"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -28)
	bottom.Size = UDim2.new(1, 0, 0, 96)
	bottom.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = bottom

	titleLabel = label("Title", 1, 20, 0.25)
	titleLabel.Parent = bottom

	sayLabel = label("Say", 2, 26, 1)
	sayLabel.Parent = bottom

	lampLabel = label("Lamp", 1, 18, 0.35)
	lampLabel.AnchorPoint = Vector2.new(0.5, 0)
	lampLabel.Position = UDim2.new(0.5, 0, 0, 20)
	lampLabel.Size = UDim2.new(1, -40, 0, 26)
	lampLabel.Parent = gui
end

function ObjectiveHud.setLocale(next: string)
	locale = next
end

function ObjectiveHud.setChapter(chapterId: string?)
	if not chapterId then
		titleLabel.Text = Strings.get("hub.welcome", locale)
		return
	end
	titleLabel.Text = Strings.chapterTitle(chapterId, locale)
end

-- Lamp brightness and the verse the player has rebuilt so far. Never a ranking,
-- never compared to anyone else (DESIGN.md 4-4).
function ObjectiveHud.setProgress(snapshot: { [string]: any })
	local lampLevel = snapshot.lampLevel or 0
	local owned = snapshot.fragments or {}

	local lamps = string.rep("✦", math.max(lampLevel, 0))
	local verseLines = {}
	for _, verse in Verses.all() do
		local rendered = Verses.render(verse.id, owned, locale)
		if rendered ~= "" and string.find(rendered, "＿", 1, true) == nil then
			table.insert(verseLines, `{rendered} ({verse.reference})`)
		end
	end

	local latest = verseLines[#verseLines]
	lampLabel.Text = if latest then `{lamps}  {latest}` else lamps
end

function ObjectiveHud.say(stringKey: string)
	local text = Strings.get(stringKey, locale)
	sayToken += 1
	local token = sayToken

	sayLabel.Text = text
	sayLabel.TextTransparency = 1
	TweenService:Create(sayLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

	task.delay(6, function()
		if token ~= sayToken then
			return
		end
		TweenService:Create(sayLabel, TweenInfo.new(1), { TextTransparency = 1 }):Play()
	end)
end

return ObjectiveHud
