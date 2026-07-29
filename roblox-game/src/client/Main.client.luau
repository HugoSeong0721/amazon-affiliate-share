--!strict
-- Client for Comeback! K-pop Dress Up.
-- Builds the whole UI in code (closet, coins, photo booth, popups) and fills
-- the closet from the live Roblox catalog, so no asset ids are hardcoded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarEditorService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")
local CaptureService = game:GetService("CaptureService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyItem") :: RemoteFunction
local equipRemote = remotes:WaitForChild("EquipItem") :: RemoteFunction
local photoRemote = remotes:WaitForChild("TakePhoto") :: RemoteFunction
local stateRemote = remotes:WaitForChild("GetState") :: RemoteFunction
local coinsChanged = remotes:WaitForChild("CoinsChanged") :: RemoteEvent
local dailyReward = remotes:WaitForChild("DailyReward") :: RemoteEvent

----------------------------------------------------------------------
-- Palette / helpers
----------------------------------------------------------------------

local PINK = Color3.fromRGB(255, 89, 158)
local PINK_SOFT = Color3.fromRGB(255, 214, 231)
local PURPLE_DARK = Color3.fromRGB(58, 34, 84)
local WHITE = Color3.fromRGB(255, 255, 255)
local YELLOW = Color3.fromRGB(255, 214, 74)
local FONT = Enum.Font.FredokaOne

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

local function round(radius: number): Instance
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

----------------------------------------------------------------------
-- Client state
----------------------------------------------------------------------

type CatalogItem = { id: number, name: string }

local coins = 0
local owned: { [string]: boolean } = {}
local equipped: { [string]: number } = {}
local catalogCache: { [string]: { CatalogItem } } = {}
local photoBusy = false

local function isOwnedOrFree(assetId: number): boolean
	return owned[tostring(assetId)] == true or Config.priceFor(assetId) == 0
end

----------------------------------------------------------------------
-- Root UI
----------------------------------------------------------------------

local gui = create("ScreenGui", {
	Name = "ComebackUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Top-left logo
create("TextLabel", {
	Size = UDim2.fromOffset(280, 44),
	Position = UDim2.fromOffset(16, 14),
	BackgroundTransparency = 1,
	Text = "COMEBACK! \u{2728}",
	Font = FONT,
	TextSize = 34,
	TextColor3 = WHITE,
	TextStrokeColor3 = PINK,
	TextStrokeTransparency = 0.2,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = gui,
})

-- Top-right coin bar
local coinLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "\u{1FA99} 0",
	Font = FONT,
	TextSize = 26,
	TextColor3 = PURPLE_DARK,
})
create("Frame", {
	Size = UDim2.fromOffset(150, 44),
	Position = UDim2.new(1, -166, 0, 14),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.1,
	Parent = gui,
}, { round(22), coinLabel })

local function setCoins(value: number)
	coins = value
	coinLabel.Text = `\u{1FA99} {value}`
end

-- Toast message (short feedback, big and readable for young kids)
local toastLabel = create("TextLabel", {
	Size = UDim2.fromOffset(420, 52),
	Position = UDim2.new(0.5, -210, 0, 80),
	BackgroundColor3 = PURPLE_DARK,
	BackgroundTransparency = 0.15,
	Text = "",
	Font = FONT,
	TextSize = 26,
	TextColor3 = WHITE,
	Visible = false,
	Parent = gui,
}, { round(26) })

local toastToken = 0
local function toast(message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(2.2, function()
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- Bottom action buttons
----------------------------------------------------------------------

local function actionButton(text: string, xOffset: number): TextButton
	local button = create("TextButton", {
		Size = UDim2.fromOffset(170, 62),
		Position = UDim2.new(0.5, xOffset, 1, -86),
		BackgroundColor3 = PINK,
		Text = text,
		Font = FONT,
		TextSize = 28,
		TextColor3 = WHITE,
		AutoButtonColor = true,
		Parent = gui,
	}, { round(31) })
	create("UIStroke", { Thickness = 3, Color = WHITE, Parent = button })
	return button
end

local closetButton = actionButton("\u{1F457} Closet", -184)
local photoButton = actionButton("\u{1F4F8} Photo", 14)

----------------------------------------------------------------------
-- Closet panel
----------------------------------------------------------------------

local closetPanel = create("Frame", {
	Size = UDim2.new(0, 420, 1, -160),
	Position = UDim2.new(1, -436, 0, 72),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = gui,
}, { round(18) })

local tabBar = create("Frame", {
	Size = UDim2.new(1, -16, 0, 46),
	Position = UDim2.fromOffset(8, 8),
	BackgroundTransparency = 1,
	Parent = closetPanel,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})

local itemGrid = create("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -70),
	Position = UDim2.fromOffset(8, 62),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = closetPanel,
}, {
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(120, 140),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})

local loadingLabel = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.fromScale(0, 0.4),
	BackgroundTransparency = 1,
	Text = "Loading... \u{2728}",
	Font = FONT,
	TextSize = 26,
	TextColor3 = PINK,
	Visible = false,
	Parent = closetPanel,
})

