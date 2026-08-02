-- CharacterSetup (Script / ServerScriptService)
--
-- 왜 이 스크립트가 필요한가
--   게시(publish)하지 않은 place 파일은 PlaceId가 0이라서, 플레이 중 로블록스
--   에셋 서버에 보내는 요청이 전부 거부된다(콘솔의 serverplaceid=0 오류).
--   기본 아바타는 몸통이 MeshPart라 인터넷에서 받아와야 하는데, 그게 실패하면
--   HumanoidRootPart만 남아 캐릭터가 통째로 안 보인다.
--
--   그래서 이 게임은 고양이와 마찬가지로 캐릭터도 파츠로 직접 조립한다.
--   에셋을 하나도 받지 않으므로 게시 전에도, 오프라인에서도 항상 보인다.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

-- 우리가 만든 리그로만 스폰시킨다
Players.CharacterAutoLoads = false
StarterPlayer.LoadCharacterAppearance = false -- 옷·액세서리도 에셋이라 끈다

local SKIN = Color3.fromRGB(253, 205, 106)
local SHIRT = Color3.fromRGB(87, 141, 216)
local PANTS = Color3.fromRGB(63, 74, 94)
local EYE = Color3.fromRGB(20, 20, 20)
local HALF = math.pi / 2

---------------------------------------------------------------
-- R6 규격 그대로의 블록 캐릭터를 만든다
-- (파츠 이름·크기·관절 위치가 R6 표준이라 Humanoid가 그대로 인식한다)
---------------------------------------------------------------
local function buildStarterCharacter()
	local model = Instance.new("Model")
	model.Name = "StarterCharacter"

	local function addPart(name, size, color, position)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(position)
		part.Parent = model
		return part
	end

	local root = addPart("HumanoidRootPart", Vector3.new(2, 2, 1), SKIN, Vector3.new(0, 3, 0))
	root.Transparency = 1
	root.CanCollide = false

	local torso = addPart("Torso", Vector3.new(2, 2, 1), SHIRT, Vector3.new(0, 3, 0))
	local head = addPart("Head", Vector3.new(2, 1, 1), SKIN, Vector3.new(0, 4.5, 0))
	local leftArm = addPart("Left Arm", Vector3.new(1, 2, 1), SKIN, Vector3.new(-1.5, 3, 0))
	local rightArm = addPart("Right Arm", Vector3.new(1, 2, 1), SKIN, Vector3.new(1.5, 3, 0))
	local leftLeg = addPart("Left Leg", Vector3.new(1, 2, 1), PANTS, Vector3.new(-0.5, 1, 0))
	local rightLeg = addPart("Right Leg", Vector3.new(1, 2, 1), PANTS, Vector3.new(0.5, 1, 0))

	-- 머리는 기본 아바타와 같은 둥근 모양 (내장 메시라 다운로드가 없다)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	-- 얼굴도 이미지(Decal)를 쓰면 에셋이 되므로 작은 파츠로 눈을 붙인다
	for _, offsetX in ipairs({ -0.32, 0.32 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.16, 0.2, 0.1)
		eye.Color = EYE
		eye.Material = Enum.Material.SmoothPlastic
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(offsetX, 0.12, -0.6)
		eye.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
	end

	local function addMotor(name, part0, part1, c0, c1, parent)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = parent
	end

	addMotor("RootJoint", root, torso,
		CFrame.new(0, 0, 0) * CFrame.Angles(-HALF, 0, math.pi),
		CFrame.new(0, 0, 0) * CFrame.Angles(-HALF, 0, math.pi), root)
	addMotor("Neck", torso, head,
		CFrame.new(0, 1, 0) * CFrame.Angles(-HALF, 0, math.pi),
		CFrame.new(0, -0.5, 0) * CFrame.Angles(-HALF, 0, math.pi), torso)
	addMotor("Right Shoulder", torso, rightArm,
		CFrame.new(1, 0.5, 0) * CFrame.Angles(0, HALF, 0),
		CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, HALF, 0), torso)
	addMotor("Left Shoulder", torso, leftArm,
		CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -HALF, 0),
		CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -HALF, 0), torso)
	addMotor("Right Hip", torso, rightLeg,
		CFrame.new(1, -1, 0) * CFrame.Angles(0, HALF, 0),
		CFrame.new(0.5, 1, 0) * CFrame.Angles(0, HALF, 0), torso)
	addMotor("Left Hip", torso, leftLeg,
		CFrame.new(-1, -1, 0) * CFrame.Angles(0, -HALF, 0),
		CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -HALF, 0), torso)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local existing = StarterPlayer:FindFirstChild("StarterCharacter")
if existing then
	existing:Destroy()
end
buildStarterCharacter().Parent = StarterPlayer

---------------------------------------------------------------
-- 스폰 / 리스폰 (CharacterAutoLoads를 껐으니 직접 불러준다)
---------------------------------------------------------------
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)

	-- defer: 다른 스크립트들이 CharacterAdded를 연결할 틈을 준 뒤 스폰시킨다
	task.defer(function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
