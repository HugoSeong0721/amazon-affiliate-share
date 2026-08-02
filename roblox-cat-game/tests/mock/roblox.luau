-- 로블록스 API 흉내내기 (테스트 전용)
--
-- 게임 스크립트를 Studio 없이 실행해보기 위한 최소 구현.
-- 진짜 로블록스가 아니라 "우리 게임이 쓰는 부분만" 흉내낸다.
--   · 인스턴스 트리 (Parent/자식/찾기/삭제)
--   · 시그널 (Connect/Fire/Wait)
--   · RemoteEvent 서버↔클라 왕복
--   · 가상 시계 위에서 도는 task 스케줄러 + Heartbeat
--
-- 가상 시계라서 "밥 8번 주는 12초"를 즉시 돌려볼 수 있다.

local Mock = {}

---------------------------------------------------------------
-- 스케줄러 (가상 시간)
---------------------------------------------------------------
local clockNow = 0
local pending = {} -- { resumeAt, thread, args }

local function schedule(delay, thread, ...)
	table.insert(pending, { at = clockNow + math.max(delay or 0, 0), thread = thread, args = table.pack(...) })
end

local scheduler = {}

function scheduler.now()
	return clockNow
end

-- 시간을 dt만큼 흘리고, 그 사이 깨어날 코루틴을 순서대로 재개한다
function scheduler.advance(dt)
	local target = clockNow + dt
	while true do
		local nextIndex, nextAt = nil, math.huge
		for index, entry in ipairs(pending) do
			if entry.at <= target and entry.at < nextAt then
				nextIndex, nextAt = index, entry.at
			end
		end
		if not nextIndex then
			break
		end
		local entry = table.remove(pending, nextIndex)
		clockNow = math.max(clockNow, entry.at)
		local ok, err = coroutine.resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
		if not ok then
			error("task 안에서 오류: " .. tostring(err), 0)
		end
	end
	clockNow = target
end

Mock.scheduler = scheduler

local task = {}

function task.spawn(fn, ...)
	local thread = type(fn) == "thread" and fn or coroutine.create(fn)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error("task.spawn 안에서 오류: " .. tostring(err), 0)
	end
	return thread
end

function task.defer(fn, ...)
	local thread = type(fn) == "thread" and fn or coroutine.create(fn)
	schedule(0, thread, ...)
	return thread
end

function task.delay(delay, fn, ...)
	local thread = type(fn) == "thread" and fn or coroutine.create(fn)
	schedule(delay, thread, ...)
	return thread
end

function task.wait(duration)
	local thread = coroutine.running()
	schedule(duration or 0, thread)
	coroutine.yield()
	return duration or 0
end

Mock.task = task

---------------------------------------------------------------
-- 시그널
---------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

local function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
	local entry = { handler = handler, connected = true }
	table.insert(self.handlers, entry)
	return {
		Connected = true,
		Disconnect = function(connection)
			entry.connected = false
			if type(connection) == "table" then
				connection.Connected = false
			end
		end,
	}
end

Signal.connect = Signal.Connect

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- 순회 도중 Connect/Disconnect가 일어나도 안전하도록 복사본을 쓴다
	local snapshot = table.clone(self.handlers)
	for _, entry in ipairs(snapshot) do
		if entry.connected then
			local thread = coroutine.create(entry.handler)
			local ok, err = coroutine.resume(thread, ...)
			if not ok then
				error("시그널 처리 중 오류: " .. tostring(err), 0)
			end
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		schedule(0, thread, ...)
	end)
	return coroutine.yield()
end

Mock.newSignal = newSignal

---------------------------------------------------------------
-- 값 타입 (Vector3 / CFrame / Color3 / UDim2 …)
---------------------------------------------------------------
local Vector3 = {}
Vector3.__index = Vector3

local function vec3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

