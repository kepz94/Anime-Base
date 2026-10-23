local Assert = require("./lib/Assert")
local Actions = require("../src/shared/Base/Actions")
local Catalog = require("../src/shared/Base/Catalog")
local Profile = require("../src/shared/Base/Profile")

local cat = Catalog.new(
	require("../src/shared/Config/Data/Buildings"),
	require("../src/shared/Config/Data/BuildingLevels"),
	require("../src/shared/Config/Data/Economy")
)

local T0 = 1_800_000_000 -- fixed clock (seconds, UTC)
local OC, EC, OS, ES, AC, BK, WALL, LAB = "B-NIN-04", "B-NIN-05", "B-NIN-06", "B-NIN-07", "B-NIN-08", "B-NIN-09", "B-NIN-11", "B-NIN-10"

local function started()
	local p = Profile.New()
	assert(Actions.PickFaction(p, cat, T0, "Ninja"))
	return p
end

-- Runs fn and asserts it was rejected with `reason` and left the profile unchanged.
local function rejects(p, reason: string, fn)
	local before = Assert.DeepCopy(p)
	local ok, got = fn()
	Assert.Equal(ok, false, "ok")
	Assert.Equal(got, reason, "reason")
	Assert.DeepEqual(p, before, "profile after rejected " .. reason)
end

local function find(p, buildingId)
	for _, b in p.Buildings do
		if b.BuildingId == buildingId then
			return b
		end
	end
	return nil
end

-- Places and completes one of each TH1 building (for Town Hall tests).
local function fillTownHall1(p, now)
	local spots = { [OC] = { 2, 2 }, [EC] = { 6, 2 }, [OS] = { 10, 2 }, [ES] = { 14, 2 }, [AC] = { 18, 2 }, [BK] = { 23, 2 } }
	p.Coins += 100000
	for _, id in { OC, EC, OS, ES, AC, BK } do
		local ok, reason = Actions.Place(p, cat, now, id, spots[id][1], spots[id][2])
		assert(ok, reason)
		Actions.Advance(p, cat, now + 3600)
	end
end

