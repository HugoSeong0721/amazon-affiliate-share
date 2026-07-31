--!strict
-- Income loops + Robux monetization hooks (game passes, cash dev products).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local notify = Net.event("Notify")

-- gamepass ownership cache: [userId] = { [passId] = boolean }
local passCache: { [number]: { [number]: boolean } } = {}

function EconomyService.HasPass(player: Player, passName: string): boolean
	local passId = Config.GamePasses[passName]
	if not passId or passId == 0 then
		return false
	end
	local cache = passCache[player.UserId]
	if not cache then
		cache = {}
		passCache[player.UserId] = cache
	end
	if cache[passId] ~= nil then
		return cache[passId]
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	local result = ok and owns == true
	cache[passId] = result
	return result
end

function EconomyService.OnJoin(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if os.time() - (profile.lastDailyBonus or 0) >= Config.DailyBonusCooldown then
		profile.lastDailyBonus = os.time()
		DataService.Credit(player, Config.DailyBonus)
		notify:FireClient(player, ("Daily bonus +%s"):format(Util.money(Config.DailyBonus)), "good")
	end
end

function EconomyService.Init()
	-- passive "rent" income while playing
	task.spawn(function()
		while true do
			task.wait(Config.PassiveIncomeInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				if DataService.Get(player) then
					DataService.Credit(player, Config.PassiveIncomeAmount)
					notify:FireClient(player, ("Rent income +%s"):format(Util.money(Config.PassiveIncomeAmount)), "info")
				end
			end
		end
	end)

	-- cash developer products
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local cash = Config.Products[receiptInfo.ProductId]
		if not cash then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player or not DataService.Get(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		DataService.Credit(player, cash)
		DataService.Save(player)
		notify:FireClient(player, ("Purchased +%s"):format(Util.money(cash)), "good")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- refresh pass cache when a pass is bought in-session
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passCache[player.UserId] then
			passCache[player.UserId][passId] = true
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		passCache[player.UserId] = nil
	end)
end

return EconomyService