function Vector3.__add(a, b) return vec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function Vector3.__sub(a, b) return vec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function Vector3.__mul(a, b)
	if type(b) == "number" then return vec3(a.X * b, a.Y * b, a.Z * b) end
	return vec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function Vector3.__eq(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function Vector3.__index(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local m = self.Magnitude
		if m == 0 then return vec3(0, 0, 0) end
		return vec3(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(Vector3, key)
end

local Vector3Lib = setmetatable({
	new = function(x, y, z) return vec3(x, y, z) end,
	zero = vec3(0, 0, 0),
}, {})

-- CFrame: 위치만 제대로 다루고 회전은 자리만 잡아둔다 (테스트에 회전은 필요없다)
local CFrameMT = {}
local function cframe(pos)
	return setmetatable({ Position = pos or vec3(0, 0, 0) }, CFrameMT)
end
CFrameMT.__index = function(self, key)
	if key == "LookVector" then return vec3(0, 0, -1) end
	if key == "X" then return self.Position.X end
	if key == "Y" then return self.Position.Y end
	if key == "Z" then return self.Position.Z end
	if key == "Inverse" then return function(s) return cframe(vec3(-s.Position.X, -s.Position.Y, -s.Position.Z)) end end
	if key == "Lerp" then
		return function(s, goal, alpha)
			local a, b = s.Position, goal.Position
			return cframe(vec3(a.X + (b.X - a.X) * alpha, a.Y + (b.Y - a.Y) * alpha, a.Z + (b.Z - a.Z) * alpha))
		end
	end
	return nil
end
CFrameMT.__mul = function(a, b)
	if getmetatable(b) == CFrameMT then
		return cframe(a.Position + b.Position)
	end
	return cframe(a.Position + b) -- CFrame * Vector3
end

local CFrameLib = {
	new = function(x, y, z)
		if type(x) == "table" then return cframe(x) end
		return cframe(vec3(x, y, z))
	end,
	Angles = function() return cframe(vec3(0, 0, 0)) end,
	lookAt = function(from) return cframe(from) end,
	identity = cframe(vec3(0, 0, 0)),
}

local function passthrough(fields)
	return setmetatable({}, {
		__call = function(_, ...) return { ... } end,
		__index = function(_, key) return fields and fields[key] or nil end,
	})
end

local Color3Lib = {
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end,
	fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 } end,
}

local UDimLib = { new = function(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end }

-- 주의: 테이블 안에서 자기 자신을 참조하려면 먼저 선언해야 한다.
-- (Lua에서 `local t = { f = function() return t.g() end }` 의 t는 전역 nil이다)
local UDim2Lib = {}
UDim2Lib.new = function(xs, xo, ys, yo)
	return { X = UDimLib.new(xs, xo), Y = UDimLib.new(ys, yo) }
end
UDim2Lib.fromOffset = function(x, y) return UDim2Lib.new(0, x, 0, y) end
UDim2Lib.fromScale = function(x, y) return UDim2Lib.new(x, 0, y, 0) end

-- Enum.무엇이든.무엇이든 을 허용하는 만능 테이블
local function enumItem(enumName, itemName)
	return setmetatable({ Name = itemName, EnumType = enumName }, {
		__tostring = function() return ("Enum.%s.%s"):format(enumName, itemName) end,
	})
end

local EnumLib = setmetatable({}, {
	__index = function(_, enumName)
		local cache = {}
		return setmetatable({}, {
			__index = function(_, itemName)
				cache[itemName] = cache[itemName] or enumItem(enumName, itemName)
				return cache[itemName]
			end,
		})
	end,
})

Mock.Vector3 = Vector3Lib
Mock.CFrame = CFrameLib
Mock.Color3 = Color3Lib
Mock.UDim = UDimLib
Mock.UDim2 = UDim2Lib
Mock.Enum = EnumLib

---------------------------------------------------------------
-- 인스턴스
---------------------------------------------------------------
local Instance = {}

local instanceMT = {}

local CLASS_PARENTS = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	SpawnLocation = { "Part", "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiObject", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	IntValue = { "ValueBase" },
	NumberValue = { "ValueBase" },
	StringValue = { "ValueBase" },
	BoolValue = { "ValueBase" },
}

local function newInstance(className)
	local self = {
		ClassName = className,
		_props = { Name = className, Archivable = true },
		_children = {},
		_attributes = {},
		_signals = {},
		_destroyed = false,
		_parent = nil,
	}
	return setmetatable(self, instanceMT)
end

local function getSignal(self, name)
	if not self._signals[name] then
		self._signals[name] = newSignal()
	end
	return self._signals[name]
end

local METHODS = {}

function METHODS:GetChildren()
	return table.clone(self._children)
end

function METHODS:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in ipairs(node._children) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function METHODS:FindFirstChild(name)
	for _, child in ipairs(self._children) do
		if child._props.Name == name then
			return child
		end
	end
	return nil
end

function METHODS:FindFirstChildOfClass(className)
	for _, child in ipairs(self._children) do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

function METHODS:FindFirstChildWhichIsA(className)
	for _, child in ipairs(self._children) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

-- 테스트는 가상 시간이라 실제로 기다리지 않는다.
-- 이미 있으면 바로 주고, 없으면 nil (타임아웃과 같은 결과)
function METHODS:WaitForChild(name, _timeout)
	return self:FindFirstChild(name)
end

function METHODS:IsA(className)
	if self.ClassName == className or className == "Instance" then
		return true
	end
	for _, ancestor in ipairs(CLASS_PARENTS[self.ClassName] or {}) do
		if ancestor == className then
			return true
		end
	end
	return false
end

function METHODS:IsDescendantOf(other)
	local node = self._parent
	while node do
		if node == other then return true end
		node = node._parent
	end
	return false
end

function METHODS:Destroy()
	self._destroyed = true
	for _, child in ipairs(table.clone(self._children)) do
		child:Destroy()
	end
	self._props.Parent = nil
	if self._parent then
		local siblings = self._parent._children
		for index, child in ipairs(siblings) do
			if child == self then
				table.remove(siblings, index)
				break
			end
		end
		self._parent = nil
	end
end

METHODS.Remove = METHODS.Destroy

function METHODS:Clone()
	local copy = newInstance(self.ClassName)
	for key, value in pairs(self._props) do
		if key ~= "Parent" then
			copy._props[key] = value
		end
	end
	for key, value in pairs(self._attributes) do
		copy._attributes[key] = value
	end
	for _, child in ipairs(self._children) do
		local childCopy = child:Clone()
		childCopy.Parent = copy
	end
	return copy
end

function METHODS:SetAttribute(name, value)
	self._attributes[name] = value
end

function METHODS:GetAttribute(name)
	return self._attributes[name]
end

function METHODS:GetAttributes()
	return table.clone(self._attributes)
end

function METHODS:PivotTo(target)
	self._props.WorldPivot = target
	local primary = self._props.PrimaryPart
	if primary then
		primary._props.CFrame = target
		primary._props.Position = target.Position
	end
end

function METHODS:GetPivot()
	local primary = self._props.PrimaryPart
	if primary and primary._props.CFrame then
		return primary._props.CFrame
	end
	return self._props.WorldPivot or CFrameLib.new(0, 0, 0)
end

METHODS.SetPrimaryPartCFrame = METHODS.PivotTo

function METHODS:GetPropertyChangedSignal(_name)
	return getSignal(self, "PropertyChanged")
end

-- RemoteEvent
-- 진짜 로블록스는 서버 핸들러 첫 인자로 "보낸 플레이어"를 자동으로 끼워준다.
-- 테스트에서도 같게 만들기 위해 현재 조종 중인 플레이어를 쓴다.
local activePlayer = nil

function METHODS:FireServer(...)
	getSignal(self, "OnServerEvent"):Fire(self._sender or activePlayer, ...)
end

function METHODS:FireClient(player, ...)
	if self._clientTarget == nil or self._clientTarget == player then
		getSignal(self, "OnClientEvent"):Fire(...)
	end
	getSignal(self, "_ServerToClient"):Fire(player, ...)
end

function METHODS:FireAllClients(...)
	getSignal(self, "OnClientEvent"):Fire(...)
end

local SIGNAL_PROPS = {
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	AncestryChanged = true,
	Touched = true,
	Activated = true,
	MouseButton1Click = true,
	Triggered = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	Died = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	OnServerEvent = true,
	OnClientEvent = true,
	_ServerToClient = true,
}

instanceMT.__index = function(self, key)
	local method = METHODS[key]
	if method then
		return method
	end
	if SIGNAL_PROPS[key] then
		return getSignal(self, key)
	end
	if key == "Parent" then
		return self._parent
	end
	if key == "Name" then
		return self._props.Name
	end
	local stored = self._props[key]
	if stored ~= nil then
		return stored
	end
	-- 로블록스는 부모.자식이름 으로도 자식을 찾을 수 있다 (stats["후원금"] 같은 코드)
	for _, child in ipairs(self._children) do
		if child._props.Name == key then
			return child
		end
	end
	return nil
end

instanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = self._parent
		if old then
			for index, child in ipairs(old._children) do
				if child == self then
					table.remove(old._children, index)
					break
				end
			end
			getSignal(old, "ChildRemoved"):Fire(self)
		end
		self._parent = value
		if value then
			table.insert(value._children, self)
			getSignal(value, "ChildAdded"):Fire(self)
		end
		return
	end
	self._props[key] = value
	local changed = rawget(self, "_signals") and self._signals.Changed
	if changed then
		changed:Fire(key)
	end
end

instanceMT.__tostring = function(self)
	return self._props.Name or self.ClassName
end

Instance.new = function(className, parent)
	local inst = newInstance(className)
	if parent then
		inst.Parent = parent
	end
	return inst
end

Mock.Instance = Instance
Mock.newInstance = newInstance

---------------------------------------------------------------
-- 서비스 / game
---------------------------------------------------------------
local services = {}

local function service(className, name)
	if services[name or className] then
		return services[name or className]
	end
	local inst = newInstance(className)
	inst._props.Name = name or className
	services[name or className] = inst
	return inst
end

local Workspace = service("Workspace")

local Players = service("Players")
Players._props.RespawnTime = 0
Players._props.CharacterAutoLoads = true
Players.GetPlayers = function(self)
	local out = {}
	for _, child in ipairs(self._children) do
		if child.ClassName == "Player" then
			table.insert(out, child)
		end
	end
	return out
end

local RunService = service("RunService")
RunService.IsServer = function() return true end
RunService.IsClient = function() return true end
RunService.IsStudio = function() return true end

-- DataStore: 저장은 안 하고 항상 비어있는 것처럼 (Studio에서 API 꺼진 상태와 동일)
local DataStoreService = service("DataStoreService")
local storeData = {}
DataStoreService.GetDataStore = function(_, storeName)
	storeData[storeName] = storeData[storeName] or {}
	local store = {}
	function store:GetAsync(key)
		return storeData[storeName][key]
	end
	function store:SetAsync(key, value)
		storeData[storeName][key] = value
		return true
	end
	function store:UpdateAsync(key, transform)
		storeData[storeName][key] = transform(storeData[storeName][key])
		return storeData[storeName][key]
	end
	return store
end

service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
service("StarterGui")
service("StarterPack")
service("Lighting")
service("SoundService")
service("TweenService")
service("UserInputService")
service("ContextActionService")
service("HttpService")
service("CollectionService")
service("TextChatService")
service("MarketplaceService")

local StarterPlayer = service("StarterPlayer")
StarterPlayer._props.LoadCharacterAppearance = true
local starterPlayerScripts = newInstance("StarterPlayerScripts")
starterPlayerScripts._props.Name = "StarterPlayerScripts"
starterPlayerScripts.Parent = StarterPlayer
local starterCharacterScripts = newInstance("StarterCharacterScripts")
starterCharacterScripts._props.Name = "StarterCharacterScripts"
starterCharacterScripts.Parent = StarterPlayer

local game = newInstance("DataModel")
game._props.Name = "game"
game.GetService = function(_, name)
	local existing = services[name]
	if existing then
		return existing
	end
	return service(name)
end
game.FindService = game.GetService
game.BindToClose = function(_, callback)
	Mock.onClose = callback
end
game._props.PlaceId = 0
game._props.JobId = ""

Mock.game = game
Mock.workspace = Workspace
Mock.services = services

---------------------------------------------------------------
-- 플레이어 / 캐릭터 만들기 (테스트에서 접속을 흉내낼 때 쓴다)
---------------------------------------------------------------
local nextUserId = 100

function Mock.addPlayer(name)
	nextUserId += 1
	local player = newInstance("Player")
	player._props.Name = name or ("TestPlayer" .. nextUserId)
	player._props.UserId = nextUserId
	player._props.DisplayName = player._props.Name

	local playerGui = newInstance("PlayerGui")
	playerGui._props.Name = "PlayerGui"
	playerGui.Parent = player

	player.LoadCharacter = function(self)
		Mock.spawnCharacter(self)
	end
	player.Kick = function() end

	player.Parent = Players
	if activePlayer == nil then
		activePlayer = player -- 첫 플레이어를 "내가 조종하는 플레이어"로 삼는다
	end
	Players.PlayerAdded:Fire(player)
	return player
end

-- 여러 명을 흉내낼 때 누가 조작 중인지 바꾼다
function Mock.setActivePlayer(player)
	activePlayer = player
end

function Mock.spawnCharacter(player, position)
	local character = newInstance("Model")
	character._props.Name = player._props.Name

	local root = newInstance("Part")
	root._props.Name = "HumanoidRootPart"
	root._props.Position = position or vec3(0, 3, 0)
	root._props.CFrame = cframe(root._props.Position)
	root._props.AssemblyLinearVelocity = vec3(0, 0, 0)
	root.Parent = character

	local torso = newInstance("Part")
	torso._props.Name = "Torso"
	torso.Parent = character

	local humanoid = newInstance("Humanoid")
	humanoid._props.Name = "Humanoid"
	humanoid._props.Health = 100
	humanoid._props.WalkSpeed = 16
	humanoid._props.MoveDirection = vec3(0, 0, 0)
	humanoid.Parent = character

	character._props.PrimaryPart = root
	character.Parent = Workspace

	player._props.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

-- 캐릭터를 옮긴다 (튜토리얼의 "움직였는지" 판정 등을 테스트할 때)
function Mock.moveCharacter(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root._props.Position = position
		root._props.CFrame = cframe(position)
	end
end

---------------------------------------------------------------
-- 프레임 진행: Heartbeat / RenderStepped 를 돌리며 시간을 흘린다
---------------------------------------------------------------
function Mock.step(seconds, fps)
	local dt = 1 / (fps or 30)
	local elapsed = 0
	while elapsed < seconds do
		scheduler.advance(dt)
		RunService.Heartbeat:Fire(dt)
		RunService.RenderStepped:Fire(dt)
		RunService.Stepped:Fire(scheduler.now(), dt)
		elapsed += dt
	end
end

return Mock
