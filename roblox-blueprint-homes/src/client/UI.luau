--!strict
-- All 2D UI: HUD, build catalog, blueprint market, publish dialog, toasts.
-- Built entirely in code (no asset dependencies).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local UI = {}

-- // theme
local C_PANEL = Color3.fromRGB(28, 30, 36)
local C_PANEL2 = Color3.fromRGB(38, 41, 49)
local C_STROKE = Color3.fromRGB(70, 74, 84)
local C_TEXT = Color3.fromRGB(235, 236, 240)
local C_SUBTEXT = Color3.fromRGB(160, 165, 175)
local C_ACCENT = Color3.fromRGB(72, 160, 220)
local C_GOOD = Color3.fromRGB(88, 180, 120)
local C_BAD = Color3.fromRGB(210, 92, 84)
local C_GOLD = Color3.fromRGB(232, 190, 90)

local ERR: { [string]: string } = {
	["slow-down"] = "Too fast - give it a second.",
	["bad-request"] = "Something went wrong.",
	["no-money"] = "Not enough cash!",
	["occupied"] = "That spot is taken.",
	["out-of-bounds"] = "Outside your plot.",
	["plot-full"] = "Plot item limit reached.",
	["not-found"] = "Not found - try refreshing.",
	["market-offline"] = "Market unavailable (offline session).",
	["store-error"] = "Market hiccup - try again.",
	["no-slots"] = "No free publish slots. Pro Builder gives you 5!",
	["too-few-items"] = ("Place at least %d items before publishing."):format(Config.Blueprint.MinItemsToPublish),
	["name-too-short"] = "Give your blueprint a longer name.",
	["bad-price"] = ("Price must be %s - %s."):format(Util.money(Config.Blueprint.MinPrice), Util.money(Config.Blueprint.MaxPrice)),
	["already-owned"] = "You already own this blueprint.",
	["own-blueprint"] = "That's your own blueprint.",
	["not-owned"] = "Buy the blueprint first.",
	["bad-build"] = "This blueprint can't be built.",
	["too-many-items"] = "Too many items.",
}

function UI.ErrorText(code: any): string
	return ERR[tostring(code)] or ("Error: " .. tostring(code))
end

