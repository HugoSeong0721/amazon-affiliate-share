--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ProgressLogic = require(ServerScriptService.Server.ProgressLogic)
local Runner = require(script.Parent.Runner)

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("ProgressLogic", function()
		it("starts empty", function()
			local data = ProgressLogic.template()
			expect(ProgressLogic.countFragments(data)).toBe(0)
			expect(ProgressLogic.lampLevel(data)).toBe(0)
			expect(ProgressLogic.completedCount(data)).toBe(0)
		end)

		it("grants a fragment exactly once", function()
			local data = ProgressLogic.template()
			expect(ProgressLogic.grantFragment(data, "ch01_f1")).toBe(true)
			expect(ProgressLogic.grantFragment(data, "ch01_f1")).toBe(false)
			expect(ProgressLogic.countFragments(data)).toBe(1)
		end)

		it("lights one lamp per three fragments", function()
			local data = ProgressLogic.template()
			ProgressLogic.grantFragment(data, "a")
			ProgressLogic.grantFragment(data, "b")
			expect(ProgressLogic.lampLevel(data)).toBe(0)

			ProgressLogic.grantFragment(data, "c")
			expect(ProgressLogic.lampLevel(data)).toBe(1)

			ProgressLogic.grantFragment(data, "d")
			expect(ProgressLogic.lampLevel(data)).toBe(1)
		end)

		it("records a completion timestamp once", function()
			local data = ProgressLogic.template()
			expect(ProgressLogic.markChapterComplete(data, "ch00_waiting", 1000)).toBe(true)
			expect(ProgressLogic.markChapterComplete(data, "ch00_waiting", 2000)).toBe(false)
			-- Replaying a chapter must not rewrite when it was first walked.
			expect(data.completedChapters.ch00_waiting).toBe(1000)
		end)

		it("fills missing fields on migrate without losing progress", function()
			local stale: any = { schema = 0, fragments = { ch01_f1 = true } }
			local migrated = ProgressLogic.migrate(stale)

			expect(migrated.schema).toBe(ProgressLogic.CURRENT_SCHEMA)
			expect(migrated.fragments.ch01_f1).toBe(true)
			expect(migrated.guideCount).toBe(0)
			expect(migrated.locale).toBe("ko")
			expect(migrated.completedChapters).toEqual({})
		end)

		it("snapshots only what the client needs to draw", function()
			local data = ProgressLogic.template()
			ProgressLogic.grantFragment(data, "ch00_f1")
			ProgressLogic.markChapterComplete(data, "ch00_waiting", 42)

			local snapshot = ProgressLogic.snapshot(data, { "ch00_waiting", "ch01_bethlehem" })
			expect(snapshot.order).toHaveLength(2)
			expect(snapshot.completedChapters.ch00_waiting).toBe(42)
			expect(snapshot.lampLevel).toBe(0)

			-- The snapshot must be a copy: a mutation on the client's payload cannot
			-- reach the authoritative table.
			snapshot.completedChapters.ch01_bethlehem = 1
			expect(ProgressLogic.isChapterComplete(data, "ch01_bethlehem")).toBe(false)
		end)
	end)
end
