--!strict
-- Grid math shared by server (authoritative placement) and client (ghost preview).
-- A plot is Config.PlotSizeCells^2 cells; cell (0,0) is the plot's -X,-Z corner.
-- Item anchor = its minimum cell after rotation. Rotation r is 0..3 (r * 90 deg CCW around Y).

local Config = require(script.Parent.Config)

local GridUtil = {}

-- Footprint dimensions in cells after rotation.
function GridUtil.rotatedFootprint(w: number, d: number, r: number): (number, number)
	if r % 2 == 1 then
		return d, w
	end
	return w, d
end

function GridUtil.inBounds(x: number, z: number, w: number, d: number, r: number): boolean
	local rw, rd = GridUtil.rotatedFootprint(w, d, r)
	return x >= 0 and z >= 0 and (x + rw) <= Config.PlotSizeCells and (z + rd) <= Config.PlotSizeCells
end

-- Iterate the cell keys ("x:z") an item covers.
function GridUtil.cellKeys(x: number, z: number, w: number, d: number, r: number): { string }
	local rw, rd = GridUtil.rotatedFootprint(w, d, r)
	local keys = table.create(rw * rd)
	for cx = x, x + rw - 1 do
		for cz = z, z + rd - 1 do
			table.insert(keys, cx .. ":" .. cz)
		end
	end
	return keys
end

-- Pivot CFrame for an item model (pivot sits 0.1 studs above the plot surface,
-- matching ItemModels root part). `origin` is the plot's min corner at surface height.
function GridUtil.itemPivot(origin: Vector3, x: number, z: number, w: number, d: number, r: number): CFrame
	local rw, rd = GridUtil.rotatedFootprint(w, d, r)
	local cs = Config.CellSize
	local px = origin.X + (x + rw / 2) * cs
	local pz = origin.Z + (z + rd / 2) * cs
	return CFrame.new(px, origin.Y + 0.1, pz) * CFrame.Angles(0, math.rad(r * 90), 0)
end

-- World position -> anchor cell for an item of rotated size (rw, rd), clamped
-- so the whole footprint stays inside the plot.
function GridUtil.worldToAnchor(origin: Vector3, worldPos: Vector3, w: number, d: number, r: number): (number, number)
	local rw, rd = GridUtil.rotatedFootprint(w, d, r)
	local cs = Config.CellSize
	local x = math.floor((worldPos.X - origin.X) / cs - rw / 2 + 0.5)
	local z = math.floor((worldPos.Z - origin.Z) / cs - rd / 2 + 0.5)
	x = math.clamp(x, 0, Config.PlotSizeCells - rw)
	z = math.clamp(z, 0, Config.PlotSizeCells - rd)
	return x, z
end

return GridUtil
