--!strict
-- Blueprint Homes - client bootstrap.

local UI = require(script.UI)
local BuildController = require(script.BuildController)

UI.Init()
BuildController.Init(UI)

print("[BlueprintHomes] client ready")
