--!strict
-- Chapter 1's lesson lives in these numbers, so they get a test: walking gathers
-- the flock, charging scatters it.

local ServerScriptService = game:GetService("ServerScriptService")
local SheepController = require(ServerScriptService.Server.greybox.SheepController)
local Runner = require(script.Parent.Runner)

local PEN_CENTER = Vector3.new(0, 3, -70)
local PEN_SIZE = Vector3.new(36, 20, 30)

local function makeSheep(position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(3, 3, 4)
	part.CFrame = CFrame.new(position)
	return part
end

local function controllerWith(sheep: { BasePart })
	return SheepController.new({
		sheep = sheep,
		penCenter = PEN_CENTER,
		penSize = PEN_SIZE,
		boundsCenter = Vector3.new(0, 0, 0),
		boundsSize = Vector3.new(208, 0, 208),
		groundY = 3,
		seed = 7,
	})
end

local function stepFor(controller: any, seconds: number, herders: { any })
	local dt = 1 / 60
	for _ = 1, math.floor(seconds / dt) do
		controller:step(dt, herders)
	end
end

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("SheepController", function()
		it("pens a sheep that is already inside the walls", function()
			local sheep = makeSheep(PEN_CENTER)
			local controller = controllerWith({ sheep })

			expect(controller:pennedCount()).toBe(0)
			controller:step(1 / 60, {})
			expect(controller:pennedCount()).toBe(1)
			expect(controller:total()).toBe(1)
		end)

		it("moves a sheep away from a herder", function()
			local sheep = makeSheep(Vector3.new(0, 3, 0))
			local controller = controllerWith({ sheep })

			-- Herder stands south of the sheep, so the sheep should end up north.
			stepFor(controller, 1, { { position = Vector3.new(0, 3, 8), speed = 0 } })
			expect(sheep.Position.Z < -2).toBeTruthy()
		end)

		it("pushes harder the faster the herder is moving", function()
			local calmSheep = makeSheep(Vector3.new(0, 3, 0))
			local calm = controllerWith({ calmSheep })
			stepFor(calm, 1, { { position = Vector3.new(0, 3, 8), speed = 0 } })

			local chasedSheep = makeSheep(Vector3.new(0, 3, 0))
			local chased = controllerWith({ chasedSheep })
			stepFor(chased, 1, { { position = Vector3.new(0, 3, 8), speed = 24 } })

			-- Same seed, same start, same herder position — only the speed differs.
			expect(chasedSheep.Position.Z < calmSheep.Position.Z).toBeTruthy()
		end)

		it("keeps sheep inside the field", function()
			local sheep = makeSheep(Vector3.new(0, 3, 100))
			local controller = controllerWith({ sheep })

			stepFor(controller, 3, { { position = Vector3.new(0, 3, 90), speed = 40 } })
			expect(sheep.Position.Z <= 104).toBeTruthy()
			expect(sheep.Position.Y).toBe(3)
		end)

		it("stops moving a sheep once it is penned", function()
			local sheep = makeSheep(PEN_CENTER)
			local controller = controllerWith({ sheep })
			controller:step(1 / 60, {})

			local resting = sheep.Position
			stepFor(controller, 2, { { position = PEN_CENTER + Vector3.new(0, 0, 6), speed = 40 } })
			expect((sheep.Position - resting).Magnitude).toBeCloseTo(0, 1e-3)
		end)
	end)
end
