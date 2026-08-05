-- Minimal Roblox API mock, enough to load and exercise the server modules
-- outside Roblox. Assembled ahead of the game sources by tests/run.py, which
-- also rewrites Roblox-style `require(Shared.X)` calls into `req("X")`.
--
-- Only what the game actually touches is mocked, so a module reaching for a
-- new API fails loudly here rather than silently passing.

-- // fake clock (rate limits and daily bonus are time based) --------------

local NOW = { clock = 1000.0, time = 1700000000 }
local os = {
	clock = function()
		return NOW.clock
	end,
	time = function()
		return NOW.time
	end,
	date = function()
		return "mock"
	end,
}
local function advance(seconds: number)
	NOW.clock += seconds
	NOW.time += math.floor(seconds)
end

-- // logging -------------------------------------------------------------

local LOG = { warns = {} }
local function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	table.insert(LOG.warns, table.concat(parts, " "))
end

-- // value types ---------------------------------------------------------

local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function Vector3.__eq(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return setmetatable({ X = x.X, Y = x.Y, Z = x.Z, rot = 0 }, CFrame)
	end
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, rot = 0 }, CFrame)
end
function CFrame.Angles(_, y, _z)
	return setmetatable({ X = 0, Y = 0, Z = 0, rot = y or 0 }, CFrame)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.__mul(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z, rot = a.rot + b.rot }, CFrame)
end

local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}
local UDim = {
	new = function(s, o)
		return { Scale = s, Offset = o }
	end,
}
local UDim2 = {
	new = function(sx, ox, sy, oy)
		return { sx = sx, ox = ox, sy = sy, oy = oy }
	end,
	fromScale = function(sx, sy)
		return { sx = sx, ox = 0, sy = sy, oy = 0 }
	end,
	fromOffset = function(ox, oy)
		return { sx = 0, ox = ox, sy = 0, oy = oy }
	end,
}

-- Enums are permissive: any member name resolves to a stable token.
local function enumFamily(name)
	return setmetatable({}, {
		__index = function(_, key)
			return name .. "." .. key
		end,
	})
end
local Enum = setmetatable({}, {
	__index = function(_, family)
		return enumFamily(family)
	end,
})

-- // remote delivery log -------------------------------------------------
-- Records what the server sent to each client so tests can assert on it.

local FIRED = {}
local function recordFire(eventName, player, ...)
	FIRED[eventName] = FIRED[eventName] or {}
	table.insert(FIRED[eventName], { player = player, args = { ... } })
end

-- // instances -----------------------------------------------------------

local Instance = {}
local instanceMt

local function newInstance(className: string)
	local self = {
		ClassName = className,
		Name = className,
		_children = {},
		_parent = nil,
		_attributes = {},
	}
	return setmetatable(self, instanceMt)
end

local instanceMethods = {}

function instanceMethods:IsA(className)
	return self.ClassName == className
end
function instanceMethods:GetChildren()
	local out = {}
	for i, c in ipairs(self._children) do
		out[i] = c
	end
	return out
end
function instanceMethods:GetDescendants()
	local out = {}
	for _, c in ipairs(self._children) do
		table.insert(out, c)
		for _, d in ipairs(c:GetDescendants()) do
			table.insert(out, d)
		end
	end
	return out
