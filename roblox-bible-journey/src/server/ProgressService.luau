--!strict
-- Owns every player's ProgressData: loads it, mutates it through ProgressLogic,
-- pushes a snapshot to the client, and flushes on anything that matters.
--
-- All progress decisions happen here, on the server. The client is only ever told
-- what to draw.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

local ProgressLogic = require(script.Parent.ProgressLogic)
local MemoryBackend = require(script.Parent.backends.MemoryBackend)
local ProfileStoreBackend = require(script.Parent.backends.ProfileStoreBackend)

local ProgressService = {}

ProgressService.Changed = Signal.new() -- (player, data)
ProgressService.FragmentGranted = Signal.new() -- (player, fragmentId)
ProgressService.ChapterCompleted = Signal.new() -- (player, chapterId)

local data: { [Player]: Types.ProgressData } = {}
local backend: Types.Backend
local chapterOrder: { string } = {}
local started = false

local function pushSnapshot(player: Player)
	local playerData = data[player]
	if not playerData then
		return
	end
	Net.event("ProgressChanged"):FireClient(player, ProgressLogic.snapshot(playerData, chapterOrder))
end

local function onPlayerAdded(player: Player)
	local loaded = backend.load(player)
	if not loaded then
		return -- backend already handled the failure (kick)
	end

	if player.Parent ~= Players then
		backend.release(player)
		return
	end

	data[player] = ProgressLogic.migrate(loaded)
	pushSnapshot(player)
	ProgressService.Changed:fire(player, data[player])
end

local function onPlayerRemoving(player: Player)
	if data[player] then
		backend.flush(player)
	end
	data[player] = nil
	backend.release(player)
end

function ProgressService.start(order: { string })
	assert(not started, "ProgressService.start called twice")
	started = true
	chapterOrder = order

	if ProfileStoreBackend.isAvailable() then
		backend = ProfileStoreBackend :: any
	else
		backend = MemoryBackend :: any
		warn(
			"[ProgressService] ProfileStore not found at Server.Vendor.ProfileStore — "
				.. "running on MemoryBackend. Progress will NOT survive a server restart. "
				.. "Do not ship in this state (see DESIGN.md 5-3)."
		)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Studio "stop" and real shutdowns both land here.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			onPlayerRemoving(player)
		end
	end)
end

function ProgressService.get(player: Player): Types.ProgressData?
	return data[player]
end

function ProgressService.isLoaded(player: Player): boolean
	return data[player] ~= nil
end

function ProgressService.locale(player: Player): string
	local playerData = data[player]
	return if playerData then playerData.locale else Strings.DEFAULT
end

function ProgressService.setLocale(player: Player, locale: string)
	local playerData = data[player]
	if not playerData or not table.find(Strings.SUPPORTED, locale) then
		return
	end
	playerData.locale = locale
	pushSnapshot(player)
end

function ProgressService.grantFragment(player: Player, fragmentId: string): boolean
	local playerData = data[player]
	if not playerData then
		return false
	end

	local lampBefore = ProgressLogic.lampLevel(playerData)
	local isNew = ProgressLogic.grantFragment(playerData, fragmentId)
	if not isNew then
		Net.event("Narrate"):FireClient(player, "hub.fragmentAlready")
		return false
	end

	backend.flush(player)
	pushSnapshot(player)

	Net.event("Narrate"):FireClient(player, "hub.fragmentFound")
	if ProgressLogic.lampLevel(playerData) > lampBefore then
		Net.event("Narrate"):FireClient(player, "hub.lampBrighter")
	end

	ProgressService.FragmentGranted:fire(player, fragmentId)
	ProgressService.Changed:fire(player, playerData)
	return true
end

function ProgressService.markChapterComplete(player: Player, chapterId: string): boolean
	local playerData = data[player]
	if not playerData then
		return false
	end

	local isNew = ProgressLogic.markChapterComplete(playerData, chapterId, os.time())
	if isNew then
		backend.flush(player)
		ProgressService.ChapterCompleted:fire(player, chapterId)
	end

	pushSnapshot(player)
	ProgressService.Changed:fire(player, playerData)
	return isNew
end

function ProgressService.incrementGuideCount(player: Player)
	local playerData = data[player]
	if not playerData then
		return
	end
	playerData.guideCount += 1
	backend.flush(player)
	pushSnapshot(player)
end

return ProgressService
