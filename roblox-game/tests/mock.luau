-- Headless stand-in for the Roblox engine.
-- Enough of the API surface for the game scripts to actually run outside
-- Studio, so runtime mistakes surface in CI instead of in a playtest.

local mock = {}

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self.handlers, handler)
	return { Disconnect = function() end, Connected = true }
end

Signal.Once = Signal.Connect

function Signal:Wait()
	return nil
end

function Signal:Fire(...)
	for _, handler in ipairs(self.handlers) do
		mock.spawn(handler, ...)
	end
end

mock.Signal = Signal

----------------------------------------------------------------------
-- Math types
----------------------------------------------------------------------

local Vector3 = {}
Vector3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(Vector3, key)
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
Vector3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3.__tostring = function(v)
	return string.format("Vector3(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)

local function cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end

local Vector2 = {}
Vector2.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2)
	end
	return rawget(Vector2, key)
end
Vector2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
Vector2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
Vector2.__mul = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
Vector2.__div = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end

-- CFrame stored as position + 3x3 rotation (row-major basis vectors).
local CFrame = {}
CFrame.__index = function(self, key)
	if key == "Position" or key == "p" then
		return rawget(self, "_pos")
	elseif key == "X" then
		return rawget(self, "_pos").X
	elseif key == "Y" then
		return rawget(self, "_pos").Y
	elseif key == "Z" then
		return rawget(self, "_pos").Z
	elseif key == "RightVector" then
		return rawget(self, "_r")
	elseif key == "UpVector" then
		return rawget(self, "_u")
	elseif key == "LookVector" then
		return -rawget(self, "_b")
	end
	return rawget(CFrame, key)
end

local function newCFrame(pos, right, up, back)
	return setmetatable({ _pos = pos, _r = right, _u = up, _b = back }, CFrame)
end

function CFrame.new(x, y, z)
	local pos
	if type(x) == "table" then
		pos = x
	else
		pos = Vector3.new(x or 0, y or 0, z or 0)
	end
	return newCFrame(pos, Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
end

function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	-- R = Rx * Ry * Rz, columns are the basis vectors
	local right = Vector3.new(cy * cz, cx * sz + sx * sy * cz, sx * sz - cx * sy * cz)
	local up = Vector3.new(-cy * sz, cx * cz - sx * sy * sz, sx * cz + cx * sy * sz)
	local back = Vector3.new(sy, -sx * cy, cx * cy)
	return newCFrame(Vector3.new(0, 0, 0), right, up, back)
end

function CFrame.lookAt(from, to, up)
	up = up or Vector3.new(0, 1, 0)
	local direction = to - from
	if direction.Magnitude < 1e-6 then
		direction = Vector3.new(0, 0, -1)
	end
	local back = (-direction).Unit
	local right = cross(up, back)
	if right.Magnitude < 1e-6 then
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	local trueUp = cross(back, right)
	return newCFrame(from, right, trueUp, back)
end

CFrame.__mul = function(a, b)
	local ar, au, ab, ap = rawget(a, "_r"), rawget(a, "_u"), rawget(a, "_b"), rawget(a, "_pos")
	local function rotate(v)
		return Vector3.new(
			ar.X * v.X + au.X * v.Y + ab.X * v.Z,
			ar.Y * v.X + au.Y * v.Y + ab.Y * v.Z,
			ar.Z * v.X + au.Z * v.Y + ab.Z * v.Z
		)
	end
	if getmetatable(b) == Vector3 then
		return ap + rotate(b)
	end
	local br, bu, bb, bp = rawget(b, "_r"), rawget(b, "_u"), rawget(b, "_b"), rawget(b, "_pos")
	return newCFrame(ap + rotate(bp), rotate(br), rotate(bu), rotate(bb))
end

CFrame.__tostring = function(self)
	return "CFrame@" .. tostring(rawget(self, "_pos"))
end

local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then return Color3.new(v, t, p) end
	if m == 1 then return Color3.new(q, v, p) end
	if m == 2 then return Color3.new(p, v, t) end
	if m == 3 then return Color3.new(p, q, v) end
	if m == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end
Color3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

local UDim = {}
UDim.__index = UDim
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim)
end

