-- 헤드리스 플레이 테스트
--
-- 진짜 게임 스크립트(src/)를 가짜 로블록스 환경에 얹어서 실행하고,
-- 플레이어가 실제로 하는 행동을 순서대로 시켜본 뒤 결과를 확인한다.
-- Studio 없이도 "돌려보고 오류 잡기"를 할 수 있게 하는 것이 목적.
--
--   cargo run --release --manifest-path tests/runner/Cargo.toml -- tests/main.luau

local Mock = _loadChunk(_readFile(_scriptDir .. "/mock/roblox.luau"), "roblox.luau")()

local ROOT = _scriptDir .. "/.."
local SRC = ROOT .. "/src"

---------------------------------------------------------------
-- 간단한 검증 도구
---------------------------------------------------------------
local passed, failed = 0, 0
local failures = {}
local currentScenario = "?"

local function scenario(name)
	currentScenario = name
	_write("")
	_write("▶ " .. name)
end

local function check(label, ok, detail)
	if ok then
		passed += 1
		_write("   ✓ " .. label)
	else
		failed += 1
		table.insert(failures, currentScenario .. " → " .. label .. (detail and ("  (" .. detail .. ")") or ""))
		_write("   ✗ " .. label .. (detail and ("  (" .. detail .. ")") or ""))
	end
end

local function checkEqual(label, actual, expected)
	check(label, actual == expected, ("실제 %s / 기대 %s"):format(tostring(actual), tostring(expected)))
end

---------------------------------------------------------------
-- 게임 스크립트를 가짜 환경에 얹기
---------------------------------------------------------------
local moduleResults = {}

local envBase
local function makeEnv(scriptInstance)
	local env = {}
	for key, value in pairs(envBase) do
		env[key] = value
	end
	env.script = scriptInstance
	env._G = env
	return env
end

local function runSource(path, scriptInstance)
	local source = _readFile(path)
	local env = makeEnv(scriptInstance)
	local chunk = _loadWithEnv(source, path, env)
	return chunk()
end

local function requireImpl(target)
	if moduleResults[target] ~= nil then
		return moduleResults[target]
	end
	error("require: 모듈을 찾을 수 없습니다 — " .. tostring(target), 0)
end

envBase = {
	print = function(...) _write("      [print]", ...) end,
	warn = function(...) _write("      [warn]", ...) end,
	error = error,
	assert = assert,
	pcall = pcall,
	xpcall = xpcall,
	select = select,
	type = type,
	tostring = tostring,
	tonumber = tonumber,
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	unpack = table.unpack,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	rawlen = rawlen,
	math = math,
	string = string,
	table = table,
	coroutine = coroutine,
	buffer = buffer,
	utf8 = utf8,
	os = {
		clock = function() return Mock.scheduler.now() end,
		time = function() return 1700000000 + math.floor(Mock.scheduler.now()) end,
		date = os.date,
		difftime = os.difftime,
	},
	tick = function() return Mock.scheduler.now() end,
	time = function() return Mock.scheduler.now() end,
	typeof = function(value)
		if type(value) == "table" and value.ClassName then return "Instance" end
		return type(value)
	end,
	task = Mock.task,
	Instance = Mock.Instance,
	Vector3 = Mock.Vector3,
	CFrame = Mock.CFrame,
	Color3 = Mock.Color3,
	UDim = Mock.UDim,
	UDim2 = Mock.UDim2,
	Enum = Mock.Enum,
	game = Mock.game,
	workspace = Mock.workspace,
	Game = Mock.game,
	require = requireImpl,
}

local ReplicatedStorage = Mock.game:GetService("ReplicatedStorage")
local ServerScriptService = Mock.game:GetService("ServerScriptService")
local Players = Mock.game:GetService("Players")
local StarterPlayer = Mock.game:GetService("StarterPlayer")

-- ModuleScript 등록
local function installModule(name, parent, path)
	local inst = Mock.newInstance("ModuleScript")
	inst._props.Name = name
	inst.Parent = parent
	moduleResults[inst] = runSource(path, inst)
	return inst
end

