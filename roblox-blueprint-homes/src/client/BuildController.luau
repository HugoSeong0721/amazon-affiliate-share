--!strict
-- Client build mode: grid ghost preview, rotate, place, delete.
-- Purely cosmetic - the server re-validates everything.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local GridUtil = require(Shared.GridUtil)
local ItemModels = require(Shared.ItemModels)
local Net = require(Shared.Net)

local BuildController = {}

local UI: any = nil

-- plot state (from PlotAssigned)
local plotBase: BasePart? = nil
local itemsFolder: Folder? = nil
local plotOrigin: Vector3? = nil

-- occupancy mirror (cell key -> overlapping item count) for instant green/red feedback
local occupancyCount: { [string]: { [string]: number } } = { floor = {}, object = {} }

-- build mode state
local active = false
local deleteMode = false
local selectedId: string? = nil
local rotation = 0
local ghost: Model? = nil
local ghostValid = false
local lastCell: { x: number, z: number }? = nil
local plotSelection: SelectionBox? = nil
local hoverHighlight: Highlight? = nil

local placeSound: Sound? = nil

-- // occupancy mirror ----------------------------------------------------

local function trackItem(model: Instance, add: boolean)
	if not model:IsA("Model") then
		return
	end
	local itemId = model:GetAttribute("ItemId")
	local x = model:GetAttribute("X")
	local z = model:GetAttribute("Z")
	local r = model:GetAttribute("R")
	local def = itemId and Catalog.ById[itemId]
	if not def or type(x) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return
	end
	local layerMap = occupancyCount[def.layer]
	for _, key in ipairs(GridUtil.cellKeys(x, z, def.w, def.d, r)) do
		layerMap[key] = math.max(0, (layerMap[key] or 0) + (add and 1 or -1))
		if layerMap[key] == 0 then
			layerMap[key] = nil
		end
	end
end

local function watchItemsFolder(folder: Folder)
	occupancyCount = { floor = {}, object = {} }
	for _, child in ipairs(folder:GetChildren()) do
		trackItem(child, true)
	end
	folder.ChildAdded:Connect(function(child)
		task.defer(trackItem, child, true) -- defer so attributes replicate first
	end)
	folder.ChildRemoved:Connect(function(child)
		trackItem(child, false)
	end)
end

local function cellsFree(def: any, x: number, z: number, r: number): boolean
	local layerMap = occupancyCount[def.layer]
	for _, key in ipairs(GridUtil.cellKeys(x, z, def.w, def.d, r)) do
		if layerMap[key] then
			return false
		end
	end
	return true
end

-- // ghost ---------------------------------------------------------------

local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	lastCell = nil
end

local function setGhostColor(valid: boolean)
	if not ghost then
		return
	end
	local highlight = ghost:FindFirstChild("GhostHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight.FillColor = valid and Color3.fromRGB(90, 200, 120) or Color3.fromRGB(220, 80, 70)
		highlight.OutlineColor = highlight.FillColor
	end
end

local function refreshGhost()
	destroyGhost()
	if active and not deleteMode and selectedId then
		local def = Catalog.ById[selectedId]
		if def then
			ghost = ItemModels.buildGhost(def)
			ghost.Parent = workspace.CurrentCamera -- camera children don't collide/replicate
		end
	end
end

-- // input helpers -------------------------------------------------------

local function pointerRay(): Ray?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local pos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(pos.X, pos.Y)
	return Ray.new(unitRay.Origin, unitRay.Direction * 300)
end

local function raycastPlot(): Vector3?
	local base = plotBase
	if not base then
		return nil
	end
	local ray = pointerRay()
	if not ray then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { base }
	local hit = workspace:Raycast(ray.Origin, ray.Direction, params)
	return hit and hit.Position or nil
end

local function raycastOwnItem(): Model?
	local folder = itemsFolder
	if not folder then
		return nil
	end
	local ray = pointerRay()
	if not ray then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction, params)
	if hit and hit.Instance then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Uid") then
			return model
		end
	end
	return nil
end

-- // actions -------------------------------------------------------------

local function tryPlace()
	if not (active and not deleteMode and selectedId and lastCell and ghostValid) then
		return
	end
	local result = Net.func("PlaceItem"):InvokeServer(selectedId, lastCell.x, lastCell.z, rotation)
	if result and result.ok then
		if placeSound then
			placeSound:Play()
		end
	elseif result then
		UI.Toast(UI.ErrorText(result.err), "bad")
	end
