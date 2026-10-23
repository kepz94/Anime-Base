-- Placement (v0.3): ghost footprint that follows the pointer over the player's plot.
-- Green = Grid.CanPlace accepts the tile locally; red = it does not. The server re-validates.
-- Modes: "place" (new building, BuildingId) and "move" (existing building, Uid).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Base.Grid)
local WorldConfig = require(Shared.Base.WorldConfig)
local Catalog = require(Shared.Base.Catalog)
local Config = require(Shared.Config)
local Remotes = require(Shared.Net.Remotes)

local StateClient = require(script.Parent.StateClient)
local BaseCamera = require(script.Parent.BaseCamera)

local Placement = {}

local catalog = Catalog.new(Config.Data.Buildings, Config.Data.BuildingLevels, Config.Data.Economy)
local remotes = ReplicatedStorage:WaitForChild(Remotes.FolderName)

local GREEN = Color3.fromRGB(87, 209, 139)
local RED = Color3.fromRGB(255, 107, 107)

local active: { Mode: string, BuildingId: string, Uid: number?, Size: number, X: number?, Y: number? }? = nil
local ghost: Part? = nil

local finished = Instance.new("BindableEvent")
Placement.Finished = finished.Event -- fires (ok, reason?, mode)

local function footprints(ignoreUid: number?)
	local out = {}
	local state = StateClient.Get()
	for _, b in state.Profile.Buildings do
		if b.Uid ~= ignoreUid then
			local size = tonumber(string.match(catalog:Building(b.BuildingId).Footprint, "^(%d+)x"))
			table.insert(out, { Uid = b.Uid, X = b.X, Y = b.Y, Size = size })
		end
	end
	return out
end

local function sizeOf(buildingId: string): number
	return tonumber(string.match(catalog:Building(buildingId).Footprint, "^(%d+)x")) :: number
end

local function drawGhost()
	local a = active
	if a == nil or a.X == nil then
		return
	end
	local state = StateClient.Get()
	local corner = state.Plot.Corner
	local ok = Grid.CanPlace(footprints(a.Uid), a.X, a.Y, a.Size, WorldConfig.GridSize)
	if ghost == nil then
		local g = Instance.new("Part")
		g.Name = "PlacementGhost"
		g.Anchored = true
		g.CanCollide = false
		g.CanQuery = false
		g.CanTouch = false
		g.Material = Enum.Material.SmoothPlastic
		g.Transparency = 0.35
		g.Parent = workspace.CurrentCamera
		ghost = g
	end
	local g = ghost :: Part
	local dx, dz = Grid.TileCenterOffset(a.X, a.Y :: number, a.Size, WorldConfig.TileStuds)
	g.Size = Vector3.new(a.Size * WorldConfig.TileStuds, 1, a.Size * WorldConfig.TileStuds)
	g.Position = corner + Vector3.new(dx, 0.6, dz)
	g.Color = if ok then GREEN else RED
end

-- Moves the ghost so its footprint is centred under a screen position (clamped to the plot).
function Placement.PointAt(screen: Vector2)
	local a = active
	if a == nil then
		return
	end
	local p = BaseCamera.GroundPoint(screen)
	if p == nil then
		return
	end
	local corner = StateClient.Get().Plot.Corner
	local tx = math.floor((p.X - corner.X) / WorldConfig.TileStuds - a.Size / 2 + 0.5)
	local ty = math.floor((p.Z - corner.Z) / WorldConfig.TileStuds - a.Size / 2 + 0.5)
	a.X = math.clamp(tx, 0, WorldConfig.GridSize - a.Size)
	a.Y = math.clamp(ty, 0, WorldConfig.GridSize - a.Size)
	drawGhost()
end

function Placement.Active(): boolean
	return active ~= nil
end

function Placement.Cancel()
	active = nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
end

function Placement.BeginPlace(buildingId: string)
	Placement.Cancel()
	active = { Mode = "place", BuildingId = buildingId, Uid = nil, Size = sizeOf(buildingId) }
	-- GetMouseLocation includes the top-bar inset; PointAt takes inset-excluded coordinates.
	local inset = GuiService:GetGuiInset()
	Placement.PointAt(UserInputService:GetMouseLocation() - inset)
end

function Placement.BeginMove(uid: number)
	local b = StateClient.Get().Profile.Buildings[tostring(uid)]
	if b == nil then
		return
	end
	Placement.Cancel()
	active = { Mode = "move", BuildingId = b.BuildingId, Uid = uid, Size = sizeOf(b.BuildingId), X = b.X, Y = b.Y }
	drawGhost()
end

-- Sends the request for the current ghost tile. On success the ghost is removed; on rejection it
-- stays where it is so the player can try another tile.
function Placement.Confirm(screen: Vector2)
	local a = active
	if a == nil then
		return
	end
	Placement.PointAt(screen)
	if a.X == nil then
		return
	end
	local result
	if a.Mode == "place" then
		result = remotes.Place:InvokeServer(a.BuildingId, a.X, a.Y)
	else
		result = remotes.Move:InvokeServer(a.Uid, a.X, a.Y)
	end
	if result.ok then
		Placement.Cancel()
	end
	finished:Fire(result.ok, result.reason, a.Mode)
end

UserInputService.InputChanged:Connect(function(input)
	if active and input.UserInputType == Enum.UserInputType.MouseMovement then
		Placement.PointAt(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

return Placement
