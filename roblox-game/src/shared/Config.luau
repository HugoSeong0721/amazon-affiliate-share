--!strict
-- Shared game configuration for Comeback! K-pop Dress Up.
-- Prices are derived deterministically from the asset id so the client and
-- server always agree without a round trip.

local Config = {}

Config.StartingCoins = 100
Config.DailyRewardCoins = 50
Config.DailyCooldownSeconds = 20 * 60 * 60
Config.PhotoRewardCoins = 15
Config.PhotoCooldownSeconds = 60
Config.ItemsPerSearch = 24

-- Ages 6-12 across the US: skin tones must cover a wide, even range.
Config.SkinTones = {
	Color3.fromRGB(255, 220, 196),
	Color3.fromRGB(250, 205, 176),
	Color3.fromRGB(241, 194, 167),
	Color3.fromRGB(232, 179, 143),
	Color3.fromRGB(216, 160, 122),
	Color3.fromRGB(199, 141, 105),
	Color3.fromRGB(180, 122, 88),
	Color3.fromRGB(158, 103, 72),
	Color3.fromRGB(134, 84, 57),
	Color3.fromRGB(109, 66, 44),
	Color3.fromRGB(87, 52, 34),
	Color3.fromRGB(64, 38, 25),
}

export type Category = {
	key: string,
	label: string,
	icon: string,
	avatarAssetTypes: { Enum.AvatarAssetType }?,
	assetTypeIds: { number }?,
	searches: { string }?,
	isSkin: boolean?,
}

-- Closet tabs. Each clothing tab is filled at runtime from the live Roblox
-- catalog using these search keywords, so no asset ids are hardcoded.
Config.Categories = {
	{
		key = "Hair",
		label = "Hair",
		icon = "\u{1F487}",
		avatarAssetTypes = { Enum.AvatarAssetType.HairAccessory },
		assetTypeIds = { 41 },
		searches = { "kpop idol hair", "y2k aesthetic hair" },
	},
	{
		key = "Tops",
		label = "Tops",
		icon = "\u{1F455}",
		avatarAssetTypes = { Enum.AvatarAssetType.Shirt },
		assetTypeIds = { 11 },
		searches = { "kpop stage outfit shirt", "y2k aesthetic top" },
	},
	{
		key = "Bottoms",
		label = "Bottoms",
		icon = "\u{1F456}",
		avatarAssetTypes = { Enum.AvatarAssetType.Pants },
		assetTypeIds = { 12 },
		searches = { "kpop stage pants", "y2k aesthetic pants" },
	},
	{
		key = "Hats",
		label = "Hats",
		icon = "\u{1F9E2}",
		avatarAssetTypes = { Enum.AvatarAssetType.Hat },
		assetTypeIds = { 8 },
		searches = { "y2k beanie", "cute bucket hat" },
	},
	{
		key = "Skin",
		label = "Skin",
		icon = "\u{1F3A8}",
		isSkin = true,
	},
} :: { Category }

-- Maps a HumanoidDescription field to each equippable asset type id.
Config.AccessoryFields = {
	[8] = "HatAccessory",
	[41] = "HairAccessory",
}
Config.ClassicClothingFields = {
	[11] = "Shirt",
	[12] = "Pants",
}

-- Every 6th item is free so brand-new players can start dressing up
-- immediately; the rest scale up to 150 coins.
local PRICE_TIERS = { 0, 25, 50, 75, 100, 150 }

function Config.priceFor(assetId: number): number
	return PRICE_TIERS[(assetId % #PRICE_TIERS) + 1]
end

function Config.categoryByKey(key: string): Category?
	for _, category in Config.Categories do
		if category.key == key then
			return category
		end
	end
	return nil
end

return Config
