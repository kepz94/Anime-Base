-- Grid math (v0.3). Pure: no Roblox APIs, so Lune tests and the game share it.
-- Tiles are integers; (X, Y) is a footprint's top-left tile; footprints are Size x Size squares.

local Grid = {}

export type Footprint = { X: number, Y: number, Size: number, Uid: any? }

local function isInteger(n: any): boolean
	return type(n) == "number" and n == n and math.floor(n) == n
end

function Grid.InBounds(x: number, y: number, size: number, gridSize: number): boolean
	return x >= 0 and y >= 0 and x + size <= gridSize and y + size <= gridSize
end

-- Footprints that share only an edge do not overlap.
function Grid.Overlaps(a: Footprint, b: Footprint): boolean
	return a.X < b.X + b.Size and b.X < a.X + a.Size and a.Y < b.Y + b.Size and b.Y < a.Y + a.Size
end

-- Returns (true, nil) or (false, "BadCoordinates" | "OutOfBounds" | "Blocked").
-- ignoreUid skips one placed footprint (the building being moved).
function Grid.CanPlace(placed: { Footprint }, x: number, y: number, size: number, gridSize: number, ignoreUid: any?): (boolean, string?)
	if not isInteger(x) or not isInteger(y) then
		return false, "BadCoordinates"
	end
	if not Grid.InBounds(x, y, size, gridSize) then
		return false, "OutOfBounds"
	end
	local candidate = { X = x, Y = y, Size = size }
	for _, other in placed do
		if (ignoreUid == nil or other.Uid ~= ignoreUid) and Grid.Overlaps(candidate, other) then
			return false, "Blocked"
		end
	end
	return true, nil
end

-- Centre of a footprint in studs, measured from the plot's corner tile edge.
function Grid.TileCenterOffset(x: number, y: number, size: number, tileStuds: number): (number, number)
	return (x + size / 2) * tileStuds, (y + size / 2) * tileStuds
end

return Grid
