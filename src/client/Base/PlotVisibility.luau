-- Plot visibility (v0.3): other players' plots are not viewable (owner decision 2026-10-23).
-- Hides every plot except the local player's, on this client only, including parts that stream in later.

local PlotVisibility = {}

local ownIndex: number? = nil
local connections: { RBXScriptConnection } = {}

local function apply(inst: Instance, hidden: boolean)
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = if hidden then 1 else 0
	elseif inst:IsA("BillboardGui") then
		inst.Enabled = not hidden
	end
end

local function watch(plot: Instance)
	local hidden = plot:GetAttribute("PlotIndex") ~= ownIndex
	for _, d in plot:GetDescendants() do
		apply(d, hidden)
	end
	table.insert(connections, plot.DescendantAdded:Connect(function(d)
		apply(d, plot:GetAttribute("PlotIndex") ~= ownIndex)
	end))
end

function PlotVisibility.ShowOnly(plotIndex: number)
	if ownIndex == plotIndex then
		return
	end
	ownIndex = plotIndex
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watch(plot)
	end
	table.insert(connections, plots.ChildAdded:Connect(watch))
end

return PlotVisibility
