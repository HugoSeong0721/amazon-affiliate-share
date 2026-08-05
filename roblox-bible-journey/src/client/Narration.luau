--!strict
-- Narration is not decoration here — it is the primary channel, because a large
-- share of the target age group will not read a paragraph (DESIGN.md 5-5).
--
-- Roblox restricts uploaded audio longer than 6 seconds to experiences you own,
-- which is exactly this case, so full narration lines are fine. Record them,
-- upload them, and fill in the asset ids below. Until then every line still
-- reaches the player as HUD text, so the prototype is playable today.

local SoundService = game:GetService("SoundService")

-- stringKey -> rbxassetid://...
local NARRATION: { [string]: string } = {
	-- ["chapter.ch01_bethlehem.intro"] = "rbxassetid://0",
	-- ["ch01.penSheep"] = "rbxassetid://0",
}

local Narration = {}

local current: Sound? = nil

function Narration.play(stringKey: string): boolean
	local assetId = NARRATION[stringKey]
	if not assetId then
		return false
	end

	if current then
		current:Destroy()
		current = nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "Narration"
	sound.SoundId = assetId
	sound.Volume = 0.9
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
		if current == sound then
			current = nil
		end
	end)

	current = sound
	sound:Play()
	return true
end

function Narration.hasAudio(stringKey: string): boolean
	return NARRATION[stringKey] ~= nil
end

return Narration
