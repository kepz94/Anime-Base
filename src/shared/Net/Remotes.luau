-- Remote names (v0.3). The server creates these under ReplicatedStorage.Remotes at start;
-- the client waits for them. One RemoteFunction per base action, one RemoteEvent for state.

return {
	FolderName = "Remotes",
	Actions = { "PickFaction", "Place", "Move", "StartUpgrade", "CancelUpgrade", "Collect", "Sell" },
	State = "BaseState", -- server -> client: { Profile, Summary, ServerTime, Plot = { Index, Corner } }
	GetState = "GetState", -- client -> server on start (the first push can arrive before the client listens)
}