end

local function tryDelete()
	local model = raycastOwnItem()
	if not model then
		return
	end
	local uid = model:GetAttribute("Uid")
	local result = Net.func("RemoveItem"):InvokeServer(uid)
	if result and not result.ok then
		UI.Toast(UI.ErrorText(result.err), "bad")
	end
end

-- // mode control --------------------------------------------------------

local function setDeleteMode(on: boolean)
	deleteMode = on
	if deleteMode then
		destroyGhost()
	else
		refreshGhost()
	end
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
	UI.SetBuildMode(active, deleteMode)
end

function BuildController.EnterBuild()
	if not plotBase then
		UI.Toast("You don't have a plot on this server.", "bad")
		return
	end
	active = true
	deleteMode = false
	UI.SetBuildMode(true, false)
	if plotSelection then
		plotSelection:Destroy()
	end
	local selection = Instance.new("SelectionBox")
	selection.LineThickness = 0.03
	selection.Color3 = Color3.fromRGB(90, 200, 250)
	selection.Adornee = plotBase
	selection.Parent = plotBase
	plotSelection = selection
	refreshGhost()
end

function BuildController.ExitBuild()
	active = false
	deleteMode = false
	selectedId = nil
	destroyGhost()
	if plotSelection then
		plotSelection:Destroy()
		plotSelection = nil
	end
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
	UI.SetBuildMode(false, false)
end

function BuildController.SelectItem(itemId: string)
	selectedId = itemId
	if deleteMode then
		setDeleteMode(false)
	else
		refreshGhost()
	end
end

function BuildController.Rotate()
	rotation = (rotation + 1) % 4
end

function BuildController.ToggleDelete()
	if active then
		setDeleteMode(not deleteMode)
	end
end

-- // per-frame preview ---------------------------------------------------

local function updatePreview()
	if not active then
		return
	end

	if deleteMode then
		local model = raycastOwnItem()
		if hoverHighlight and hoverHighlight.Adornee ~= model then
			hoverHighlight:Destroy()
			hoverHighlight = nil
		end
		if model and not hoverHighlight then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(220, 80, 70)
			highlight.FillTransparency = 0.5
			highlight.Adornee = model
			highlight.Parent = model
			hoverHighlight = highlight
		end
		return
	end

	local origin = plotOrigin
	local id = selectedId
	if not (ghost and origin and id) then
		return
	end
	local def = Catalog.ById[id]
	if not def then
		return
	end
	local hitPos = raycastPlot()
	if not hitPos then
		return
	end

	local x, z = GridUtil.worldToAnchor(origin, hitPos, def.w, def.d, rotation)
	lastCell = { x = x, z = z }
	ghost:PivotTo(GridUtil.itemPivot(origin, x, z, def.w, def.d, rotation))
	ghostValid = cellsFree(def, x, z, rotation)
	setGhostColor(ghostValid)
end

-- // init ----------------------------------------------------------------

function BuildController.Init(ui: any)
	UI = ui
	UI.SetHandlers({
		enterBuild = BuildController.EnterBuild,
		exitBuild = BuildController.ExitBuild,
		selectItem = BuildController.SelectItem,
		toggleDelete = BuildController.ToggleDelete,
		rotate = BuildController.Rotate,
	})

	placeSound = Instance.new("Sound")
	placeSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	placeSound.Volume = 0.4
	placeSound.Parent = game:GetService("SoundService")

	Net.event("PlotAssigned").OnClientEvent:Connect(function(model: Model, origin: Vector3)
		plotOrigin = origin
		plotBase = model:WaitForChild("Base") :: BasePart
		local folder = model:WaitForChild("Items") :: Folder
		itemsFolder = folder
		watchItemsFolder(folder)
		UI.Toast("This is your lot! Press BUILD to start.", "good")
	end)

	RunService.RenderStepped:Connect(updatePreview)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not active then
				return
			end
			if deleteMode then
				tryDelete()
			else
				-- on touch, first tap aims (RenderStepped follows GetMouseLocation), second tap places
				tryPlace()
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			if active then
				BuildController.Rotate()
			end
		elseif input.KeyCode == Enum.KeyCode.X then
			BuildController.ToggleDelete()
		elseif input.KeyCode == Enum.KeyCode.Q then
			if active then
				BuildController.ExitBuild()
			end
		end
	end)
end

return BuildController
