-- Base client entry (v0.3): receives base state, frames and drives the camera on the player's own
-- plot, selection, placement and moves. The HUD (layout A) comes with AB-10.
-- Clicks (press + release without dragging): placement active -> confirm the ghost tile;
-- otherwise -> select the building under the pointer (or clear the selection).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Catalog = require(Shared.Base.Catalog)
local Config = require(Shared.Config)

local BaseCamera = require(script.Parent.Base.BaseCamera)
local PlotVisibility = require(script.Parent.Base.PlotVisibility)
local StateClient = require(script.Parent.Base.StateClient)
local Selection = require(script.Parent.Base.Selection)
local Placement = require(script.Parent.Base.Placement)
local DevKeys = require(script.Parent.Base.DevKeys)

local catalog = Catalog.new(Config.Data.Buildings, Config.Data.BuildingLevels, Config.Data.Economy)
local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
local stateEvent = folder:WaitForChild(Remotes.State) :: RemoteEvent
local getState = folder:WaitForChild(Remotes.GetState) :: RemoteFunction

local framedCorner: Vector3? = nil

local function onState(state)
	if state == nil then
		return
	end
	StateClient.Set(state)
	local corner = state.Plot.Corner
	if framedCorner ~= corner then
		framedCorner = corner
		BaseCamera.FramePlot(corner)
		PlotVisibility.ShowOnly(state.Plot.Index)
		local plot = workspace:WaitForChild("Plots"):WaitForChild(`Plot_{state.Plot.Index}`)
		Selection.Track(plot:WaitForChild("Buildings"))
		print(`[Client] Base state: plot {state.Plot.Index}, Town Hall {state.Summary.TownHall}, Coins {state.Profile.Coins}`)
	end
	-- A selected building that no longer exists (e.g. cancelled construction) is deselected.
	local uid = Selection.Get()
	if uid and state.Profile.Buildings[tostring(uid)] == nil then
		Selection.Set(nil)
	end
end

stateEvent.OnClientEvent:Connect(onState)

BaseCamera.Clicked:Connect(function(screen: Vector2)
	if Placement.Active() then
		Placement.Confirm(screen)
	else
		Selection.Set(Selection.PartAt(screen))
	end
end)

Placement.Finished:Connect(function(ok: boolean, reason: string?, mode: string)
	-- Shown as a toast once the HUD exists (AB-10).
	print(`[Client] {mode} -> {if ok then "OK" else "rejected: " .. tostring(reason)}`)
end)

DevKeys.Init(function(buildingType: string, resourceType: string?)
	local state = StateClient.Get()
	return state and state.Profile.Faction and catalog:FindByType(state.Profile.Faction, buildingType, resourceType)
end, Placement, Selection)

-- First state: ask until the server has created the session (plot + DataStore load), up to 15 s.
-- The server also pushes state when the load finishes.
for _ = 1, 60 do
	local state = getState:InvokeServer()
	if state then
		onState(state)
		break
	end
	task.wait(0.25)
end
