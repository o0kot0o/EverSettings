-- Addon-managed backups stored in SavedVariables.
--
-- These are snapshots of values EverSettings can read through the API. They are NOT copies
-- of the game's configuration files (Config.wtf, config-cache.wtf), which addons cannot access.
local _, ns = ...

local Compat, Util = ns.Compat, ns.Util
local Backup = {}
ns.Backup = Backup

-- Initial snapshot: taken once on first run, read-only. Machine and account variables go in
-- one snapshot; character variables are snapshotted per character.
function Backup:EnsureInitialSnapshot()
	local db = ns.db
	local catalog = ns.CVarCatalog and ns.CVarCatalog.cvars or {}
	local Registry = ns.Registry
	local charKey = Compat.GetCharacterKey()

	local needGlobal = not db.snapshots.initial
	local needChar = not db.characterSnapshots[charKey]
	if not needGlobal and not needChar then return false end

	local globalValues, charValues = {}, {}
	local count = 0
	for name, entry in pairs(catalog) do
		local value = Compat.GetCVar(name)
		if value ~= nil then
			if Registry.HasFlag(entry[3], Registry.FLAG_CHARACTER) then
				charValues[name] = value
			else
				globalValues[name] = value
			end
			count = count + 1
		end
	end
	-- Non-CVar settings (API providers) are captured as canonical values.
	local apiValues = {}
	for _, def in ipairs(Registry.ordered) do
		if def.provider == "api" and ns.Providers:IsAvailable(def) then
			local v = ns.Providers:Get(def)
			if v ~= nil then apiValues[def.id] = v end
		end
	end
	if needGlobal then
		db.snapshots.initial = { time = Util.Now(), build = Compat.buildString, values = globalValues, addonVersion = ns.version }
	end
	if needChar then
		db.characterSnapshots[charKey] = { time = Util.Now(), build = Compat.buildString, values = charValues, api = apiValues }
	end
	ns:Debug("initial snapshot captured (%d variables)", count)
	return true
end

-- Raw value of a CVar in the initial snapshot (global or this character's).
function Backup:GetInitialRaw(cvarName)
	local db = ns.db
	local g = db.snapshots.initial
	if g and g.values[cvarName] ~= nil then return g.values[cvarName] end
	local c = db.characterSnapshots[Compat.GetCharacterKey()]
	if c and c.values[cvarName] ~= nil then return c.values[cvarName] end
end

-- Original value: what a setting was before EverSettings changed it for the first time.
function Backup:RecordOriginal(def, value)
	local originals = ns.db.originals
	if originals[def.id] == nil and value ~= nil then
		originals[def.id] = { value = value, time = Util.Now(), build = Compat.buildString }
	end
end

function Backup:GetOriginal(def)
	local o = ns.db.originals[def.id]
	return o and o.value
end

function Backup:ClearOriginal(id)
	ns.db.originals[id] = nil
end

-- Named backup of every available managed setting (taken before applying a profile).
function Backup:Create(name, reason)
	local values = {}
	for _, def in ipairs(ns.Registry.ordered) do
		if not def.disabled and def.control ~= "readonly" and ns.Providers:IsAvailable(def) then
			local v = ns.Providers:Get(def)
			if v ~= nil then values[def.id] = v end
		end
	end
	local list = ns.db.backups
	list[#list + 1] = { name = name, time = Util.Now(), reason = reason, build = Compat.buildString, values = values }
	while #list > ns.MAX_BACKUPS do table.remove(list, 1) end
	return list[#list]
end

function Backup:List()
	return ns.db.backups
end

function Backup:Delete(index)
	table.remove(ns.db.backups, index)
end

-- Stage the values of a backup (optionally only some ids) as pending changes.
-- Restoring goes through the normal apply pipeline, never through a global reset.
function Backup:StageRestore(backup, filter)
	local staged = 0
	for id, value in pairs(backup.values) do
		local def = ns.Registry:Get(id)
		if def and (not filter or filter[id]) then
			local current = ns.Providers:Get(def)
			if not ns.Values.Equal(def, current, value) and ns.Values.Validate(def, value) then
				ns.Changes:Stage(def, value)
				staged = staged + 1
			end
		end
	end
	return staged
end

-- Stage originals (pre-EverSettings values) for the given ids or all.
function Backup:StageOriginals(filter)
	local staged = 0
	for id, o in pairs(ns.db.originals) do
		local def = ns.Registry:Get(id)
		if def and (not filter or filter[id]) then
			local current = ns.Providers:Get(def)
			if not ns.Values.Equal(def, current, o.value) and ns.Values.Validate(def, o.value) then
				ns.Changes:Stage(def, o.value)
				staged = staged + 1
			end
		end
	end
	return staged
end
