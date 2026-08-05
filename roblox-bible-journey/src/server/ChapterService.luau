--!strict
-- Loads chapter modules, derives the journey order from their `requires` edges,
-- decides who may enter what, and owns the lifetime of every live Session.
--
-- Adding chapter 18 should mean adding one file. `buildOrder` is what makes that
-- true, and it is pure so tests can prove the graph before a map exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local Verses = require(ReplicatedStorage.Shared.Verses)

local ProgressLogic = require(script.Parent.ProgressLogic)
local ProgressService = require(script.Parent.ProgressService)
local Session = require(script.Parent.Session)

-- Chapter worlds are built far apart along X so streaming never loads two at once.
local CHAPTER_SPACING = 2048
local CHAPTER_Z = 4096
local RETURN_DELAY = 5

local ChapterService = {}

local chapters: { [string]: Types.Chapter } = {}
local order: { string } = {}
local sessions: { [string]: Session.Session } = {}
local playerSession: { [Player]: Session.Session } = {}
local hubSpawn: CFrame = CFrame.new(0, 8, 0)

--------------------------------------------------------------------------------
-- Pure graph logic (unit tested)
--------------------------------------------------------------------------------

-- Kahn's algorithm with an alphabetical tie-break, so the order is stable across
-- runs. An unstable order would shuffle the road segments under the players' feet.
function ChapterService.buildOrder(input: { [string]: Types.Chapter }): { string }
	local ids = {}
	for id in input do
		table.insert(ids, id)
	end
	table.sort(ids)

	local indegree: { [string]: number } = {}
	local dependents: { [string]: { string } } = {}
	for _, id in ids do
		indegree[id] = 0
		dependents[id] = {}
	end

	for _, id in ids do
		local seen: { [string]: boolean } = {}
		for _, requirement in input[id].requires do
			if input[requirement] == nil then
				error(`chapter "{id}" requires unknown chapter "{requirement}"`)
			end
			if requirement == id then
				error(`chapter "{id}" requires itself`)
			end
			if not seen[requirement] then
				seen[requirement] = true
				indegree[id] += 1
				table.insert(dependents[requirement], id)
			end
		end
	end

	local ready = {}
	for _, id in ids do
		if indegree[id] == 0 then
			table.insert(ready, id)
		end
	end

	local result = {}
	while #ready > 0 do
		table.sort(ready)
		local id = table.remove(ready, 1) :: string
		table.insert(result, id)
		for _, dependent in dependents[id] do
			indegree[dependent] -= 1
			if indegree[dependent] == 0 then
				table.insert(ready, dependent)
			end
		end
	end

	if #result < #ids then
		error("chapter graph has a cycle")
	end
	return result
end

export type EntryVerdict = {
	allowed: boolean,
	reason: string, -- "ok" | "locked" | "needsPlayers" | "unknown"
	replay: boolean,
}

-- Soft gating (DESIGN.md 4-1): a chapter you have cleared is always re-enterable.
-- Never lock a kid out of somewhere they have already been.
function ChapterService.entryVerdict(
	data: Types.ProgressData,
	chapter: Types.Chapter?,
	presentPlayers: number
): EntryVerdict
	if not chapter then
		return { allowed = false, reason = "unknown", replay = false }
	end

	local replay = ProgressLogic.isChapterComplete(data, chapter.id)

	for _, requirement in chapter.requires do
		if not ProgressLogic.isChapterComplete(data, requirement) then
			return { allowed = false, reason = "locked", replay = replay }
		end
	end

	if presentPlayers < chapter.minPlayers then
		return { allowed = false, reason = "needsPlayers", replay = replay }
	end

	return { allowed = true, reason = "ok", replay = replay }
end

--------------------------------------------------------------------------------
-- Session wiring
--------------------------------------------------------------------------------

local function originFor(chapterId: string): CFrame
	local index = table.find(order, chapterId) or 1
	return CFrame.new((index - 1) * CHAPTER_SPACING, 0, CHAPTER_Z)
end

local function broadcastObjectives(session: any)
	local payload = {
		chapterId = session.chapterId,
		objectives = table.clone(session.objectives),
		focus = session.focus,
	}
	for _, player in session.players do
		Net.event("ObjectiveChanged"):FireClient(player, payload)
	end
end

local function narrate(players: { Player }, stringKey: string)
	for _, player in players do
		Net.event("Narrate"):FireClient(player, stringKey)
	end
end

