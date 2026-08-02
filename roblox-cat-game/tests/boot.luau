-- 게임 부팅 공용 코드
--
-- 가짜 로블록스 환경을 만들고 src/ 의 스크립트를 전부 얹는다.
-- main.luau(플레이 테스트)와 layout.luau(UI 배치 검사)가 같이 쓴다.

return function(options)
	options = options or {}

	local Mock = _loadChunk(_readFile(_scriptDir .. "/mock/roblox.luau"), "roblox.luau")()
	local SRC = _scriptDir .. "/../src"

	local moduleResults = {}
	local envBase
	local sharedG = {} -- 로블록스의 _G 는 서버 스크립트끼리 공유된다

	local function makeEnv(scriptInstance)
		local env = {}
		for key, value in pairs(envBase) do
			env[key] = value
		end
		env.script = scriptInstance
		env._G = sharedG
		return env
	end

	local function runSource(path, scriptInstance)
		return _loadWithEnv(_readFile(path), path, makeEnv(scriptInstance))()
	end

	envBase = {
		print = function(...) if options.verbose then _write("      [print]", ...) end end,
		warn = function(...) _write("      [warn]", ...) end,
		error = error, assert = assert, pcall = pcall, xpcall = xpcall,
		select = select, type = type, tostring = tostring, tonumber = tonumber,
		ipairs = ipairs, pairs = pairs, next = next, unpack = table.unpack,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
		math = math, string = string, table = table, coroutine = coroutine,
		buffer = buffer, utf8 = utf8,
		os = {
			clock = function() return Mock.scheduler.now() end,
			time = function() return 1700000000 + math.floor(Mock.scheduler.now()) end,
			date = os.date, difftime = os.difftime,
		},
		tick = function() return Mock.scheduler.now() end,
		time = function() return Mock.scheduler.now() end,
		typeof = function(value)
			if type(value) == "table" and value.ClassName then return "Instance" end
			return type(value)
		end,
		task = Mock.task,
		Instance = Mock.Instance, Vector3 = Mock.Vector3, CFrame = Mock.CFrame,
		Color3 = Mock.Color3, UDim = Mock.UDim, UDim2 = Mock.UDim2, Enum = Mock.Enum,
		game = Mock.game, workspace = Mock.workspace, Game = Mock.game,
		require = function(target)
			if moduleResults[target] ~= nil then
				return moduleResults[target]
			end
			error("require: 모듈을 찾을 수 없습니다 — " .. tostring(target), 0)
		end,
	}

	local ReplicatedStorage = Mock.game:GetService("ReplicatedStorage")
	local ServerScriptService = Mock.game:GetService("ServerScriptService")
	local Players = Mock.game:GetService("Players")
	local StarterPlayer = Mock.game:GetService("StarterPlayer")

	local function installModule(name, parent, path)
		local inst = Mock.newInstance("ModuleScript")
		inst._props.Name = name
		inst.Parent = parent
		moduleResults[inst] = runSource(path, inst)
		return moduleResults[inst]
	end

	local function installScript(className, name, parent, path)
		local inst = Mock.newInstance(className)
		inst._props.Name = name
		inst.Parent = parent
		runSource(path, inst)
		return inst
	end

	local CatConfig = installModule("CatConfig", ReplicatedStorage, SRC .. "/ReplicatedStorage/CatConfig.lua")
	local BigNumber = installModule("BigNumber", ReplicatedStorage, SRC .. "/ReplicatedStorage/BigNumber.lua")

	installScript("Script", "CatGameServer", ServerScriptService, SRC .. "/ServerScriptService/CatGameServer.server.lua")
	installScript("Script", "Breakables", ServerScriptService, SRC .. "/ServerScriptService/Breakables.server.lua")
	installScript("Script", "World", ServerScriptService, SRC .. "/ServerScriptService/World.server.lua")
	installScript("Script", "CharacterSetup", ServerScriptService, SRC .. "/ServerScriptService/CharacterSetup.server.lua")

	local player = Mock.addPlayer(options.playerName or "테스터")
	Mock.step(0.5)

	Players._props.LocalPlayer = player
	local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")

	if not options.skipClient then
		installScript("LocalScript", "CatGameClient", playerScripts,
			SRC .. "/StarterPlayerScripts/CatGameClient.client.lua")
		installScript("LocalScript", "CatTutorial", playerScripts,
			SRC .. "/StarterPlayerScripts/CatTutorial.client.lua")
	end
	Mock.step(1)

	return {
		Mock = Mock,
		CatConfig = CatConfig,
		BigNumber = BigNumber,
		player = player,
		ReplicatedStorage = ReplicatedStorage,
		Players = Players,
		remotes = ReplicatedStorage:FindFirstChild("CatGameRemotes"),
	}
end
