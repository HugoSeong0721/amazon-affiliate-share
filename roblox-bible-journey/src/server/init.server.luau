--!strict
-- Boot order matters:
--   1. ChapterService loads the chapter modules and derives the journey order.
--   2. ProgressService needs that order to send road snapshots to clients.
--   3. HubBuilder lays one road segment per chapter, in that order.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ChapterService = require(script.ChapterService)
local ProgressService = require(script.ProgressService)
local HubBuilder = require(script.greybox.HubBuilder)

local order = ChapterService.start(script.Chapters)
ProgressService.start(order)

local hub = HubBuilder.build(Workspace, order)
ChapterService.setHubSpawn(hub.spawn)

local padCooldown: { [Player]: number } = {}

for pad, chapterId in hub.pads do
	pad.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- Standing on a pad fires Touched constantly; one attempt per second is plenty.
		local now = os.clock()
		if padCooldown[player] and now - padCooldown[player] < 1 then
			return
		end
		padCooldown[player] = now

		ChapterService.requestEnter(player, chapterId)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	padCooldown[player] = nil
end)

print(`[Journey] {#order} chapters loaded: {table.concat(order, ", ")}`)
