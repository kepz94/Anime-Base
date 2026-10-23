-- Base client entry (v0.3): receives base state and frames the camera on the player's own plot.
-- Placement, edit mode and the HUD (layout A) come with AB-9 / AB-10.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local BaseCamera = require(script.Parent.Base.BaseCamera)
local PlotVisibility = require(script.Parent.Base.PlotVisibility)

local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
local stateEvent = folder:WaitForChild(Remotes.State) :: RemoteEvent
local getState = folder:WaitForChild(Remotes.GetState) :: RemoteFunction

local framedCorner: Vector3? = nil

local function onState(state)
	if state == nil then
		return
	end
	local corner = state.Plot.Corner
	if framedCorner ~= corner then
		framedCorner = corner
		BaseCamera.FramePlot(corner)
		PlotVisibility.ShowOnly(state.Plot.Index)
		print(`[Client] Base state: plot {state.Plot.Index}, Town Hall {state.Summary.TownHall}, Coins {state.Profile.Coins}`)
	end
end

stateEvent.OnClientEvent:Connect(onState)

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
