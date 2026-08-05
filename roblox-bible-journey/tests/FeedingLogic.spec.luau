--!strict
-- Chapter 10's meaning is in these rules, so they get the same treatment as the
-- sheep: pin the numbers that carry the story.

local ServerScriptService = game:GetService("ServerScriptService")
local FeedingLogic = require(ServerScriptService.Server.greybox.FeedingLogic)
local Runner = require(script.Parent.Runner)

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("FeedingLogic", function()
		it("starts with everyone hungry and the basket empty", function()
			local logic = FeedingLogic.new({ 12, 12 }, 12)
			expect(logic:remainingTotal()).toBe(24)
			expect(logic:isEveryoneFed()).toBe(false)
			expect(logic:contributorCount()).toBe(0)
		end)

		it("gives nothing until someone has shared", function()
			-- The whole chapter hinges here: no contribution, no bread, no matter
			-- how many times the basket is touched.
			local logic = FeedingLogic.new({ 12 }, 12)
			expect(logic:pickUp("kid_a")).toBe(0)
			expect(logic:pickUp("kid_a")).toBe(0)
		end)

		it("accepts a lunch only once — giving cannot be taken back", function()
			local logic = FeedingLogic.new({ 12 }, 12)
			expect(logic:contribute("kid_a")).toBe(true)
			expect(logic:contribute("kid_a")).toBe(false)
			expect(logic:contributorCount()).toBe(1)
			expect(logic:hasContributed("kid_a")).toBe(true)
		end)

		it("never runs dry after the first gift", function()
			local logic = FeedingLogic.new({ 12, 12, 12, 12, 12 }, 12)
			logic:contribute("kid_a")

			-- One lunch, five full loads: the basket refills every trip. The miracle
			-- is the multiplication, not a stored quantity.
			local drawn = 0
			for group = 1, 5 do
				drawn += logic:pickUp("kid_a")
				logic:deliver("kid_a", group)
			end
			expect(drawn).toBe(60)
		end)

		it("carries more when more players share", function()
			local logic = FeedingLogic.new({ 48 }, 12)
			logic:contribute("kid_a")
			expect(logic:carryCapacity()).toBe(12)

			logic:contribute("kid_b")
			logic:contribute("kid_c")
			expect(logic:carryCapacity()).toBe(36)
			expect(logic:pickUp("kid_a")).toBe(36)
		end)

		it("refuses a second pickup while hands are full", function()
			local logic = FeedingLogic.new({ 24 }, 12)
			logic:contribute("kid_a")

			expect(logic:pickUp("kid_a")).toBe(12)
			expect(logic:pickUp("kid_a")).toBe(0)
			expect(logic:carryingOf("kid_a")).toBe(12)
		end)

		it("feeds a group no more than it needs", function()
			local logic = FeedingLogic.new({ 5, 12 }, 12)
			logic:contribute("kid_a")
			logic:pickUp("kid_a")

			expect(logic:deliver("kid_a", 1)).toBe(5)
			expect(logic:groupNeed(1)).toBe(0)
			-- The rest stays in hand for the next group.
			expect(logic:carryingOf("kid_a")).toBe(7)

			expect(logic:deliver("kid_a", 2)).toBe(7)
			expect(logic:groupNeed(2)).toBe(5)
		end)

		it("delivers nothing empty-handed, to a fed group, or off the map", function()
			local logic = FeedingLogic.new({ 3 }, 12)
			logic:contribute("kid_a")

			expect(logic:deliver("kid_a", 1)).toBe(0) -- never picked up

			logic:pickUp("kid_a")
			expect(logic:deliver("kid_a", 9)).toBe(0) -- no such group
			expect(logic:deliver("kid_a", 1)).toBe(3)
			expect(logic:deliver("kid_a", 1)).toBe(0) -- already fed
		end)

		it("lets one kid finish alone", function()
			-- Solo must work (minPlayers = 1); sharing together is faster, not
			-- mandatory. 5 groups x 12 need / 12 carry = 5 trips.
			local logic = FeedingLogic.new({ 12, 12, 12, 12, 12 }, 12)
			logic:contribute("kid_a")

			local trips = 0
			for group = 1, 5 do
				logic:pickUp("kid_a")
				logic:deliver("kid_a", group)
				trips += 1
			end

			expect(trips).toBe(5)
			expect(logic:isEveryoneFed()).toBe(true)
		end)

		it("finishes faster when four share than when one does", function()
			local solo = FeedingLogic.new({ 48 }, 12)
			solo:contribute("a")
			local soloTrips = 0
			while not solo:isEveryoneFed() do
				solo:pickUp("a")
				solo:deliver("a", 1)
				soloTrips += 1
			end

			local four = FeedingLogic.new({ 48 }, 12)
			for _, kid in { "a", "b", "c", "d" } do
				four:contribute(kid)
			end
			four:pickUp("a")
			expect(four:deliver("a", 1)).toBe(48)

			expect(soloTrips).toBe(4)
			expect(four:isEveryoneFed()).toBe(true)
		end)

		it("counts twelve baskets left over", function()
			expect(FeedingLogic.LEFTOVER_BASKETS).toBe(12)
		end)
	end)
end