----------------------------------------------------------------------
-- Buy confirmation popup (simple yes/no, readable at age 6)
----------------------------------------------------------------------

local buyPopup = create("Frame", {
	Size = UDim2.fromOffset(320, 220),
	Position = UDim2.new(0.5, -160, 0.5, -110),
	BackgroundColor3 = WHITE,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, { round(18) })

local buyThumb = create("ImageLabel", {
	Size = UDim2.fromOffset(90, 90),
	Position = UDim2.new(0.5, -45, 0, 12),
	BackgroundColor3 = PINK_SOFT,
	ZIndex = 10,
	Parent = buyPopup,
}, { round(12) })

local buyText = create("TextLabel", {
	Size = UDim2.new(1, -20, 0, 36),
	Position = UDim2.fromOffset(10, 108),
	BackgroundTransparency = 1,
	Text = "",
	Font = FONT,
	TextSize = 26,
	TextColor3 = PURPLE_DARK,
	ZIndex = 10,
	Parent = buyPopup,
})

local function popupButton(text: string, x: number, color: Color3): TextButton
	return create("TextButton", {
		Size = UDim2.fromOffset(130, 50),
		Position = UDim2.new(0, x, 1, -62),
		BackgroundColor3 = color,
		Text = text,
		Font = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		ZIndex = 10,
		Parent = buyPopup,
	}, { round(25) })
end

local buyYes = popupButton("Yes! \u{1F49C}", 20, PINK)
local buyNo = popupButton("No", 170, Color3.fromRGB(170, 170, 190))
local pendingPurchase: { item: CatalogItem, categoryKey: string }? = nil

----------------------------------------------------------------------
-- Equipping / buying
----------------------------------------------------------------------

local refreshGrid: () -> () -- forward-declared, defined with the tabs below

local function equipItem(assetId: number?, categoryKey: string)
	local result = equipRemote:InvokeServer(assetId, categoryKey)
	if result and result.ok then
		if assetId == nil then
			equipped[categoryKey] = nil
		else
			equipped[categoryKey] = assetId
		end
		refreshGrid()
	elseif result and result.message then
		toast(result.message)
	end
end

buyYes.MouseButton1Click:Connect(function()
	local purchase = pendingPurchase
	buyPopup.Visible = false
	pendingPurchase = nil
	if not purchase then
		return
	end
	local result = buyRemote:InvokeServer(purchase.item.id, purchase.categoryKey)
	if result and result.ok then
		owned[tostring(purchase.item.id)] = true
		if result.coins then
			setCoins(result.coins)
		end
		toast("You got it! \u{1F389}")
		equipItem(purchase.item.id, purchase.categoryKey)
	elseif result and result.message then
		toast(result.message)
	end
end)

buyNo.MouseButton1Click:Connect(function()
	buyPopup.Visible = false
	pendingPurchase = nil
end)

----------------------------------------------------------------------
-- Catalog search
----------------------------------------------------------------------

local function searchCategory(category: Config.Category): { CatalogItem }
	local cached = catalogCache[category.key]
	if cached then
		return cached
	end

	local items: { CatalogItem } = {}
	local seen: { [number]: boolean } = {}

	for _, keyword in category.searches or {} do
		local ok, pages = pcall(function()
			local params = CatalogSearchParams.new()
			params.SearchKeyword = keyword
			params.AssetTypes = category.avatarAssetTypes :: any
			return AvatarEditorService:SearchCatalog(params)
		end)
		if not ok or not pages then
			continue
		end
		local pageOk, page = pcall(function()
			return pages:GetCurrentPage()
		end)
		if not pageOk or not page then
			continue
		end
		for _, entry in page do
			local id = entry.Id
			local itemType = entry.ItemType
			local isAsset = itemType == "Asset" or itemType == Enum.AvatarItemType.Asset
			if type(id) == "number" and not seen[id] and isAsset then
				seen[id] = true
				table.insert(items, { id = id, name = tostring(entry.Name or "Item") })
				if #items >= Config.ItemsPerSearch * 2 then
					break
				end
			end
		end
	end

	catalogCache[category.key] = items
	return items
end

----------------------------------------------------------------------
-- Closet grid rendering
----------------------------------------------------------------------

local activeCategory: Config.Category = Config.Categories[1]

local function clearGrid()
	for _, child in itemGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeCell(): (TextButton, ImageLabel, TextLabel)
	local thumb = create("ImageLabel", {
		Size = UDim2.new(1, -12, 1, -46),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = PINK_SOFT,
	}, { round(10) })
	local caption = create("TextLabel", {
		Size = UDim2.new(1, -8, 0, 32),
		Position = UDim2.new(0, 4, 1, -36),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextColor3 = PURPLE_DARK,
		Text = "",
	})
	local cell = create("TextButton", {
		BackgroundColor3 = WHITE,
		Text = "",
		AutoButtonColor = true,
		Parent = itemGrid,
	}, { round(12), thumb, caption })
	create("UIStroke", { Thickness = 3, Color = PINK_SOFT, Parent = cell })
	return cell, thumb, caption
end

local function renderSkinTab()
	for index, tone in Config.SkinTones do
		local cell, thumb, caption = makeCell()
		thumb.Image = ""
		thumb.BackgroundColor3 = tone
		caption.Text = equipped.Skin == index and "\u{2705}" or ""
		if equipped.Skin == index then
			(cell:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = PINK
		end
		cell.MouseButton1Click:Connect(function()
			equipItem(index, "Skin")
		end)
	end
end

local function renderItemTab(category: Config.Category)
	loadingLabel.Visible = true
	local items = searchCategory(category)
	loadingLabel.Visible = false

	if activeCategory.key ~= category.key then
		return -- the player switched tabs while we were searching
	end

	if #items == 0 then
		loadingLabel.Text = "Nothing here yet \u{1F97A} Try again!"
		loadingLabel.Visible = true
		catalogCache[category.key] = nil
		return
	end
	loadingLabel.Text = "Loading... \u{2728}"

	-- "Take off" cell first
	local offCell, offThumb, offCaption = makeCell()
	offThumb.Image = ""
	offCaption.Text = "Take off"
	offThumb.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
	offCell.MouseButton1Click:Connect(function()
		equipItem(nil, category.key)
	end)

	for _, item in items do
		local cell, thumb, caption = makeCell()
		thumb.Image = `rbxthumb://type=Asset&id={item.id}&w=150&h=150`
		local price = Config.priceFor(item.id)
		if equipped[category.key] == item.id then
			caption.Text = "\u{2705} On!"
			;(cell:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = PINK
		elseif isOwnedOrFree(item.id) then
			caption.Text = price == 0 and "FREE \u{1F49B}" or "Owned \u{2714}"
		else
			caption.Text = `\u{1FA99} {price}`
		end
		cell.MouseButton1Click:Connect(function()
			if isOwnedOrFree(item.id) then
				equipItem(item.id, category.key)
			else
				pendingPurchase = { item = item, categoryKey = category.key }
				buyThumb.Image = thumb.Image
				buyText.Text = `Buy for \u{1FA99} {price}?`
				buyPopup.Visible = true
			end
		end)
	end
end

refreshGrid = function()
	clearGrid()
	if activeCategory.isSkin then
		renderSkinTab()
	else
		task.spawn(renderItemTab, activeCategory)
	end
end

-- Tabs
for _, category in Config.Categories do
	local tab = create("TextButton", {
		Size = UDim2.fromOffset(74, 42),
		BackgroundColor3 = category.key == activeCategory.key and PINK or PINK_SOFT,
		Text = `{category.icon}`,
		Font = FONT,
		TextSize = 22,
		TextColor3 = WHITE,
		Parent = tabBar,
	}, { round(21) })
	tab.MouseButton1Click:Connect(function()
		activeCategory = category
		for _, other in tabBar:GetChildren() do
			if other:IsA("TextButton") then
				other.BackgroundColor3 = PINK_SOFT
			end
		end
		tab.BackgroundColor3 = PINK
		refreshGrid()
	end)
end

closetButton.MouseButton1Click:Connect(function()
	closetPanel.Visible = not closetPanel.Visible
	if closetPanel.Visible then
		refreshGrid()
	end
end)

----------------------------------------------------------------------
-- Photocard booth
----------------------------------------------------------------------

local photoOverlay = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
})

-- Cute photocard frame borders
local function frameBar(size: UDim2, position: UDim2)
	create("Frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = PINK,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = photoOverlay,
	})
