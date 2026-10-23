-- Player profile schema (v0.3). Pure data; saved as-is to the DataStore.
--
-- Version      schema version (1)
-- Faction      nil until picked, then "Ninja" | "Ki Warriors"
-- Coins        no cap (owner decision 2026-10-23)
-- Ore, Essence stored resources (capped by Town Hall + storage capacity)
-- NextUid      next building uid
-- Buildings    map uid-string -> { Uid, BuildingId, Level, X, Y, UpgradeEndsAt?, Stored, ProducedAt? }
--              Level 0 = under construction. UpgradeEndsAt set = a builder is working on it.
-- Market       { CycleId, SoldCoins } for the daily sell limit

local Profile = {}

Profile.Version = 1

function Profile.New()
	return {
		Version = Profile.Version,
		Faction = nil,
		Coins = 0,
		Ore = 0,
		Essence = 0,
		NextUid = 1,
		Buildings = {},
		Market = { CycleId = -1, SoldCoins = 0 },
	}
end

-- Saved data -> profile. nil (new player) -> fresh profile. Unknown versions raise instead of
-- being overwritten, so a newer server's data is never wiped by an older one.
function Profile.FromSaved(saved: any)
	if saved == nil then
		return Profile.New()
	end
	if type(saved) ~= "table" then
		error(`Profile: saved data is a {type(saved)}, expected a table`)
	end
	if saved.Version == Profile.Version then
		return saved
	end
	error(`Profile: unsupported saved version {tostring(saved.Version)} (this server reads {Profile.Version})`)
end

return Profile
