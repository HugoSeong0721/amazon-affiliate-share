-- 헤드리스 플레이 테스트
--
-- 진짜 게임 스크립트(src/)를 가짜 로블록스 환경에 얹어서 실행하고,
-- 플레이어가 실제로 하는 행동을 시켜본 뒤 결과를 확인한다.
-- 마지막에는 "자동 플레이어"가 처음부터 끝까지 게임을 클리어하며
-- 각 구역까지 몇 분 걸리는지 재준다 (밸런스 조정용).
--
--   cargo run --release --manifest-path tests/runner/Cargo.toml -- tests/main.luau

local Mock = _loadChunk(_readFile(_scriptDir .. "/mock/roblox.luau"), "roblox.luau")()

local SRC = _scriptDir .. "/../src"

---------------------------------------------------------------
-- 검증 도구
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

local function note(text)
	_write("      " .. text)
end

---------------------------------------------------------------
-- 게임 스크립트를 가짜 환경에 얹기
---------------------------------------------------------------
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
	print = function(...) _write("      [print]", ...) end,
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

---------------------------------------------------------------
-- 부팅
---------------------------------------------------------------
_write("=== 게임 부팅 ===")

local CatConfig = installModule("CatConfig", ReplicatedStorage, SRC .. "/ReplicatedStorage/CatConfig.lua")
local BigNumber = installModule("BigNumber", ReplicatedStorage, SRC .. "/ReplicatedStorage/BigNumber.lua")

installScript("Script", "CatGameServer", ServerScriptService, SRC .. "/ServerScriptService/CatGameServer.server.lua")
installScript("Script", "Breakables", ServerScriptService, SRC .. "/ServerScriptService/Breakables.server.lua")
installScript("Script", "World", ServerScriptService, SRC .. "/ServerScriptService/World.server.lua")
installScript("Script", "CharacterSetup", ServerScriptService, SRC .. "/ServerScriptService/CharacterSetup.server.lua")
_write("서버 스크립트 4개 실행 완료")

local player = Mock.addPlayer("테스터")
Mock.step(0.5)

Players._props.LocalPlayer = player
local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")

-- SKIP_CLIENT=1 로 실행하면 서버만 검증한다 (UI 작업 중 서버 회귀 확인용)
if not _skipClient then
	installScript("LocalScript", "CatGameClient", playerScripts, SRC .. "/StarterPlayerScripts/CatGameClient.client.lua")
	installScript("LocalScript", "CatTutorial", playerScripts, SRC .. "/StarterPlayerScripts/CatTutorial.client.lua")
	_write("클라이언트 스크립트 2개 실행 완료")
else
	_write("클라이언트 스크립트 건너뜀 (서버만 검증)")
end
Mock.step(1)

---------------------------------------------------------------
-- 헬퍼
---------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("CatGameRemotes")
local hatchRemote = remotes:FindFirstChild("HatchEgg")
local unlockRemote = remotes:FindFirstChild("UnlockZone")
local equipRemote = remotes:FindFirstChild("ToggleEquip")
local fuseRemote = remotes:FindFirstChild("FuseCats")
local rebirthRemote = remotes:FindFirstChild("Rebirth")
local notifyRemote = remotes:FindFirstChild("Notify")

local lastNotice
notifyRemote.OnClientEvent:Connect(function(message)
	lastNotice = message
end)

local latest = {}
remotes:FindFirstChild("DataChanged").OnClientEvent:Connect(function(data)
	latest = data
end)

-- 서버는 접속 시점에 이미 첫 데이터를 보냈다. 리스너를 붙인 지금 다시 달라고 한다.
remotes:FindFirstChild("RequestData"):FireServer()
Mock.step(0.2)

local function coins() return latest.Coins or 0 end
local function power() return latest.Power or 0 end
local function catCount() return latest.Cats and #latest.Cats or 0 end
local function equippedCount() return latest.Equipped and #latest.Equipped or 0 end
local function zoneUnlocked(id) return latest.Zones and latest.Zones[id] == true end

