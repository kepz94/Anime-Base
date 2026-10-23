-- Base service (v0.3): owns each player's profile on this server, runs base actions from remotes,
-- re-renders the plot and pushes state to the client. Every request and completion is traced.
-- Profiles load from / save to PlayerStore: on join, every AUTOSAVE_SECONDS, on leave, on shutdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Actions = require(Shared.Base.Actions)
local Catalog = require(Shared.Base.Catalog)
local Remotes = require(Shared.Net.Remotes)
local Config = require(Shared.Config)

local BaseRenderer = require(script.Parent.BaseRenderer)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local Trace = require(script.Parent.Parent.Diagnostics.Trace)
local DevFlags = require(script.Parent.Parent.DevFlags)
local PlayerStore = require(script.Parent.Parent.Data.PlayerStore)

local BaseService = {}

local MAX_CALLS_PER_SECOND = 20
local AUTOSAVE_SECONDS = 60
local KICK_LOCKED = "Your base is open on another server. Please try again in a moment."
local KICK_LOAD_FAILED = "Your base could not be loaded. Please rejoin."
local KICK_LOCK_LOST = "Your base was opened on another server."

local catalog = Catalog.new(Config.Data.Buildings, Config.Data.BuildingLevels, Config.Data.Economy)
local sessions: { [Player]: { Profile: any, Plot: any, Calls: number, Window: number } } = {}
local stateEvent: RemoteEvent

local function snapshot(player: Player)
	local s = sessions[player]
	if s == nil then
		return nil
	end
	local now = os.time()
	return {
		Profile = s.Profile,
		Summary = Actions.Summary(s.Profile, catalog, now),
		ServerTime = now,
		Plot = { Index = s.Plot.Index, Corner = s.Plot.Corner },
	}
end

local function push(player: Player)
	local state = snapshot(player)
	if state then
		stateEvent:FireClient(player, state)
	end
end

local function refresh(player: Player)
	local s = sessions[player]
	if s == nil then
		return
	end
	BaseRenderer.Render(s.Plot.Model, s.Plot.Corner, s.Profile, catalog, os.time())
	push(player)
end

local function advance(player: Player, now: number): boolean
	local s = sessions[player]
	local _, _, detail = Actions.Advance(s.Profile, catalog, now)
	for _, c in detail.Completed do
		Trace.Event(player, "UpgradeComplete", c)
	end
	return #detail.Completed > 0
end

-- Rate limit: at most MAX_CALLS_PER_SECOND requests per player per wall-clock second.
local function allowCall(s): boolean
	local second = os.time()
	if s.Window ~= second then
		s.Window, s.Calls = second, 0
	end
	s.Calls += 1
	return s.Calls <= MAX_CALLS_PER_SECOND
end

local function handle(actionName: string, player: Player, ...)
	local s = sessions[player]
	if s == nil then
		Trace.Action(player, actionName, false, "NoSession")
		return { ok = false, reason = "NoSession" }
	end
	if not allowCall(s) then
		Trace.Action(player, actionName, false, "TooManyRequests")
		return { ok = false, reason = "TooManyRequests" }
	end
	local now = os.time()
	advance(player, now)
	local fn = Actions[actionName]
	local success, ok, reason, detail = pcall(fn, s.Profile, catalog, now, ...)
	if not success then
		Trace.Action(player, actionName, false, "Error", { Message = ok })
		return { ok = false, reason = "Error" }
	end
	Trace.Action(player, actionName, ok, reason, detail)
	refresh(player)
	return { ok = ok, reason = reason, detail = detail }
end

local function onPlayerAdded(player: Player)
	local plot = PlotService.Assign(player)
	if plot == nil then
		Trace.Event(player, "Kicked", { Reason = "ServerFull" })
		player:Kick("This server is full. Please join another server.")
		return
	end
	Trace.Event(player, "PlotAssigned", { Plot = plot.Index })

	local profile, loadErr = PlayerStore.Load(player.UserId)
	if player.Parent == nil then
		-- Left while loading: hand the lock back untouched and free the plot.
		if profile then
			PlayerStore.Save(player.UserId, profile, true)
		end
		PlotService.Release(player)
		return
	end
	if profile == nil then
		Trace.Event(player, "LoadFailed", { Reason = loadErr })
		PlotService.Release(player)
		player:Kick(if loadErr == "Locked" then KICK_LOCKED else KICK_LOAD_FAILED)
		return
	end
	Trace.Event(player, "Loaded", { Faction = profile.Faction or "none", Buildings = (function()
		local n = 0
		for _ in profile.Buildings do
			n += 1
		end
		return n
	end)() })

	sessions[player] = { Profile = profile, Plot = plot, Calls = 0, Window = 0 }
	local auto = DevFlags.AutoPickFactionInStudio
	if RunService:IsStudio() and auto ~= nil and profile.Faction == nil then
		local ok, reason = Actions.PickFaction(profile, catalog, os.time(), auto)
		Trace.Action(player, "PickFaction (Studio auto-pick)", ok, reason, { Faction = auto })
	end
	advance(player, os.time()) -- offline progress: finish due upgrades, accrue production
	refresh(player)
end

local savesInFlight = 0 -- shutdown waits for these (a leave-save may still be running)

local function save(player: Player, s, release: boolean, why: string)
	savesInFlight += 1
	local ok, reason = PlayerStore.Save(player.UserId, s.Profile, release)
	savesInFlight -= 1
	if ok then
		if release then
			Trace.Event(player, "Saved", { Why = why })
		end
	else
		Trace.Event(player, "SaveFailed", { Why = why, Reason = reason })
		if reason == "LockLost" and player.Parent ~= nil then
			sessions[player] = nil
			PlotService.Release(player)
			player:Kick(KICK_LOCK_LOST)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local s = sessions[player]
	sessions[player] = nil
	if s then
		Trace.Event(player, "Left", { Plot = s.Plot.Index })
		save(player, s, true, "Left")
	end
	PlotService.Release(player)
end

function BaseService.Init()
	Players.CharacterAutoLoads = false -- character hidden while on the base (owner decision)
	PlotService.Init()

	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for _, name in Remotes.Actions do
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.OnServerInvoke = function(player, ...)
			return handle(name, player, ...)
		end
		rf.Parent = folder
	end
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = Remotes.State
	stateEvent.Parent = folder
	local getState = Instance.new("RemoteFunction")
	getState.Name = Remotes.GetState
	getState.OnServerInvoke = function(player)
		-- nil while the player's session is still being created; the client retries.
		return snapshot(player)
	end
	getState.Parent = folder
	folder.Parent = ReplicatedStorage

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave every AUTOSAVE_SECONDS (lock kept).
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, s in sessions do
				task.spawn(save, player, s, false, "Autosave")
			end
		end
	end)

	-- Shutdown: save every remaining session (releasing its lock), then wait for every save in
	-- flight, including leave-saves started by PlayerRemoving, before the server closes.
	game:BindToClose(function()
		for player, s in sessions do
			sessions[player] = nil
			task.spawn(save, player, s, true, "Shutdown")
		end
		task.wait() -- let the spawned saves register as in flight
		while savesInFlight > 0 do
			task.wait(0.1)
		end
	end)

	-- 1 s tick: finish due upgrades; re-render while any timer is running so labels count down.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for player, s in sessions do
				local changed = advance(player, now)
				local _, busy = Actions.Builders(s.Profile, catalog)
				if changed or busy > 0 then
					refresh(player)
				end
			end
		end
	end)
end

return BaseService
