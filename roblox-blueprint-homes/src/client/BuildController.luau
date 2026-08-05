--!strict
-- Client build mode: grid ghost preview, rotate, place, delete.
-- Purely cosmetic - the server re-validates everything.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
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

-- build mode state. Exactly one tool is active: place (an item is selected),
-- delete, or move.
local active = false
local deleteMode = false
local moveMode = false
local heldUid: number? = nil -- item picked up in move mode
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
	if type(itemId) ~= "string" or type(x) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return -- attributes not replicated yet, or an item from another version
	end
	local def = Catalog.ById[itemId]
	if not def then
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
		-- Parent to the camera so the preview never collides or replicates.
		-- CurrentCamera is nil for a frame or two while the client boots; without
		-- a parent the ghost would exist but never render.
		local camera = workspace.CurrentCamera
		if def and camera then
			local model = ItemModels.buildGhost(def)
			model.Parent = camera
			ghost = model
		end
	end
end

-- // input helpers -------------------------------------------------------

local function ctrlHeld(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
end

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
	if not (active and not deleteMode and not moveMode and selectedId and lastCell and ghostValid) then
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

-- Move mode: first click picks an item up, second click drops it on the grid.
local function tryPickUp()
	local model = raycastOwnItem()
	if not model then
		return
	end
	local uid = model:GetAttribute("Uid")
	local itemId = model:GetAttribute("ItemId")
	local r = model:GetAttribute("R")
	if type(uid) ~= "number" or type(itemId) ~= "string" then
		return
	end
	heldUid = uid
	selectedId = itemId
	rotation = type(r) == "number" and r or 0
	refreshGhost()
	UI.SetCarrying(true)
end

local function tryDrop()
	local uid = heldUid
	if not (uid and lastCell and ghostValid) then
		return
	end
	local result = Net.func("MoveItem"):InvokeServer(uid, lastCell.x, lastCell.z, rotation)
	if result and result.ok then
		heldUid = nil
		selectedId = nil
		destroyGhost()
		UI.SetCarrying(false)
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

local function sendHistory(which: string)
	local result = Net.func(which):InvokeServer()
	if result and not result.ok then
		UI.Toast(UI.ErrorText(result.err), "bad")
	end
end

-- // mode control --------------------------------------------------------

local function clearHover()
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
end

-- Delete and move are mutually exclusive tools; entering either drops whatever
-- was being carried so the two never fight over the ghost.
local function setTool(tool: string)
	deleteMode = tool == "delete"
	moveMode = tool == "move"
	heldUid = nil
	clearHover()
	if deleteMode or moveMode then
		selectedId = nil
		destroyGhost()
	else
		refreshGhost()
	end
	UI.SetBuildMode(active, deleteMode, moveMode)
	UI.SetCarrying(false)
end

function BuildController.EnterBuild()
	if not plotBase then
		UI.Toast("You don't have a plot on this server.", "bad")
		return
	end
	active = true
	deleteMode = false
	moveMode = false
	heldUid = nil
	UI.SetBuildMode(true, false, false)
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
	moveMode = false
	heldUid = nil
	selectedId = nil
	destroyGhost()
	if plotSelection then
		plotSelection:Destroy()
		plotSelection = nil
	end
	clearHover()
	UI.SetBuildMode(false, false, false)
	UI.SetCarrying(false)
end

function BuildController.SelectItem(itemId: string)
	if deleteMode or moveMode then
		setTool("place")
	end
	selectedId = itemId
	refreshGhost()
end

function BuildController.Rotate()
	rotation = (rotation + 1) % 4
end

function BuildController.ToggleDelete()
	if active then
		setTool(deleteMode and "place" or "delete")
	end
end

function BuildController.ToggleMove()
	if active then
		setTool(moveMode and "place" or "move")
	end
end

function BuildController.Undo()
	if active then
		sendHistory("Undo")
	end
end

function BuildController.Redo()
	if active then
		sendHistory("Redo")
	end
end

-- // per-frame preview ---------------------------------------------------

local function updatePreview()
	if not active then
		return
	end

	-- delete, and move before an item is picked up, both hover-highlight
	if deleteMode or (moveMode and not heldUid) then
		local model = raycastOwnItem()
		if hoverHighlight and hoverHighlight.Adornee ~= model then
			hoverHighlight:Destroy()
			hoverHighlight = nil
		end
		if model and not hoverHighlight then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = deleteMode and Color3.fromRGB(220, 80, 70) or Color3.fromRGB(90, 170, 240)
			highlight.FillTransparency = 0.5
			highlight.Adornee = model
			highlight.Parent = model
			hoverHighlight = highlight
		end
		return
	end
	clearHover()

	local origin = plotOrigin
	local id = selectedId
	if id and not ghost then
		refreshGhost() -- CurrentCamera wasn't ready when the item was picked
	end
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
		toggleMove = BuildController.ToggleMove,
		undo = BuildController.Undo,
		redo = BuildController.Redo,
		rotate = BuildController.Rotate,
	})

	if Config.Sounds.Place ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Sounds.Place
		sound.Volume = 0.4
		sound.Parent = game:GetService("SoundService")
		placeSound = sound
	end

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
			elseif moveMode then
				if heldUid then
					tryDrop()
				else
					tryPickUp()
				end
			else
				-- on touch, first tap aims (RenderStepped follows GetMouseLocation), second tap places
				tryPlace()
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			if active then
				BuildController.Rotate()
			end
		elseif input.KeyCode == Enum.KeyCode.Z and ctrlHeld() then
			BuildController.Undo()
		elseif input.KeyCode == Enum.KeyCode.Y and ctrlHeld() then
			BuildController.Redo()
		elseif input.KeyCode == Enum.KeyCode.M then
			BuildController.ToggleMove()
		elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.G then
			BuildController.ToggleDelete()
		elseif input.KeyCode == Enum.KeyCode.Q then
			if active then
				BuildController.ExitBuild()
			end
		end
	end)
end

return BuildController