-- 플레이어를 해당 구역 한가운데로 옮긴다 (그 구역 물건을 때리게 됨)
local function standInZone(zone)
	Mock.moveCharacter(player, Mock.Vector3.new(zone.Origin.X, 3, zone.Origin.Z))
	Mock.step(0.1)
end

local function countBreakables()
	local folder = Mock.workspace:FindFirstChild("Breakables")
	return folder and #folder:GetChildren() or 0
end

---------------------------------------------------------------
scenario("접속 직후")

checkEqual("시작 코인", coins(), CatConfig.StartCoins)
checkEqual("시작 고양이 1마리", catCount(), 1)
check("치즈냥이를 들고 시작한다", latest.Cats[1].Id == "Cheese", tostring(latest.Cats[1].Id))
checkEqual("자동 장착됨", equippedCount(), 1)
check("파워가 0보다 크다", power() > 0, tostring(power()))
check("마당은 처음부터 열려있다", zoneUnlocked("Yard"))
check("뒷골목은 잠겨있다", not zoneUnlocked("Alley"))
check("월드가 지어졌다", Mock.workspace:FindFirstChild("World") ~= nil)

local expectedBreakables = 0
for _, zone in ipairs(CatConfig.Zones) do
	expectedBreakables += zone.BreakableCount
end
checkEqual("부술 물건이 모든 구역에 깔렸다", countBreakables(), expectedBreakables)

---------------------------------------------------------------
scenario("핵심 루프: 가만히 서 있으면 고양이가 알아서 부순다")

standInZone(CatConfig.Zones[1])
local before = coins()
Mock.step(10)
local earned = coins() - before

note(("10초 동안 %d 코인 획득 (파워 %d)"):format(earned, power()))
check("코인이 저절로 늘어난다", earned > 0, ("%d 획득"):format(earned))
check("보상이 물건 1개 값의 배수다", earned % CatConfig.Zones[1].Reward == 0, tostring(earned))

-- 사거리 밖으로 나가면 멈춰야 한다
Mock.moveCharacter(player, Mock.Vector3.new(400, 3, 400))
local idleBefore = coins()
Mock.step(5)
checkEqual("멀리 떨어지면 아무것도 안 부순다", coins(), idleBefore)
standInZone(CatConfig.Zones[1])

---------------------------------------------------------------
scenario("상자 뽑기")

-- 코인이 없을 때
local pooredCoins = coins()
while coins() >= CatConfig.Zones[1].EggCost do
	-- 이미 충분하면 일부러 다 쓴다
	hatchRemote:FireServer("Yard", 1)
	Mock.step(0.2)
end
lastNotice = nil
hatchRemote:FireServer("Yard", 1)
Mock.step(0.2)
check("코인이 모자라면 알려준다", lastNotice ~= nil and string.find(tostring(lastNotice), "부족") ~= nil,
	tostring(lastNotice))

-- 모아서 다시
local catsBefore = catCount()
while coins() < CatConfig.Zones[1].EggCost do
	Mock.step(2)
end
local coinsBefore = coins()
hatchRemote:FireServer("Yard", 1)
Mock.step(0.3)
checkEqual("뽑으면 고양이가 1마리 늘어난다", catCount(), catsBefore + 1)
checkEqual("상자 값이 빠져나간다", coinsBefore - coins(), CatConfig.Zones[1].EggCost)
check("자리가 남으면 자동 장착된다", equippedCount() == math.min(catsBefore + 1, CatConfig.MaxEquipped),
	("장착 %d"):format(equippedCount()))

-- 잠긴 구역의 상자는 못 연다
lastNotice = nil
hatchRemote:FireServer("Rooftop", 1)
Mock.step(0.2)
check("잠긴 구역 상자는 막힌다", lastNotice ~= nil and string.find(tostring(lastNotice), "열지 않은") ~= nil,
	tostring(lastNotice))

---------------------------------------------------------------
scenario("장착 제한 4마리")

