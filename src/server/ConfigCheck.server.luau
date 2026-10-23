-- Server-start config validation (v0.2).
-- Clean: prints one summary line. Any error: warns each one, then halts this script with error().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Config.Validate)

local version = Config.Schema.TemplateVersion
local result = Validate.Run(Config)

if #result.Errors == 0 then
	print(`[Config] Stat Template {version}: {result.RecordCount} records across {result.TabCount} tabs, 0 errors`)
else
	for _, message in result.Errors do
		warn(`[Config] {message}`)
	end
	error(`[Config] Stat Template {version}: validation failed with {#result.Errors} error(s)`)
end
