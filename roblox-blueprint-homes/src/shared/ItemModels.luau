--!strict
-- Builds an item Model from its catalog part specs. Used by the server for
-- real placement and by the client for the translucent placement ghost.

local Config = require(script.Parent.Config)

local ItemModels = {}

-- Returns an anchored Model whose pivot (PrimaryPart "Root") sits at the
-- bottom-center of the footprint, 0.1 studs above ground level. Position it
-- with model:PivotTo(GridUtil.itemPivot(...)).
function ItemModels.build(def: any): Model
	local cs = Config.CellSize
	local model = Instance.new("Model")
	model.Name = def.id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(def.w * cs, 0.2, def.d * cs)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Parent = model
	model.PrimaryPart = root

	for _, spec in ipairs(def.parts) do
		local part = Instance.new("Part")
		if spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.Size = spec.size
		part.CFrame = CFrame.new(spec.offset)
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.SmoothPlastic
		part.Transparency = spec.t or 0
		part.Anchored = true
		part.CanCollide = true
		part.CastShadow = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end

	return model
end

-- Ghost variant for placement preview: see-through, no collision, no raycast hits.
function ItemModels.buildGhost(def: any): Model
	local model = ItemModels.build(def)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			part.Transparency = math.max((part.Transparency :: number), 0.55)
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "GhostHighlight"
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	return model
end

return ItemModels
