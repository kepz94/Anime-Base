-- Config validation (v0.2). Run once at server start by ConfigCheck.server.luau.
-- Run(Config) returns { Errors = { string }, RecordCount = number, TabCount = number }.
-- Every error names the sheet, sheet row, record ID and field, so it traces to one template cell.
-- A nil field means "not yet decided" (Legend) and is never an error, except a record's ID and a levels row's Level.

local Validate = {}

-- ID faction code -> Faction value (Legend: FAC = NIN or KI).
local FACTION_CODES = {
	NIN = "Ninja",
	KI = "Ki Warriors",
}

-- Buildings: Resource type applies only to these building types (Legend: Resource type).
local RESOURCE_TYPE_SCOPE = {
	Collector = true,
	Storage = true,
}

-- Building Levels: type-specific columns and the building types they apply to
-- (Legend: "Building Levels columns by type"; other types leave them blank).
local BUILDING_LEVEL_SCOPE = {
	ProductionPerHour = { Collector = true },
	ResourceCapacity = { Collector = true, Storage = true },
	MarketSellLimit = { Market = true },
	ArmyCampHousing = { ["Army Camp"] = true },
	MaxHeroLevel = { ["Hero Hall"] = true },
	HeroSlots = { ["Hero Hall"] = true },
	BuildersProvided = { ["Builder Hut"] = true },
	Unlocks = { Barracks = true },
}

local function splitType(fieldType: string): (string, string?)
	local base, arg = string.match(fieldType, "^(%a+):(.+)$")
	if base then
		return base, arg
	end
	return fieldType, nil
end

-- Returns an error message for a non-nil value, or nil if the value is valid for its type.
local function checkType(value: any, fieldType: string, enumSets: { [string]: { [string]: boolean } }): string?
	local base, arg = splitType(fieldType)
	if base == "id" or base == "ref" or base == "string" then
		if type(value) ~= "string" or value == "" then
			return `expected non-empty text, got {typeof(value)} {tostring(value)}`
		end
		return nil
	elseif base == "int" or base == "number" then
		if type(value) ~= "number" or value ~= value then
			return `expected a number, got {typeof(value)} {tostring(value)}`
		elseif value < 0 then
			return `expected a non-negative number, got {value}`
		elseif base == "int" and math.floor(value) ~= value then
			return `expected a whole number, got {value}`
		end
		return nil
	elseif base == "bool" then
		if type(value) ~= "boolean" then
			return `expected true/false (Y/N), got {typeof(value)} {tostring(value)}`
		end
		return nil
	elseif base == "enum" then
		local set = arg and enumSets[arg]
		if set == nil then
			return `unknown enum {tostring(arg)}`
		elseif type(value) ~= "string" or not set[value] then
			return `{tostring(value)} is not a {arg} value`
		end
		return nil
	elseif base == "footprint" then
		if type(value) ~= "string" or string.match(value, "^%d+x%d+$") == nil then
			return `expected <W>x<D> (e.g. 3x3), got {tostring(value)}`
		end
		return nil
	elseif base == "idlist" then
		if type(value) ~= "table" then
			return `expected a list of IDs, got {typeof(value)}`
		end
		for index, id in value do
			if type(index) ~= "number" or type(id) ~= "string" or id == "" then
				return `list entry {tostring(index)} is not an ID`
			end
		end
		return nil
	else
		return `unknown field type {fieldType}`
	end
end