end
frameBar(UDim2.new(1, 0, 0, 14), UDim2.fromScale(0, 0))
frameBar(UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -14))
frameBar(UDim2.new(0, 14, 1, 0), UDim2.fromScale(0, 0))
frameBar(UDim2.new(0, 14, 1, 0), UDim2.new(1, -14, 0, 0))

create("TextLabel", {
	Size = UDim2.fromOffset(300, 40),
	Position = UDim2.new(0.5, -150, 1, -60),
	BackgroundTransparency = 1,
	Text = "COMEBACK! \u{2728}",
	Font = FONT,
	TextSize = 30,
	TextColor3 = WHITE,
	TextStrokeColor3 = PINK,
	TextStrokeTransparency = 0.2,
	ZIndex = 20,
	Parent = photoOverlay,
})

local countdownLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 0.3),
	Position = UDim2.fromScale(0, 0.32),
	BackgroundTransparency = 1,
	Text = "",
	Font = FONT,
	TextSize = 120,
	TextColor3 = WHITE,
	TextStrokeColor3 = PINK,
	TextStrokeTransparency = 0,
	ZIndex = 21,
	Visible = false,
	Parent = gui,
})

local function takePhoto()
	if photoBusy then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not head or not humanoidRoot then
		return
	end
	photoBusy = true
	closetPanel.Visible = false

	local camera = workspace.CurrentCamera
	local originalType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local lookDirection = humanoidRoot.CFrame.LookVector
	local focus = head.Position - Vector3.new(0, 0.5, 0)
	local target = CFrame.lookAt(focus + lookDirection * 7 + Vector3.new(0, 0.5, 0), focus)
	local tween = TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = target })
	tween:Play()
	tween.Completed:Wait()

	countdownLabel.Visible = true
	for count = 3, 1, -1 do
		countdownLabel.Text = tostring(count)
		task.wait(0.7)
	end
	countdownLabel.Visible = false
	photoOverlay.Visible = true
	task.wait(0.1)

	pcall(function()
		CaptureService:CaptureScreenshot(function(contentId: string)
			pcall(function()
				CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
			end)
		end)
	end)

	task.wait(0.5)
	photoOverlay.Visible = false
	camera.CameraType = originalType

	local result = photoRemote:InvokeServer()
	if result and result.ok then
		if result.coins then
			setCoins(result.coins)
		end
		if result.rewarded then
			toast(`Photocard saved! +{Config.PhotoRewardCoins} \u{1FA99}`)
		else
			toast("Photocard saved! \u{1F4F8}")
		end
	end
	photoBusy = false
