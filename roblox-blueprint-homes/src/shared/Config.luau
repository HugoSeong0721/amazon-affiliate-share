--!strict
-- Central tuning knobs for Blueprint Homes.
-- Everything gameplay-balance related lives here so design iteration
-- never requires touching service code.

local Config = {}

-- // World / plots
Config.PlotSizeCells = 32 -- plot is 32x32 cells
Config.CellSize = 2 -- studs per cell (plot = 64x64 studs)
Config.PlotsPerServer = 8 -- set the place's max players to match
Config.PlotGap = 12 -- studs between neighbouring plots
Config.StreetWidth = 16
Config.WallHeight = 9

-- // Economy
Config.StartingMoney = 25000
Config.DailyBonus = 2500
Config.DailyBonusCooldown = 20 * 3600 -- seconds
Config.PassiveIncomeAmount = 500 -- "rent" while playing
Config.PassiveIncomeInterval = 600 -- seconds
Config.SellRefundRate = 0.75 -- refund when deleting an item

-- // Blueprint market (the differentiator)
Config.Blueprint = {
	MinPrice = 100, -- design fee floor, in-game cash
	MaxPrice = 250000,
	RoyaltyRate = 0.70, -- creator's cut of every sale; rest is a currency sink
	MinItemsToPublish = 10, -- stops empty-plot spam listings
	MaxItems = 400, -- per blueprint / per plot
	FreePublishSlots = 1,
	ProPublishSlots = 5, -- with the Pro Builder game pass
	NameMaxLength = 40,
	MarketPageSize = 25,
	MetaCacheSeconds = 120,
	DataCacheSeconds = 300,
}

-- // Monetization (fill in real ids after publishing the place)
Config.GamePasses = {
	ProBuilder = 0, -- 5 market slots + "PRO" tag on listings
	LargePlot = 0, -- reserved for a future 48x48 plot
	MultipleFloors = 0, -- reserved: Bloxburg's best seller, phase 2
}

-- Developer products: productId -> cash granted
Config.Products = {
	-- [0000001] = 25000,  -- e.g. "Small cash pack"
	-- [0000002] = 90000,
	-- [0000003] = 400000,
}

-- // Sounds
-- Left empty on purpose: an unpublished place cannot fetch any audio asset
-- (asset delivery answers 403), and a broken SoundId spams the console. Put a
-- real "rbxassetid://..." here once the place is published.
Config.Sounds = {
	Place = "",
}

-- // Persistence
Config.DataStoreVersion = "v1"
Config.AutosaveInterval = 120 -- seconds
Config.EarningsClaimInterval = 90 -- poll offline-sale earnings while online

-- // Anti-abuse: minimum seconds between calls, per remote
Config.RateLimits = {
	PlaceItem = 0.06,
	RemoveItem = 0.06,
	GetMarket = 1.0,
	BuyBlueprint = 2.0,
	ApplyBlueprint = 5.0,
	PublishBlueprint = 30.0,
	GetMyBlueprints = 1.0,
}

return Config
