-- Client copy of the latest base state from the server (v0.3). Read-only on the client:
-- every change goes through a remote and comes back as a new state.

local StateClient = {}

local current = nil
local changed = Instance.new("BindableEvent")

StateClient.Changed = changed.Event -- fires (state)

function StateClient.Set(state)
	current = state
	changed:Fire(state)
end

function StateClient.Get()
	return current
end

return StateClient
