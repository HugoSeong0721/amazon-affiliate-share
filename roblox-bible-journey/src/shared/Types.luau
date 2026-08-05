--!strict

export type ProgressData = {
	schema: number,
	completedChapters: { [string]: number },
	fragments: { [string]: boolean },
	guideCount: number,
	lastSeedAt: number,
	locale: string,
}

-- What a chapter module is handed. Everything a chapter spawns goes through
-- `track` so cleanup is guaranteed no matter how the session ends.
export type Session = {
	chapterId: string,
	origin: CFrame,
	players: { Player },
	world: Folder,

	track: (self: Session, instance: Instance) -> Instance,
	bind: (self: Session, signal: RBXScriptSignal, handler: (...any) -> ()) -> (),
	setObjective: (self: Session, objectiveId: string, done: boolean) -> (),
	isObjectiveDone: (self: Session, objectiveId: string) -> boolean,
	point: (self: Session, position: Vector3?) -> (),
	say: (self: Session, stringKey: string) -> (),
	sayTo: (self: Session, player: Player, stringKey: string) -> (),
	grantFragment: (self: Session, player: Player, fragmentId: string) -> (),
	isActive: (self: Session) -> boolean,
}

export type Chapter = {
	id: string,
	reference: string,
	-- Verse fragments hidden in the map. Optional to collect; never gate on them.
	fragments: { string },
	requires: { string },
	minPlayers: number,
	estimatedMinutes: number,
	-- All of these must be true for the chapter to count as complete.
	objectives: { string },

	start: (session: Session) -> (),
	onObjective: ((session: Session, objectiveId: string) -> ())?,
	cleanup: (session: Session) -> (),
}

export type Backend = {
	name: string,
	load: (player: Player) -> ProgressData?,
	flush: (player: Player) -> (),
	release: (player: Player) -> (),
}

return {}
