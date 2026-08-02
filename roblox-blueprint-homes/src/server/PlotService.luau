--!strict
-- Generates the neighbourhood (baseplate, street, plots) at runtime and
-- assigns each player a plot. Runtime generation keeps the whole game in
-- code - no .rbxl asset needed to run the place.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
	base: Part,
	sign: TextLabel,
	itemsFolder: Folder,
	origin: Vector3, -- min corner at surface height
	ownerUserId: number?,
	-- build state (managed by BuildService)
	items: { [number]: any },
	occupancy: { [string]: { [string]: boolean } },
	nextUid: number,
}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

local plotAssigned = Net.event("PlotAssigned")

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(part :: any)[k] = v
	end
	return part
end

local function makePlot(index: number, centerX: number, centerZ: number, parent: Instance): Plot
	local sizeStuds = Config.PlotSizeCells * Config.CellSize

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local base = makePart({
		Name = "Base",
		Size = Vector3.new(sizeStuds, 1, sizeStuds),
		Position = Vector3.new(centerX, 0, centerZ),
		Color = Color3.fromRGB(106, 158, 88),
		Material = Enum.Material.Grass,
	})
	base.Parent = model

	-- thin border so plots read clearly
	local border = makePart({
		Name = "Border",
		Size = Vector3.new(sizeStuds + 1, 0.4, sizeStuds + 1),
		Position = Vector3.new(centerX, 0.25, centerZ),
		Color = Color3.fromRGB(226, 218, 200),
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	border.Parent = model

	-- ownership sign at the street-facing edge
	local signFacesNorth = centerZ > 0
	local signZ = centerZ + (signFacesNorth and -(sizeStuds / 2 + 2) or (sizeStuds / 2 + 2))
	local post = makePart({
		Name = "SignPost",
		Size = Vector3.new(0.4, 5, 0.4),
		Position = Vector3.new(centerX, 3, signZ),
		Color = Color3.fromRGB(94, 68, 45),
		Material = Enum.Material.Wood,
	})
	post.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "SignGui"
	-- Sized in studs (scale component), so distant signs shrink instead of
	-- staying pixel-huge and overlapping each other across the street.
	gui.Size = UDim2.fromScale(11, 2.8)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 220
	gui.Parent = post

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "FOR SALE"
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "Items"
	itemsFolder.Parent = model

	model.Parent = parent

	return {
		index = index,
		model = model,
		base = base,
		sign = label,
		itemsFolder = itemsFolder,
		origin = Vector3.new(centerX - sizeStuds / 2, base.Position.Y + 0.5, centerZ - sizeStuds / 2),
		ownerUserId = nil,
		items = {},
		occupancy = { floor = {}, object = {} },
		nextUid = 1,
	}
end

function PlotService.GenerateMap()
	local map = Instance.new("Folder")
	map.Name = "Neighborhood"

	local sizeStuds = Config.PlotSizeCells * Config.CellSize -- 64
	local pitch = sizeStuds + Config.PlotGap -- plot center spacing
	local perRow = math.ceil(Config.PlotsPerServer / 2)
	local rowSpan = perRow * pitch
	local rowZ = Config.StreetWidth / 2 + Config.PlotGap + sizeStuds / 2

	makePart({
		Name = "Ground",
		Size = Vector3.new(rowSpan + 260, 4, (rowZ + sizeStuds) * 2 + 160),
		Position = Vector3.new(0, -2.05, 0),
		Color = Color3.fromRGB(92, 140, 78),
		Material = Enum.Material.Grass,
	}).Parent = map

	makePart({
		Name = "Street",
		Size = Vector3.new(rowSpan + 120, 0.35, Config.StreetWidth),
		Position = Vector3.new(0, 0.05, 0),
		Color = Color3.fromRGB(66, 66, 70),
		Material = Enum.Material.Asphalt,
	}).Parent = map

	makePart({
		Name = "CenterLine",
		Size = Vector3.new(rowSpan + 120, 0.36, 0.5),
		Position = Vector3.new(0, 0.06, 0),
		Color = Color3.fromRGB(228, 200, 60),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}).Parent = map

	local firstX = -((perRow - 1) * pitch) / 2
	for i = 1, Config.PlotsPerServer do
		local row = (i - 1) % 2 -- 0 = south, 1 = north
		local col = math.floor((i - 1) / 2)
		local x = firstX + col * pitch
		local z = (row == 0) and -rowZ or rowZ
		table.insert(plots, makePlot(i, x, z, map))
	end

	-- Spawn plaza at the head of the street, set back from the road so the
	-- character lands clear of traffic and can see the whole neighbourhood.
	local plazaX = -(rowSpan / 2) - 34
	makePart({
		Name = "SpawnPlaza",
		Size = Vector3.new(28, 1, 28),
		Position = Vector3.new(plazaX, 0.5, 0),
		Color = Color3.fromRGB(198, 194, 186),
		Material = Enum.Material.Concrete,
	}).Parent = map

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Size = Vector3.new(12, 1, 12)
	spawnPad.Position = Vector3.new(plazaX, 1.5, 0)
	spawnPad.Color = Color3.fromRGB(150, 150, 155)
	spawnPad.Material = Enum.Material.Concrete
	spawnPad.Anchored = true
	spawnPad.CanCollide = true
	spawnPad.Duration = 0
	spawnPad.Parent = map

	map.Parent = workspace
end

function PlotService.Assign(player: Player): Plot?
	for _, plot in ipairs(plots) do
		if plot.ownerUserId == nil then
			plot.ownerUserId = player.UserId
			plot.sign.Text = player.DisplayName .. "'s Lot"
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plotByPlayer[player] = plot
			plotAssigned:FireClient(player, plot.model, plot.origin)
			return plot
		end
	end
	return nil
end

function PlotService.Get(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.Release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.ownerUserId = nil
	plot.sign.Text = "FOR SALE"
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.itemsFolder:ClearAllChildren()
	plot.items = {}
	plot.occupancy = { floor = {}, object = {} }
	plot.nextUid = 1
end

return PlotService
