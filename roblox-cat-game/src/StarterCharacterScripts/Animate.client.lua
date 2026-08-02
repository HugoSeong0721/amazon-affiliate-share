-- Animate (LocalScript / StarterPlayer > StarterCharacterScripts)
--
-- 로블록스 기본 Animate 스크립트를 대체한다.
-- 기본 스크립트는 걷기·점프 애니메이션을 rbxassetid로 인터넷에서 받아오는데,
-- 게시하지 않은 place에서는 그 요청이 전부 막혀 콘솔에 오류가 수십 개 쌓인다.
-- (StarterCharacterScripts에 같은 이름의 스크립트가 있으면 기본 것이 들어오지 않는다.)
--
-- 대신 관절(Motor6D)을 직접 돌려서 걷는 모습을 만든다. 다운로드가 없다.

local RunService = game:GetService("RunService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local torso = character:WaitForChild("Torso")

local JOINT_NAMES = { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

local joints = {}
local restC0 = {}
for _, name in ipairs(JOINT_NAMES) do
	local motor = torso:WaitForChild(name, 10)
	if not motor then
		return -- R6 리그가 아니면 아무것도 하지 않는다
	end
	joints[name] = motor
	restC0[name] = motor.C0
end

-- 어깨/엉덩이 관절의 로컬 Z축은 좌우가 서로 반대 방향을 향한다.
-- 같은 부호를 주면 팔다리가 서로 엇갈리고(걷기), 부호를 뒤집으면 나란히 움직인다.
local WALK_SPEED_REFERENCE = 16 -- 기본 걷기 속도
local MAX_SWING = 0.9 -- 최대 스윙 각(라디안)

local phase = 0
local swingScale = 0

RunService.RenderStepped:Connect(function(dt)
	local velocity = rootPart.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local airborne = humanoid.FloorMaterial == Enum.Material.Air

	-- 멈추면 팔다리가 툭 끊기지 않고 부드럽게 제자리로 돌아오도록
	local target = airborne and 0 or math.clamp(speed / WALK_SPEED_REFERENCE, 0, 1)
	swingScale = swingScale + (target - swingScale) * math.min(dt * 10, 1)
	phase = phase + dt * math.clamp(speed, 0, 24) * 1.1

	local swing = math.sin(phase) * swingScale * MAX_SWING
	local jumpPose = airborne and 1.2 or 0 -- 공중에서는 두 팔을 앞으로 든다

	joints["Right Shoulder"].C0 = restC0["Right Shoulder"] * CFrame.Angles(0, 0, swing + jumpPose)
	joints["Left Shoulder"].C0 = restC0["Left Shoulder"] * CFrame.Angles(0, 0, swing - jumpPose)
	joints["Right Hip"].C0 = restC0["Right Hip"] * CFrame.Angles(0, 0, -swing)
	joints["Left Hip"].C0 = restC0["Left Hip"] * CFrame.Angles(0, 0, -swing)
end)
