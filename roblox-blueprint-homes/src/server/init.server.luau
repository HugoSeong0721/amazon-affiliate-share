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

-- The neighbourhood is generated at runtime, so hold character spawning until
-- it exists. Without this a character can spawn into an empty DataModel, fall
-- past the void threshold and die before the ground and SpawnLocation appear.
Players.CharacterAutoLoads = false
PlotService.GenerateMap()
Players.CharacterAutoLoads = true

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

-- Anyone already in the game when this script started (Studio solo test) was
-- either never spawned or spawned into the not-yet-generated world. Give them
-- a fresh character now that the ground and SpawnLocation exist.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			warn("[BlueprintHomes] LoadCharacter failed for", player.Name, err)
		end
		onPlayerAdded(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Remove(player)
	PlotService.Release(player)
	BuildService.ForgetPlayer(player)
end)

print("[BlueprintHomes] server ready")
