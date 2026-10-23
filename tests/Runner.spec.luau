-- Smoke case for the runner itself. Exit-code behavior verified 2026-10-23 with a deliberate failure (removed).
local Assert = require("./lib/Assert")

return {
	["runner works"] = function()
		Assert.Equal(1 + 1, 2)
	end,
}
