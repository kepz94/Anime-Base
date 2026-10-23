-- Base renderer (v0.3): one placeholder block per building, sized to its footprint, labelled by
-- building type (names are undecided) with level, or a timer while a builder is working on it.
-- Rebuilds the plot's Buildings folder from the profile on every call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grid = require(ReplicatedStorage.Shared.Base.Grid)
local WorldConfig = require(ReplicatedStorage.Shared.Base.WorldConfig)

local BaseRenderer = {}

local GAP = 0.4 -- studs left between neighbouring blocks
local STYLE = { -- [BuildingType] = { height in studs, colour }
	["Town Hall"] = { 9, Color3.fromRGB(232, 201, 160) },
	["Builder Hut"] = { 4, Color3.fromRGB(201, 178, 138) },
	["Market"] = { 6, Color3.fromRGB(244, 210, 122) },
	["Collector"] = { 5, Color3.fromRGB(240, 163, 58) },
	["Storage"] = { 6, Color3.fromRGB(217, 138, 43) },
	["Army Camp"] = { 3, Color3.fromRGB(156, 195, 230) },
	["Barracks"] = { 6, Color3.fromRGB(231, 154, 154) },
	["Laboratory"] = { 7, Color3.fromRGB(143, 224, 200) },
	["Wall"] = { 3, Color3.fromRGB(191, 198, 214) },
	["Hero Hall"] = { 7, Color3.fromRGB(200, 160, 230) },
}
local ESSENCE_COLOUR = { Collector = Color3.fromRGB(169, 155, 255), Storage = Color3.fromRGB(125, 107, 239) }

local function label(def): string
	return if def.ResourceType then `{def.ResourceType} {def.BuildingType}` else def.BuildingType
end

local function timeLeft(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return `{seconds}s`
	elseif seconds < 3600 then
		return `{seconds // 60}m {seconds % 60}s`
	end
	return `{seconds // 3600}h {(seconds % 3600) // 60}m`
end

function BaseRenderer.Render(plotModel: Model, corner: Vector3, profile, catalog, now: number)
	local folder = plotModel:FindFirstChild("Buildings") :: Folder
	folder:ClearAllChildren()
	for key, b in profile.Buildings do
		local def = catalog:Building(b.BuildingId)
		local size = tonumber(string.match(def.Footprint, "^(%d+)x")) :: number
		local style = STYLE[def.BuildingType] or { 5, Color3.fromRGB(180, 180, 180) }
		local height = if b.Level == 0 then 1.5 else style[1]
		local dx, dz = Grid.TileCenterOffset(b.X, b.Y, size, WorldConfig.TileStuds)

		local part = Instance.new("Part")
		part.Name = `{label(def)} #{key}`
		part.Anchored = true
		part.Material = Enum.Material.SmoothPlastic
		part.Color = if def.ResourceType == "Essence" and ESSENCE_COLOUR[def.BuildingType] then ESSENCE_COLOUR[def.BuildingType] else style[2]
		part.Size = Vector3.new(size * WorldConfig.TileStuds - GAP, height, size * WorldConfig.TileStuds - GAP)
		part.Position = corner + Vector3.new(dx, height / 2, dz)
		part:SetAttribute("Uid", b.Uid)
		part:SetAttribute("BuildingId", b.BuildingId)
		part:SetAttribute("Level", b.Level)

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(150, 40)
		gui.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 2, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 1000
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 14
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.4
		local status = if b.UpgradeEndsAt then (if b.Level == 0 then "building " else `L{b.Level} → L{b.Level + 1} `) .. timeLeft(b.UpgradeEndsAt - now) else `L{b.Level}`
		text.Text = `{label(def)}\n{status}`
		text.Parent = gui
		gui.Parent = part

		part.Parent = folder
	end
end

return BaseRenderer