local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

local NumberRange = {}
NumberRange.__index = NumberRange
function NumberRange.new(min, max)
	return setmetatable({ Min = min, Max = max or min }, NumberRange)
end

local NumberSequence = {}
NumberSequence.__index = NumberSequence
function NumberSequence.new(a, b)
	return setmetatable({ a = a, b = b }, NumberSequence)
end

local ColorSequence = {}
ColorSequence.__index = ColorSequence
function ColorSequence.new(a, b)
	return setmetatable({ a = a, b = b }, ColorSequence)
end

local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = (seed or 1) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, Random)
end
function Random:NextNumber(min, max)
	self.state = (self.state * 16807) % 2147483647
	local unit = self.state / 2147483647
	if min == nil then
		return unit
	end
	return min + unit * (max - min)
end
function Random:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1 - 1e-9))
end

mock.Vector3 = Vector3
mock.Vector2 = Vector2
mock.CFrame = CFrame
mock.Color3 = Color3
mock.UDim = UDim
mock.UDim2 = UDim2
mock.NumberRange = NumberRange
mock.NumberSequence = NumberSequence
mock.ColorSequence = ColorSequence
mock.Random = Random

----------------------------------------------------------------------
-- Enum: every member auto-exists and compares by identity
----------------------------------------------------------------------

local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		if not enumCache[enumName] then
			local members = {}
			enumCache[enumName] = setmetatable({}, {
				__index = function(_, memberName)
					if not members[memberName] then
						members[memberName] = setmetatable({
							Name = memberName,
							Value = memberName,
							EnumType = enumName,
						}, {
							__tostring = function()
								return `Enum.{enumName}.{memberName}`
							end,
						})
					end
					return members[memberName]
				end,
			})
		end
		return enumCache[enumName]
	end,
})
mock.Enum = Enum

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------

local CLASS_PARENT = {
	Part = "BasePart",
	SpawnLocation = "BasePart",
	MeshPart = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	PVInstance = "Instance",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	ImageLabel = "GuiObject",
	ScrollingFrame = "GuiObject",
	GuiObject = "GuiBase2d",
	GuiBase2d = "Instance",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	LayerCollector = "Instance",
	Shirt = "Clothing",
	Pants = "Clothing",
	Clothing = "Instance",
	Accessory = "Instance",
	Humanoid = "Instance",
	Sound = "Instance",
	RemoteEvent = "Instance",
	RemoteFunction = "Instance",
}

local instanceMethods = {}
local Instance_mt = {}

local function isA(self, className)
	local current = rawget(self, "_props").ClassName
	while current do
		if current == className then
			return true
		end
		current = CLASS_PARENT[current]
	end
	return className == "Instance"
end

local created = {}

