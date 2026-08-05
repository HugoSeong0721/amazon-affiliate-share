--!strict
-- IMPORTANT (see DESIGN.md 6-1): every line here is an original kid-level
-- paraphrase, not quoted text from a copyrighted translation. Chapter and verse
-- references are not copyrightable, so we cite those exactly. If you ever want
-- to ship real translation text, get written permission first and swap these
-- strings — nothing else in the codebase needs to change.
--
-- The three fragments of a verse concatenate, in order, into one sentence. That
-- is the point: collecting them literally rebuilds the sentence in the player's
-- lamp, and the rebuilt sentence is what the wilderness chapter later asks for.

export type Fragment = {
	id: string,
	ko: string,
	en: string,
}

export type Verse = {
	id: string,
	chapterId: string,
	reference: string,
	fragments: { Fragment },
}

local VERSES: { Verse } = {
	{
		id = "ch00_verse",
		chapterId = "ch00_waiting",
		reference = "이사야 9:6",
		fragments = {
			{ id = "ch00_f1", ko = "우리에게 한 아기가 오실 거예요,", en = "A child is coming to us," },
			{ id = "ch00_f2", ko = "그 이름은 놀라우신 분,", en = "and his name is Wonderful," },
			{ id = "ch00_f3", ko = "평화를 주시는 왕이에요.", en = "the King who brings peace." },
		},
	},
	{
		id = "ch01_verse",
		chapterId = "ch01_bethlehem",
		reference = "누가복음 2:11",
		fragments = {
			{ id = "ch01_f1", ko = "오늘 다윗의 동네에", en = "Today in David's town" },
			{ id = "ch01_f2", ko = "너희를 구원하실 분이", en = "the One who saves you" },
			{ id = "ch01_f3", ko = "태어나셨어요.", en = "has been born." },
		},
	},
	{
		id = "ch06_verse",
		chapterId = "ch06_nets",
		reference = "누가복음 5:5",
		fragments = {
			{ id = "ch06_f1", ko = "밤새 아무것도 못 잡았지만,", en = "We caught nothing all night," },
			{ id = "ch06_f2", ko = "말씀하시니", en = "but because you say so," },
			{ id = "ch06_f3", ko = "그물을 내려 보겠어요.", en = "I will let down the nets." },
		},
	},
	{
		id = "ch10_verse",
		chapterId = "ch10_loaves",
		reference = "요한복음 6:9",
		fragments = {
			{ id = "ch10_f1", ko = "여기 한 아이가 있어요,", en = "Here is a child" },
			{ id = "ch10_f2", ko = "보리빵 다섯 개와", en = "with five barley loaves" },
			{ id = "ch10_f3", ko = "작은 물고기 두 마리를 가진.", en = "and two little fish." },
		},
	},
}

local byFragmentId: { [string]: { verse: Verse, fragment: Fragment, index: number } } = {}
local byVerseId: { [string]: Verse } = {}
local byChapterId: { [string]: Verse } = {}

for _, verse in VERSES do
	byVerseId[verse.id] = verse
	byChapterId[verse.chapterId] = verse
	for index, fragment in verse.fragments do
		byFragmentId[fragment.id] = { verse = verse, fragment = fragment, index = index }
	end
end

local Verses = {}

function Verses.all(): { Verse }
	return VERSES
end

function Verses.forChapter(chapterId: string): Verse?
	return byChapterId[chapterId]
end

function Verses.fragment(fragmentId: string): Fragment?
	local entry = byFragmentId[fragmentId]
	return if entry then entry.fragment else nil
end

function Verses.fragmentIdsFor(chapterId: string): { string }
	local verse = byChapterId[chapterId]
	if not verse then
		return {}
	end

	local ids = {}
	for _, fragment in verse.fragments do
		table.insert(ids, fragment.id)
	end
	return ids
end

-- Renders whatever the player has collected, leaving gaps for what they haven't.
-- The gaps are the invitation to go back and look.
function Verses.render(verseId: string, owned: { [string]: boolean }, locale: string): string
	local verse = byVerseId[verseId]
	if not verse then
		return ""
	end

	local parts = {}
	for _, fragment in verse.fragments do
		if owned[fragment.id] then
			table.insert(parts, if locale == "en" then fragment.en else fragment.ko)
		else
			table.insert(parts, "＿＿＿")
		end
	end
	return table.concat(parts, " ")
end

return Verses
