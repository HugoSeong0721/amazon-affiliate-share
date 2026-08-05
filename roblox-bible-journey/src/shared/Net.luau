--!strict
-- Remote plumbing. The server creates the folder; the client waits for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "JourneyNet"

local EVENT_NAMES = {
	-- server -> client
	"ProgressChanged", -- (payload: { fragments, completedChapters, lampLevel, order })
	"ObjectiveChanged", -- (payload: { chapterId, objectives, focus: Vector3? })
	"Narrate", -- (stringKey: string)
	"ChapterEntered", -- (chapterId: string?)  nil = back in the hub
	-- client -> server
	"RequestEnterChapter", -- (chapterId: string)
	"RequestLeaveChapter", -- ()
}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Net = {}

function Net.event(name: string): RemoteEvent
	assert(table.find(EVENT_NAMES, name), `unknown remote "{name}"`)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