local DEFAULT_SIGNALS = {
	TextButton = { "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "Activated", "MouseEnter", "MouseLeave" },
	ImageButton = { "MouseButton1Click", "Activated" },
	ProximityPrompt = { "Triggered", "PromptShown", "PromptHidden" },
	RemoteEvent = { "OnClientEvent", "OnServerEvent" },
	Player = { "CharacterAdded", "CharacterRemoving", "Idled" },
	Humanoid = { "Died", "StateChanged" },
	Part = { "Touched", "TouchEnded" },
	Tool = { "Activated" },
}

local function newInstance(className)
	local self = setmetatable({}, Instance_mt)
	rawset(self, "_props", { Name = className, ClassName = className })
	rawset(self, "_children", {})
	rawset(self, "_attrs", {})
	rawset(self, "_signals", {})
	if className == "Part" or className == "SpawnLocation" or className == "MeshPart" or className == "Model" then
		local props = rawget(self, "_props")
		props.CFrame = CFrame.new(0, 0, 0)
		props.Position = Vector3.new(0, 0, 0)
		props.Size = Vector3.new(4, 1, 2)
		props.Transparency = 0
		props.Anchored = false
	end
	for _, signalName in ipairs(DEFAULT_SIGNALS[className] or {}) do
		local signal = Signal.new()
		rawget(self, "_props")[signalName] = signal
		rawget(self, "_signals")[signalName] = signal
	end
	created[className] = (created[className] or 0) + 1
	return self
end

Instance_mt.__index = function(self, key)
	local method = instanceMethods[key]
	if method then
		return method
	end
	local props = rawget(self, "_props")
	if props[key] ~= nil then
		return props[key]
	end
	-- Roblox exposes children as properties
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == key then
			return child
		end
	end
	local signals = rawget(self, "_signals")
	if key == "Changed" or key:match("^%u") and signals[key] then
		return signals[key]
	end
	return nil
end

Instance_mt.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			local siblings = rawget(old, "_children")
			for index, child in ipairs(siblings) do
				if child == self then
					table.remove(siblings, index)
					break
				end
			end
		end
		props.Parent = value
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	props[key] = value
	if key == "Position" and props.CFrame ~= nil then
		props.CFrame = CFrame.new(value)
	elseif key == "CFrame" and value ~= nil then
		props.Position = rawget(value, "_pos")
	end
end

Instance_mt.__tostring = function(self)
	return rawget(self, "_props").Name
end

function instanceMethods.IsA(self, className)
	return isA(self, className)
end

function instanceMethods.GetChildren(self)
	local copy = {}
	for index, child in ipairs(rawget(self, "_children")) do
		copy[index] = child
	end
	return copy
end

function instanceMethods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in ipairs(rawget(node, "_children")) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function instanceMethods.FindFirstChild(self, name)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == name then
			return child
		end
	end
	return nil
end

function instanceMethods.FindFirstChildOfClass(self, className)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").ClassName == className then
			return child
		end
	end
	return nil
end

function instanceMethods.FindFirstChildWhichIsA(self, className)
	for _, child in ipairs(rawget(self, "_children")) do
		if isA(child, className) then
			return child
		end
	end
	return nil
end

function instanceMethods.WaitForChild(self, name)
	local found = instanceMethods.FindFirstChild(self, name)
	if not found then
		error(`WaitForChild timed out waiting for "{name}" under "{rawget(self, "_props").Name}"`, 0)
	end
	return found
end

function instanceMethods.Destroy(self)
	local props = rawget(self, "_props")
	if props.Parent then
		local siblings = rawget(props.Parent, "_children")
		for index, child in ipairs(siblings) do
			if child == self then
				table.remove(siblings, index)
				break
			end
		end
	end
	props.Parent = nil
	rawset(self, "_children", {})
end

function instanceMethods.ClearAllChildren(self)
	rawset(self, "_children", {})
end

function instanceMethods.Clone(self)
	local copy = newInstance(rawget(self, "_props").ClassName)
	for key, value in pairs(rawget(self, "_props")) do
		if key ~= "Parent" then
			rawget(copy, "_props")[key] = value
		end
	end
	for key, value in pairs(rawget(self, "_attrs")) do
		rawget(copy, "_attrs")[key] = value
	end
	for _, child in ipairs(rawget(self, "_children")) do
		local childCopy = instanceMethods.Clone(child)
		childCopy.Parent = copy
	end
	return copy
end

function instanceMethods.SetAttribute(self, key, value)
	rawget(self, "_attrs")[key] = value
end

function instanceMethods.GetAttribute(self, key)
	return rawget(self, "_attrs")[key]
end

function instanceMethods.GetAttributes(self)
	return rawget(self, "_attrs")
end

function instanceMethods.GetPropertyChangedSignal(self)
	local signals = rawget(self, "_signals")
	signals.__changed = signals.__changed or Signal.new()
	return signals.__changed
end

function instanceMethods.PivotTo(self, cframe)
	rawget(self, "_props").CFrame = cframe
end

function instanceMethods.GetPivot(self)
	return rawget(self, "_props").CFrame or CFrame.new(0, 0, 0)
end

-- Humanoid / character helpers
function instanceMethods.GetAppliedDescription(self)
	local description = rawget(self, "_description")
	if not description then
		description = newInstance("HumanoidDescription")
		rawset(self, "_description", description)
	end
	return description
end

function instanceMethods.ApplyDescription(self, description)
	rawset(self, "_description", description)
	local counters = mock.counters
	counters.applyDescription += 1
end

function instanceMethods.PlayEmote(self, emoteName)
	mock.counters.emotes += 1
	return true
end

function instanceMethods.LoadAnimation(self)
	local track = newInstance("AnimationTrack")
	rawget(track, "_props").Looped = false
	rawget(track, "_props").Play = function() end
	rawget(track, "_props").Stop = function() end
	return track
end

local function overridable(name)
	return function(self, ...)
		local custom = rawget(self, "_props")[name]
		if type(custom) == "function" then
			return custom(self, ...)
		end
		return nil
	end
end

instanceMethods.Play = overridable("Play")
instanceMethods.Stop = overridable("Stop")
instanceMethods.Pause = overridable("Pause")
instanceMethods.Resume = overridable("Resume")

function instanceMethods.Emit(self, count)
	mock.counters.particles += (count or 1)
end

function instanceMethods.Move(self) end
function instanceMethods.AddAccessory(self, accessory)
	accessory.Parent = rawget(self, "_props").Parent
end

-- Remotes
function instanceMethods.FireClient(self, player, ...)
	mock.counters.fireClient += 1
	local signal = rawget(self, "_signals")
	signal.OnClientEvent = signal.OnClientEvent or Signal.new()
	if player == mock.localPlayer then
		signal.OnClientEvent:Fire(...)
	end
end

function instanceMethods.FireAllClients(self, ...)
	mock.counters.fireAllClients += 1
	local signal = rawget(self, "_signals")
	signal.OnClientEvent = signal.OnClientEvent or Signal.new()
	signal.OnClientEvent:Fire(...)
end

function instanceMethods.FireServer(self, ...)
	local signal = rawget(self, "_signals")
	if signal.OnServerEvent then
		signal.OnServerEvent:Fire(mock.localPlayer, ...)
	end
end

function instanceMethods.InvokeServer(self, ...)
	local handler = rawget(self, "_props").OnServerInvoke
	if not handler then
		error(`InvokeServer on "{rawget(self, "_props").Name}" with no server handler`, 0)
	end
	return handler(mock.localPlayer, ...)
end

mock.newInstance = newInstance
mock.created = created

----------------------------------------------------------------------
-- Scheduler: coroutines run, waits park them, the runner pumps a few rounds
----------------------------------------------------------------------

local parked = {}

local task = {}

function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(err, 0)
	end
	if coroutine.status(co) == "suspended" then
		table.insert(parked, co)
	end
	return co
end

function task.defer(fn, ...)
	return task.spawn(fn, ...)
end

function task.delay(seconds, fn, ...)
	local args = table.pack(...)
	return task.spawn(function()
		task.wait(seconds)
		fn(table.unpack(args, 1, args.n))
	end)
end

function task.wait(_)
	if coroutine.isyieldable() then
		coroutine.yield()
	end
	return 0
end

mock.task = task
mock.spawn = task.spawn

function mock.pump(rounds)
	for _ = 1, rounds or 3 do
		local batch = parked
		parked = {}
		for _, co in ipairs(batch) do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					error(err, 0)
				end
				if coroutine.status(co) == "suspended" then
					table.insert(parked, co)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------

mock.counters = {
	applyDescription = 0,
	emotes = 0,
	fireClient = 0,
	fireAllClients = 0,
	dataStoreWrites = 0,
	particles = 0,
}

local services = {}

local function service(className, name)
	local instance = newInstance(className)
	rawget(instance, "_props").Name = name or className
	services[name or className] = instance
	return instance
end

local workspace = service("Workspace", "Workspace")
local players = service("Players", "Players")
local replicatedStorage = service("ReplicatedStorage", "ReplicatedStorage")
local serverStorage = service("ServerStorage", "ServerStorage")
local lighting = service("Lighting", "Lighting")
local soundService = service("SoundService", "SoundService")
local starterGui = service("StarterGui", "StarterGui")

workspace.CurrentCamera = newInstance("Camera")
workspace.CurrentCamera.CFrame = CFrame.new(0, 0, 0)
rawget(workspace, "_props").Gravity = 196
rawget(workspace, "_props").Raycast = function(_, origin, direction)
	return {
		Position = origin + direction * 0.05,
		Normal = Vector3.new(0, 1, 0),
		Instance = (function()
			local hit = newInstance("Part")
			rawget(hit, "_props").Anchored = true
			return hit
		end)(),
	}
end
rawget(workspace.CurrentCamera, "_props").ViewportPointToRay = function(_, x, y)
	return { Origin = Vector3.new(0, 5, 0), Direction = Vector3.new(0, 0, -1) }
end

-- TweenService
local tweenService = service("TweenService", "TweenService")
rawget(tweenService, "_props").Create = function(_, instance, info, goals)
	local tween = newInstance("Tween")
	rawget(tween, "_props").Play = function()
		for key, value in pairs(goals) do
			instance[key] = value
		end
	end
	rawget(tween, "_props").Completed = Signal.new()
	return tween
end

-- CollectionService
local collection = service("CollectionService", "CollectionService")
local tagged = {}
rawget(collection, "_props").AddTag = function(_, instance, tag)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], instance)
end
rawget(collection, "_props").GetTagged = function(_, tag)
	local list = {}
	for index, instance in ipairs(tagged[tag] or {}) do
		list[index] = instance
	end
	return list
