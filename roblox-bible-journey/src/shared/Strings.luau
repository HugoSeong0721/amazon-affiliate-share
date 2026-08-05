--!strict
-- No hardcoded UI text anywhere else in the codebase (DESIGN.md 5-6).
-- Keep every line short enough to read in two lines on a phone (DESIGN.md 5-5) —
-- the narration audio carries the rest.

type Entry = { ko: string, en: string }

local STRINGS: { [string]: Entry } = {
	["hub.welcome"] = {
		ko = "길이 앞에 있어요. 걸어가 볼까요?",
		en = "The road is ahead. Shall we walk?",
	},
	["hub.locked"] = {
		ko = "아직 안개가 걷히지 않았어요.",
		en = "The mist hasn't lifted yet.",
	},
	["hub.needsFriends"] = {
		ko = "여기는 친구가 더 있어야 열려요.",
		en = "This one needs more friends with you.",
	},
	["hub.lampBrighter"] = {
		ko = "등불이 더 밝아졌어요!",
		en = "Your lamp is brighter!",
	},
	["hub.fragmentFound"] = {
		ko = "말씀 조각을 찾았어요!",
		en = "You found a piece of the verse!",
	},
	["hub.fragmentAlready"] = {
		ko = "이미 가진 조각이에요.",
		en = "You already have this piece.",
	},
	["chapter.complete"] = {
		ko = "여기까지 잘 왔어요. 길이 조금 더 열렸어요.",
		en = "You made it. The road opened a little more.",
	},
	["chapter.returning"] = {
		ko = "잠시 뒤에 길로 돌아가요.",
		en = "Heading back to the road shortly.",
	},

	["chapter.ch00_waiting.title"] = { ko = "기다림", en = "The Waiting" },
	["chapter.ch00_waiting.intro"] = {
		ko = "아주 오래전부터, 사람들은 한 분을 기다렸어요.",
		en = "For a very long time, people waited for someone.",
	},
	["ch00.walk"] = { ko = "첫 번째 등불까지 걸어가 보세요.", en = "Walk to the first lamp." },
	["ch00.jump"] = { ko = "점프해서 건너가 보세요.", en = "Jump across." },
	["ch00.touch"] = { ko = "빛나는 두루마리를 만져 보세요.", en = "Touch the glowing scroll." },

	["chapter.ch01_bethlehem.title"] = { ko = "베들레헴의 밤", en = "The Night in Bethlehem" },
	["chapter.ch01_bethlehem.intro"] = {
		ko = "밤이에요. 양들이 흩어졌고, 하늘에 큰 별이 떴어요.",
		en = "It's night. The sheep have scattered, and a great star is out.",
	},
	["ch01.findStable"] = {
		ko = "별이 가리키는 곳으로 가 보세요.",
		en = "Go where the star is pointing.",
	},
	["ch01.penSheep"] = {
		ko = "양들을 우리로 몰아 주세요. 뛰면 더 멀리 도망가요.",
		en = "Guide the sheep into the pen. Running makes them flee farther.",
	},
	["ch01.sheepLeft"] = { ko = "아직 남은 양이 있어요.", en = "Some sheep are still out there." },
	["ch01.allPenned"] = { ko = "모두 안전해요. 잘했어요!", en = "All safe. Well done!" },
}

local Strings = {}

Strings.SUPPORTED = { "ko", "en" }
Strings.DEFAULT = "ko"

function Strings.get(key: string, locale: string?): string
	local entry = STRINGS[key]
	if not entry then
		-- Loud in Studio, harmless in production: better a visible key than silence.
		warn(`[Strings] missing key "{key}"`)
		return key
	end

	if locale == "en" then
		return entry.en
	end
	return entry.ko
end

function Strings.has(key: string): boolean
	return STRINGS[key] ~= nil
end

function Strings.chapterTitle(chapterId: string, locale: string?): string
	return Strings.get(`chapter.{chapterId}.title`, locale)
end

return Strings
