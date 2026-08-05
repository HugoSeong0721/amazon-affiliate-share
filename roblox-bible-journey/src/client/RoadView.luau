--!strict
-- Draws this player's progress onto the shared hub road.
--
-- All of it is client-local: mist transparency, lamp brightness, pad colour.
-- Two kids standing on the same segment correctly see different roads, and the
-- server never has to build one hub per player.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local WALKED_FOG = 1 -- cleared
local NEXT_FOG = 0.72 -- thin enough to see something is there
local UNKNOWN_FOG = 0.3 -- still a wall of mist

local RoadView = {}

local segmentsFolder: Folder? = nil
local lastSnapshot: { [string]: any }? = nil

local function tween(instance: Instance, goal: { [string]: any })
	TweenService:Create(instance, FADE, goal):Play()
end

local function applySegment(segment: Instance, state: "walked" | "next" | "unknown")
	local fog = segment:FindFirstChild("Fog")
	local lamp = segment:FindFirstChild("Lamp")
	local pad = segment:FindFirstChild("Pad")

	if fog and fog:IsA("BasePart") then
		local target = if state == "walked" then WALKED_FOG elseif state == "next" then NEXT_FOG else UNKNOWN_FOG
		tween(fog, { Transparency = target })
	end

	if lamp and lamp:IsA("BasePart") then
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			tween(light, { Brightness = if state == "walked" then 2.5 else 0 })
		end
		tween(lamp, { Transparency = if state == "walked" then 0 else 0.75 })
	end

	if pad and pad:IsA("BasePart") then
		local colour = if state == "unknown"
			then Color3.fromRGB(120, 120, 128)
			else Color3.fromRGB(236, 214, 160)
		tween(pad, { Color = colour })
	end
end

function RoadView.apply(snapshot: { [string]: any })
	lastSnapshot = snapshot

	local folder = segmentsFolder
	if not folder then
		return
	end

	local order = snapshot.order :: { string }
	local completed = snapshot.completedChapters :: { [string]: any }

	-- Exactly one segment is "next": the first one not yet walked. That is the one
	-- the mist thins over, and the only forward hint the hub gives.
	local nextIndex: number? = nil
	for index, chapterId in order do
		if completed[chapterId] == nil then
			nextIndex = index
			break
		end
	end

	for index, chapterId in order do
		local segment = folder:FindFirstChild(chapterId)
		if not segment then
			continue
		end

		local state: "walked" | "next" | "unknown"
		if completed[chapterId] ~= nil then
			state = "walked"
		elseif index == nextIndex then
			state = "next"
		else
			state = "unknown"
		end

		applySegment(segment, state)
	end
end

function RoadView.start()
	task.spawn(function()
		local hub = Workspace:WaitForChild("Hub", 30)
		if not hub then
			warn("[RoadView] no Hub in Workspace")
			return
		end

		local folder = hub:WaitForChild("Segments", 30)
		if not folder then
			return
		end
		segmentsFolder = folder :: Folder

		-- StreamingEnabled can deliver segments after the first snapshot arrives.
		folder.ChildAdded:Connect(function()
			if lastSnapshot then
				RoadView.apply(lastSnapshot)
			end
		end)

		if lastSnapshot then
			RoadView.apply(lastSnapshot)
		end
	end)
end

return RoadView
