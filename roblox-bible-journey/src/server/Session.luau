--!strict
-- One live run of one chapter, shared by everyone currently inside it (the
-- co-op gates in DESIGN.md 3-3 depend on players sharing a session, not each
-- getting a private copy).
--
-- Chapters never touch Workspace, Players or remotes directly. They spawn through
-- `track` and connect through `bind`, so `destroy` can guarantee cleanup however
-- the session ends — cleared, abandoned, or server shutdown mid-chapter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

export type Deps = {
	grantFragment: (player: Player, fragmentId: string) -> (),
	narrate: (players: { Player }, stringKey: string) -> (),
	objectiveChanged: (session: any) -> (),
}

type SessionFields = {
	chapterId: string,
	chapter: Types.Chapter,
	origin: CFrame,
	world: Folder,
	players: { Player },
	objectives: { [string]: boolean },
	focus: Vector3?,

	Completed: Signal.Signal,
	Ended: Signal.Signal,

	_deps: Deps,
	_connections: { RBXScriptConnection },
	_active: boolean,
	_completed: boolean,
}

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable({} :: SessionFields, Session))

function Session.new(chapter: Types.Chapter, origin: CFrame, worldParent: Instance, deps: Deps): Session
	local world = Instance.new("Folder")
	world.Name = `Session_{chapter.id}`
	world.Parent = worldParent

	local objectives: { [string]: boolean } = {}
	for _, objectiveId in chapter.objectives do
		objectives[objectiveId] = false
	end

	local self = setmetatable({
		chapterId = chapter.id,
		chapter = chapter,
		origin = origin,
		world = world,
		players = {} :: { Player },
		objectives = objectives,
		focus = nil :: Vector3?,

		Completed = Signal.new(),
		Ended = Signal.new(),

		_deps = deps,
		_connections = {} :: { RBXScriptConnection },
		_active = true,
		_completed = false,
	}, Session)

	return self
end

function Session.isActive(self: Session): boolean
	return self._active
end

function Session.track(self: Session, instance: Instance): Instance
	instance.Parent = self.world
	return instance
end

function Session.bind(self: Session, signal: RBXScriptSignal, handler: (...any) -> ())
	if not self._active then
		return
	end
	table.insert(self._connections, signal:Connect(function(...)
		if self._active then
			handler(...)
		end
	end))
end

function Session.addPlayer(self: Session, player: Player)
	if table.find(self.players, player) then
		return
	end
	table.insert(self.players, player)
	self._deps.objectiveChanged(self)
end

function Session.removePlayer(self: Session, player: Player): number
	local index = table.find(self.players, player)
	if index then
		table.remove(self.players, index)
	end
	return #self.players
end

function Session.say(self: Session, stringKey: string)
	if not self._active then
		return
	end
	self._deps.narrate(self.players, stringKey)
end

-- Where the client should plant the guiding light pillar. Kids do not read a
-- objective line at the top of the screen; they follow a beam (DESIGN.md 5-5).
function Session.point(self: Session, position: Vector3?)
	self.focus = position
	self._deps.objectiveChanged(self)
end

function Session.grantFragment(self: Session, player: Player, fragmentId: string)
	if not self._active then
		return
	end
	assert(table.find(self.chapter.fragments, fragmentId), `fragment "{fragmentId}" is not in {self.chapterId}`)
	self._deps.grantFragment(player, fragmentId)
end

function Session.isObjectiveDone(self: Session, objectiveId: string): boolean
	return self.objectives[objectiveId] == true
end

function Session.setObjective(self: Session, objectiveId: string, done: boolean)
	if not self._active or self._completed then
		return
	end
	if self.objectives[objectiveId] == nil then
		warn(`[Session] {self.chapterId} has no objective "{objectiveId}"`)
		return
	end
	if self.objectives[objectiveId] == done then
		return
	end

	self.objectives[objectiveId] = done
	self._deps.objectiveChanged(self)

	if done and self.chapter.onObjective then
		self.chapter.onObjective(self :: any, objectiveId)
	end

	for _, value in self.objectives do
		if not value then
			return
		end
	end

	-- onObjective above may have set the last objective and already completed us.
	if self._completed then
		return
	end

	self._completed = true
	self.Completed:fire(self)
end

function Session.destroy(self: Session)
	if not self._active then
		return
	end
	self._active = false

	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)

	local ok, err = pcall(self.chapter.cleanup, self :: any)
	if not ok then
		warn(`[Session] {self.chapterId} cleanup errored: {err}`)
	end

	self.world:Destroy()
	self.Ended:fire(self)
	self.Completed:destroy()
	self.Ended:destroy()
end

return Session
