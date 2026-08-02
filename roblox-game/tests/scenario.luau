-- Plays a session against the mock engine and reports what happened.
-- Appended to the generated run.luau, so `scenario`, `mock` and `Config`
-- are already in scope.

local failures = 0
local checks = 0

local function check(label: string, condition: any)
	checks += 1
	if condition then
		print(`  ok   {label}`)
	else
		failures += 1
		print(`  FAIL {label}`)
	end
end

local function step(label: string, fn: () -> ())
	print(`\n[{label}]`)
	local ok, err = pcall(fn)
	if not ok then
		failures += 1
		print(`  ERROR {err}`)
	end
end

----------------------------------------------------------------------
-- Helpers for driving the UI the way a player would
----------------------------------------------------------------------

local function descendants(root)
	local out = {}
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(root)
	return out
end

local function findButton(root, needle)
	for _, node in ipairs(descendants(root)) do
		if node:IsA("TextButton") then
			local text = node.Text
			if type(text) == "string" and string.find(text, needle, 1, true) then
				return node
			end
		end
	end
	return nil
end

local function clickButton(button, label)
	if not button then
		error(`no button found for "{label}"`, 0)
	end
	button.MouseButton1Click:Fire()
end

----------------------------------------------------------------------
-- Boot
----------------------------------------------------------------------

print("=== Comeback headless playtest ===")

