local Assert = require("./lib/Assert")
local Rules = require("../src/shared/Economy/Rules")

return {
	["accrue at rate, clamped at cap"] = function()
		Assert.Equal(Rules.Accrue(0, 200, 1000, 3600), 200)
		Assert.Near(Rules.Accrue(0, 200, 1000, 18), 1, 1e-9)
		Assert.Equal(Rules.Accrue(900, 200, 1000, 3600), 1000)
		Assert.Equal(Rules.Accrue(1000, 200, 1000, 3600), 1000)
		Assert.Equal(Rules.Accrue(10, 200, 1000, 0), 10, "zero time")
		Assert.Equal(Rules.Accrue(10, 200, 1000, -5), 10, "negative time is ignored")
	end,
	["collect takes whole units within free capacity"] = function()
		Assert.Equal(Rules.CollectAmount(137.9, 0, 1000), 137)
		Assert.Equal(Rules.CollectAmount(500, 800, 1000), 200, "partial room")
		Assert.Equal(Rules.CollectAmount(500, 1000, 1000), 0, "full")
		Assert.Equal(Rules.CollectAmount(500, 1200, 1000), 0, "over capacity never goes negative")
		Assert.Equal(Rules.CollectAmount(0.9, 0, 1000), 0, "less than one unit")
	end,
	["capacity is town hall plus storages"] = function()
		Assert.Equal(Rules.Capacity(1000, { 1500 }), 2500)
		Assert.Equal(Rules.Capacity(10000, { 45000, 45000 }), 100000)
		Assert.Equal(Rules.Capacity(1000, {}), 1000)
	end,
	["market cycle changes exactly at 00:00 UTC"] = function()
		local day = 86400
		local midnight = 20000 * day
		Assert.Equal(Rules.MarketCycleId(midnight - 1, 0, day), 19999)
		Assert.Equal(Rules.MarketCycleId(midnight, 0, day), 20000)
		Assert.Equal(Rules.MarketCycleId(midnight + day - 1, 0, day), 20000)
		Assert.Equal(Rules.MarketCycleId(midnight + 3600, 3600, day), 20000, "reset second offset")
		Assert.Equal(Rules.MarketCycleId(midnight + 3599, 3600, day), 19999, "reset second offset")
	end,
	["sell value at sell prices"] = function()
		Assert.Equal(Rules.SellValue(500, 0, 1, 2), 500)
		Assert.Equal(Rules.SellValue(100, 250, 1, 2), 600)
	end,
	["refund is half, rounded down"] = function()
		Assert.Equal(Rules.Refund(600), 300)
		Assert.Equal(Rules.Refund(301), 150)
		Assert.Equal(Rules.Refund(0), 0)
	end,
}
