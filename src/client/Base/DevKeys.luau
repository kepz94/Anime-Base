-- TEMPORARY (v0.3, until the layout A HUD in AB-10): Studio-only keys to start placement and moves.
-- Delete this module and its require in BaseClient.client.luau when the HUD lands.
--   1 Ore Collector   2 Essence Collector   3 Ore Storage   4 Essence Storage   5 Army Camp   6 Barracks
--   M move the selected building   Esc / right-click cancel

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DevKeys = {}

local KEYS = {
	[Enum.KeyCode.One] = { "Collector", "Ore" },
	[Enum.KeyCode.Two] = { "Collector", "Essence" },
	[Enum.KeyCode.Three] = { "Storage", "Ore" },
	[Enum.KeyCode.Four] = { "Storage", "Essence" },
	[Enum.KeyCode.Five] = { "Army Camp" },
	[Enum.KeyCode.Six] = { "Barracks" },
}

-- findId(buildingType, resourceType?) -> BuildingId for the player's faction.
function DevKeys.Init(findId, Placement, Selection)
	if not RunService:IsStudio() then
		return
	end
	print("[DevKeys] Studio test keys: 1-6 place a building, M move selected, Esc cancel (temporary until the HUD)")
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local spec = KEYS[input.KeyCode]
		if spec then
			local id = findId(spec[1], spec[2])
			if id then
				Placement.BeginPlace(id)
			end
		elseif input.KeyCode == Enum.KeyCode.M then
			local uid = Selection.Get()
			if uid then
				Placement.BeginMove(uid)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
			Placement.Cancel()
		end
	end)
end

return DevKeys