-- // tiny instance helper
local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className) :: any
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(inst: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function stroke(inst: Instance, color: Color3?, thickness: number?)
	new("UIStroke", { Color = color or C_STROKE, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local function textButton(text: string, props: { [string]: any }, parent: Instance?): TextButton
	local btn = new("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C_TEXT,
		BackgroundColor3 = C_PANEL2,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	for k, v in pairs(props) do
		btn[k] = v
	end
	round(btn, 8)
	return btn
end

-- // state
local screen: ScreenGui
local moneyLabel: TextLabel
local toastHolder: Frame
local catalogPanel: Frame
local marketWindow: Frame
local publishDialog: Frame
local confirmDialog: Frame
local buildButton: TextButton
local deleteButton: TextButton

local handlers = {
	enterBuild = function() end,
	exitBuild = function() end,
	selectItem = function(_id: string) end,
	toggleDelete = function() end,
	rotate = function() end,
}

function UI.SetHandlers(h: { [string]: () -> () } | any)
	for k, v in pairs(h) do
		(handlers :: any)[k] = v
	end
end

-- // toasts
function UI.Toast(text: string, kind: string?)
	local color = kind == "good" and C_GOOD or kind == "bad" and C_BAD or C_ACCENT
	local toast = new("TextLabel", {
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C_PANEL,
		BackgroundTransparency = 0.08,
		Text = "  " .. text .. "  ",
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = C_TEXT,
	}, toastHolder)
	round(toast, 8)
	stroke(toast, color, 1.5)
	task.delay(3.2, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

function UI.SetMoney(amount: number)
	moneyLabel.Text = Util.money(amount)
end

-- // confirm dialog ------------------------------------------------------

local confirmYes: TextButton
local confirmTitle: TextLabel
local confirmBody: TextLabel
local confirmCallback: (() -> ())? = nil

function UI.Confirm(title: string, body: string, onYes: () -> ())
	confirmTitle.Text = title
	confirmBody.Text = body
	confirmCallback = onYes
	confirmDialog.Visible = true
end

local function buildConfirmDialog()
	confirmDialog = new("Frame", {
		Size = UDim2.fromOffset(340, 170),
		Position = UDim2.new(0.5, -170, 0.5, -85),
		BackgroundColor3 = C_PANEL,
		Visible = false,
		ZIndex = 50,
	}, screen)
	round(confirmDialog, 12)
	stroke(confirmDialog)

	confirmTitle = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = C_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 51,
	}, confirmDialog)

	confirmBody = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 60),
		Position = UDim2.fromOffset(12, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = C_SUBTEXT,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 51,
	}, confirmDialog)

	confirmYes = textButton("Confirm", {
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(0.5, -158, 1, -48),
		BackgroundColor3 = C_ACCENT,
		ZIndex = 51,
	}, confirmDialog)
	local noBtn = textButton("Cancel", {
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(0.5, 8, 1, -48),
		ZIndex = 51,
	}, confirmDialog)

	confirmYes.Activated:Connect(function()
		confirmDialog.Visible = false
		if confirmCallback then
			confirmCallback()
		end
	end)
	noBtn.Activated:Connect(function()
		confirmDialog.Visible = false
	end)
end

-- // HUD -----------------------------------------------------------------

local function buildHUD()
	local moneyPill = new("Frame", {
		Size = UDim2.fromOffset(170, 40),
		Position = UDim2.new(0.5, -85, 0, 12),
		BackgroundColor3 = C_PANEL,
		BackgroundTransparency = 0.1,
	}, screen)
	round(moneyPill, 20)
	stroke(moneyPill, C_GOLD)
	moneyLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 19,
		TextColor3 = C_GOLD,
		Text = "$0",
	}, moneyPill)

	local bottomBar = new("Frame", {
		Size = UDim2.fromOffset(360, 46),
		Position = UDim2.new(0.5, -180, 1, -60),
		BackgroundTransparency = 1,
	}, screen)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
	}, bottomBar)

	buildButton = textButton("BUILD", { Size = UDim2.fromOffset(110, 46), BackgroundColor3 = C_ACCENT }, bottomBar)
	local marketBtn = textButton("MARKET", { Size = UDim2.fromOffset(110, 46), BackgroundColor3 = C_GOOD }, bottomBar)
	local publishBtn = textButton("PUBLISH", { Size = UDim2.fromOffset(110, 46), BackgroundColor3 = C_GOLD }, bottomBar)
	publishBtn.TextColor3 = Color3.fromRGB(40, 34, 16)

	buildButton.Activated:Connect(function()
		if catalogPanel.Visible then
			handlers.exitBuild()
		else
			handlers.enterBuild()
		end
	end)
	marketBtn.Activated:Connect(function()
		UI.ToggleMarket()
	end)
	publishBtn.Activated:Connect(function()
		publishDialog.Visible = not publishDialog.Visible
	end)

	toastHolder = new("Frame", {
		Size = UDim2.fromOffset(400, 300),
		Position = UDim2.new(0.5, -200, 0, 64),
		BackgroundTransparency = 1,
	}, screen)
	new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toastHolder)
end

-- // build catalog -------------------------------------------------------

local selectedItemButton: TextButton? = nil

