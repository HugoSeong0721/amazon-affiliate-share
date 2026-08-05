--!strict
-- Every chapter trusts Session to clean up after it. If that trust is misplaced,
-- an abandoned chapter leaks its map and its Heartbeat connection into a live
-- server, and the next player to walk in finds someone else's sheep.

local ServerScriptService = game:GetService("ServerScriptService")
local Session = require(ServerScriptService.Server.Session)
local Runner = require(script.Parent.Runner)

local function fakeChapter(objectives: { string }, hooks: { [string]: any }?): any
	local chapter: any = {
		id = "ch_test",
		reference = "",
		fragments = { "frag_a" },
		requires = {},
		minPlayers = 1,
		estimatedMinutes = 1,
		objectives = objectives,
		start = function() end,
		cleanup = function() end,
	}
	for key, value in hooks or {} do
		chapter[key] = value
	end
	return chapter
end

local function newSession(chapter: any): (any, { [string]: any })
	local calls = { fragments = {}, narrated = {}, objectiveBroadcasts = 0, cleanups = 0 }

	local baseCleanup = chapter.cleanup
	chapter.cleanup = function(session)
		calls.cleanups += 1
		baseCleanup(session)
	end

	local session = Session.new(chapter, CFrame.new(0, 0, 0), Instance.new("Folder"), {
		grantFragment = function(_player, fragmentId)
			table.insert(calls.fragments, fragmentId)
		end,
		narrate = function(_players, stringKey)
			table.insert(calls.narrated, stringKey)
		end,
		objectiveChanged = function()
			calls.objectiveBroadcasts += 1
		end,
	})

	return session, calls
end

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("Session", function()
		it("starts with every objective unfinished", function()
			local session = newSession(fakeChapter({ "a", "b" }))
			expect(session:isObjectiveDone("a")).toBe(false)
			expect(session:isActive()).toBe(true)
		end)

		it("parents tracked instances into its own world", function()
			local session = newSession(fakeChapter({ "a" }))
			local part = Instance.new("Part")
			session:track(part)
			expect(part.Parent).toBe(session.world)
		end)

		it("completes only when the last objective lands", function()
			local session, calls = newSession(fakeChapter({ "a", "b" }))
			local completions = 0
			session.Completed:connect(function()
				completions += 1
			end)

			session:setObjective("a", true)
			expect(completions).toBe(0)

			session:setObjective("b", true)
			expect(completions).toBe(1)
			expect(calls.objectiveBroadcasts >= 2).toBeTruthy()
		end)

		it("ignores an unknown objective id", function()
			local session = newSession(fakeChapter({ "a" }))
			local completions = 0
			session.Completed:connect(function()
				completions += 1
			end)

			session:setObjective("typo", true)
			expect(completions).toBe(0)
			expect(session:isObjectiveDone("a")).toBe(false)
		end)

		it("fires Completed once even when onObjective finishes the chapter itself", function()
			-- Regression: chaining objectives inside onObjective used to complete twice,
			-- which double-awarded the chapter and double-scheduled the trip home.
			local chapter = fakeChapter({ "first", "second" }, {
				onObjective = function(session, objectiveId)
					if objectiveId == "first" then
						session:setObjective("second", true)
					end
				end,
			})

			local session = newSession(chapter)
			local completions = 0
			session.Completed:connect(function()
				completions += 1
			end)

			session:setObjective("first", true)
			expect(completions).toBe(1)
		end)

		it("destroys its world and calls chapter cleanup exactly once", function()
			local session, calls = newSession(fakeChapter({ "a" }))
			local world = session.world
			local part = Instance.new("Part")
			session:track(part)

			session:destroy()
			expect(calls.cleanups).toBe(1)
			expect(session:isActive()).toBe(false)
			expect(world.Parent).toBeNil()

			-- Double destroy must be harmless: leave() and a shutdown can race.
			session:destroy()
			expect(calls.cleanups).toBe(1)
		end)

		it("goes inert after destroy", function()
			local session, calls = newSession(fakeChapter({ "a" }))
			session:destroy()
			local broadcastsAtDeath = calls.objectiveBroadcasts

			session:setObjective("a", true)
			session:say("anything")
			session:point(Vector3.new(1, 2, 3))
			expect(session:isObjectiveDone("a")).toBe(false)
			expect(calls.narrated).toHaveLength(0)
			expect(calls.objectiveBroadcasts).toBe(broadcastsAtDeath)
			expect(session.focus).toBeNil()
		end)

		it("cleans up even when the chapter's cleanup throws", function()
			local chapter = fakeChapter({ "a" }, {
				cleanup = function()
					error("chapter cleanup is broken")
				end,
			})

			local session = newSession(chapter)
			local world = session.world
			session:destroy()

			-- A buggy chapter must not strand its map in the live world.
			expect(world.Parent).toBeNil()
			expect(session:isActive()).toBe(false)
		end)

		it("tracks players without duplicates", function()
			local session = newSession(fakeChapter({ "a" }))
			local player = Instance.new("Folder") :: any

			session:addPlayer(player)
			session:addPlayer(player)
			expect(session.players).toHaveLength(1)
			expect(session:removePlayer(player)).toBe(0)
		end)

		it("narrates to one player without addressing the room", function()
			local session, calls = newSession(fakeChapter({ "a" }))
			local player = Instance.new("Folder") :: any

			session:sayTo(player, "ch10.shared")
			expect(calls.narrated).toEqual({ "ch10.shared" })

			session:destroy()
			session:sayTo(player, "ch10.shared")
			expect(calls.narrated).toHaveLength(1)
		end)

		it("refuses to grant a fragment the chapter does not own", function()
			local session, calls = newSession(fakeChapter({ "a" }))
			local player = Instance.new("Folder") :: any

			session:grantFragment(player, "frag_a")
			expect(calls.fragments).toEqual({ "frag_a" })

			expect(function()
				session:grantFragment(player, "frag_from_another_chapter")
			end).toThrow("is not in ch_test")
		end)
	end)
end