end
function instanceMethods:FindFirstChild(name)
	for _, c in ipairs(self._children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function instanceMethods:WaitForChild(name)
	local found = self:FindFirstChild(name)
	assert(found, "WaitForChild would block forever: " .. tostring(self.Name) .. "." .. tostring(name))
	return found
end
function instanceMethods:FindFirstAncestorOfClass(className)
	local node = self._parent
	while node do
		if node.ClassName == className then
			return node
		end
		node = node._parent
	end
	return nil
end
function instanceMethods:Destroy()
	local parent = self._parent
	if parent then
		for i, c in ipairs(parent._children) do
			if c == self then
				table.remove(parent._children, i)
				break
			end
		end
	end
	rawset(self, "_parent", nil)
	rawset(self, "_destroyed", true)
end
function instanceMethods:ClearAllChildren()
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
end
function instanceMethods:SetAttribute(key, value)
	self._attributes[key] = value
end
function instanceMethods:GetAttribute(key)
	return self._attributes[key]
end
function instanceMethods:PivotTo(cframe)
	rawset(self, "_pivot", cframe)
end
-- RemoteEvent surface: deliveries are recorded per remote name for assertions.
function instanceMethods:FireClient(player, ...)
	recordFire(self.Name, player, ...)
end
function instanceMethods:FireAllClients(...)
	recordFire(self.Name, nil, ...)
end
function instanceMethods:GetPivot()
	return rawget(self, "_pivot") or CFrame.new(0, 0, 0)
end

instanceMt = {
	__index = function(t, key)
		if key == "Parent" then
			return rawget(t, "_parent")
		end
		local method = instanceMethods[key]
		if method then
			return method
		end
		return nil
	end,
	__newindex = function(t, key, value)
		if key == "Parent" then
			local old = rawget(t, "_parent")
			if old then
				for i, c in ipairs(old._children) do
					if c == t then
						table.remove(old._children, i)
						break
					end
				end
			end
			rawset(t, "_parent", value)
			if value then
				table.insert(value._children, t)
			end
			return
		end
		rawset(t, key, value)
	end,
}

Instance.new = newInstance

-- // signals / remotes ---------------------------------------------------

local function newSignal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in ipairs(handlers) do
				fn(...)
			end
		end,
	}
end

-- // services ------------------------------------------------------------

local replicatedStorage = newInstance("ReplicatedStorage")
replicatedStorage.Name = "ReplicatedStorage"
local starterPlayer = newInstance("StarterPlayer")
starterPlayer.Name = "StarterPlayer"
local soundService = newInstance("SoundService")
local workspace = newInstance("Workspace")
workspace.Name = "Workspace"

