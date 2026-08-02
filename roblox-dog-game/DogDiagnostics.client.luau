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

	-- Transparency 와 LocalTransparencyModifier 는 별개다.
	-- 후자는 클라이언트에서만 몸을 숨기며(1인칭 처리 등) 서버에는 안 보인다.
	local total, invisible, localHidden = 0, 0, 0
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("BasePart") then
			total = total + 1
			if item.Transparency >= 1 then
				invisible = invisible + 1
			end
			if item.LocalTransparencyModifier >= 1 then
				localHidden = localHidden + 1
			end
		end
	end
	log(string.format("   파트 %d개 | Transparency 투명 %d개 | LocalTransparencyModifier 숨김 %d개",
		total, invisible, localHidden))
	if localHidden > 0 then
		log("   👉 클라이언트에서 몸을 숨기고 있습니다 (1인칭 처리 등)")
	end

	-- ⚠️ MeshId 가 채워져 있어도 실제 다운로드는 실패할 수 있다.
	--    (미게시 place 는 assetdelivery 가 403 을 준다)
	--    따라서 MeshId 유무가 아니라 실제 로딩 성공 여부를 확인해야 한다.
	local ContentProvider = game:GetService("ContentProvider")
	local targets = {}
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("MeshPart") or item:IsA("SpecialMesh") or item:IsA("Decal") then
			table.insert(targets, item)
		end
	end

	if #targets == 0 then
		log("   아바타 메시/텍스처 에셋 없음 (기본 블록 아바타)")
	else
		local okCount, failCount = 0, 0
		local preloaded = pcall(function()
			ContentProvider:PreloadAsync(targets, function(_, status)
				if status == Enum.AssetFetchStatus.Success then
					okCount = okCount + 1
				else
					failCount = failCount + 1
				end
			end)
		end)
		if preloaded then
			log(string.format("   아바타 에셋 %d개 → 다운로드 성공 %d개 / 실패 %d개",
				#targets, okCount, failCount))
			if failCount > 0 then
				log("   👉 몸통 메시를 못 받았습니다. 이래서 캐릭터가 안 보입니다 (게시하면 해결)")
			end
		else
			log("   아바타 에셋 확인 실패 (PreloadAsync 오류)")
		end
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
