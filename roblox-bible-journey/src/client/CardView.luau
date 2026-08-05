--!strict
-- Draws verse text onto the card tablets the server spawns (parts carrying a
-- "VerseCardId" attribute).
--
-- Rendered client-side for two reasons: the text must follow this player's
-- locale, and — the good part — the card shows only the fragments THIS player
-- has collected, blanks for the rest. A card that reads "사람은 빵만으로는 ＿＿＿"
-- is its own reason to walk back up the path. Two kids at the same station see
-- different cards, and both are telling the truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Verses = require(ReplicatedStorage.Shared.Verses)

local ATTRIBUTE = "VerseCardId"

local CardView = {}

local locale = Strings.DEFAULT
local owned: { [string]: boolean } = {}
local labels: { [BasePart]: TextLabel } = {}

local function textFor(verseId: string): string
	local verse = Verses.get(verseId)
	if not verse then
		return verseId
	end
	return `{Verses.render(verseId, owned, locale)}\n— {verse.reference}`
end

local function refresh(card: BasePart)
	local label = labels[card]
	local verseId = card:GetAttribute(ATTRIBUTE)
	if label and typeof(verseId) == "string" then
		label.Text = textFor(verseId)
	end
end

local function attach(card: BasePart)
	if labels[card] then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CardText"
	billboard.Size = UDim2.new(9, 0, 5, 0)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.MaxDistance = 90
	billboard.Parent = card

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 250, 232)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(24, 20, 14)
	label.Parent = billboard

	labels[card] = label
	refresh(card)

	card.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			labels[card] = nil
		end
	end)
end

local function consider(instance: Instance)
	if instance:IsA("BasePart") and typeof(instance:GetAttribute(ATTRIBUTE)) == "string" then
		attach(instance)
	end
end

-- Called from the ProgressChanged handler: newly collected fragments fill in on
-- the standing cards immediately.
function CardView.setState(fragments: { [string]: boolean }, nextLocale: string)
	owned = fragments
	locale = nextLocale
	for card in labels do
		refresh(card)
	end
end

function CardView.start()
	-- DescendantAdded covers both fresh spawns and StreamingEnabled late arrivals.
	Workspace.DescendantAdded:Connect(consider)
	for _, instance in Workspace:GetDescendants() do
		consider(instance)
	end
end

return CardView
