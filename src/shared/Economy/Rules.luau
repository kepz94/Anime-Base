-- Economy rules (v0.3, Design v2.4). Pure: no Roblox APIs.

local Rules = {}

-- Collector production: stored grows at ratePerHour for `seconds`, never above cap.
-- Non-positive time leaves stored unchanged.
function Rules.Accrue(stored: number, ratePerHour: number, cap: number, seconds: number): number
	if seconds <= 0 then
		return stored
	end
	return math.min(cap, stored + ratePerHour * seconds / 3600)
end

-- Whole units moved from a collector into storage: limited by what is stored and by free capacity.
function Rules.CollectAmount(stored: number, current: number, capacity: number): number
	local room = math.max(0, capacity - current)
	return math.floor(math.min(stored, room))
end

-- Total capacity for one resource: the Town Hall's own storage plus each storage's capacity.
function Rules.Capacity(townHallCapacity: number, storageCapacities: { number }): number
	local total = townHallCapacity
	for _, c in storageCapacities do
		total += c
	end
	return total
end

-- Market sell-limit cycle index. Changes when (now - resetSecond) crosses a multiple of interval.
-- resetSecond 0 + interval 86400 = daily at 00:00 UTC (os.time() is UTC epoch seconds).
function Rules.MarketCycleId(now: number, resetSecond: number, interval: number): number
	return math.floor((now - resetSecond) / interval)
end

-- Coin value of a sale at the Market sell prices.
function Rules.SellValue(ore: number, essence: number, orePrice: number, essencePrice: number): number
	return ore * orePrice + essence * essencePrice
end

-- Cancelled upgrade or construction: 50% of the Coin cost back, rounded down (mirror).
function Rules.Refund(cost: number): number
	return math.floor(cost * 0.5)
end

return Rules
