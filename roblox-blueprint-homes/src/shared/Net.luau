--!strict
-- Remote registry. The server creates every remote on first require;
-- the client waits for them. Both sides address remotes by name only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- (message: string, kind: "info"|"good"|"bad")
	"MoneyChanged", -- (newBalance: number)
	"PlotAssigned", -- (plotModel: Model, originVector: Vector3)
}

local FUNCTIONS = {
	"PlaceItem", -- (itemId, x, z, r) -> {ok, err?, money?}
	"RemoveItem", -- (uid) -> {ok, err?, money?}
	"PublishBlueprint", -- (name, price) -> {ok, err?, meta?}
	"GetMarket", -- (tab: "top"|"new") -> {ok, listings?}
	"BuyBlueprint", -- (blueprintId) -> {ok, err?, money?}
	"ApplyBlueprint", -- (blueprintId) -> {ok, err?, money?, materialCost?}
	"GetMyBlueprints", -- () -> {ok, published?, owned?}
	"GetBalance", -- () -> number
}

local Net = {}

local folder: Folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(EVENTS) do
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
	end
	for _, name in ipairs(FUNCTIONS) do
		local fn = Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