local function buildCatalog()
	catalogPanel = new("Frame", {
		Size = UDim2.new(0, 260, 1, -140),
		Position = UDim2.new(0, 12, 0, 70),
		BackgroundColor3 = C_PANEL,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, screen)
	round(catalogPanel, 12)
	stroke(catalogPanel)

	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = C_TEXT,
		Text = "Build Catalog",
	}, catalogPanel)

	-- category tabs
	local tabs = new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 36),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
	}, catalogPanel)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabs)

	-- item list
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -160),
		Position = UDim2.fromOffset(8, 72),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, catalogPanel)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local function showCategory(category: string)
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		selectedItemButton = nil
		for _, item in ipairs(Catalog.Items) do
			if item.category == category then
				local row = textButton("", { Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = C_PANEL2 }, list)
				new("TextLabel", {
					Size = UDim2.new(1, -80, 1, 0),
					Position = UDim2.fromOffset(10, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamMedium,
					TextSize = 14,
					TextColor3 = C_TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = item.name,
				}, row)
				new("TextLabel", {
					Size = UDim2.fromOffset(70, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Position = UDim2.new(1, -78, 0.5, -8),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextColor3 = C_GOLD,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = Util.money(item.price),
				}, row)
				row.Activated:Connect(function()
					if selectedItemButton then
						selectedItemButton.BackgroundColor3 = C_PANEL2
					end
					selectedItemButton = row
					row.BackgroundColor3 = C_ACCENT
					handlers.selectItem(item.id)
				end)
			end
		end
	end

	for i, category in ipairs(Catalog.Categories) do
		local tab = textButton(category, { Size = UDim2.fromOffset(76, 26), TextSize = 12 }, tabs)
		tab.Activated:Connect(function()
			showCategory(category)
		end)
		if i == 1 then
			task.defer(showCategory, category)
		end
	end

	-- action buttons (also the mobile path for rotate/delete/exit)
	local actions = new("Frame", {
		Size = UDim2.new(1, -16, 0, 78),
		Position = UDim2.new(0, 8, 1, -86),
		BackgroundTransparency = 1,
	}, catalogPanel)
	local rotateBtn = textButton("Rotate [R]", { Size = UDim2.new(0.5, -4, 0, 34) }, actions)
	deleteButton = textButton("Delete [X]", { Size = UDim2.new(0.5, -4, 0, 34), Position = UDim2.new(0.5, 4, 0, 0) }, actions)
	local exitBtn = textButton("Exit Build [Q]", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 40),
		BackgroundColor3 = C_BAD,
	}, actions)

	rotateBtn.Activated:Connect(function()
		handlers.rotate()
	end)
	deleteButton.Activated:Connect(function()
		handlers.toggleDelete()
	end)
	exitBtn.Activated:Connect(function()
		handlers.exitBuild()
	end)
end

function UI.SetBuildMode(active: boolean, deleteMode: boolean)
	catalogPanel.Visible = active
	buildButton.Text = active and "DONE" or "BUILD"
	deleteButton.BackgroundColor3 = deleteMode and C_BAD or C_PANEL2
	if not active and selectedItemButton then
		selectedItemButton.BackgroundColor3 = C_PANEL2
		selectedItemButton = nil
	end
end

-- // blueprint market ----------------------------------------------------

local marketList: ScrollingFrame
local marketTabs: { [string]: TextButton } = {}
local currentTab = "top"

local function metaLine(meta: any): string
	return ("by %s%s  |  %d items  |  %d sold"):format(
		meta.creatorName or "?",
		meta.pro and " [PRO]" or "",
		meta.itemCount or 0,
		meta.sales or 0
	)
end

