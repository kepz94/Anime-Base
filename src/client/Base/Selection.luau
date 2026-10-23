-- Selection (v0.3): the building the player tapped. Highlighted locally; the highlight is
-- re-applied when the server re-renders the plot (blocks are rebuilt on every render).

local Selection = {}

local selectedUid: number? = nil
local plotFolder: Folder? = nil
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded

local changed = Instance.new("BindableEvent")
Selection.Changed = changed.Event -- fires (uid?)

local function reapply()
	highlight.Adornee = nil
	highlight.Parent = nil
	if selectedUid == nil or plotFolder == nil then
		return
	end
	for _, part in plotFolder:GetChildren() do
		if part:GetAttribute("Uid") == selectedUid then
			highlight.Adornee = part
			highlight.Parent = part
			return
		end
	end
end

function Selection.Track(buildingsFolder: Folder)
	plotFolder = buildingsFolder
	buildingsFolder.ChildAdded:Connect(function()
		task.defer(reapply)
	end)
end

function Selection.Set(uid: number?)
	selectedUid = uid
	reapply()
	changed:Fire(uid)
end

function Selection.Get(): number?
	return selectedUid
end

-- Uid of the building block under a screen position, or nil.
function Selection.PartAt(screen: Vector2): number?
	if plotFolder == nil then
		return nil
	end
	local ray = workspace.CurrentCamera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plotFolder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	return hit and hit.Instance:GetAttribute("Uid") or nil
end

return Selection