-- DataStores: in-memory, with an ordered variant for the sales charts.
local STORE_DATA = {}
local function dataStore(name)
	STORE_DATA[name] = STORE_DATA[name] or {}
	local bucket = STORE_DATA[name]
	return {
		GetAsync = function(_, key)
			return bucket[key]
		end,
		SetAsync = function(_, key, value)
			bucket[key] = value
			return key
		end,
		UpdateAsync = function(_, key, transform)
			local updated = transform(bucket[key])
			if updated ~= nil then
				bucket[key] = updated
			end
			return updated
		end,
		RemoveAsync = function(_, key)
			local old = bucket[key]
			bucket[key] = nil
			return old
		end,
		GetSortedAsync = function(_, ascending, pageSize)
			local entries = {}
			for key, value in pairs(bucket) do
				table.insert(entries, { key = key, value = value })
			end
			table.sort(entries, function(a, b)
				if a.value == b.value then
					return a.key < b.key
				end
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			while #entries > pageSize do
				table.remove(entries)
			end
			return {
				GetCurrentPage = function()
					return entries
				end,
			}
		end,
	}
end

local PLAYERS = {}
local playersService = {
	CharacterAutoLoads = true,
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		local out = {}
		for _, p in ipairs(PLAYERS) do
			table.insert(out, p)
		end
		return out
	end,
	GetPlayerByUserId = function(_, userId)
		for _, p in ipairs(PLAYERS) do
			if p.UserId == userId then
				return p
			end
		end
		return nil
	end,
}

local GAMEPASS_OWNERSHIP = {}
local marketplaceService = {
	UserOwnsGamePassAsync = function(_, userId, passId)
		local owned = GAMEPASS_OWNERSHIP[userId]
		return owned ~= nil and owned[passId] == true
	end,
	PromptGamePassPurchaseFinished = newSignal(),
}

local GUID_COUNTER = { n = 0 }
local httpService = {
	GenerateGUID = function()
		GUID_COUNTER.n += 1
		return string.format("bp-%04d", GUID_COUNTER.n)
	end,
	JSONEncode = function(_, v)
		return tostring(v)
	end,
}

local textService = {
	FilterStringAsync = function(_, text)
		return {
			GetNonChatStringForBroadcastAsync = function()
				return text
			end,
		}
	end,
}

local runService = {
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsStudio = function()
		return true
	end,
	RenderStepped = newSignal(),
	Heartbeat = newSignal(),
}

local SERVICES = {
	ReplicatedStorage = replicatedStorage,
	StarterPlayer = starterPlayer,
	SoundService = soundService,
	Workspace = workspace,
	Players = playersService,
	MarketplaceService = marketplaceService,
	HttpService = httpService,
	TextService = textService,
	RunService = runService,
	DataStoreService = {
		GetDataStore = function(_, name)
			return dataStore(name)
		end,
		GetOrderedDataStore = function(_, name)
			return dataStore(name)
		end,
	},
}

local BOUND_TO_CLOSE = {}
local game = {
	PlaceId = 0,
	GetService = function(_, name)
		local service = SERVICES[name]
		assert(service, "mock is missing service: " .. tostring(name))
		return service
	end,
	BindToClose = function(_, fn)
		table.insert(BOUND_TO_CLOSE, fn)
	end,
}

-- // task ----------------------------------------------------------------
-- Deferred work runs only when a test asks for it, so nothing happens behind
-- the test's back. Loops that wait forever simply never resume.

local DEFERRED = {}
local task = {
	spawn = function(fn, ...)
		local args = { ... }
		table.insert(DEFERRED, function()
			fn(table.unpack(args))
		end)
	end,
	defer = function(fn, ...)
		local args = { ... }
		table.insert(DEFERRED, function()
			fn(table.unpack(args))
		end)
	end,
	delay = function(_, fn, ...)
		local args = { ... }
		table.insert(DEFERRED, function()
			fn(table.unpack(args))
		end)
	end,
	wait = function(seconds)
		advance(seconds or 0)
		-- A `while true do task.wait(n) end` loop would spin forever here, so
		-- background service loops are stopped after their first sleep.
		error("__mock_yield__", 0)
	end,
}

local function drain()
	local pending = DEFERRED
	DEFERRED = {}
	for _, fn in ipairs(pending) do
		local ok, err = pcall(fn)
		if not ok and not tostring(err):find("__mock_yield__") then
			error(err, 0)
		end
	end
end

-- // module registry -----------------------------------------------------
-- run.py appends each game module as MODULES["Name"] = function() ... end.

local MODULES = {}
local LOADED = {}
local function req(name: string)
	if LOADED[name] == nil then
		local factory = MODULES[name]
		assert(factory, "no such module in harness: " .. tostring(name))
		LOADED[name] = factory()
	end
	return LOADED[name]
end

-- // test player factory -------------------------------------------------

local USER_ID = { next = 100 }
local function newPlayer(name: string)
	USER_ID.next += 1
	local player = {
		Name = name,
		DisplayName = name,
		UserId = USER_ID.next,
		Character = nil,
		LoadCharacter = function() end,
	}
	table.insert(PLAYERS, player)
	return player
end

local function removePlayer(player)
	for i, p in ipairs(PLAYERS) do
		if p == player then
			table.remove(PLAYERS, i)
			break
		end
	end
end

local MOCK = {
	advance = advance,
	drain = drain,
	log = LOG,
	fired = FIRED,
	recordFire = recordFire,
	newPlayer = newPlayer,
	removePlayer = removePlayer,
	players = playersService,
	gamePasses = GAMEPASS_OWNERSHIP,
	stores = STORE_DATA,
	workspace = workspace,
	starterPlayer = starterPlayer,
	game = game,
	bindToClose = BOUND_TO_CLOSE,
}