local function addMarketRow(meta: any, mineTab: boolean)
	local row = new("Frame", {
		Size = UDim2.new(1, -6, 0, 64),
		BackgroundColor3 = C_PANEL2,
	}, marketList)
	round(row, 8)

	new("TextLabel", {
		Size = UDim2.new(1, -240, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = meta.name or "?",
	}, row)
	new("TextLabel", {
		Size = UDim2.new(1, -240, 0, 18),
		Position = UDim2.fromOffset(12, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = C_SUBTEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = metaLine(meta),
	}, row)
	new("TextLabel", {
		Size = UDim2.fromOffset(100, 24),
		Position = UDim2.new(1, -218, 0, 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C_GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Util.money(meta.price or 0),
	}, row)
	new("TextLabel", {
		Size = UDim2.fromOffset(100, 16),
		Position = UDim2.new(1, -218, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = C_SUBTEXT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "+ materials " .. Util.money(meta.materialCost or 0),
	}, row)

	local owned = meta.owned or meta.mine or mineTab
	local action = textButton(owned and "BUILD IT" or "BUY", {
		Size = UDim2.fromOffset(96, 40),
		Position = UDim2.new(1, -108, 0, 12),
		BackgroundColor3 = owned and C_GOOD or C_ACCENT,
	}, row)

	action.Activated:Connect(function()
		if owned then
			UI.Confirm(
				"Build this house?",
				("Your current build is refunded at %d%%. Materials cost %s."):format(
					Config.SellRefundRate * 100,
					Util.money(meta.materialCost or 0)
				),
				function()
					local result = Net.func("ApplyBlueprint"):InvokeServer(meta.id)
					if result and result.ok then
						UI.Toast("Blueprint built on your plot!", "good")
						UI.CloseMarket()
					else
						UI.Toast(UI.ErrorText(result and result.err), "bad")
					end
				end
			)
		else
			UI.Confirm(
				"Buy blueprint?",
				("Design fee %s. The creator earns %d%%. You can then build it anytime (materials %s)."):format(
					Util.money(meta.price or 0),
					Config.Blueprint.RoyaltyRate * 100,
					Util.money(meta.materialCost or 0)
				),
				function()
					local result = Net.func("BuyBlueprint"):InvokeServer(meta.id)
					if result and result.ok then
						UI.Toast("Blueprint purchased! Open MARKET > Mine to build it.", "good")
						UI.RefreshMarket()
					else
						UI.Toast(UI.ErrorText(result and result.err), "bad")
					end
				end
			)
		end
	end)
end

function UI.RefreshMarket()
	for _, child in ipairs(marketList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for name, tabBtn in pairs(marketTabs) do
		tabBtn.BackgroundColor3 = name == currentTab and C_ACCENT or C_PANEL2
	end

	task.spawn(function()
		if currentTab == "mine" then
			local result = Net.func("GetMyBlueprints"):InvokeServer()
			if not (result and result.ok) then
				UI.Toast(UI.ErrorText(result and result.err), "bad")
				return
			end
			for _, meta in ipairs(result.published or {}) do
				addMarketRow(meta, true)
			end
			for _, meta in ipairs(result.owned or {}) do
				addMarketRow(meta, true)
			end
			if result.totalRoyalties and result.totalRoyalties > 0 then
				UI.Toast(("Lifetime royalties: %s"):format(Util.money(result.totalRoyalties)), "info")
			end
		else
			local result = Net.func("GetMarket"):InvokeServer(currentTab)
			if not (result and result.ok) then
				UI.Toast(UI.ErrorText(result and result.err), "bad")
				return
			end
			for _, meta in ipairs(result.listings or {}) do
				addMarketRow(meta, false)
			end
		end
	end)
end

local function buildMarket()
	marketWindow = new("Frame", {
		Size = UDim2.fromOffset(560, 440),
		Position = UDim2.new(0.5, -280, 0.5, -220),
		BackgroundColor3 = C_PANEL,
		Visible = false,
		ZIndex = 20,
	}, screen)
	round(marketWindow, 12)
	stroke(marketWindow)

	new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 40),
		Position = UDim2.fromOffset(16, 6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 19,
		TextColor3 = C_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Blueprint Market",
		ZIndex = 21,
	}, marketWindow)

	local closeBtn = textButton("X", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -42, 0, 8),
		BackgroundColor3 = C_BAD,
		ZIndex = 21,
	}, marketWindow)
	closeBtn.Activated:Connect(function()
		marketWindow.Visible = false
	end)

	local tabDefs = { { "top", "Top Sellers" }, { "new", "Newest" }, { "mine", "Mine" } }
	for i, def in ipairs(tabDefs) do
		local tabBtn = textButton(def[2], {
			Size = UDim2.fromOffset(110, 30),
			Position = UDim2.fromOffset(16 + (i - 1) * 118, 48),
			TextSize = 13,
			ZIndex = 21,
		}, marketWindow)
		marketTabs[def[1]] = tabBtn
		tabBtn.Activated:Connect(function()
			currentTab = def[1]
			UI.RefreshMarket()
		end)
	end

	local refreshBtn = textButton("Refresh", {
		Size = UDim2.fromOffset(80, 30),
		Position = UDim2.new(1, -96, 0, 48),
		TextSize = 13,
		ZIndex = 21,
	}, marketWindow)
	refreshBtn.Activated:Connect(UI.RefreshMarket)

	marketList = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -100),
		Position = UDim2.fromOffset(12, 88),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, marketWindow)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, marketList)
