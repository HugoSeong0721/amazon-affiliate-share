--!strict
-- Chapter 1's herding rule, and the reason the chapter is about shepherding
-- rather than collecting: sheep flee harder the faster you move at them. Charging
-- scatters the flock; walking gathers it. Nobody has to say that in a text box.
--
-- Anchored parts moved by hand rather than physics — deterministic, cheap, and it
-- cannot launch a sheep into the skybox on a bad frame.

local SheepController = {}
SheepController.__index = SheepController

local FLEE_RADIUS = 20
local FLEE_ACCEL = 70
local WANDER_ACCEL = 8
local MAX_SPEED = 26
local DAMPING = 2.4
-- A player standing still barely pushes; a sprinting player pushes ~3x as hard.
local PANIC_PER_STUD_PER_SECOND = 1 / 12
local MAX_PANIC = 3

type SheepState = {
	part: BasePart,
	velocity: Vector3,
	penned: boolean,
}

export type Config = {
	sheep: { BasePart },
	penCenter: Vector3,
	penSize: Vector3,
	boundsCenter: Vector3,
	boundsSize: Vector3,
	groundY: number,
	seed: number?,
}

type Fields = {
	states: { SheepState },
	penCenter: Vector3,
	penSize: Vector3,
	boundsCenter: Vector3,
	boundsSize: Vector3,
	groundY: number,
	rng: Random,
}

export type SheepController = typeof(setmetatable({} :: Fields, SheepController))

function SheepController.new(config: Config): SheepController
	local states: { SheepState } = {}
	for _, part in config.sheep do
		table.insert(states, { part = part, velocity = Vector3.zero, penned = false })
	end

	return setmetatable({
		states = states,
		penCenter = config.penCenter,
		penSize = config.penSize,
		boundsCenter = config.boundsCenter,
		boundsSize = config.boundsSize,
		groundY = config.groundY,
		rng = Random.new(config.seed or 20250805),
	}, SheepController)
end

local function insideBox(point: Vector3, center: Vector3, size: Vector3): boolean
	local half = size / 2
	local delta = point - center
	return math.abs(delta.X) <= half.X and math.abs(delta.Z) <= half.Z
end

local function clampToBounds(position: Vector3, center: Vector3, size: Vector3): Vector3
	local half = size / 2
	return Vector3.new(
		math.clamp(position.X, center.X - half.X, center.X + half.X),
		position.Y,
		math.clamp(position.Z, center.Z - half.Z, center.Z + half.Z)
	)
end

function SheepController.total(self: SheepController): number
	return #self.states
end

function SheepController.pennedCount(self: SheepController): number
	local count = 0
	for _, state in self.states do
		if state.penned then
			count += 1
		end
	end
	return count
end

-- `herders` is a list of {position, speed} so this stays testable without characters.
export type Herder = { position: Vector3, speed: number }

function SheepController.step(self: SheepController, dt: number, herders: { Herder })
	-- Long frames (a kid on a cheap tablet) must not teleport sheep through the pen wall.
	dt = math.min(dt, 1 / 20)

	for _, state in self.states do
		if state.penned then
			continue
		end

		local position = state.part.Position
		local acceleration = Vector3.zero

		for _, herder in herders do
			local away = position - herder.position
			local flat = Vector3.new(away.X, 0, away.Z)
			local distance = flat.Magnitude
			if distance > 0.001 and distance < FLEE_RADIUS then
				local closeness = 1 - distance / FLEE_RADIUS
				local panic = math.clamp(1 + herder.speed * PANIC_PER_STUD_PER_SECOND, 1, MAX_PANIC)
				acceleration += flat.Unit * (FLEE_ACCEL * closeness * panic)
			end
		end

		acceleration += Vector3.new(
			self.rng:NextNumber(-1, 1) * WANDER_ACCEL,
			0,
			self.rng:NextNumber(-1, 1) * WANDER_ACCEL
		)

		local velocity = state.velocity + acceleration * dt
		velocity -= velocity * math.min(DAMPING * dt, 1)
		if velocity.Magnitude > MAX_SPEED then
			velocity = velocity.Unit * MAX_SPEED
		end

		local nextPosition = clampToBounds(position + velocity * dt, self.boundsCenter, self.boundsSize)
		nextPosition = Vector3.new(nextPosition.X, self.groundY, nextPosition.Z)

		state.velocity = velocity
		state.part.CFrame = CFrame.new(nextPosition)

		if insideBox(nextPosition, self.penCenter, self.penSize) then
			state.penned = true
			state.velocity = Vector3.zero
			state.part.Color = Color3.fromRGB(255, 248, 226)
		end
	end
end

return SheepController
