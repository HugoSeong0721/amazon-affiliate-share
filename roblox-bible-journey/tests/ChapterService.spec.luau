--!strict
-- The journey graph is the one thing that must be right before any map exists:
-- a wrong order means the road segments do not match the story.

local ServerScriptService = game:GetService("ServerScriptService")
local ChapterService = require(ServerScriptService.Server.ChapterService)
local ProgressLogic = require(ServerScriptService.Server.ProgressLogic)
local Runner = require(script.Parent.Runner)

local function chapter(id: string, requires: { string }, minPlayers: number?): any
	return {
		id = id,
		reference = "",
		fragments = {},
		requires = requires,
		minPlayers = minPlayers or 1,
		estimatedMinutes = 5,
		objectives = { "done" },
		start = function() end,
		cleanup = function() end,
	}
end

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("ChapterService.buildOrder", function()
		it("orders a straight chain", function()
			local order = ChapterService.buildOrder({
				c = chapter("c", { "b" }),
				a = chapter("a", {}),
				b = chapter("b", { "a" }),
			})
			expect(order).toEqual({ "a", "b", "c" })
		end)

		it("is stable when two chapters are equally ready", function()
			local input = {
				zeta = chapter("zeta", { "root" }),
				alpha = chapter("alpha", { "root" }),
				root = chapter("root", {}),
			}
			-- Same result every run: an unstable order would reshuffle the road.
			expect(ChapterService.buildOrder(input)).toEqual(ChapterService.buildOrder(input))
			expect(ChapterService.buildOrder(input)).toEqual({ "root", "alpha", "zeta" })
		end)

		it("tolerates a duplicated requirement", function()
			local order = ChapterService.buildOrder({
				a = chapter("a", {}),
				b = chapter("b", { "a", "a" }),
			})
			expect(order).toEqual({ "a", "b" })
		end)

		it("rejects an unknown requirement", function()
			expect(function()
				ChapterService.buildOrder({ a = chapter("a", { "nope" }) })
			end).toThrow("unknown chapter")
		end)

		it("rejects a self-requirement", function()
			expect(function()
				ChapterService.buildOrder({ a = chapter("a", { "a" }) })
			end).toThrow("requires itself")
		end)

		it("rejects a cycle", function()
			expect(function()
				ChapterService.buildOrder({
					a = chapter("a", { "b" }),
					b = chapter("b", { "a" }),
				})
			end).toThrow("cycle")
		end)
	end)

	describe("ChapterService.entryVerdict", function()
		it("locks a chapter whose requirement is unmet", function()
			local data = ProgressLogic.template()
			local verdict = ChapterService.entryVerdict(data, chapter("b", { "a" }), 1)
			expect(verdict.allowed).toBe(false)
			expect(verdict.reason).toBe("locked")
		end)

		it("opens a chapter once its requirement is walked", function()
			local data = ProgressLogic.template()
			ProgressLogic.markChapterComplete(data, "a", 1)
			expect(ChapterService.entryVerdict(data, chapter("b", { "a" }), 1).allowed).toBe(true)
		end)

		it("keeps a finished chapter re-enterable", function()
			local data = ProgressLogic.template()
			ProgressLogic.markChapterComplete(data, "a", 1)

			local verdict = ChapterService.entryVerdict(data, chapter("a", {}), 1)
			expect(verdict.allowed).toBe(true)
			expect(verdict.replay).toBe(true)
		end)

		it("holds a co-op chapter until enough players are present", function()
			local data = ProgressLogic.template()
			local coop = chapter("stretcher", {}, 4)

			expect(ChapterService.entryVerdict(data, coop, 3).reason).toBe("needsPlayers")
			expect(ChapterService.entryVerdict(data, coop, 4).allowed).toBe(true)
		end)

		it("refuses an unknown chapter id", function()
			local verdict = ChapterService.entryVerdict(ProgressLogic.template(), nil, 1)
			expect(verdict.allowed).toBe(false)
			expect(verdict.reason).toBe("unknown")
		end)
	end)
end
