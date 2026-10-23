local Assert = require("./lib/Assert")
local Catalog = require("../src/shared/Base/Catalog")

local cat = Catalog.new(
	require("../src/shared/Config/Data/Buildings"),
	require("../src/shared/Config/Data/BuildingLevels"),
	require("../src/shared/Config/Data/Economy")
)

return {
	["building and level lookup"] = function()
		Assert.Equal(cat:Building("B-NIN-04").BuildingType, "Collector")
		Assert.Equal(cat:Level("B-NIN-04", 1).UpgradeCost, 300)
		Assert.Equal(cat:Level("B-NIN-04", 7), nil)
		Assert.Equal(cat:MaxLevel("B-NIN-04"), 6)
		Assert.Equal(cat:Building("B-NOPE-99"), nil)
	end,
	["allowed counts by Town Hall"] = function()
		for th, n in { [1] = 1, [2] = 2, [3] = 3 } do
			Assert.Equal(cat:AllowedAt("B-NIN-04", th), n, `Ore Collector at TH{th}`)
		end
		Assert.Equal(cat:AllowedAt("B-NIN-11", 1), 0, "Wall TH1")
		Assert.Equal(cat:AllowedAt("B-NIN-11", 2), 25, "Wall TH2")
		Assert.Equal(cat:AllowedAt("B-NIN-11", 3), 50, "Wall TH3")
		Assert.Equal(cat:AllowedAt("B-NIN-10", 2), 0, "Laboratory TH2")
		Assert.Equal(cat:AllowedAt("B-NIN-10", 3), 1, "Laboratory TH3")
		Assert.Equal(cat:AllowedAt("B-NIN-02", 1), 2, "Builder Hut TH1")
	end,
	["find by type"] = function()
		Assert.Equal(cat:FindByType("Ninja", "Collector", "Ore"), "B-NIN-04")
		Assert.Equal(cat:FindByType("Ki Warriors", "Storage", "Essence"), "B-KI-07")
		Assert.Equal(cat:FindByType("Ninja", "Town Hall"), "B-NIN-01")
		Assert.Equal(cat:FindByType("Ninja", "Hero Hall"), nil)
	end,
	["faction building list is ordered by ID"] = function()
		local ids = cat:ForFaction("Ninja")
		Assert.Equal(#ids, 11)
		Assert.Equal(ids[1], "B-NIN-01")
		Assert.Equal(ids[11], "B-NIN-11")
		Assert.Equal(#cat:ForFaction("Nobody"), 0)
	end,
	["settings"] = function()
		Assert.Equal(cat:Setting("StartingCoins"), 1500)
		Assert.Equal(cat:Setting("EssenceSellPrice"), 2)
		Assert.Error(function()
			cat:Setting("RelicShardSellPrice")
		end, "has no value")
		Assert.Error(function()
			cat:Setting("NoSuchSetting")
		end, "unknown setting")
	end,
}