-- Script / LocalScript 실행
local function installScript(className, name, parent, path)
	local inst = Mock.newInstance(className)
	inst._props.Name = name
	inst.Parent = parent
	runSource(path, inst)
	return inst
end

---------------------------------------------------------------
-- 부팅 (Studio에서 Play를 누른 것과 같은 순서)
---------------------------------------------------------------
_write("=== 게임 부팅 ===")

installModule("CatConfig", ReplicatedStorage, SRC .. "/ReplicatedStorage/CatConfig.lua")
local CatConfig = moduleResults[ReplicatedStorage:FindFirstChild("CatConfig")]

installScript("Script", "Shelter", ServerScriptService, SRC .. "/ServerScriptService/Shelter.server.lua")
installScript("Script", "CatGameServer", ServerScriptService, SRC .. "/ServerScriptService/CatGameServer.server.lua")
installScript("Script", "CharacterSetup", ServerScriptService, SRC .. "/ServerScriptService/CharacterSetup.server.lua")

_write("서버 스크립트 3개 실행 완료")

-- 플레이어 접속
local player = Mock.addPlayer("테스터")
Mock.step(0.5)

-- 클라이언트 스크립트는 LocalPlayer가 있어야 돈다
Players._props.LocalPlayer = player
local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
installScript("LocalScript", "CatGameClient", playerScripts, SRC .. "/StarterPlayerScripts/CatGameClient.client.lua")
installScript("LocalScript", "CatTutorial", playerScripts, SRC .. "/StarterPlayerScripts/CatTutorial.client.lua")

_write("클라이언트 스크립트 2개 실행 완료")
Mock.step(1)

---------------------------------------------------------------
-- 헬퍼
---------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("CatGameRemotes")

local function findMyCats()
	local out = {}
	for _, child in ipairs(Mock.workspace:GetChildren()) do
		if child.ClassName == "Model" and child:GetAttribute("CatOwnerUserId") == player.UserId then
			table.insert(out, child)
		end
	end
	return out
end

-- 고양이 옆에서 E를 누르는 것과 같다
local function feedOnce()
	local cats = findMyCats()
	if #cats == 0 then
		return false
	end
	local head = cats[1]:FindFirstChild("Head")
	local prompt = head and head:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return false
	end
	prompt.Triggered:Fire(player)
	return true
end

local function stats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("후원금")
	local cats = leaderstats and leaderstats:FindFirstChild("고양이")
	return coins and coins.Value or -1, cats and cats.Value or -1
end

---------------------------------------------------------------
-- 시나리오
---------------------------------------------------------------
scenario("접속 직후 상태")

