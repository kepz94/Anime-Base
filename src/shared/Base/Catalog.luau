-- Catalog (v0.3): read-only lookups over the generated Config tables (Buildings, BuildingLevels, Economy).
-- Pure: the tables are passed in, so Lune tests use the real generated Config/Data files.

local Catalog = {}
Catalog.__index = Catalog

export type Catalog = typeof(setmetatable({} :: {
	_buildings: { [string]: any },
	_levels: { [string]: { [number]: any } },
	_maxLevel: { [string]: number },
	_settings: { [string]: any },
	_ids: { string },
}, Catalog))

function Catalog.new(buildings: { any }, buildingLevels: { any }, economy: { any }): Catalog
	local self = setmetatable({
		_buildings = {},
		_levels = {},
		_maxLevel = {},
		_settings = {},
		_ids = {},
	}, Catalog)
	for _, b in buildings do
		self._buildings[b.BuildingId] = b
		table.insert(self._ids, b.BuildingId)
	end
	table.sort(self._ids)
	for _, row in buildingLevels do
		local byLevel = self._levels[row.BuildingId] or {}
		self._levels[row.BuildingId] = byLevel
		byLevel[row.Level] = row
		self._maxLevel[row.BuildingId] = math.max(self._maxLevel[row.BuildingId] or 0, row.Level)
	end
	for _, s in economy do
		self._settings[s.SettingId] = s
	end
	return self
end

function Catalog.Building(self: Catalog, buildingId: string): any?
	return self._buildings[buildingId]
end

function Catalog.Level(self: Catalog, buildingId: string, level: number): any?
	local byLevel = self._levels[buildingId]
	return byLevel and byLevel[level]
end

function Catalog.MaxLevel(self: Catalog, buildingId: string): number
	return self._maxLevel[buildingId] or 0
end

-- How many of a building may exist at Town Hall th: the largest CountAllowed among its
-- level rows whose RequiredTownHall <= th; 0 when no row qualifies.
function Catalog.AllowedAt(self: Catalog, buildingId: string, th: number): number
	local allowed = 0
	for _, row in self._levels[buildingId] or {} do
		if row.RequiredTownHall ~= nil and row.CountAllowed ~= nil and row.RequiredTownHall <= th and row.CountAllowed > allowed then
			allowed = row.CountAllowed
		end
	end
	return allowed
end

-- Building IDs of one faction, sorted by ID.
function Catalog.ForFaction(self: Catalog, faction: string): { string }
	local out = {}
	for _, id in self._ids do
		if self._buildings[id].Faction == faction then
			table.insert(out, id)
		end
	end
	return out
end

-- First building of a faction with this type (and resource type, when given); nil if none.
function Catalog.FindByType(self: Catalog, faction: string, buildingType: string, resourceType: string?): string?
	for _, id in self._ids do
		local b = self._buildings[id]
		if b.Faction == faction and b.BuildingType == buildingType and (resourceType == nil or b.ResourceType == resourceType) then
			return id
		end
	end
	return nil
end

-- Economy tab value. Unknown IDs and settings with no value (undecided) raise.
function Catalog.Setting(self: Catalog, settingId: string): number
	local s = self._settings[settingId]
	if s == nil then
		error(`Catalog: unknown setting {settingId}`, 2)
	end
	if s.Value == nil then
		error(`Catalog: setting {settingId} has no value (undecided)`, 2)
	end
	return s.Value
end

return Catalog
