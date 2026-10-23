-- Base actions (v0.3, Design v2.4): every change to a player's base goes through here.
-- Pure: (profile, catalog, now, ...) -> (ok, reason?, detail?). No Roblox APIs.
--
-- Rules:
-- * Checks run in the order written; the first failing check is the reason returned.
-- * A rejected action does not change the profile, except time-driven progress
--   (collector production accrued to `now`, Market cycle rollover), which is state, not the action.
-- * Callers run Actions.Advance(profile, catalog, now) before any other action.
-- * Every reason code is listed in Actions.Reasons.

local Grid = require("./Grid")
local WorldConfig = require("./WorldConfig")
local Rules = require("../Economy/Rules")

local Actions = {}

Actions.Reasons = {
	"NoFaction", "AlreadyPicked", "UnknownFaction", "UnknownBuilding", "NotPurchasable",
	"TownHallTooLow", "LimitReached", "OutOfBounds", "Blocked", "BadCoordinates",
	"NotEnoughCoins", "NoBuilderFree", "AlreadyUpgrading", "NotUpgrading", "MaxLevel",
	"PlaceAllFirst", "NotCollector", "NothingToCollect", "StorageFull", "NoMarket",
	"BadAmount", "NotEnoughResources", "NothingToSell", "OverLimit",
}

local RESOURCE_FIELD = { Ore = "Ore", Essence = "Essence" }

-- Starting-kit positions (top-left tiles) beside the Town Hall at the grid centre. Movable in edit mode.
local KIT_BUILDER_HUTS = { { X = 17, Y = 20 }, { X = 17, Y = 22 } }
local KIT_MARKET = { X = 25, Y = 20 }

-- ---------------------------------------------------------------- helpers

local function size(catalog, buildingId: string): number
	local fp = catalog:Building(buildingId).Footprint
	local n = tonumber(string.match(fp, "^(%d+)x"))
	assert(n, `Actions: bad footprint {fp} on {buildingId}`)
	return n :: number
end

local function list(profile)
	local out = {}
	for _, b in profile.Buildings do
		table.insert(out, b)
	end
	table.sort(out, function(a, b)
		return a.Uid < b.Uid
	end)
	return out
end

local function footprints(profile, catalog)
	local out = {}
	for _, b in list(profile) do
		table.insert(out, { Uid = b.Uid, X = b.X, Y = b.Y, Size = size(catalog, b.BuildingId) })
	end
	return out
end

local function typeOf(catalog, b): string
	return catalog:Building(b.BuildingId).BuildingType
end

function Actions.TownHallLevel(profile, catalog): number
	for _, b in profile.Buildings do
		if typeOf(catalog, b) == "Town Hall" then
			return b.Level
		end
	end
	return 0
end

function Actions.Builders(profile, catalog): (number, number)
	local total, busy = 0, 0
	for _, b in profile.Buildings do
		if typeOf(catalog, b) == "Builder Hut" and b.Level >= 1 then
			total += 1
		end
		if b.UpgradeEndsAt ~= nil then
			busy += 1
		end
	end
	return total, busy
end

-- Town Hall's own storage (per resource) + every built storage of that resource at its current level.
function Actions.Capacity(profile, catalog, resource: string): number
	local th, storages = 0, {}
	for _, b in list(profile) do
		local def = catalog:Building(b.BuildingId)
		if def.BuildingType == "Town Hall" and b.Level >= 1 then
			th = catalog:Level(b.BuildingId, b.Level).ResourceCapacity or 0
		elseif def.BuildingType == "Storage" and def.ResourceType == resource and b.Level >= 1 then
			table.insert(storages, catalog:Level(b.BuildingId, b.Level).ResourceCapacity)
		end
	end
	return Rules.Capacity(th, storages)
end

local function placedCount(profile, buildingId: string): number
	local n = 0
	for _, b in profile.Buildings do
		if b.BuildingId == buildingId then
			n += 1
		end
	end
	return n
end

-- Buildings still to place before the Town Hall may upgrade (Design v2.4: template buildings only).
function Actions.MissingForTownHall(profile, catalog): { { BuildingId: string, Missing: number } }
	local th, out = Actions.TownHallLevel(profile, catalog), {}
	for _, id in catalog:ForFaction(profile.Faction) do
		local missing = catalog:AllowedAt(id, th) - placedCount(profile, id)
		if missing > 0 then
			table.insert(out, { BuildingId = id, Missing = missing })
		end
	end
	return out