end
rawget(collection, "_props").HasTag = function(_, instance, tag)
	for _, candidate in ipairs(tagged[tag] or {}) do
		if candidate == instance then
			return true
		end
	end
	return false
end

-- DataStoreService (in-memory)
local dataStoreService = service("DataStoreService", "DataStoreService")
local stores = {}
rawget(dataStoreService, "_props").GetDataStore = function(_, name)
	if stores[name] then
		return stores[name]
	end
	local values = {}
	local store = newInstance("GlobalDataStore")
	rawget(store, "_props").GetAsync = function(_, key)
		return values[key]
	end
	rawget(store, "_props").SetAsync = function(_, key, value)
		values[key] = value
		mock.counters.dataStoreWrites += 1
	end
	rawget(store, "_props").UpdateAsync = function(_, key, transform)
		values[key] = transform(values[key])
		mock.counters.dataStoreWrites += 1
		return values[key]
	end
	stores[name] = store
	return store
end

-- MarketplaceService: pretend catalog ids map to plausible asset types
local marketplace = service("MarketplaceService", "MarketplaceService")
mock.assetTypeById = {}
rawget(marketplace, "_props").GetProductInfo = function(_, assetId)
	return { AssetTypeId = mock.assetTypeById[assetId] or 41, Name = `Asset {assetId}` }