-- 넉넉히 뽑는다
for _ = 1, 12 do
	while coins() < CatConfig.Zones[1].EggCost do
		Mock.step(2)
	end
	hatchRemote:FireServer("Yard", 1)
	Mock.step(0.2)
end
check("장착은 최대치를 넘지 않는다", equippedCount() <= CatConfig.MaxEquipped,
	("장착 %d / 최대 %d"):format(equippedCount(), CatConfig.MaxEquipped))

lastNotice = nil
-- 장착 안 된 고양이를 하나 찾아 억지로 장착 시도
local unequippedUid
for _, entry in ipairs(latest.Cats) do
	local isOn = false
	for _, uid in ipairs(latest.Equipped) do
		if uid == entry.Uid then isOn = true break end
	end
	if not isOn then unequippedUid = entry.Uid break end
end
if unequippedUid then
	equipRemote:FireServer(unequippedUid)
	Mock.step(0.2)
	checkEqual("가득 찼으면 더 장착되지 않는다", equippedCount(), CatConfig.MaxEquipped)
	check("이유를 알려준다", lastNotice ~= nil and string.find(tostring(lastNotice), "최대") ~= nil,
		tostring(lastNotice))
end

-- 뺐다가 다시 끼우기
local firstEquipped = latest.Equipped[1]
equipRemote:FireServer(firstEquipped)
Mock.step(0.2)
checkEqual("장착 해제된다", equippedCount(), CatConfig.MaxEquipped - 1)
equipRemote:FireServer(firstEquipped)
Mock.step(0.2)
checkEqual("다시 장착된다", equippedCount(), CatConfig.MaxEquipped)

---------------------------------------------------------------
scenario("합성 (같은 고양이 3마리 → 골든)")

-- 치즈냥이는 확률이 높아 3마리 이상 있을 가능성이 크다. 없으면 나올 때까지 뽑는다.
local function countOf(catId)
	local total = 0
	for _, entry in ipairs(latest.Cats) do
		if entry.Id == catId and not entry.Golden then
			total += 1
		end
	end
	return total
end

local guard = 0
while countOf("Cheese") < CatConfig.FuseCount and guard < 60 do
	while coins() < CatConfig.Zones[1].EggCost do
		Mock.step(2)
	end
	hatchRemote:FireServer("Yard", 1)
	Mock.step(0.2)
	guard += 1
end

if countOf("Cheese") >= CatConfig.FuseCount then
	local powerBefore = power()
	local totalBefore = catCount()
	fuseRemote:FireServer("Cheese")
	Mock.step(0.3)

	checkEqual("3마리가 1마리로 합쳐진다", catCount(), totalBefore - CatConfig.FuseCount + 1)

	local hasGolden = false
	for _, entry in ipairs(latest.Cats) do
		if entry.Golden then hasGolden = true break end
	end
	check("골든 고양이가 생겼다", hasGolden)

	local goldenPower = CatConfig.GetCat("Cheese").Power * CatConfig.GoldenMultiplier
	check("골든은 파워가 5배다", goldenPower == CatConfig.GetCat("Cheese").Power * 5,
		tostring(goldenPower))
	note(("합성 전 파워 %d → 후 %d"):format(powerBefore, power()))
end

lastNotice = nil
fuseRemote:FireServer("Rainbow") -- 갖고 있지 않은 고양이
Mock.step(0.2)
check("재료가 모자라면 막힌다", lastNotice ~= nil and string.find(tostring(lastNotice), "필요") ~= nil,
	tostring(lastNotice))

---------------------------------------------------------------
scenario("구역 해금 순서")

lastNotice = nil
unlockRemote:FireServer("Park") -- 뒷골목을 건너뛰고 공원을 열려는 시도
Mock.step(0.2)
check("순서를 건너뛸 수 없다", not zoneUnlocked("Park"))
check("이유를 알려준다", lastNotice ~= nil and string.find(tostring(lastNotice), "먼저") ~= nil,
	tostring(lastNotice))

---------------------------------------------------------------
scenario("환생 조건")