local function teleport(player: Player, target: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(target)
	end
end

local function sendToHub(player: Player)
	playerSession[player] = nil
	teleport(player, hubSpawn)
	Net.event("ChapterEntered"):FireClient(player, nil)
	Net.event("ObjectiveChanged"):FireClient(player, { chapterId = nil, objectives = {}, focus = nil })
end

local function destroySession(session: Session.Session)
	sessions[session.chapterId] = nil
	for _, player in table.clone(session.players) do
		sendToHub(player)
	end
	session:destroy()
end

local function onSessionCompleted(session: Session.Session)
	for _, player in session.players do
		ProgressService.markChapterComplete(player, session.chapterId)
	end
	narrate(session.players, "chapter.complete")

	task.delay(RETURN_DELAY, function()
		if sessions[session.chapterId] == session then
			narrate(session.players, "chapter.returning")
			destroySession(session)
		end
	end)
end

local function getOrCreateSession(chapter: Types.Chapter): Session.Session?
	local existing = sessions[chapter.id]
	if existing and existing:isActive() then
		return existing
	end

	local session = Session.new(chapter, originFor(chapter.id), Workspace, {
		grantFragment = function(player, fragmentId)
			ProgressService.grantFragment(player, fragmentId)
		end,
		narrate = narrate,
		objectiveChanged = broadcastObjectives,
	})

	sessions[chapter.id] = session
	session.Completed:connect(onSessionCompleted)

	local ok, err = pcall(chapter.start, session :: any)
	if not ok then
		-- A broken chapter takes itself down, not the pad the player stepped on.
		warn(`[ChapterService] {chapter.id} failed to start: {err}`)
		destroySession(session)
		return nil
	end

	return session
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function ChapterService.getOrder(): { string }
	return table.clone(order)
end

function ChapterService.get(chapterId: string): Types.Chapter?
	return chapters[chapterId]
end

function ChapterService.setHubSpawn(cframe: CFrame)
	hubSpawn = cframe
end

function ChapterService.sessionFor(player: Player): Session.Session?
	return playerSession[player]
end

function ChapterService.requestEnter(player: Player, chapterId: string)
	local data = ProgressService.get(player)
	if not data then
		return
	end

	local chapter = chapters[chapterId]
	local verdict = ChapterService.entryVerdict(data, chapter, #Players:GetPlayers())

	if not verdict.allowed then
		if verdict.reason == "locked" then
			Net.event("Narrate"):FireClient(player, "hub.locked")
		elseif verdict.reason == "needsPlayers" then
			Net.event("Narrate"):FireClient(player, "hub.needsFriends")
		end
		return
	end

	local current = playerSession[player]
	if current and current.chapterId == chapterId then
		return
	end
	if current then
		ChapterService.leave(player)
	end

	local session = getOrCreateSession(chapter :: Types.Chapter)
	if not session then
		return
	end

	playerSession[player] = session
	session:addPlayer(player)

	teleport(player, session.origin * CFrame.new(0, 8, 0))
	Net.event("ChapterEntered"):FireClient(player, chapterId)
	Net.event("Narrate"):FireClient(player, `chapter.{chapterId}.intro`)
end

function ChapterService.leave(player: Player)
	local session = playerSession[player]
	if not session then
		return
	end

	local remaining = session:removePlayer(player)
	sendToHub(player)

	if remaining == 0 and sessions[session.chapterId] == session then
		destroySession(session)
	end
end

function ChapterService.start(chapterFolder: Instance)
	for _, module in chapterFolder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end

		local chapter = require(module) :: Types.Chapter
		assert(chapter.id, `{module.Name} has no id`)
		assert(chapters[chapter.id] == nil, `duplicate chapter id "{chapter.id}"`)
		assert(#chapter.objectives > 0, `chapter "{chapter.id}" has no objectives`)
		assert(Strings.has(`chapter.{chapter.id}.title`), `chapter "{chapter.id}" has no title string`)

		-- Fragments must match the verse table, or a kid could collect a piece that
		-- never renders into a sentence.
		local expected = Verses.fragmentIdsFor(chapter.id)
		assert(
			#expected == #chapter.fragments,
			`chapter "{chapter.id}" declares {#chapter.fragments} fragments but Verses has {#expected}`
		)

		chapters[chapter.id] = chapter
	end

	order = ChapterService.buildOrder(chapters)

	Players.PlayerRemoving:Connect(function(player)
		local session = playerSession[player]
		if session then
			ChapterService.leave(player)
		end
	end)

	Net.event("RequestEnterChapter").OnServerEvent:Connect(function(player, chapterId)
		if typeof(chapterId) == "string" then
			ChapterService.requestEnter(player, chapterId)
		end
	end)

	Net.event("RequestLeaveChapter").OnServerEvent:Connect(function(player)
		ChapterService.leave(player)
	end)

	return order
end

return ChapterService
