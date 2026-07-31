--!strict
-- Buildable item catalog. Items are assembled from primitive parts at runtime
-- (no meshes/assets needed), so the whole game ships as plain code.
--
-- Item fields:
--   id/name/category/price
--   w, d       footprint in cells at rotation 0 (1 cell = Config.CellSize studs)
--   layer      "floor" (tiles/rugs, can sit under objects) or "object"
--   parts      primitive specs; offsets are relative to the footprint's
--              bottom-center, y measured up from the plot surface

local Catalog = {}

Catalog.Categories = { "Structure", "Floor", "Living", "Kitchen", "Bedroom", "Bathroom", "Decor", "Outdoor" }

-- palette
local WHITE = Color3.fromRGB(238, 238, 232)
local CREAM = Color3.fromRGB(226, 218, 200)
local WOOD = Color3.fromRGB(133, 100, 66)
local WOOD_DARK = Color3.fromRGB(94, 68, 45)
local WOOD_LIGHT = Color3.fromRGB(186, 152, 110)
local GRAY = Color3.fromRGB(120, 124, 130)
local DARK = Color3.fromRGB(42, 44, 48)
local STEEL = Color3.fromRGB(180, 186, 192)
local NAVY = Color3.fromRGB(58, 76, 110)
local TEAL = Color3.fromRGB(64, 130, 128)
local GREEN = Color3.fromRGB(88, 140, 74)
local LEAF = Color3.fromRGB(66, 116, 58)
local TERRA = Color3.fromRGB(168, 96, 66)
local RED = Color3.fromRGB(158, 66, 60)
local BLUE_SOFT = Color3.fromRGB(132, 158, 196)
local YELLOW_WARM = Color3.fromRGB(236, 200, 120)
local GLASS = Color3.fromRGB(170, 205, 220)

type PartSpec = {
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: string?,
	t: number?, -- transparency
}

-- compact part constructor
local function P(sx: number, sy: number, sz: number, ox: number, oy: number, oz: number, color: Color3, material: Enum.Material?, shape: string?, t: number?): PartSpec
	return {
		size = Vector3.new(sx, sy, sz),
		offset = Vector3.new(ox, oy, oz),
		color = color,
		material = material,
		shape = shape,
		t = t,
	}
end

local SP = Enum.Material.SmoothPlastic
local WOODP = Enum.Material.WoodPlanks
local FAB = Enum.Material.Fabric
local MET = Enum.Material.Metal
local GLA = Enum.Material.Glass
local GRA = Enum.Material.Grass
local SLA = Enum.Material.Slate
local MAR = Enum.Material.Marble

