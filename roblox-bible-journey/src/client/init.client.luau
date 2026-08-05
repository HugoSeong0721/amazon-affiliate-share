--!strict
-- The client only draws. Every progress decision was already made on the server;
-- nothing here can unlock a chapter or award a fragment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Beacon = require(script.Beacon)
local CardView = require(script.CardView)
local Narration = require(script.Narration)
local ObjectiveHud = require(script.ObjectiveHud)
local RoadView = require(script.RoadView)

ObjectiveHud.start()
RoadView.start()
Beacon.start()
CardView.start()

Net.event("ProgressChanged").OnClientEvent:Connect(function(snapshot)
	if typeof(snapshot) ~= "table" then
		return
	end

	if typeof(snapshot.locale) == "string" then
		ObjectiveHud.setLocale(snapshot.locale)
	end
	ObjectiveHud.setProgress(snapshot)
	RoadView.apply(snapshot)
	if typeof(snapshot.fragments) == "table" then
		CardView.setState(snapshot.fragments, if typeof(snapshot.locale) == "string" then snapshot.locale else "ko")
	end
end)

Net.event("ChapterEntered").OnClientEvent:Connect(function(chapterId)
	ObjectiveHud.setChapter(if typeof(chapterId) == "string" then chapterId else nil)
	if chapterId == nil then
		Beacon.setTarget(nil)
	end
end)

Net.event("ObjectiveChanged").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	Beacon.setTarget(if typeof(payload.focus) == "Vector3" then payload.focus else nil)
end)

Net.event("Narrate").OnClientEvent:Connect(function(stringKey)
	if typeof(stringKey) ~= "string" then
		return
	end
	-- Audio and text are not alternatives: the text line always shows, and the
	-- voice plays on top of it when it has been recorded.
	Narration.play(stringKey)
	ObjectiveHud.say(stringKey)
end)

ObjectiveHud.setChapter(nil)
