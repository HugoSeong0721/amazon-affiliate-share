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

	["chapter.ch05_wilderness.title"] = { ko = "광야의 시험", en = "The Wilderness" },
	["chapter.ch05_wilderness.intro"] = {
		ko = "메마른 광야예요. 여기서 사십 일을 보내셨어요.",
		en = "A dry wilderness. Forty days were spent here.",
	},
	["ch05.walkPath"] = {
		ko = "길을 따라가며 말씀 조각을 모으세요. 곧 필요해져요.",
		en = "Gather the verse pieces along the path. You'll need them soon.",
	},
	["ch05.trial_bread"] = {
		ko = "\"배고프지? 이 돌들한테 빵이 되라고 해 봐.\"",
		en = "\"Hungry? Tell these stones to become bread.\"",
	},
	["ch05.trial_leap"] = {
		ko = "\"여기서 뛰어내려 봐. 천사들이 받아 줄 거야.\"",
		en = "\"Jump from here. The angels will catch you.\"",
	},
	["ch05.trial_worship"] = {
		ko = "\"나한테 절하면, 이 모든 걸 다 줄게.\"",
		en = "\"Bow to me, and I will give you everything.\"",
	},
	["ch05.chooseCard"] = {
		ko = "말씀 카드를 골라 대답하세요.",
		en = "Answer by choosing a verse card.",
	},
	["ch05.wrong"] = {
		ko = "음... 다시 생각해 볼까요?",
		en = "Hmm... want to think again?",
	},
	["ch05.hint"] = {
		ko = "길에서 모은 말씀을 떠올려 보세요.",
		en = "Remember the words you gathered on the path.",
	},
	["ch05.reveal"] = {
		ko = "빛이 한 카드를 가리켜요.",
		en = "The light is pointing at one card.",
	},
	["ch05.correct"] = {
		ko = "어두운 목소리가 물러갔어요!",
		en = "The dark voice backs away!",
	},

	["chapter.ch06_nets.title"] = { ko = "그물을 던져라", en = "Let Down the Nets" },
	["chapter.ch06_nets.intro"] = {
		ko = "밤새 고기를 잡았지만, 그물은 텅 비어 있었어요.",
		en = "They fished all night, and the nets came up empty.",
	},
	["ch06.castShallow"] = {
		ko = "부두 끝에서 그물을 던져 보세요.",
		en = "Cast the net from the end of the pier.",
	},
	["ch06.emptyNet"] = {
		ko = "이번에도... 아무것도 없어요.",
		en = "Again... nothing.",
	},
	["ch06.goDeeper"] = {
		ko = "\"깊은 곳으로 가서 그물을 내려라.\" 목소리가 들려요.",
		en = "\"Go out into the deep, and let down the nets.\" A voice.",
	},
	["ch06.fullNet"] = {
		ko = "그물이 찢어질 만큼 가득해요!",
		en = "The net is so full it's starting to tear!",
	},

	["chapter.ch10_loaves.title"] = { ko = "오병이어", en = "Five Loaves, Two Fish" },
	["chapter.ch10_loaves.intro"] = {
		ko = "배고픈 사람이 아주 많아요. 그런데 먹을 것이 없어요.",
		en = "So many hungry people. And no food anywhere.",
	},
	["ch10.shareLunch"] = {
		ko = "가진 도시락을 바구니에 넣어 보세요.",
		en = "Put your lunch in the basket.",
	},
	["ch10.shared"] = {
		ko = "도시락을 내놓았어요. 그런데... 바구니가 가득해요!",
		en = "You gave your lunch away. And... the basket is full!",
	},
	["ch10.basketWaits"] = {
		ko = "바구니가 비어 있어요. 누가 먼저 나눌까요?",
		en = "The basket is empty. Who will share first?",
	},
	["ch10.pickedUp"] = {
		ko = "빵을 들었어요! 배고픈 사람들에게 가져다 주세요.",
		en = "You're carrying bread! Take it to the hungry.",
	},
	["ch10.handsFull"] = {
		ko = "손이 가득해요. 먼저 나눠 주고 오세요.",
		en = "Your hands are full. Share this first.",
	},
	["ch10.needBread"] = {
		ko = "바구니에서 빵을 받아 오세요.",
		en = "Get bread from the basket first.",
	},
	["ch10.groupFed"] = {
		ko = "이쪽 사람들은 배불러요!",
		en = "These people are full!",
	},
	["ch10.leftovers"] = {
		ko = "모두 먹고도 열두 바구니가 남았어요!",
		en = "Everyone ate — and twelve baskets are left over!",
	},
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
