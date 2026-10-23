-- Plots (v0.3): 6 plots per server in 2 rows x 3 columns, one per player.
-- Each plot is a GridSize x GridSize tile floor (TileStuds per tile) with grid lines.
-- Tile (0, 0) is the plot's minimum-X / minimum-Z corner; tile X runs along +X, tile Y along +Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Base.WorldConfig)

local PlotService = {}

local SIDE = WorldConfig.GridSize * WorldConfig.TileStuds -- 176 studs
local PITCH = SIDE + 2 * WorldConfig.PlotBorderStuds -- centre-to-centre spacing
local FLOOR_TOP = 1 -- studs; sits on top of a standard baseplate (top at 0)
local COLUMNS = 3

local plots: { { Index: number, Model: Model, Corner: Vector3, Owner: Player? } } = {}

local function line(parent: Instance, size: Vector3, position: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(70, 122, 59)
	p.Size = size
	p.Position = position
	p.Parent = parent
end

local function buildPlot(index: number): Model
	local row = (index - 1) // COLUMNS
	local col = (index - 1) % COLUMNS
	local centre = Vector3.new((col - (COLUMNS - 1) / 2) * PITCH, 0, (row - 0.5) * PITCH)
	local model = Instance.new("Model")
	model.Name = `Plot_{index}`

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(63, 110, 53)
	floor.Size = Vector3.new(SIDE, 1, SIDE)
	floor.Position = centre + Vector3.new(0, FLOOR_TOP - 0.5, 0)
	floor.Parent = model

	local lines = Instance.new("Folder")
	lines.Name = "GridLines"
	lines.Parent = model
	local corner = centre - Vector3.new(SIDE / 2, 0, SIDE / 2)
	local y = FLOOR_TOP + 0.03
	for i = 0, WorldConfig.GridSize do
		local offset = i * WorldConfig.TileStuds
		line(lines, Vector3.new(0.15, 0.05, SIDE), Vector3.new(corner.X + offset, y, centre.Z))
		line(lines, Vector3.new(SIDE, 0.05, 0.15), Vector3.new(centre.X, y, corner.Z + offset))
	end

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = model

	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("Corner", Vector3.new(corner.X, FLOOR_TOP, corner.Z))
	return model
end

function PlotService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	for i = 1, WorldConfig.PlotsPerServer do
		local model = buildPlot(i)
		model.Parent = folder
		table.insert(plots, { Index = i, Model = model, Corner = model:GetAttribute("Corner"), Owner = nil })
	end
	folder.Parent = workspace
end

-- First free plot in index order, or nil when all are taken.
function PlotService.Assign(player: Player)
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			-- StreamingEnabled + no character: stream around the player's own plot instead.
			player.ReplicationFocus = plot.Model:FindFirstChild("Floor") :: BasePart
			return plot
		end
	end
	return nil
end

function PlotService.Release(player: Player)
	for _, plot in plots do
		if plot.Owner == player then
			plot.Owner = nil
			plot.Model:SetAttribute("OwnerUserId", nil)
			plot.Model.Buildings:ClearAllChildren()
		end
	end
end

return PlotService
