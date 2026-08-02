--[[
	🔍 진단 스크립트 (임시)

	"내 캐릭터가 안 보인다" 의 원인을 확정하기 위한 스크립트입니다.
	Play 후 5초 뒤 Output 창에 진단 결과가 출력됩니다.

	원인이 해결되면 이 스크립트는 지워도 됩니다
	(Explorer > StarterPlayer > StarterPlayerScripts > DogDiagnostics 삭제).
]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local player = Players.LocalPlayer

task.wait(5) -- 캐릭터와 아바타 에셋이 로딩될 시간을 준다

local lines = {}
local function log(text)
	table.insert(lines, text)
end

----------------------------------------------------------------------
-- 1. 게시 여부 (PlaceId 가 0 이면 에셋을 못 불러온다)
----------------------------------------------------------------------
log(string.format("PlaceId = %d   %s", game.PlaceId,
	game.PlaceId == 0 and "❌ 미게시 상태 (아바타/애니메이션 로딩 불가)" or "✅ 게시됨"))

----------------------------------------------------------------------
-- 2. 캐릭터가 존재하는가, 몸이 보이는 상태인가
----------------------------------------------------------------------
local character = player.Character
if not character then
	log("❌ player.Character 가 nil — 캐릭터가 아예 스폰되지 않았습니다")
else
	log(string.format("✅ 캐릭터 존재: %s", character.Name))

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		log(string.format("   Humanoid RigType = %s, 상태 = %s",
			tostring(humanoid.RigType), tostring(humanoid:GetState())))
	else
		log("   ❌ Humanoid 없음")
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	log(string.format("   위치 = %s", root and tostring(root.Position) or "HumanoidRootPart 없음"))

	local total, invisible, emptyMesh = 0, 0, 0
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("BasePart") then
			total = total + 1
			if item.Transparency >= 1 then
				invisible = invisible + 1
			end
			if item:IsA("MeshPart") and item.MeshId == "" then
				emptyMesh = emptyMesh + 1
			end
		end
	end
	log(string.format("   파트 %d개 | 완전투명 %d개 | 메시 로딩 실패 %d개", total, invisible, emptyMesh))
	if total > 0 and invisible == total then
		log("   👉 모든 파트가 투명합니다")
	elseif emptyMesh > 0 then
		log("   👉 아바타 메시를 못 불러왔습니다 (게시하면 해결)")
	end
end

----------------------------------------------------------------------
-- 3. 카메라 — 1인칭이면 자기 몸이 안 보이는 게 정상이다
----------------------------------------------------------------------
local camera = workspace.CurrentCamera
log(string.format("카메라 모드 = %s | 줌 범위 %.1f ~ %.1f",
	tostring(StarterPlayer.CameraMode),
	StarterPlayer.CameraMinZoomDistance,
	StarterPlayer.CameraMaxZoomDistance))
log(string.format("CameraSubject = %s",
	camera.CameraSubject and camera.CameraSubject:GetFullName() or "없음"))

if character and character:FindFirstChild("HumanoidRootPart") then
	local distance = (camera.CFrame.Position - character.HumanoidRootPart.Position).Magnitude
	log(string.format("카메라 ↔ 캐릭터 거리 = %.1f studs   %s", distance,
		distance < 3 and "❌ 1인칭 시점입니다 (그래서 몸이 안 보임)" or "✅ 3인칭"))
end

----------------------------------------------------------------------
-- 출력
----------------------------------------------------------------------
print("")
print("===== 🐶 진단 결과 — 이 블록을 복사해서 알려주세요 =====")
for _, line in ipairs(lines) do
	print("  " .. line)
end
print("=========================================================")
print("")