end

local function isProducing(catalog, b): boolean
	return typeOf(catalog, b) == "Collector" and b.Level >= 1 and b.UpgradeEndsAt == nil
end

-- Brings one collector's Stored up to `now`. Production is paused while upgrading.
local function accrue(catalog, b, now: number)
	if not isProducing(catalog, b) then
		return
	end
	local row = catalog:Level(b.BuildingId, b.Level)
	b.Stored = Rules.Accrue(b.Stored, row.ProductionPerHour, row.ResourceCapacity, now - (b.ProducedAt or now))
	b.ProducedAt = now
end

local function marketRollover(profile, catalog, now: number)
	local cycle = Rules.MarketCycleId(now, catalog:Setting("MarketResetUtcSecond"), catalog:Setting("MarketResetIntervalSeconds"))
	if profile.Market.CycleId ~= cycle then
		profile.Market.CycleId = cycle
		profile.Market.SoldCoins = 0
	end
end

local function marketLimit(profile, catalog): number
	for _, b in profile.Buildings do
		if typeOf(catalog, b) == "Market" and b.Level >= 1 then
			return catalog:Level(b.BuildingId, b.Level).MarketSellLimit
		end
	end
	return 0
end

local function newBuilding(profile, buildingId: string, x: number, y: number)
	local uid = profile.NextUid
	profile.NextUid += 1
	local b = { Uid = uid, BuildingId = buildingId, Level = 0, X = x, Y = y, Stored = 0 }
	profile.Buildings[tostring(uid)] = b
	return b
end

