--!strict
-- Runs on server start in Studio only. Auto-discovers every *.spec module next to
-- it, so a new spec file needs no registration.

local RunService = game:GetService("RunService")

if RunService:IsStudio() then
	local Runner = require(script.Parent.Runner)

	local specs: { ModuleScript } = {}
	for _, child in script.Parent:GetChildren() do
		if child:IsA("ModuleScript") and string.match(child.Name, "%.spec$") then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)

	Runner.run(specs)
end
