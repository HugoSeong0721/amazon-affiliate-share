--!strict
-- The verse table is content, but content with invariants: fragment ids feed
-- ProgressData keys and card attributes, so a duplicate or a dangling reference
-- corrupts saves and cards alike.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Verses = require(ReplicatedStorage.Shared.Verses)
local Runner = require(script.Parent.Runner)

return function(env: Runner.Env)
	local describe, it, expect = env.describe, env.it, env.expect

	describe("Verses", function()
		it("gives every verse a chapter, a reference and at least two fragments", function()
			for _, verse in Verses.all() do
				expect(verse.chapterId ~= "").toBeTruthy()
				expect(verse.reference ~= "").toBeTruthy()
				expect(#verse.fragments >= 2).toBeTruthy()
			end
		end)

		it("resolves every fragment id back to its fragment", function()
			for _, verse in Verses.all() do
				for _, fragment in verse.fragments do
					local found = Verses.fragment(fragment.id)
					expect(found).toBeTruthy()
					expect((found :: any).ko).toBe(fragment.ko)
				end
			end
		end)

		it("carries three verses for the wilderness — one per temptation", function()
			local list = Verses.versesFor("ch05_wilderness")
			expect(list).toHaveLength(3)
			expect(Verses.fragmentIdsFor("ch05_wilderness")).toHaveLength(9)
		end)

		it("still carries one verse for a single-verse chapter", function()
			expect(Verses.versesFor("ch01_bethlehem")).toHaveLength(1)
			expect(Verses.fragmentIdsFor("ch01_bethlehem")).toHaveLength(3)
		end)

		it("returns nothing for a chapter without verses", function()
			expect(Verses.versesFor("ch99_nowhere")).toHaveLength(0)
			expect(Verses.fragmentIdsFor("ch99_nowhere")).toHaveLength(0)
		end)

		it("renders blanks for missing fragments and fills them in order", function()
			local none = Verses.render("ch05_bread", {}, "ko")
			expect(string.find(none, "＿＿＿", 1, true) ~= nil).toBeTruthy()

			local partial = Verses.render("ch05_bread", { ch05_bread_f1 = true }, "ko")
			expect(string.find(partial, "사람은 빵만으로는", 1, true) ~= nil).toBeTruthy()
			expect(string.find(partial, "＿＿＿", 1, true) ~= nil).toBeTruthy()

			local full = Verses.render("ch05_bread", {
				ch05_bread_f1 = true,
				ch05_bread_f2 = true,
				ch05_bread_f3 = true,
			}, "ko")
			expect(string.find(full, "＿", 1, true)).toBeNil()
		end)

		it("renders the requested locale", function()
			local en = Verses.render("ch05_test", {
				ch05_test_f1 = true,
				ch05_test_f2 = true,
				ch05_test_f3 = true,
			}, "en")
			expect(en).toBe("You must not put the Lord your God to the test.")
		end)
	end)
end