lastNotice = nil
rebirthRemote:FireServer()
Mock.step(0.2)
checkEqual("마지막 구역 전에는 환생 불가", latest.Rebirths, 0)
check("이유를 알려준다", lastNotice ~= nil, tostring(lastNotice))

---------------------------------------------------------------
scenario("숫자 줄여쓰기")

checkEqual("999", BigNumber.Short(999), "999")
checkEqual("1000 → 1K", BigNumber.Short(1000), "1K")
checkEqual("1234 → 1.23K", BigNumber.Short(1234), "1.23K")
checkEqual("12345678 → 12.3M", BigNumber.Short(12345678), "12.3M")
checkEqual("5000000000 → 5B", BigNumber.Short(5e9), "5B")

---------------------------------------------------------------
scenario("자동 플레이: 처음부터 옥상까지 클리어")

-- 사람이 하듯이 논다: 상자를 열 수 있으면 열고, 문을 열 수 있으면 열고,
-- 아니면 서서 부순다. 각 구역 도달 시각을 기록한다.
local milestones = {}
local simSeconds = 0
local SIM_LIMIT = 60 * 90 -- 게임 내 90분까지만 돌려본다

local function currentZoneIndex()
	local best = 1
	for index, zone in ipairs(CatConfig.Zones) do
		if zoneUnlocked(zone.Id) then
			best = index
		end
	end
	return best
end

milestones[CatConfig.Zones[1].Id] = 0
standInZone(CatConfig.Zones[1])

-- 사람이 하는 방식: 새 구역에 오면 상자를 몇 번 열어 파워를 키우고,
-- 그 다음 다음 구역 해금 비용을 모은다. (계속 뽑기만 하면 영원히 못 넘어간다)
local HATCHES_PER_ZONE = 6
local hatchedInZone = {}

while simSeconds < SIM_LIMIT do
	local index = currentZoneIndex()
	local zone = CatConfig.Zones[index]
	local nextZone = CatConfig.Zones[index + 1]
	local hatched = hatchedInZone[zone.Id] or 0

	if hatched < HATCHES_PER_ZONE and coins() >= zone.EggCost then
		hatchRemote:FireServer(zone.Id, 1)
		Mock.step(0.3)
		simSeconds += 0.3
		hatchedInZone[zone.Id] = hatched + 1
	elseif nextZone and coins() >= nextZone.UnlockCost then
		unlockRemote:FireServer(nextZone.Id)
		Mock.step(0.3)
		simSeconds += 0.3
		if zoneUnlocked(nextZone.Id) then
			milestones[nextZone.Id] = simSeconds
			milestones[nextZone.Id .. "_power"] = power()
			standInZone(nextZone)
		end
	else
		Mock.step(5)
		simSeconds += 5
	end

	if zoneUnlocked(CatConfig.Zones[#CatConfig.Zones].Id) then
		break
	end
end

note(("자동 플레이 %d분 경과, 파워 %s, 코인 %s"):format(
	math.floor(simSeconds / 60), BigNumber.Short(power()), BigNumber.Short(coins())))
for _, zone in ipairs(CatConfig.Zones) do
	if milestones[zone.Id] then
		note(("  %-12s 도달 %5.1f분  (파워 %s)"):format(
			zone.Name, milestones[zone.Id] / 60,
			BigNumber.Short(milestones[zone.Id .. "_power"] or 0)))
	else
		note(("  %-12s 도달 못함"):format(zone.Name))
	end
end

check("2번째 구역까지 10분 안에 간다",
	milestones.Alley ~= nil and milestones.Alley <= 600,
	milestones.Alley and ("%.1f분"):format(milestones.Alley / 60) or "도달 못함")
check("마지막 구역까지 90분 안에 간다",
	milestones.Rooftop ~= nil,
	milestones.Rooftop and ("%.1f분"):format(milestones.Rooftop / 60) or "도달 못함")

---------------------------------------------------------------
scenario("퇴장해도 터지지 않는다")

local ok, err = pcall(function()
	Players.PlayerRemoving:Fire(player)
	Mock.step(1)
end)
check("퇴장 처리에 오류 없음", ok, tostring(err))

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