end

-- RunService
local runService = service("RunService", "RunService")
rawget(runService, "_props").IsStudio = function()
	return false
end
rawget(runService, "_props").IsServer = function()
	return true
end
rawget(runService, "_props").Heartbeat = Signal.new()
rawget(runService, "_props").RenderStepped = Signal.new()

-- AvatarEditorService: a small fake catalog
local avatarEditor = service("AvatarEditorService", "AvatarEditorService")
rawget(avatarEditor, "_props").SearchCatalog = function()
	local page = {}
    for index = 1, 12 do
		table.insert(page, { Id = 1000 + index, Name = `Item {index}`, ItemType = "Asset" })
	end
	local pages = newInstance("CatalogPages")
	rawget(pages, "_props").GetCurrentPage = function()
		return page
	end
	return pages
end

-- CaptureService / UserInputService / others the client touches
local capture = service("CaptureService", "CaptureService")
rawget(capture, "_props").CaptureScreenshot = function(_, callback)
	callback("rbxtemp://1")
end
rawget(capture, "_props").PromptSaveCapturesToGallery = function(_, _, callback)
	if callback then
		callback(true)
	end
end

local userInput = service("UserInputService", "UserInputService")
rawget(userInput, "_props").InputBegan = Signal.new()
rawget(userInput, "_props").TouchEnabled = false

