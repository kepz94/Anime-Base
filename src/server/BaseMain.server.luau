-- Base entry point (v0.3): starts plots, remotes and the base service.
-- Separate from Main.server.luau (version smoke test) and ConfigCheck.server.luau (config validation).

local BaseService = require(script.Parent.Base.BaseService)

BaseService.Init()