return {
	-- PickFaction ------------------------------------------------------------------------------
	["pick faction: TH1, 2 builder huts, market L1, 1500 coins"] = function()
		local p = started()
		Assert.Equal(p.Faction, "Ninja")
		Assert.Equal(Actions.TownHallLevel(p, cat), 1)
		local total, busy = Actions.Builders(p, cat)
		Assert.Equal(total, 2)
		Assert.Equal(busy, 0)
		Assert.Equal(find(p, "B-NIN-03").Level, 1, "market level")
		Assert.Equal(p.Coins, 1500)
		Assert.Equal(find(p, "B-NIN-01").X, 20, "TH at grid centre")
		Assert.Equal(Actions.Summary(p, cat, T0).MarketLimit, 7500)
		Assert.Equal(Actions.Capacity(p, cat, "Ore"), 1000, "TH1 own storage")
	end,
	["pick faction twice -> AlreadyPicked"] = function()
		local p = started()
		rejects(p, "AlreadyPicked", function()
			return Actions.PickFaction(p, cat, T0, "Ki Warriors")
		end)
	end,
	["unknown faction -> UnknownFaction"] = function()
		local p = Profile.New()
		rejects(p, "UnknownFaction", function()
			return Actions.PickFaction(p, cat, T0, "Pirates")
		end)
	end,
	["actions before a faction -> NoFaction"] = function()
		local p = Profile.New()
		rejects(p, "NoFaction", function() return Actions.Place(p, cat, T0, OC, 0, 0) end)
		rejects(p, "NoFaction", function() return Actions.Move(p, cat, T0, 1, 0, 0) end)
		rejects(p, "NoFaction", function() return Actions.StartUpgrade(p, cat, T0, 1) end)
		rejects(p, "NoFaction", function() return Actions.CancelUpgrade(p, cat, T0, 1) end)
		rejects(p, "NoFaction", function() return Actions.Collect(p, cat, T0, 1) end)
		rejects(p, "NoFaction", function() return Actions.Sell(p, cat, T0, 0, 0) end)
	end,

	-- Place ------------------------------------------------------------------------------------
	["place ore collector: -300 coins, builder busy 5 s, level 1 after"] = function()
		local p = started()
		local ok, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		Assert.True(ok)
		local b = p.Buildings[tostring(d.Uid)]
		Assert.Equal(p.Coins, 1200)
		Assert.Equal(b.Level, 0)
		Assert.Equal(b.UpgradeEndsAt, T0 + 5)
		Assert.Equal(select(2, Actions.Builders(p, cat)), 1, "busy")
		Actions.Advance(p, cat, T0 + 4)
		Assert.Equal(b.Level, 0, "not yet")
		local _, _, adv = Actions.Advance(p, cat, T0 + 5)
		Assert.Equal(b.Level, 1)
		Assert.Equal(#adv.Completed, 1)
		Assert.Equal(b.ProducedAt, T0 + 5, "production starts at completion")
	end,
	["place rejections"] = function()
		local p = started()
		rejects(p, "UnknownBuilding", function() return Actions.Place(p, cat, T0, "B-KI-04", 2, 2) end)
		rejects(p, "UnknownBuilding", function() return Actions.Place(p, cat, T0, "B-NOPE-01", 2, 2) end)
		rejects(p, "NotPurchasable", function() return Actions.Place(p, cat, T0, "B-NIN-02", 2, 2) end)
		rejects(p, "TownHallTooLow", function() return Actions.Place(p, cat, T0, WALL, 2, 2) end)
		rejects(p, "TownHallTooLow", function() return Actions.Place(p, cat, T0, LAB, 2, 2) end)
		rejects(p, "LimitReached", function() return Actions.Place(p, cat, T0, "B-NIN-03", 2, 2) end)
		rejects(p, "OutOfBounds", function() return Actions.Place(p, cat, T0, OC, 42, 0) end)
		rejects(p, "Blocked", function() return Actions.Place(p, cat, T0, OC, 21, 21) end)
		rejects(p, "BadCoordinates", function() return Actions.Place(p, cat, T0, OC, 2.5, 2) end)
		p.Coins = 299
		rejects(p, "NotEnoughCoins", function() return Actions.Place(p, cat, T0, OC, 2, 2) end)
	end,
	["place: limit per town hall"] = function()
		local p = started()
		assert(Actions.Place(p, cat, T0, OC, 2, 2))
		rejects(p, "LimitReached", function() return Actions.Place(p, cat, T0, OC, 6, 2) end)
	end,
	["place: no builder free"] = function()
		local p = started()
		assert(Actions.Place(p, cat, T0, OC, 2, 2))
		assert(Actions.Place(p, cat, T0, EC, 6, 2))
		rejects(p, "NoBuilderFree", function() return Actions.Place(p, cat, T0, OS, 10, 2) end)
	end,

	-- Move -------------------------------------------------------------------------------------
	["move: free spot, own tiles, blocked, unknown"] = function()
		local p = started()
		local hut = find(p, "B-NIN-02")
		assert(Actions.Move(p, cat, T0, hut.Uid, 2, 2))
		Assert.Equal(hut.X, 2)
		assert(Actions.Move(p, cat, T0, hut.Uid, 3, 2)) -- overlaps only its own old tiles
		rejects(p, "Blocked", function() return Actions.Move(p, cat, T0, hut.Uid, 21, 21) end)
		rejects(p, "OutOfBounds", function() return Actions.Move(p, cat, T0, hut.Uid, 43, 0) end)
		rejects(p, "UnknownBuilding", function() return Actions.Move(p, cat, T0, 999, 0, 0) end)
	end,

	-- Upgrade / cancel -------------------------------------------------------------------------
	["upgrade collector: auto-collects, cost, busy, production paused then new rate"] = function()
		local p = started()
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		local b = p.Buildings[tostring(d.Uid)]
		Actions.Advance(p, cat, T0 + 5) -- built at T0+5
		Actions.Advance(p, cat, T0 + 5 + 1800) -- 30 min at 200/h = 100
		Assert.Near(b.Stored, 100, 1e-6, "stored before upgrade")
		local coins = p.Coins
		local ok, _, r = Actions.StartUpgrade(p, cat, T0 + 1805, b.Uid)
		Assert.True(ok)
		Assert.Equal(r.Collected, 100, "auto-collected on upgrade start")
		Assert.Near(r.Lost, 0, 1e-6, "nothing lost")
		Assert.Equal(p.Ore, 100)
		Assert.Equal(b.Stored, 0, "collector emptied")
		Assert.Equal(p.Coins, coins - 600)
		Assert.Equal(b.UpgradeEndsAt, T0 + 1805 + 15)
		Actions.Advance(p, cat, T0 + 1815) -- mid-upgrade: no production
		Assert.Equal(b.Stored, 0, "paused")
		Actions.Advance(p, cat, T0 + 1820 + 3600) -- done at T0+1820, then 1 h at 400/h
		Assert.Equal(b.Level, 2)
		Assert.Near(b.Stored, 400, 1e-6, "new rate after completion")
	end,
	["upgrade collector with full storage: contents lost"] = function()
		local p = started()
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		local b = p.Buildings[tostring(d.Uid)]
		Actions.Advance(p, cat, T0 + 5 + 3600) -- 200 stored
		p.Ore = 1000 -- TH1 capacity 1000, no storage: full
		local ok, _, r = Actions.StartUpgrade(p, cat, T0 + 3605, b.Uid)
		Assert.True(ok)
		Assert.Equal(r.Collected, 0)
		Assert.Near(r.Lost, 200, 1e-6, "overflow lost")
		Assert.Equal(p.Ore, 1000, "storage unchanged")
		Assert.Equal(b.Stored, 0, "collector emptied")
	end,
	["upgrade collector with partial room: fills storage, rest lost"] = function()
		local p = started()
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		local b = p.Buildings[tostring(d.Uid)]
		Actions.Advance(p, cat, T0 + 5 + 3600) -- 200 stored
		p.Ore = 950
		local _, _, r = Actions.StartUpgrade(p, cat, T0 + 3605, b.Uid)
		Assert.Equal(r.Collected, 50)
		Assert.Near(r.Lost, 150, 1e-6)
		Assert.Equal(p.Ore, 1000)
		Assert.Equal(b.Stored, 0)
	end,
	["upgrade rejections"] = function()
		local p = started()
		local market = find(p, "B-NIN-03")
		rejects(p, "UnknownBuilding", function() return Actions.StartUpgrade(p, cat, T0, 999) end)
		rejects(p, "TownHallTooLow", function() return Actions.StartUpgrade(p, cat, T0, market.Uid) end)
		local hut = find(p, "B-NIN-02")
		rejects(p, "MaxLevel", function() return Actions.StartUpgrade(p, cat, T0, hut.Uid) end)
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		rejects(p, "AlreadyUpgrading", function() return Actions.StartUpgrade(p, cat, T0, d.Uid) end)
		Actions.Advance(p, cat, T0 + 5)
		p.Coins = 599
		rejects(p, "NotEnoughCoins", function() return Actions.StartUpgrade(p, cat, T0 + 5, d.Uid) end)
	end,
	["upgrade: no builder free"] = function()
		local p = started()
		local _, _, a = Actions.Place(p, cat, T0, OC, 2, 2)
		Actions.Advance(p, cat, T0 + 5)
		assert(Actions.Place(p, cat, T0 + 5, EC, 6, 2))
		assert(Actions.Place(p, cat, T0 + 5, OS, 10, 2))
		p.Coins += 10000 -- coins check runs before the builder check
		rejects(p, "NoBuilderFree", function() return Actions.StartUpgrade(p, cat, T0 + 5, a.Uid) end)
	end,
	["town hall upgrade needs every TH1 building placed"] = function()
		local p = started()
		local th = find(p, "B-NIN-01")
		p.Coins = 100000
		rejects(p, "PlaceAllFirst", function() return Actions.StartUpgrade(p, cat, T0, th.Uid) end)
		Assert.Equal(#Actions.MissingForTownHall(p, cat), 6)
		fillTownHall1(p, T0)
		Assert.Equal(#Actions.MissingForTownHall(p, cat), 0)
		local coins = p.Coins
		assert(Actions.StartUpgrade(p, cat, T0 + 99999, th.Uid))
		Assert.Equal(p.Coins, coins - 1000)
		Actions.Advance(p, cat, T0 + 99999 + 10)
		Assert.Equal(Actions.TownHallLevel(p, cat), 2)
		Assert.Equal(Actions.Capacity(p, cat, "Ore"), 2500 + 1500, "TH2 own storage + L1 storage")
	end,
	["wall upgrades are instant and need no builder"] = function()
		local p = started()
		fillTownHall1(p, T0)
		local th = find(p, "B-NIN-01")
		assert(Actions.StartUpgrade(p, cat, T0 + 99999, th.Uid))
		Actions.Advance(p, cat, T0 + 99999 + 10)
		local _, _, w = Actions.Place(p, cat, T0 + 100100, WALL, 40, 40)
		local wall = p.Buildings[tostring(w.Uid)]
		Assert.Equal(wall.Level, 1, "level 1 wall placed instantly")
		assert(Actions.StartUpgrade(p, cat, T0 + 100100, w.Uid))
		Assert.Equal(wall.Level, 2, "instant upgrade")
		Assert.Equal(wall.UpgradeEndsAt, nil)
	end,
	["cancel upgrade: 50% refund, level kept, production resumes"] = function()
		local p = started()
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		Actions.Advance(p, cat, T0 + 5)
		assert(Actions.StartUpgrade(p, cat, T0 + 5, d.Uid))
		local coins = p.Coins
		local ok, _, r = Actions.CancelUpgrade(p, cat, T0 + 6, d.Uid)
		Assert.True(ok)
		Assert.Equal(r.Refund, 300)
		Assert.Equal(p.Coins, coins + 300)
		local b = p.Buildings[tostring(d.Uid)]
		Assert.Equal(b.Level, 1)
		Assert.Equal(b.UpgradeEndsAt, nil)
		Assert.Equal(b.ProducedAt, T0 + 6)
	end,
	["cancel construction removes the building"] = function()
		local p = started()
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		local ok, _, r = Actions.CancelUpgrade(p, cat, T0 + 1, d.Uid)
		Assert.True(ok)
		Assert.Equal(r.Removed, true)
		Assert.Equal(p.Coins, 1200 + 150)
		Assert.Equal(p.Buildings[tostring(d.Uid)], nil)
	end,
	["cancel rejections"] = function()
		local p = started()
		rejects(p, "UnknownBuilding", function() return Actions.CancelUpgrade(p, cat, T0, 999) end)
		rejects(p, "NotUpgrading", function() return Actions.CancelUpgrade(p, cat, T0, find(p, "B-NIN-01").Uid) end)
	end,

	-- Collect ----------------------------------------------------------------------------------
	["collect: whole units into storage, capped by capacity"] = function()
		local p = started()
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		Actions.Advance(p, cat, T0 + 5)
		Actions.Advance(p, cat, T0 + 5 + 3600) -- 200 stored
		local ok, _, r = Actions.Collect(p, cat, T0 + 3605, d.Uid)
		Assert.True(ok)
		Assert.Equal(r.Amount, 200)
		Assert.Equal(p.Ore, 200)
		p.Ore = 1000 -- TH1 capacity 1000, no storage
		Actions.Advance(p, cat, T0 + 3605 + 3600)
		rejects(p, "StorageFull", function() return Actions.Collect(p, cat, T0 + 7205, d.Uid) end)
		p.Ore = 950
		assert(Actions.Collect(p, cat, T0 + 7205, d.Uid))
		Assert.Equal(p.Ore, 1000, "partial collect up to capacity")
		Assert.Near(p.Buildings[tostring(d.Uid)].Stored, 150, 1e-6, "rest stays in the collector")
	end,
	["collect rejections"] = function()
		local p = started()
		rejects(p, "UnknownBuilding", function() return Actions.Collect(p, cat, T0, 999) end)
		rejects(p, "NotCollector", function() return Actions.Collect(p, cat, T0, find(p, "B-NIN-03").Uid) end)
		local _, _, d = Actions.Place(p, cat, T0, OC, 2, 2)
		rejects(p, "NothingToCollect", function() return Actions.Collect(p, cat, T0, d.Uid) end)
	end,

	-- Sell -------------------------------------------------------------------------------------
	["sell: coins at sell prices, limit tracked"] = function()
		local p = started()
		p.Ore, p.Essence = 1000, 1000
		local ok, _, r = Actions.Sell(p, cat, T0, 500, 250)
		Assert.True(ok)
		Assert.Equal(r.Coins, 1000)
		Assert.Equal(p.Coins, 2500)
		Assert.Equal(p.Ore, 500)
		Assert.Equal(p.Essence, 750)
		Assert.Equal(r.Remaining, 6500)
	end,
	["sell rejections"] = function()
		local p = started()
		p.Ore, p.Essence = 1000, 1000
		rejects(p, "BadAmount", function() return Actions.Sell(p, cat, T0, -1, 0) end)
		rejects(p, "BadAmount", function() return Actions.Sell(p, cat, T0, 1.5, 0) end)
		rejects(p, "NotEnoughResources", function() return Actions.Sell(p, cat, T0, 1001, 0) end)
		rejects(p, "NothingToSell", function() return Actions.Sell(p, cat, T0, 0, 0) end)
		p.Market.SoldCoins = 7000
		rejects(p, "OverLimit", function() return Actions.Sell(p, cat, T0, 600, 0) end)
		p.Buildings[tostring(find(p, "B-NIN-03").Uid)] = nil
		rejects(p, "NoMarket", function() return Actions.Sell(p, cat, T0, 1, 0) end)
	end,
	["sell limit resets at 00:00 UTC"] = function()
		local p = started()
		p.Ore = 1000
		local nextMidnight = (T0 // 86400 + 1) * 86400
		p.Market.SoldCoins = 7500
		rejects(p, "OverLimit", function() return Actions.Sell(p, cat, nextMidnight - 1, 1, 0) end)
		assert(Actions.Sell(p, cat, nextMidnight, 1, 0))
		Assert.Equal(p.Market.SoldCoins, 1)
	end,

	-- Profile ----------------------------------------------------------------------------------
	["profile from saved data"] = function()
		Assert.Equal(Profile.FromSaved(nil).Version, 1)
		local saved = started()
		Assert.Equal(Profile.FromSaved(saved), saved)
		Assert.Error(function() Profile.FromSaved({ Version = 2 }) end, "unsupported saved version 2")
		Assert.Error(function() Profile.FromSaved("x") end, "expected a table")
	end,
	["every reason code is covered by a test above"] = function()
		local covered = {
			NoFaction = true, AlreadyPicked = true, UnknownFaction = true, UnknownBuilding = true,
			NotPurchasable = true, TownHallTooLow = true, LimitReached = true, OutOfBounds = true,
			Blocked = true, BadCoordinates = true, NotEnoughCoins = true, NoBuilderFree = true,
			AlreadyUpgrading = true, NotUpgrading = true, MaxLevel = true, PlaceAllFirst = true,
			NotCollector = true, NothingToCollect = true, StorageFull = true, NoMarket = true,
			BadAmount = true, NotEnoughResources = true, NothingToSell = true, OverLimit = true,
		}
		for _, reason in Actions.Reasons do
			Assert.True(covered[reason], "reason " .. reason)
		end
	end,
}