Catalog.Items = {
	-- ===================== Structure =====================
	{
		id = "wall", name = "Wall", category = "Structure", price = 40, w = 2, d = 1, layer = "object",
		parts = { P(4, 9, 0.5, 0, 4.5, 0, WHITE, SP) },
	},
	{
		id = "wall_window", name = "Window Wall", category = "Structure", price = 65, w = 2, d = 1, layer = "object",
		parts = {
			P(4, 3, 0.5, 0, 1.5, 0, WHITE, SP),
			P(4, 2, 0.5, 0, 8, 0, WHITE, SP),
			P(0.75, 4, 0.5, -1.625, 5, 0, WHITE, SP),
			P(0.75, 4, 0.5, 1.625, 5, 0, WHITE, SP),
			P(2.5, 4, 0.2, 0, 5, 0, GLASS, GLA, nil, 0.5),
		},
	},
	{
		id = "wall_doorway", name = "Doorway Wall", category = "Structure", price = 55, w = 2, d = 1, layer = "object",
		parts = {
			P(4, 1.6, 0.5, 0, 8.2, 0, WHITE, SP),
			P(0.8, 7.4, 0.5, -1.6, 3.7, 0, WHITE, SP),
			P(0.8, 7.4, 0.5, 1.6, 3.7, 0, WHITE, SP),
		},
	},
	{
		id = "pillar", name = "Pillar", category = "Structure", price = 30, w = 1, d = 1, layer = "object",
		parts = { P(0.9, 9, 0.9, 0, 4.5, 0, CREAM, SP) },
	},

	-- ===================== Floor =====================
	{
		id = "floor_wood", name = "Wood Floor", category = "Floor", price = 20, w = 2, d = 2, layer = "floor",
		parts = { P(4, 0.16, 4, 0, 0.08, 0, WOOD_LIGHT, WOODP) },
	},
	{
		id = "floor_tile", name = "Tile Floor", category = "Floor", price = 25, w = 2, d = 2, layer = "floor",
		parts = { P(4, 0.16, 4, 0, 0.08, 0, WHITE, MAR) },
	},
	{
		id = "floor_carpet", name = "Carpet", category = "Floor", price = 15, w = 2, d = 2, layer = "floor",
		parts = { P(4, 0.16, 4, 0, 0.08, 0, BLUE_SOFT, FAB) },
	},
	{
		id = "path_stone", name = "Stone Path", category = "Floor", price = 10, w = 2, d = 2, layer = "floor",
		parts = { P(4, 0.16, 4, 0, 0.08, 0, GRAY, SLA) },
	},

	-- ===================== Living =====================
	{
		id = "sofa", name = "Sofa", category = "Living", price = 750, w = 2, d = 1, layer = "object",
		parts = {
			P(4, 0.9, 1.5, 0, 0.45, 0.2, NAVY, FAB),
			P(4, 1.6, 0.5, 0, 1.55, -0.7, NAVY, FAB),
			P(0.5, 1.4, 1.9, -1.75, 0.7, 0, NAVY, FAB),
			P(0.5, 1.4, 1.9, 1.75, 0.7, 0, NAVY, FAB),
		},
	},
	{
		id = "armchair", name = "Armchair", category = "Living", price = 350, w = 1, d = 1, layer = "object",
		parts = {
			P(1.8, 0.8, 1.5, 0, 0.4, 0.15, TEAL, FAB),
			P(1.8, 1.4, 0.45, 0, 1.35, -0.75, TEAL, FAB),
		},
	},
	{
		id = "coffee_table", name = "Coffee Table", category = "Living", price = 250, w = 2, d = 1, layer = "object",
		parts = {
			P(3.6, 0.2, 1.8, 0, 1.1, 0, WOOD, WOODP),
			P(0.2, 1, 0.2, -1.6, 0.5, -0.7, WOOD_DARK, SP),
			P(0.2, 1, 0.2, 1.6, 0.5, -0.7, WOOD_DARK, SP),
			P(0.2, 1, 0.2, -1.6, 0.5, 0.7, WOOD_DARK, SP),
			P(0.2, 1, 0.2, 1.6, 0.5, 0.7, WOOD_DARK, SP),
		},
	},
	{
		id = "tv_stand", name = "TV + Stand", category = "Living", price = 900, w = 2, d = 1, layer = "object",
		parts = {
			P(3.8, 1.2, 1.2, 0, 0.6, 0, WOOD_DARK, WOODP),
			P(3.2, 1.8, 0.15, 0, 2.4, 0, DARK, GLA),
		},
	},
	{
		id = "bookshelf", name = "Bookshelf", category = "Living", price = 500, w = 2, d = 1, layer = "object",
		parts = {
			P(3.8, 7, 1.1, 0, 3.5, 0, WOOD, WOODP),
			P(1.1, 0.9, 0.8, -1, 2.4, 0.2, RED, SP),
			P(1.3, 0.9, 0.8, 0.8, 4.1, 0.2, TEAL, SP),
			P(1.0, 0.9, 0.8, -0.9, 5.8, 0.2, YELLOW_WARM, SP),
		},
	},
	{
		id = "floor_lamp", name = "Floor Lamp", category = "Living", price = 150, w = 1, d = 1, layer = "object",
		parts = {
			P(0.9, 0.15, 0.9, 0, 0.08, 0, DARK, SP),
			P(0.18, 4.4, 0.18, 0, 2.3, 0, DARK, MET),
			P(1.3, 1, 1.3, 0, 5, 0, YELLOW_WARM, Enum.Material.Neon),
		},
	},
	{
		id = "plant", name = "Potted Plant", category = "Living", price = 120, w = 1, d = 1, layer = "object",
		parts = {
			P(0.9, 0.9, 0.9, 0, 0.45, 0, TERRA, SP),
			P(1.7, 1.7, 1.7, 0, 2, 0, LEAF, GRA, "Ball"),
		},
	},

	-- ===================== Kitchen =====================
	{
		id = "counter", name = "Counter", category = "Kitchen", price = 200, w = 1, d = 1, layer = "object",
		parts = {
			P(2, 2.3, 1.8, 0, 1.15, 0, CREAM, SP),
			P(2, 0.2, 2, 0, 2.4, 0, DARK, MAR),
		},
	},
	{
		id = "sink_counter", name = "Sink Counter", category = "Kitchen", price = 300, w = 1, d = 1, layer = "object",
		parts = {
			P(2, 2.3, 1.8, 0, 1.15, 0, CREAM, SP),
			P(2, 0.2, 2, 0, 2.4, 0, DARK, MAR),
			P(1.2, 0.15, 1, 0, 2.51, 0, STEEL, MET),
			P(0.18, 0.9, 0.18, 0, 2.9, -0.6, STEEL, MET),
		},
	},
	{
		id = "stove", name = "Stove", category = "Kitchen", price = 550, w = 1, d = 1, layer = "object",
		parts = {
			P(2, 2.3, 1.8, 0, 1.15, 0, WHITE, SP),
			P(1.9, 0.15, 1.7, 0, 2.4, 0, DARK, SP),
		},
	},
	{
		id = "fridge", name = "Fridge", category = "Kitchen", price = 800, w = 1, d = 1, layer = "object",
		parts = {
			P(1.8, 5.4, 1.8, 0, 2.7, 0, STEEL, MET),
			P(0.15, 1.6, 0.15, 0.75, 3.6, 0.95, GRAY, MET),
		},
	},
	{
		id = "dining_table", name = "Dining Table", category = "Kitchen", price = 400, w = 2, d = 2, layer = "object",
		parts = {
			P(3.8, 0.25, 3.8, 0, 2.4, 0, WOOD, WOODP),
			P(0.7, 2.3, 0.7, 0, 1.15, 0, WOOD_DARK, SP),
		},
	},
	{
		id = "dining_chair", name = "Dining Chair", category = "Kitchen", price = 150, w = 1, d = 1, layer = "object",
		parts = {
			P(1.6, 0.3, 1.6, 0, 1.4, 0, WOOD_LIGHT, WOODP),
			P(0.3, 1.3, 0.3, 0, 0.65, 0, WOOD_DARK, SP),
			P(1.6, 1.9, 0.3, 0, 2.5, -0.65, WOOD_LIGHT, WOODP),
		},
	},

	-- ===================== Bedroom =====================
	{
		id = "bed_single", name = "Single Bed", category = "Bedroom", price = 600, w = 1, d = 2, layer = "object",
		parts = {
			P(2, 0.8, 4, 0, 0.4, 0, WOOD, WOODP),
			P(1.9, 0.5, 3.8, 0, 1.05, 0, WHITE, FAB),
			P(1.5, 0.35, 0.9, 0, 1.45, -1.35, BLUE_SOFT, FAB),
			P(1.9, 0.25, 2.2, 0, 1.4, 0.8, NAVY, FAB),
		},
	},
	{
		id = "bed_double", name = "Double Bed", category = "Bedroom", price = 1000, w = 2, d = 2, layer = "object",
		parts = {
			P(4, 0.8, 4, 0, 0.4, 0, WOOD, WOODP),
			P(3.9, 0.5, 3.8, 0, 1.05, 0, WHITE, FAB),
			P(1.5, 0.35, 0.9, -0.95, 1.45, -1.35, BLUE_SOFT, FAB),
			P(1.5, 0.35, 0.9, 0.95, 1.45, -1.35, BLUE_SOFT, FAB),
			P(3.9, 0.25, 2.2, 0, 1.4, 0.8, TEAL, FAB),
		},
	},
	{
		id = "dresser", name = "Dresser", category = "Bedroom", price = 450, w = 2, d = 1, layer = "object",
		parts = {
			P(3.6, 2.6, 1.6, 0, 1.3, 0, WOOD, WOODP),
			P(3.7, 0.15, 1.7, 0, 2.68, 0, WOOD_DARK, SP),
		},
	},
	{
		id = "nightstand", name = "Nightstand", category = "Bedroom", price = 180, w = 1, d = 1, layer = "object",
		parts = {
			P(1.6, 1.8, 1.6, 0, 0.9, 0, WOOD, WOODP),
			P(1.7, 0.12, 1.7, 0, 1.86, 0, WOOD_DARK, SP),
		},
	},

	-- ===================== Bathroom =====================
	{
		id = "toilet", name = "Toilet", category = "Bathroom", price = 300, w = 1, d = 1, layer = "object",
		parts = {
			P(1.2, 1.1, 1.6, 0, 0.55, 0.15, WHITE, SP),
			P(1.4, 1.7, 0.5, 0, 1.7, -0.6, WHITE, SP),
		},
	},
	{
		id = "bathtub", name = "Bathtub", category = "Bathroom", price = 700, w = 1, d = 2, layer = "object",
		parts = {
			P(2, 1.5, 3.9, 0, 0.75, 0, WHITE, SP),
			P(1.5, 0.2, 3.3, 0, 1.45, 0, GLASS, SP, nil, 0.25),
		},
	},
	{
		id = "bath_sink", name = "Bathroom Sink", category = "Bathroom", price = 250, w = 1, d = 1, layer = "object",
		parts = {
			P(0.7, 2.2, 0.7, 0, 1.1, 0, WHITE, SP),
			P(1.6, 0.5, 1.4, 0, 2.45, 0, WHITE, SP),
			P(0.15, 0.7, 0.15, 0, 2.9, -0.45, STEEL, MET),
		},
	},

	-- ===================== Decor =====================
	{
		id = "rug", name = "Round Rug", category = "Decor", price = 100, w = 2, d = 2, layer = "floor",
		parts = { P(3.9, 0.12, 3.9, 0, 0.06, 0, RED, FAB) },
	},
	{
		id = "desk", name = "Desk", category = "Decor", price = 350, w = 2, d = 1, layer = "object",
		parts = {
			P(3.8, 0.25, 1.8, 0, 2.2, 0, WOOD_LIGHT, WOODP),
			P(0.25, 2.1, 1.7, -1.7, 1.05, 0, WOOD_DARK, SP),
			P(0.25, 2.1, 1.7, 1.7, 1.05, 0, WOOD_DARK, SP),
		},
	},
	{
		id = "office_chair", name = "Office Chair", category = "Decor", price = 200, w = 1, d = 1, layer = "object",
		parts = {
			P(1.6, 0.35, 1.6, 0, 1.4, 0, DARK, FAB),
			P(0.3, 1.25, 0.3, 0, 0.7, 0, GRAY, MET),
			P(1.6, 1.8, 0.35, 0, 2.45, -0.65, DARK, FAB),
		},
	},

	-- ===================== Outdoor =====================
	{
		id = "fence", name = "Fence", category = "Outdoor", price = 60, w = 2, d = 1, layer = "object",
		parts = {
			P(4, 0.3, 0.25, 0, 1.6, 0, WOOD_LIGHT, WOODP),
			P(4, 0.3, 0.25, 0, 0.8, 0, WOOD_LIGHT, WOODP),
			P(0.35, 1.9, 0.35, -1.8, 0.95, 0, WOOD, WOODP),
			P(0.35, 1.9, 0.35, 1.8, 0.95, 0, WOOD, WOODP),
		},
	},
	{
		id = "bush", name = "Bush", category = "Outdoor", price = 80, w = 1, d = 1, layer = "object",
		parts = { P(1.8, 1.5, 1.8, 0, 0.75, 0, GREEN, GRA) },
	},
	{
		id = "tree", name = "Tree", category = "Outdoor", price = 300, w = 2, d = 2, layer = "object",
		parts = {
			P(0.9, 4.2, 0.9, 0, 2.1, 0, WOOD_DARK, Enum.Material.Wood),
			P(4.6, 4.6, 4.6, 0, 5.6, 0, LEAF, GRA, "Ball"),
		},
	},
}

-- id -> item lookup
Catalog.ById = {} :: { [string]: any }
for _, item in ipairs(Catalog.Items) do
	Catalog.ById[item.id] = item
end

return Catalog