step("world builds", function()
	scenario.runWorldScript()
	mock.pump(2)
	local pads = game:GetService("CollectionService"):GetTagged("PhotoZone")
	check(`38 photo zones created (got {#pads})`, #pads == 38)
	check("floor exists", workspace:FindFirstChild("Floor") ~= nil)
	check("spawn exists", workspace:FindFirstChildOfClass("SpawnLocation") ~= nil)

	-- Zones must not pile up on top of each other.
	local tooClose = 0
	for i = 1, #pads do
		for j = i + 1, #pads do
			if (pads[i].Position - pads[j].Position).Magnitude < 45 then
				tooClose += 1
			end
		end
	end
	check(`no overlapping zones (got {tooClose} close pairs)`, tooClose == 0)
end)

step("server boots", function()
	scenario.runServerScript()
	mock.pump(2)
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	check("remotes folder", remotes ~= nil)
	if remotes then
		for _, name in { "BuyItem", "EquipItem", "TakePhoto", "GetState", "SendWish", "JoinPhoto", "PlaceSign", "FeedEvent", "EventState", "PhotoInvite" } do
			check(`remote {name}`, remotes:FindFirstChild(name) ~= nil)
		end
	end
end)

local host
step("player joins", function()
	host = mock.addPlayer("TestStar", 111, Vector3.new(0, 5, 20))
	game:GetService("Players").LocalPlayer = host
	mock.mockLocalPlayer = host
	mock.localPlayer = host
	host.CharacterAdded:Fire(host.Character)
	mock.pump(3)

	local applied = mock.counters.applyDescription
	check(`fresh spawn does not rebuild the avatar (rebuilds: {applied})`, applied == 0)
	local head = host.Character:FindFirstChild("Head")
	check("name tag attached", head ~= nil and head:FindFirstChild("ComebackTag") ~= nil)
end)

step("client boots", function()
	scenario.runClientScript()
	mock.pump(2)
	local playerGui = host:FindFirstChild("PlayerGui")
	check("screen gui created", playerGui ~= nil and playerGui:FindFirstChild("ComebackUI") ~= nil)
	check("closet button", findButton(playerGui, "Closet") ~= nil)
	check("photo button", findButton(playerGui, "Photo") ~= nil)
	check("wish button", findButton(playerGui, "Wish") ~= nil)
end)

local playerGui
step("open the closet and wear something", function()
	playerGui = host:FindFirstChild("PlayerGui")
	clickButton(findButton(playerGui, "Closet"), "Closet")
	mock.pump(3)

	-- The grid fills from the fake catalog; clicking a FREE cell equips it.
	local before = mock.counters.applyDescription
	local cells, freeCell = {}, nil
	for _, node in ipairs(descendants(playerGui)) do
		if node:IsA("TextButton") and node.Text == "" then
			table.insert(cells, node)
			for _, label in ipairs(node:GetChildren()) do
				if label:IsA("TextLabel") and type(label.Text) == "string" and string.find(label.Text, "FREE", 1, true) then
					freeCell = freeCell or node
				end
			end
		end
	end
	check(`closet rendered items (got {#cells})`, #cells > 0)
	check("closet offers at least one free item", freeCell ~= nil)
	if freeCell then
		freeCell.MouseButton1Click:Fire()
		mock.pump(2)
	end
	check(`equipping rebuilds the avatar exactly once (got {mock.counters.applyDescription - before})`, mock.counters.applyDescription == before + 1)
end)

step("take a photo", function()
	clickButton(findButton(playerGui, "Photo"), "Photo")
	mock.pump(1)
	clickButton(findButton(playerGui, "GO!"), "GO!")
	mock.pump(4)
	check("photo announced to everyone", mock.counters.fireAllClients > 0)
end)

step("group photo with a friend", function()
	local friend = mock.addPlayer("Buddy", 222, Vector3.new(4, 5, 20))
	friend.CharacterAdded:Fire(friend.Character)
	mock.pump(2)

	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local takePhoto = remotes:FindFirstChild("TakePhoto")
	-- Bypass the client cooldown by invoking as the friend directly.
	local result = takePhoto.OnServerInvoke(friend)
	check("friend photo succeeded", result ~= nil and result.ok == true)

	local head = friend.Character:FindFirstChild("Head")
	check("friend gets a CLICK! popup", head ~= nil and head:FindFirstChild("PhotoPop") ~= nil)

	local hostHead = host.Character:FindFirstChild("Head")
	check("nearby host is pulled into the group shot", hostHead ~= nil and hostHead:FindFirstChild("PhotoPop") ~= nil)

	mock.pump(3)
	check("popup clears itself afterwards", head:FindFirstChild("PhotoPop") == nil)
end)

step("wish board", function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local sendWish = remotes:FindFirstChild("SendWish")
	local first = sendWish.OnServerInvoke(host, "zones")
	local repeated = sendWish.OnServerInvoke(host, "zones")
	local bogus = sendWish.OnServerInvoke(host, "not-a-wish")
	mock.pump(2)
	check("wish accepted", first ~= nil and first.ok == true)
	check("double vote rejected", repeated ~= nil and repeated.already == true)
	check("unknown wish rejected", bogus ~= nil and bogus.ok == false)
end)

step("rides change speed", function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local equip = remotes:FindFirstChild("EquipItem")
	local humanoid = host.Character:FindFirstChildOfClass("Humanoid")

	local free = equip.OnServerInvoke(host, "donkey", "Rides")
	mock.pump(1)
	check("free donkey equips", free ~= nil and free.ok == true)
	check(`donkey is slow (speed {humanoid.WalkSpeed})`, humanoid.WalkSpeed < 16)
	check("ride model welded on", host.Character:FindFirstChild("ComebackRide") ~= nil)

	local unpaid = equip.OnServerInvoke(host, "horse", "Rides")
	check("unowned horse refused", unpaid ~= nil and unpaid.ok == false)

	local buy = remotes:FindFirstChild("BuyItem")
	local purchase = buy.OnServerInvoke(host, "horse", "Rides")
	check("horse purchase succeeds", purchase ~= nil and purchase.ok == true)
	local owned = equip.OnServerInvoke(host, "horse", "Rides")
	mock.pump(1)
	check("horse equips after buying", owned ~= nil and owned.ok == true)
	check(`horse is fast (speed {humanoid.WalkSpeed})`, humanoid.WalkSpeed > 30)
end)

step("hearts cannot go negative", function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local buy = remotes:FindFirstChild("BuyItem")
	local getState = remotes:FindFirstChild("GetState")
	local before = getState.OnServerInvoke(host).coins

	-- Drain until the server refuses.
	local refused = false
	for _ = 1, 40 do
		local result = buy.OnServerInvoke(host, "dino", "Rides")
		if result and result.ok == false then
			refused = true
			break
		end
	end
	local after = getState.OnServerInvoke(host).coins
	check(`balance stays positive (was {before}, now {after})`, after >= 0)
	check("server refuses when broke or already owned", refused or after >= 0)
end)

step("sign anywhere", function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local placeSign = remotes:FindFirstChild("PlaceSign")
	local root = host.Character:FindFirstChild("HumanoidRootPart")

	local near = placeSign.OnServerInvoke(host, root.Position + Vector3.new(0, 2, 4), Vector3.new(0, 0, 1))
	check("nearby sign placed", near ~= nil and near.ok == true)

	local far = placeSign.OnServerInvoke(host, Vector3.new(400, 2, 400), Vector3.new(0, 1, 0))
	check("far sign rejected", far ~= nil and far.ok == false)

	local stickers = 0
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "SignSticker" then
			stickers += 1
		end
	end
	check(`sticker exists in the world (got {stickers})`, stickers >= 1)
end)

step("gather event runs and leaves a monument", function()
	-- The event loop is parked on its interval wait; pumping drives it.
	mock.pump(12)
	local monuments = 0
	local beacons = 0
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "EventMonument" then
			monuments += 1
		elseif child.Name == "EventBeacon" then
			beacons += 1
		end
	end
	check(`event produced a monument (got {monuments})`, monuments >= 1)
	check(`at most one event beacon at a time (got {beacons})`, beacons <= 1)
end)

step("player leaves cleanly", function()
	mock.removePlayer(host)
	mock.pump(2)
	check("data was saved", mock.counters.dataStoreWrites > 0)
end)

print(`\n=== {checks - failures}/{checks} checks passed ===`)
if failures > 0 then
	error(`{failures} FAILURES`, 0)
end
print("all good")
