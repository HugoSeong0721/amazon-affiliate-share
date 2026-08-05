--!strict
-- Chapter 5 is the learning system's debut, so its rules get pinned hardest:
-- wrong answers cost nothing but another look, and nobody stays stuck.

local ServerScriptService = game:GetService("ServerScriptService")
local TrialLogic = require(ServerScriptService.Server.greybox.TrialLogic)
local Runner = require(script.Parent.Runner)

local function threeTrials()
	return TrialLogic.new({
		{ id = "trial_bread", answer = "ch05_bread" },
		{ id = "trial_leap", answer = "ch05_test" },
		{ id = "trial_worship", answer = "ch05_worship" },
	})
end

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("TrialLogic", function()
		it("faces the first temptation first", function()
			local logic = threeTrials()
			expect(logic:current()).toBe("trial_bread")
			expect(logic:isComplete()).toBe(false)
		end)

		it("advances only on the right verse", function()
			local logic = threeTrials()
			expect(logic:answer("trial_bread", "ch05_worship")).toBe("wrong")
			expect(logic:current()).toBe("trial_bread")

			expect(logic:answer("trial_bread", "ch05_bread")).toBe("correct")
			expect(logic:current()).toBe("trial_leap")
		end)

		it("keeps future trials locked — the story's order is the spacing", function()
			local logic = threeTrials()
			expect(logic:answer("trial_worship", "ch05_worship")).toBe("not_current")
			expect(logic:current()).toBe("trial_bread")
		end)

		it("lets a solved trial rest", function()
			local logic = threeTrials()
			logic:answer("trial_bread", "ch05_bread")
			expect(logic:answer("trial_bread", "ch05_bread")).toBe("already_solved")
			expect(logic:current()).toBe("trial_leap")
		end)

		it("counts only wrong tries", function()
			local logic = threeTrials()
			logic:answer("trial_bread", "ch05_test")
			logic:answer("trial_bread", "ch05_worship")
			logic:answer("trial_bread", "ch05_bread")
			expect(logic:attempts("trial_bread")).toBe(2)
		end)

		it("gives the answer away after three misses — nobody stays stuck", function()
			local logic = threeTrials()
			expect(logic:shouldReveal("trial_bread")).toBe(false)

			for _ = 1, 3 do
				logic:answer("trial_bread", "ch05_worship")
			end
			expect(logic:shouldReveal("trial_bread")).toBe(true)
			expect(logic:answerFor("trial_bread")).toBe("ch05_bread")

			-- The mercy beam belongs to the trial being faced, not to old ones.
			logic:answer("trial_bread", "ch05_bread")
			expect(logic:shouldReveal("trial_bread")).toBe(false)
		end)

		it("completes after the third victory", function()
			local logic = threeTrials()
			logic:answer("trial_bread", "ch05_bread")
			logic:answer("trial_leap", "ch05_test")
			expect(logic:isComplete()).toBe(false)

			logic:answer("trial_worship", "ch05_worship")
			expect(logic:isComplete()).toBe(true)
			expect(logic:current()).toBeNil()
		end)

		it("shrugs at unknown trial ids", function()
			local logic = threeTrials()
			expect(logic:answer("trial_typo", "ch05_bread")).toBe("unknown_trial")
			expect(logic:attempts("trial_typo")).toBe(0)
		end)

		it("rejects duplicate trial ids at construction", function()
			expect(function()
				TrialLogic.new({
					{ id = "a", answer = "x" },
					{ id = "a", answer = "y" },
				})
			end).toThrow("duplicate trial id")
		end)
	end)
end