local function isWholeNumber(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and math.floor(n) == n
end

-- ---------------------------------------------------------------- actions

-- Finishes due upgrades/constructions and accrues production up to `now`.
-- detail.Completed = { { Uid, Level } } in completion order.
function Actions.Advance(profile, catalog, now: number)
	local completed = {}
	if profile.Faction == nil then
		return true, nil, { Completed = completed }
	end
	for _, b in list(profile) do
		if b.UpgradeEndsAt ~= nil and now >= b.UpgradeEndsAt then
			local endedAt = b.UpgradeEndsAt
			b.Level += 1
			b.UpgradeEndsAt = nil
			if typeOf(catalog, b) == "Collector" then
				b.ProducedAt = endedAt -- production restarts at completion time, at the new rate
			end
			table.insert(completed, { Uid = b.Uid, Level = b.Level })
		end
		accrue(catalog, b, now)
	end
	marketRollover(profile, catalog, now)
	return true, nil, { Completed = completed }
end

-- Faction pick: Town Hall level 0 at the grid centre -> automatic 0 -> 1 (0 Coins, 0 s)
-- -> starting kit from the Economy tab (Builder Huts, Market level, Coins).
function Actions.PickFaction(profile, catalog, now: number, faction: string)
	if profile.Faction ~= nil then
		return false, "AlreadyPicked"
	end
	local thId = type(faction) == "string" and catalog:FindByType(faction, "Town Hall") or nil
	local hutId = thId and catalog:FindByType(faction, "Builder Hut")
	local marketId = thId and catalog:FindByType(faction, "Market")
	if thId == nil or hutId == nil or marketId == nil then
		return false, "UnknownFaction"
	end
	local hutCount = catalog:Setting("StartingBuilderHuts")
	local marketLevel = catalog:Setting("StartingMarketLevel")
	local coins = catalog:Setting("StartingCoins")
	assert(hutCount <= #KIT_BUILDER_HUTS, "Actions: more starting Builder Huts than kit positions")

	local thSize = size(catalog, thId)
	local centre = (WorldConfig.GridSize - thSize) // 2
	profile.Faction = faction
	local th = newBuilding(profile, thId, centre, centre)
	th.Level = 1 -- Town Hall 0 -> 1: automatic, free, instant (Design v2.4)
	for i = 1, hutCount do
		local hut = newBuilding(profile, hutId, KIT_BUILDER_HUTS[i].X, KIT_BUILDER_HUTS[i].Y)
		hut.Level = 1
	end
	local market = newBuilding(profile, marketId, KIT_MARKET.X, KIT_MARKET.Y)
	market.Level = marketLevel
	profile.Coins += coins
	marketRollover(profile, catalog, now)
	return true, nil, { TownHallUid = th.Uid }
end

function Actions.Place(profile, catalog, now: number, buildingId: string, x: number, y: number)
	if profile.Faction == nil then
		return false, "NoFaction"
	end
	local def = catalog:Building(buildingId)
	local first = def and catalog:Level(buildingId, 1)
	if def == nil or def.Faction ~= profile.Faction or first == nil then
		return false, "UnknownBuilding"
	end
	if first.UpgradeCost == nil then
		return false, "NotPurchasable"
	end
	local th = Actions.TownHallLevel(profile, catalog)
	if (first.RequiredTownHall or 0) > th then
		return false, "TownHallTooLow"
	end
	if placedCount(profile, buildingId) >= catalog:AllowedAt(buildingId, th) then
		return false, "LimitReached"
	end
	local ok, reason = Grid.CanPlace(footprints(profile, catalog), x, y, size(catalog, buildingId), WorldConfig.GridSize)
	if not ok then
		return false, reason
	end
	if profile.Coins < first.UpgradeCost then
		return false, "NotEnoughCoins"
	end
	local seconds = first.UpgradeTimeSeconds or 0
	local total, busy = Actions.Builders(profile, catalog)
	if seconds > 0 and busy >= total then
		return false, "NoBuilderFree"
	end
	profile.Coins -= first.UpgradeCost
	local b = newBuilding(profile, buildingId, x, y)
	if seconds > 0 then
		b.UpgradeEndsAt = now + seconds
	else
		b.Level = 1
		if def.BuildingType == "Collector" then
			b.ProducedAt = now
		end
	end
	return true, nil, { Uid = b.Uid }
end

function Actions.Move(profile, catalog, now: number, uid: number, x: number, y: number)
	if profile.Faction == nil then
		return false, "NoFaction"
	end
	local b = profile.Buildings[tostring(uid)]
	if b == nil then
		return false, "UnknownBuilding"
	end
	local ok, reason = Grid.CanPlace(footprints(profile, catalog), x, y, size(catalog, b.BuildingId), WorldConfig.GridSize, b.Uid)
	if not ok then
		return false, reason
	end
	b.X, b.Y = x, y
	return true, nil, nil
end

function Actions.StartUpgrade(profile, catalog, now: number, uid: number)
	if profile.Faction == nil then
		return false, "NoFaction"
	end
	local b = profile.Buildings[tostring(uid)]
	if b == nil then
		return false, "UnknownBuilding"
	end
	if b.UpgradeEndsAt ~= nil then
		return false, "AlreadyUpgrading"
	end
	local nextRow = catalog:Level(b.BuildingId, b.Level + 1)
	if nextRow == nil then
		return false, "MaxLevel"
	end
	if nextRow.UpgradeCost == nil then
		return false, "NotPurchasable"
	end
	local isTownHall = typeOf(catalog, b) == "Town Hall"
	if isTownHall then
		if #Actions.MissingForTownHall(profile, catalog) > 0 then
			return false, "PlaceAllFirst"
		end
	elseif (nextRow.RequiredTownHall or 0) > Actions.TownHallLevel(profile, catalog) then
		return false, "TownHallTooLow"
	end
	if profile.Coins < nextRow.UpgradeCost then
		return false, "NotEnoughCoins"
	end
	local seconds = nextRow.UpgradeTimeSeconds or 0
	local total, busy = Actions.Builders(profile, catalog)
	if seconds > 0 and busy >= total then
		return false, "NoBuilderFree"
	end
	-- Collector upgrade start (owner correction 2026-10-23): contents are collected automatically;
	-- whatever does not fit in storage is lost. Production then pauses until the upgrade ends.
	local collected, lost = 0, 0
	local def = catalog:Building(b.BuildingId)
	if def.BuildingType == "Collector" and b.Level >= 1 then
		accrue(catalog, b, now)
		local field = RESOURCE_FIELD[def.ResourceType]
		collected = Rules.CollectAmount(b.Stored, profile[field], Actions.Capacity(profile, catalog, def.ResourceType))
		lost = b.Stored - collected
		profile[field] += collected
		b.Stored = 0
	end
	profile.Coins -= nextRow.UpgradeCost
	if seconds > 0 then
		b.UpgradeEndsAt = now + seconds
	else
		b.Level += 1
		if typeOf(catalog, b) == "Collector" then
			b.ProducedAt = now
		end
	end
	return true, nil, { EndsAt = b.UpgradeEndsAt, Level = b.Level, Collected = collected, Lost = lost }
end

function Actions.CancelUpgrade(profile, catalog, now: number, uid: number)
	if profile.Faction == nil then
		return false, "NoFaction"
	end
	local b = profile.Buildings[tostring(uid)]
	if b == nil then
		return false, "UnknownBuilding"
	end
	if b.UpgradeEndsAt == nil then
		return false, "NotUpgrading"
	end
	local refund = Rules.Refund(catalog:Level(b.BuildingId, b.Level + 1).UpgradeCost)
	profile.Coins += refund
	if b.Level == 0 then
		profile.Buildings[tostring(uid)] = nil -- cancelled construction removes the building
		return true, nil, { Refund = refund, Removed = true }
	end
	b.UpgradeEndsAt = nil
	if typeOf(catalog, b) == "Collector" then
		b.ProducedAt = now -- production resumes at the current level
	end
	return true, nil, { Refund = refund, Removed = false }
end

function Actions.Collect(profile, catalog, now: number, uid: number)
	if profile.Faction == nil then
		return false, "NoFaction"
	end
	local b = profile.Buildings[tostring(uid)]
	if b == nil then
		return false, "UnknownBuilding"
	end
	local def = catalog:Building(b.BuildingId)
	if def.BuildingType ~= "Collector" then
		return false, "NotCollector"
	end
	accrue(catalog, b, now)
	if b.Stored < 1 then
		return false, "NothingToCollect"
	end
	local field = RESOURCE_FIELD[def.ResourceType]
	local amount = Rules.CollectAmount(b.Stored, profile[field], Actions.Capacity(profile, catalog, def.ResourceType))
	if amount <= 0 then
		return false, "StorageFull"
	end
	profile[field] += amount
	b.Stored -= amount
	return true, nil, { Resource = def.ResourceType, Amount = amount }
end

function Actions.Sell(profile, catalog, now: number, ore: number, essence: number)
	if profile.Faction == nil then
		return false, "NoFaction"
	end
	if not isWholeNumber(ore) or not isWholeNumber(essence) then
		return false, "BadAmount"
	end
	marketRollover(profile, catalog, now)
	local limit = marketLimit(profile, catalog)
	if limit <= 0 then
		return false, "NoMarket"
	end
	if ore > profile.Ore or essence > profile.Essence then
		return false, "NotEnoughResources"
	end
	local value = Rules.SellValue(ore, essence, catalog:Setting("OreSellPrice"), catalog:Setting("EssenceSellPrice"))
	if value <= 0 then
		return false, "NothingToSell"
	end
	if value > limit - profile.Market.SoldCoins then
		return false, "OverLimit"
	end
	profile.Ore -= ore
	profile.Essence -= essence
	profile.Coins += value
	profile.Market.SoldCoins += value
	return true, nil, { Coins = value, Remaining = limit - profile.Market.SoldCoins }
end

-- Read-only summary for the client HUD.
function Actions.Summary(profile, catalog, now: number)
	local total, busy = Actions.Builders(profile, catalog)
	local limit = 0
	local sold = profile.Market.SoldCoins
	if profile.Faction ~= nil then
		limit = marketLimit(profile, catalog)
		local cycle = Rules.MarketCycleId(now, catalog:Setting("MarketResetUtcSecond"), catalog:Setting("MarketResetIntervalSeconds"))
		if cycle ~= profile.Market.CycleId then
			sold = 0
		end
	end
	return {
		TownHall = Actions.TownHallLevel(profile, catalog),
		Builders = total,
		BuildersBusy = busy,
		OreCapacity = Actions.Capacity(profile, catalog, "Ore"),
		EssenceCapacity = Actions.Capacity(profile, catalog, "Essence"),
		MarketLimit = limit,
		MarketSold = sold,
		MissingForTownHall = profile.Faction and Actions.MissingForTownHall(profile, catalog) or {},
	}
end

return Actions