end

function UI.ToggleMarket()
	marketWindow.Visible = not marketWindow.Visible
	if marketWindow.Visible then
		UI.RefreshMarket()
	end
end

function UI.CloseMarket()
	marketWindow.Visible = false
end

-- // publish dialog ------------------------------------------------------

local function buildPublishDialog()
	publishDialog = new("Frame", {
		Size = UDim2.fromOffset(360, 250),
		Position = UDim2.new(0.5, -180, 0.5, -125),
		BackgroundColor3 = C_PANEL,
		Visible = false,
		ZIndex = 30,
	}, screen)
	round(publishDialog, 12)
	stroke(publishDialog)

	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(12, 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = C_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Publish Blueprint",
		ZIndex = 31,
	}, publishDialog)

	local nameBox = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 46),
		BackgroundColor3 = C_PANEL2,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = C_TEXT,
		PlaceholderText = "Blueprint name (e.g. Cozy Modern Villa)",
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 31,
	}, publishDialog)
	round(nameBox, 8)

	local priceBox = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 90),
		BackgroundColor3 = C_PANEL2,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = C_TEXT,
		PlaceholderText = ("Design fee (%s - %s)"):format(Util.money(Config.Blueprint.MinPrice), Util.money(Config.Blueprint.MaxPrice)),
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 31,
	}, publishDialog)
	round(priceBox, 8)

	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 54),
		Position = UDim2.fromOffset(12, 132),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = C_SUBTEXT,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = ("Sells your CURRENT plot as a design. You earn %d%% of every sale - even offline. Buyers pay materials on top, so price is pure profit share."):format(Config.Blueprint.RoyaltyRate * 100),
		ZIndex = 31,
	}, publishDialog)

	local publishGo = textButton("PUBLISH TO MARKET", {
		Size = UDim2.new(0.6, -8, 0, 38),
		Position = UDim2.new(0, 12, 1, -50),
		BackgroundColor3 = C_GOLD,
		TextColor3 = Color3.fromRGB(40, 34, 16),
		ZIndex = 31,
	}, publishDialog)
	local cancelBtn = textButton("Cancel", {
		Size = UDim2.new(0.4, -20, 0, 38),
		Position = UDim2.new(0.6, 12, 1, -50),
		ZIndex = 31,
	}, publishDialog)

	publishGo.Activated:Connect(function()
		local price = tonumber(priceBox.Text)
		if not price then
			UI.Toast(UI.ErrorText("bad-price"), "bad")
			return
		end
		publishGo.Text = "PUBLISHING..."
		task.spawn(function()
			local result = Net.func("PublishBlueprint"):InvokeServer(nameBox.Text, math.floor(price))
			publishGo.Text = "PUBLISH TO MARKET"
			if result and result.ok then
				publishDialog.Visible = false
				UI.Toast(("'%s' is live on the market!"):format(result.meta.name), "good")
			else
				UI.Toast(UI.ErrorText(result and result.err), "bad")
			end
		end)
	end)
	cancelBtn.Activated:Connect(function()
		publishDialog.Visible = false
	end)
end

-- // init ----------------------------------------------------------------

function UI.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = new("ScreenGui", {
		Name = "BlueprintHomesUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	buildHUD()
	buildCatalog()
	buildMarket()
	buildPublishDialog()
	buildConfirmDialog()

	-- server events
	Net.event("MoneyChanged").OnClientEvent:Connect(UI.SetMoney)
	Net.event("Notify").OnClientEvent:Connect(function(text, kind)
		UI.Toast(tostring(text), tostring(kind))
	end)

	task.spawn(function()
		local balance = Net.func("GetBalance"):InvokeServer()
		if type(balance) == "number" then
			UI.SetMoney(balance)
		end
	end)
end

return UI