end

photoButton.MouseButton1Click:Connect(takePhoto)

----------------------------------------------------------------------
-- Daily reward popup
----------------------------------------------------------------------

dailyReward.OnClientEvent:Connect(function(amount: number)
	local okButton = create("TextButton", {
		Size = UDim2.fromOffset(160, 52),
		Position = UDim2.new(0.5, -80, 1, -66),
		BackgroundColor3 = PINK,
		Text = "Yay!",
		Font = FONT,
		TextSize = 26,
		TextColor3 = WHITE,
		ZIndex = 15,
	}, { round(26) })
	local popup = create("Frame", {
		Size = UDim2.fromOffset(340, 200),
		Position = UDim2.new(0.5, -170, 0.5, -100),
		BackgroundColor3 = WHITE,
		ZIndex = 15,
		Parent = gui,
	}, {
		round(18),
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 70),
			Position = UDim2.fromOffset(0, 16),
			BackgroundTransparency = 1,
			Text = "\u{1F381} Daily Gift!",
			Font = FONT,
			TextSize = 34,
			TextColor3 = PURPLE_DARK,
			ZIndex = 15,
		}),
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 80),
			BackgroundTransparency = 1,
			Text = `+{amount} \u{1FA99}`,
			Font = FONT,
			TextSize = 30,
			TextColor3 = YELLOW,
			TextStrokeColor3 = PURPLE_DARK,
			TextStrokeTransparency = 0.5,
			ZIndex = 15,
		}),
		okButton,
	})
	okButton.MouseButton1Click:Connect(function()
		popup:Destroy()
	end)
end)

----------------------------------------------------------------------
-- Initial state sync
----------------------------------------------------------------------

coinsChanged.OnClientEvent:Connect(setCoins)

task.spawn(function()
	local state = stateRemote:InvokeServer()
	if state then
		setCoins(state.coins or 0)
		owned = state.owned or {}
		equipped = state.equipped or {}
	end
end)