function Validate.Run(Config)
	local schema = Config.Schema
	local errors = {}
	local recordCount = 0

	local enumSets = {}
	for name, values in schema.Enums do
		local set = {}
		for _, value in values do
			set[value] = true
		end
		enumSets[name] = set
	end

	local tabsByModule = {}
	for _, tab in schema.Tabs do
		tabsByModule[tab.Module] = tab
	end

	local function fail(tab, record, field: string, message: string)
		local keyField = tab.Fields[1].Key
		table.insert(errors, `{tab.Sheet} row {tostring(record._Row)} ({tostring(record[keyField])}) {field}: {message}`)
	end

	-- Pass 1: field types, unknown fields, and the ID index of every base tab.
	local index = {} -- Module -> { [ID] = record }
	for _, tab in schema.Tabs do
		local records = Config.Data[tab.Module]
		if type(records) ~= "table" then
			table.insert(errors, `{tab.Sheet}: data module {tab.Module} is missing`)
			continue
		end

		local known = { _Row = true }
		for _, field in tab.Fields do
			known[field.Key] = true
		end

		local ids = {}
		index[tab.Module] = ids
		for _, record in records do
			recordCount += 1
			for key in record do
				if not known[key] then
					fail(tab, record, tostring(key), "field is not in the schema")
				end
			end
			for _, field in tab.Fields do
				local value = record[field.Key]
				if value ~= nil then
					local message = checkType(value, field.Type, enumSets)
					if message then
						fail(tab, record, field.Key, message)
					end
				end
			end

			local keyField = tab.Fields[1].Key
			local id = record[keyField]
			if id == nil then
				fail(tab, record, keyField, "ID is required")
			elseif tab.Kind == "base" or tab.Kind == "extension" then
				if ids[id] then
					fail(tab, record, keyField, `duplicate ID (first on row {ids[id]._Row})`)
				else
					ids[id] = record
				end
			elseif tab.Kind == "levels" then
				-- Levels tabs are keyed by (ID, Level); checked in pass 2.
			else
				fail(tab, record, keyField, `unknown tab kind {tostring(tab.Kind)}`)
			end
		end
	end

	-- Pass 2: ID format, references, and per-tab rules.
	for _, tab in schema.Tabs do
		local records = Config.Data[tab.Module]
		if type(records) ~= "table" then
			continue
		end
		local keyField = tab.Fields[1].Key
		local levelKeys = {}

		for _, record in records do
			local id = record[keyField]

			-- ID format: <Prefix>-<FAC>-## with FAC matching Faction.
			if tab.Kind == "base" and type(id) == "string" then
				local prefix, code = string.match(id, "^(%u)%-(%u+)%-%d%d$")
				if prefix == nil then
					fail(tab, record, keyField, `ID must be {tab.IdPrefix}-<NIN|KI>-## (e.g. {tab.IdPrefix}-NIN-01)`)
				elseif prefix ~= tab.IdPrefix then
					fail(tab, record, keyField, `ID prefix must be {tab.IdPrefix}`)
				elseif FACTION_CODES[code] == nil then
					fail(tab, record, keyField, `faction code {code} must be NIN or KI`)
				elseif record.Faction ~= nil and FACTION_CODES[code] ~= record.Faction then
					fail(tab, record, "Faction", `{record.Faction} does not match ID code {code}`)
				end
			end

			-- References (ref:<Tab>, idlist:<Tab>).
			for _, field in tab.Fields do
				local value = record[field.Key]
				local base, target = splitType(field.Type)
				if value == nil or target == nil or (base ~= "ref" and base ~= "idlist") then
					continue
				end
				local targetIds = index[target]
				if targetIds == nil then
					fail(tab, record, field.Key, `references unknown tab {target}`)
				elseif base == "ref" then
					if type(value) == "string" and targetIds[value] == nil then
						fail(tab, record, field.Key, `{value} does not exist in {tabsByModule[target].Sheet}`)
					end
				elseif type(value) == "table" then
					for _, refId in value do
						if type(refId) == "string" and targetIds[refId] == nil then
							fail(tab, record, field.Key, `{refId} does not exist in {tabsByModule[target].Sheet}`)
						end
					end
				end
			end

			-- Levels tabs: Level required, (ID, Level) unique.
			if tab.Kind == "levels" then
				if record.Level == nil then
					fail(tab, record, "Level", "Level is required on a levels row")
				elseif id ~= nil then
					local pair = `{tostring(id)}#{tostring(record.Level)}`
					if levelKeys[pair] then
						fail(tab, record, "Level", `duplicate (ID, Level) (first on row {levelKeys[pair]})`)
					else
						levelKeys[pair] = record._Row
					end
				end
			end

			-- Heroes: the Units row must be Class Hero once Class is set.
			if tab.Module == "Heroes" and type(id) == "string" then
				local unit = index.Units and index.Units[id]
				if unit and unit.Class ~= nil and unit.Class ~= "Hero" then
					fail(tab, record, keyField, `Units row {unit._Row} has Class {unit.Class}, expected Hero`)
				end
			end

			-- Buildings: Resource type only on Collector/Storage once Building type is set.
			if tab.Module == "Buildings" and record.ResourceType ~= nil and record.BuildingType ~= nil then
				if not RESOURCE_TYPE_SCOPE[record.BuildingType] then
					fail(tab, record, "ResourceType", `not used by Building type {record.BuildingType}`)
				end
			end

			-- Building Levels: type-specific columns only on their building types once the type is set.
			if tab.Module == "BuildingLevels" and type(id) == "string" then
				local building = index.Buildings and index.Buildings[id]
				local buildingType = building and building.BuildingType
				if buildingType ~= nil then
					for fieldKey, allowed in BUILDING_LEVEL_SCOPE do
						if record[fieldKey] ~= nil and not allowed[buildingType] then
							fail(tab, record, fieldKey, `not used by Building type {buildingType}`)
						end
					end
				end
			end
		end
	end

	return {
		Errors = errors,
		RecordCount = recordCount,
		TabCount = #schema.Tabs,
	}
end

return Validate