service("InsertService", "InsertService")
service("Chat", "Chat")
service("TextChatService", "TextChatService")

mock.services = services
mock.workspace = workspace
mock.players = players
mock.replicatedStorage = replicatedStorage
mock.lighting = lighting

----------------------------------------------------------------------
-- Players
----------------------------------------------------------------------

rawget(players, "_props").PlayerAdded = Signal.new()
rawget(players, "_props").PlayerRemoving = Signal.new()
rawget(players, "_props").CharacterAutoLoads = true

local playerList = {}

rawget(players, "_props").GetPlayers = function()
	local copy = {}
	for index, player in ipairs(playerList) do
		copy[index] = player
	end
	return copy
end

rawget(players, "_props").GetPlayerByUserId = function(_, userId)
	for _, player in ipairs(playerList) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

function mock.makeCharacter(name, position)
	local character = newInstance("Model")
	character.Name = name

	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(position or Vector3.new(0, 5, 0))
	root.Position = position or Vector3.new(0, 5, 0)
	root.Parent = character

	local head = newInstance("Part")
	head.Name = "Head"
	head.Position = position or Vector3.new(0, 6, 0)
	head.Parent = character

	local hand = newInstance("Part")
	hand.Name = "RightHand"
	hand.CFrame = CFrame.new(position or Vector3.new(1, 5, 0))
	hand.Parent = character

	local humanoid = newInstance("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.JumpHeight = 7.2
	humanoid.HipHeight = 2
	humanoid.Parent = character

	local animator = newInstance("Animator")
	animator.Name = "Animator"
	animator.Parent = humanoid

	return character
end

function mock.addPlayer(name, userId, position)
	local player = newInstance("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	rawget(player, "_signals").CharacterAdded = Signal.new()
	rawget(player, "_props").CharacterAdded = rawget(player, "_signals").CharacterAdded

	local playerGui = newInstance("PlayerGui")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player

	player.Character = mock.makeCharacter(name, position)
	table.insert(playerList, player)
	rawget(players, "_props").PlayerAdded:Fire(player)
	return player
end

function mock.removePlayer(player)
	for index, candidate in ipairs(playerList) do
		if candidate == player then
			table.remove(playerList, index)
			break
		end
	end
	rawget(players, "_props").PlayerRemoving:Fire(player)
end

----------------------------------------------------------------------
-- game
----------------------------------------------------------------------

local game = newInstance("DataModel")
rawget(game, "_props").GetService = function(_, name)
	local existing = services[name]
	if not existing then
		existing = service(name, name)
	end
	return existing
end
rawget(game, "_props").BindToClose = function() end
rawget(game, "_props").PlaceId = 138149314456752
mock.game = game

for _, instance in pairs(services) do
	rawget(instance, "_props").Parent = game
end

----------------------------------------------------------------------
-- Globals installed into the sandbox
----------------------------------------------------------------------

function mock.globals()
	return {
		game = game,
		workspace = workspace,
		Instance = { new = newInstance },
		Enum = Enum,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		UDim = UDim,
		UDim2 = UDim2,
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		ColorSequence = ColorSequence,
		Random = Random,
		task = task,
		TweenInfo = {
			new = function(...)
				return { args = { ... } }
			end,
		},
		CatalogSearchParams = {
			new = function()
				return newInstance("CatalogSearchParams")
			end,
		},
		RaycastParams = {
			new = function()
				return newInstance("RaycastParams")
			end,
		},
		typeof = function(value)
			local meta = getmetatable(value)
			if meta == Vector3 then
				return "Vector3"
			elseif meta == CFrame then
				return "CFrame"
			elseif meta == Color3 then
				return "Color3"
			elseif type(value) == "table" and rawget(value, "_props") then
				return "Instance"
			end
			return type(value)
		end,
	}
end

return mock