local startCoins, startCats = stats()
checkEqual("시작 후원금", startCoins, CatConfig.StartCoins)
checkEqual("시작 고양이 수", startCats, 1)
check("캐릭터가 스폰됐다", player.Character ~= nil)
check("고양이 모델이 월드에 있다", #findMyCats() >= 1, ("모델 %d개"):format(#findMyCats()))
check("쉼터가 지어졌다", Mock.workspace:FindFirstChild("Shelter") ~= nil)

scenario("밥 주기")

local beforeCoins = select(1, stats())
check("E 프롬프트가 있다", feedOnce())
Mock.step(0.2)
local afterCoins = select(1, stats())
checkEqual("밥 한 번에 후원금 증가량", afterCoins - beforeCoins, CatConfig.FeedCoins)

-- 쿨타임 안에 또 누르면 무시돼야 한다
local beforeSpam = select(1, stats())
feedOnce()
Mock.step(0.05)
checkEqual("쿨타임 중에는 보상 없음", select(1, stats()), beforeSpam)

scenario("레벨업 (건강해지기)")

-- Lv.2까지 필요한 만큼 먹인다
local feedsForLevel = math.ceil(CatConfig.XpForLevel(1) / CatConfig.FeedXp)
for _ = 1, feedsForLevel do
	Mock.step(CatConfig.FeedCooldown + 0.1)
	feedOnce()
end
Mock.step(0.3)

local levelledCat = findMyCats()[1]
check("Lv.2가 된 고양이 모델이 다시 만들어졌다", levelledCat ~= nil)

scenario("구조 (핵심: 후원금이 모자랄 때 vs 충분할 때)")

local firstRescue
for _, breed in ipairs(CatConfig.Breeds) do
	if breed.Price > 0 and (firstRescue == nil or breed.Price < firstRescue.Price) then
		firstRescue = breed
	end
end
_write("      구조 대상: " .. firstRescue.Name .. " / 비용 " .. firstRescue.Price)

-- 일부러 돈이 모자란 상태에서 시도
local buyRemote = remotes:FindFirstChild("BuyCat")
local notifyRemote = remotes:FindFirstChild("Notify")

local lastNotice = nil
notifyRemote.OnClientEvent:Connect(function(message)
	lastNotice = message
end)

local coinsNow, catsNow = stats()
if coinsNow < firstRescue.Price then
	buyRemote:FireServer(firstRescue.Id)
	Mock.step(0.2)
	checkEqual("돈이 모자라면 고양이가 늘지 않는다", select(2, stats()), catsNow)
	check("모자란 금액을 알려준다", lastNotice ~= nil and string.find(tostring(lastNotice), "모자라") ~= nil,
		tostring(lastNotice))
end

-- 목표 금액까지 밥을 주며 몇 초 걸리는지 잰다
local feedsUsed = 0
local startTime = Mock.scheduler.now()
while select(1, stats()) < firstRescue.Price and feedsUsed < 200 do
	Mock.step(CatConfig.FeedCooldown + 0.05)
	if feedOnce() then
		feedsUsed += 1
	end
end
Mock.step(0.2)
local secondsTaken = Mock.scheduler.now() - startTime

_write(("      밥 %d번 / %.1f초 만에 %d 모음"):format(feedsUsed, secondsTaken, select(1, stats())))
check("첫 구조까지 60초 이내", secondsTaken <= 60, ("%.1f초 걸림"):format(secondsTaken))

buyRemote:FireServer(firstRescue.Id)
Mock.step(0.3)
checkEqual("구조 후 고양이 2마리", select(2, stats()), 2)
check("구조된 고양이 모델이 따라다닌다", #findMyCats() >= 2, ("모델 %d개"):format(#findMyCats()))

-- 같은 고양이를 또 데려올 수 없어야 한다
local coinsBeforeDup = select(1, stats())
buyRemote:FireServer(firstRescue.Id)
Mock.step(0.2)
checkEqual("중복 구조는 막힌다 (후원금 그대로)", select(1, stats()), coinsBeforeDup)

scenario("함께 다니는 마릿수 제한")

-- 후원금을 넉넉히 주기 위해 계속 먹인다
local target = 0
for _, breed in ipairs(CatConfig.Breeds) do
	target += breed.Price
end
local guard = 0
while select(1, stats()) < target and guard < 4000 do
	Mock.step(CatConfig.FeedCooldown + 0.05)
	feedOnce()
	guard += 1
end

for _, breed in ipairs(CatConfig.Breeds) do
	if breed.Price > 0 then
		buyRemote:FireServer(breed.Id)
		Mock.step(0.2)
	end
end
Mock.step(0.5)

checkEqual("고양이 5마리를 모두 모았다", select(2, stats()), #CatConfig.Breeds)
check("동시에 다니는 고양이는 최대치를 넘지 않는다",
	#findMyCats() <= CatConfig.MaxEquipped,
	("따라다니는 모델 %d개 / 최대 %d"):format(#findMyCats(), CatConfig.MaxEquipped))

scenario("퇴장/재접속해도 터지지 않는다")

local ok, err = pcall(function()
	Players.PlayerRemoving:Fire(player)
	Mock.step(0.5)
end)
check("퇴장 처리에 오류 없음", ok, tostring(err))

---------------------------------------------------------------
-- 결과
---------------------------------------------------------------
_write("")
_write(("=== 결과: 통과 %d / 실패 %d ==="):format(passed, failed))
if failed > 0 then
	_write("")
	_write("실패 목록:")
	for _, item in ipairs(failures) do
		_write("  · " .. item)
	end
	error(("테스트 %d개 실패"):format(failed), 0)
end
