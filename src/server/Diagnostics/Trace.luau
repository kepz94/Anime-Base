-- Trace (v0.3): one console line per state change or rejected request, naming the player,
-- the action, the outcome and the reason, so every change has a traceable cause.

local Trace = {}

local function describe(detail: any): string
	if type(detail) ~= "table" then
		return ""
	end
	local keys = {}
	for k in detail do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	local parts = {}
	for _, k in keys do
		local v = detail[k]
		table.insert(parts, `{k}={if type(v) == "table" then "#" .. tostring(#v) else tostring(v)}`)
	end
	return " {" .. table.concat(parts, ", ") .. "}"
end

function Trace.Action(player: Player, action: string, ok: boolean, reason: string?, detail: any?)
	print(`[Trace] {player.Name}({player.UserId}) {action} -> {if ok then "OK" else "REJECTED " .. tostring(reason)}{describe(detail)}`)
end

function Trace.Event(player: Player?, event: string, detail: any?)
	local who = if player then `{player.Name}({player.UserId})` else "server"
	print(`[Trace] {who} {event}{describe(detail)}`)
end

return Trace
