--!strict
-- Blueprint Homes - server bootstrap.
-- Order matters: Net (remotes) -> map -> services -> player lifecycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Net) -- creates all remotes before any client needs them

local DataService = require(script.DataService)
local PlotService = require(script.PlotService)
local BuildService = require(script.BuildService)
local EconomyService = require(script.EconomyService)
local BlueprintMarketService = require(script.BlueprintMarketService)

local Net = require(Shared.Net)
local notify = Net.event("Notify")

PlotService.GenerateMap()

DataService.Init()
BuildService.Init()
EconomyService.Init()
BlueprintMarketService.Init()

local function onPlayerAdded(player: Player)
	DataService.Load(player)
	local plot = PlotService.Assign(player)
	if plot then
		BuildService.LoadSavedBuild(player)
	else
		notify:FireClient(player, "No free plot on this server - try another one!", "bad")
	end
	EconomyService.OnJoin(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Remove(player)
	PlotService.Release(player)
	BuildService.ForgetPlayer(player)
end)

print("[BlueprintHomes] server ready")
