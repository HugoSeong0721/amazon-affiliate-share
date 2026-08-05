--!strict
-- Greybox helpers. Everything here is a coloured block on purpose: the point of
-- P0 is to find out where kids get bored, and art makes that measurement more
-- expensive to change.

local Players = game:GetService("Players")

local Build = {}

function Build.part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

function Build.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A soft glow marker. Used for lamps, stars and verse fragments — anything the
-- player is meant to walk toward without being told to in words.
function Build.glow(props: { [string]: any }, brightness: number, range: number): Part
	local part = Build.part(props)

	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = part.Color
	light.Parent = part

	return part
end

function Build.playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

-- Touched fires many times per step per limb. Every gameplay trigger needs this.
function Build.debouncePerPlayer(cooldown: number): (Player) -> boolean
	local last: { [Player]: number } = {}
	return function(player: Player): boolean
		local now = os.clock()
		if last[player] and now - last[player] < cooldown then
			return false
		end
		last[player] = now
		return true
	end
end

function Build.insideBox(point: Vector3, center: Vector3, size: Vector3): boolean
	local half = size / 2
	local delta = point - center
	return math.abs(delta.X) <= half.X and math.abs(delta.Y) <= half.Y and math.abs(delta.Z) <= half.Z
end

return Build
