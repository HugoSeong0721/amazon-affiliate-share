--!strict
-- Persistent progress via ProfileStore (MadStudioRoblox), which gives us the one
-- thing raw DataStoreService does not: session locking. Without it, two servers
-- holding the same player can overwrite each other and a kid loses their journey.
--
-- SETUP: drop the ProfileStore module in at src/server/Vendor/ProfileStore.luau
-- (or as a .rbxm at ServerScriptService.Server.Vendor.ProfileStore). Until then
-- ProgressService falls back to MemoryBackend and warns on every startup.
--
-- Written against the ProfileStore 1.x API (`:StartSessionAsync`). If you install
-- the older ProfileService instead, the calls are `:LoadProfileAsync`,
-- `:ListenToRelease` and `:Release` — adapt the three marked lines below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local ProgressLogic = require(script.Parent.Parent.ProgressLogic)

local STORE_NAME = "PlayerProgress_v1"

local vendorFolder = script.Parent.Parent:FindFirstChild("Vendor")
local vendored = if vendorFolder then vendorFolder:FindFirstChild("ProfileStore") else nil
local available = vendored ~= nil and vendored:IsA("ModuleScript")

local ProfileStoreBackend = {
	name = "profilestore",
}

function ProfileStoreBackend.isAvailable(): boolean
	return available
end

if available then
	local ProfileStore = require(vendored :: ModuleScript) :: any
	local store = ProfileStore.New(STORE_NAME, ProgressLogic.template())
	local profiles: { [Player]: any } = {}

	function ProfileStoreBackend.load(player: Player): Types.ProgressData?
		local key = `Player_{player.UserId}`

		-- ProfileStore 1.x. (ProfileService: store:LoadProfileAsync(key, "ForceLoad"))
		local profile = store:StartSessionAsync(key, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if not profile then
			-- Another server would not release the lock. Do NOT invent blank data —
			-- that is exactly how progress gets silently erased. Bounce instead.
			player:Kick("잠시 후에 다시 들어와 주세요. (저장한 여정을 불러오지 못했어요)")
			return nil
		end

		profile:AddUserId(player.UserId)
		profile:Reconcile()

		-- ProfileStore 1.x. (ProfileService: profile:ListenToRelease(...))
		profile.OnSessionEnd:Connect(function()
			profiles[player] = nil
			if player.Parent == Players then
				player:Kick("다른 곳에서 접속했어요. 다시 들어와 주세요.")
			end
		end)

		if player.Parent ~= Players then
			profile:EndSession()
			return nil
		end

		profiles[player] = profile
		return ProgressLogic.migrate(profile.Data)
	end

	function ProfileStoreBackend.flush(player: Player)
		local profile = profiles[player]
		if profile and profile.Save then
			profile:Save()
		end
	end

	function ProfileStoreBackend.release(player: Player)
		local profile = profiles[player]
		if not profile then
			return
		end
		profiles[player] = nil
		-- ProfileStore 1.x. (ProfileService: profile:Release())
		profile:EndSession()
	end
end

return ProfileStoreBackend
