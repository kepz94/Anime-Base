local Assert = require("./lib/Assert")
local Grid = require("../src/shared/Base/Grid")
local WorldConfig = require("../src/shared/Base/WorldConfig")

local N = WorldConfig.GridSize

return {
	["world config values (owner 2026-10-23)"] = function()
		Assert.Equal(WorldConfig.GridSize, 44)
		Assert.Equal(WorldConfig.TileStuds, 4)
		Assert.Equal(WorldConfig.PlotsPerServer, 6)
		Assert.Equal(WorldConfig.CameraPitchDegrees, 45)
	end,
	["fits exactly at both edges"] = function()
		Assert.Equal(Grid.InBounds(0, 0, 3, N), true)
		Assert.Equal(Grid.InBounds(N - 3, N - 3, 3, N), true)
	end,
	["one tile past an edge is out of bounds"] = function()
		Assert.Equal(Grid.InBounds(N - 2, 0, 3, N), false)
		Assert.Equal(Grid.InBounds(0, N - 2, 3, N), false)
		Assert.Equal(Grid.InBounds(-1, 0, 3, N), false)
		Assert.Equal(Grid.InBounds(0, -1, 3, N), false)
	end,
	["touching footprints do not overlap"] = function()
		Assert.Equal(Grid.Overlaps({ X = 0, Y = 0, Size = 3 }, { X = 3, Y = 0, Size = 3 }), false)
		Assert.Equal(Grid.Overlaps({ X = 0, Y = 0, Size = 3 }, { X = 0, Y = 3, Size = 3 }), false)
	end,
	["one shared tile overlaps"] = function()
		Assert.Equal(Grid.Overlaps({ X = 0, Y = 0, Size = 3 }, { X = 2, Y = 2, Size = 3 }), true)
	end,
	["CanPlace reports OutOfBounds, Blocked, BadCoordinates"] = function()
		local placed = { { Uid = 1, X = 10, Y = 10, Size = 4 } }
		Assert.DeepEqual({ Grid.CanPlace(placed, 42, 0, 3, N) }, { false, "OutOfBounds" })
		Assert.DeepEqual({ Grid.CanPlace(placed, 12, 12, 3, N) }, { false, "Blocked" })
		Assert.DeepEqual({ Grid.CanPlace(placed, 1.5, 0, 3, N) }, { false, "BadCoordinates" })
		Assert.DeepEqual({ Grid.CanPlace(placed, 14, 10, 3, N) }, { true, nil })
	end,
	["ignoreUid allows moving onto its own tiles"] = function()
		local placed = { { Uid = 1, X = 10, Y = 10, Size = 4 } }
		Assert.DeepEqual({ Grid.CanPlace(placed, 11, 10, 4, N, 1) }, { true, nil })
		Assert.DeepEqual({ Grid.CanPlace(placed, 11, 10, 4, N, 2) }, { false, "Blocked" })
	end,
	["tile centre offset in studs"] = function()
		local dx, dz = Grid.TileCenterOffset(0, 0, 3, 4)
		Assert.Equal(dx, 6)
		Assert.Equal(dz, 6)
		dx, dz = Grid.TileCenterOffset(10, 2, 1, 4)
		Assert.Equal(dx, 42)
		Assert.Equal(dz, 10)
	end,
}
