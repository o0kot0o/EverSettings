-- Addon-managed backups stored in SavedVariables (EverSettingsDB is account-wide:
-- WTF\Account\<account>\SavedVariables\EverSettings.lua).
--
-- These are snapshots of values EverSettings can read through the API. They are NOT copies
-- of the game's configuration files (Config.wtf, config-cache.wtf), which addons cannot access.
--
-- Scope (issue #5, finding 4): every original and backup entry records the setting's storage
-- scope and, for character-scoped settings, the owning character. Character values are only
-- ever restored on the character they came from.
local _, ns = ...

local Compat, Util = ns.Compat, ns.Util
local Backup = {}
ns.Backup = Backup

local function charKey() return Compat.GetCharacterKey() end

-- Key under which a definition's original value is stored.
function Backup.ScopeKey(def)
	if def.scope == "character" then return "character:" .. charKey() end
	if def.scope == "machine" then return "machine" end
	return "account" -- account, addon and unknown scopes are account-wide in SavedVariables
end

local function entryFor(def, value, raw)
	return {
		value = value, raw = raw, time = Util.Now(), build = Compat.buildString,
		provider = def.provider, scope = def.scope,
		owner = def.scope == "character" and charKey() or nil,
	}
end

-- One-time migration of 0.1/0.2 data (unscoped originals, owner-less backups).
-- Character-scoped legacy originals cannot be attributed to a character, so they are moved
-- to db.originalsLegacy and never restored automatically.
function Backup:Migrate()
	local db = ns.db
	db.originalsScoped = db.originalsScoped or {}
	db.originalsLegacy = db.originalsLegacy or {}
	if db.originals and next(db.originals) then
		for id, o in pairs(db.originals) do
			local def = ns.Registry:Get(id)
			if def and def.scope ~= "character" then
				local key = Backup.ScopeKey(def)
				db.originalsScoped[key] = db.originalsScoped[key] or {}
				if db.originalsScoped[key][id] == nil then
					db.originalsScoped[key][id] = { value = o.value, time = o.time, build = o.build, provider = def.provider, scope = def.scope, legacy = true }
				end
			else
				db.originalsLegacy[id] = o
			end
		end
	end
	db.originals = {}
end

-- Initial snapshot: taken once on first run, read-only. Machine and account variables go in
-- one snapshot; character variables are snapshotted per character.
function Backup:EnsureInitialSnapshot()
	local db = ns.db
	local catalog = ns.CVarCatalog and ns.CVarCatalog.cvars or {}
	local Registry = ns.Registry
	local key = charKey()

	local needGlobal = not db.snapshots.initial
	local needChar = not db.characterSnapshots[key]
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
		db.characterSnapshots[key] = { time = Util.Now(), build = Compat.buildString, values = charValues, api = apiValues }
	end
	ns:Debug("initial snapshot captured (%d variables)", count)
	return true
end

-- Raw value of a CVar in the initial snapshot (global or this character's).
function Backup:GetInitialRaw(cvarName)
	local db = ns.db
	local g = db.snapshots.initial
	if g and g.values[cvarName] ~= nil then return g.values[cvarName] end
	local c = db.characterSnapshots[charKey()]
	if c and c.values[cvarName] ~= nil then return c.values[cvarName] end
end

-- Original value: what a setting was before EverSettings changed it for the first time, in
-- the current scope (so each character keeps its own originals for character settings).
function Backup:RecordOriginal(def, value, raw)
	if value == nil then return end
	local db = ns.db
	local key = Backup.ScopeKey(def)
	db.originalsScoped[key] = db.originalsScoped[key] or {}
	if db.originalsScoped[key][def.id] == nil then
		db.originalsScoped[key][def.id] = entryFor(def, value, raw)
	end
end

function Backup:GetOriginalEntry(def)
	local scoped = ns.db.originalsScoped[Backup.ScopeKey(def)]
	return scoped and scoped[def.id]
end

function Backup:GetOriginal(def)
	local o = self:GetOriginalEntry(def)
	return o and o.value
end

function Backup:ClearOriginal(id)
	local def = ns.Registry:Get(id)
	if not def then return end
	local scoped = ns.db.originalsScoped[Backup.ScopeKey(def)]
	if scoped then scoped[id] = nil end
end

-- Originals that apply to the current character: account, machine and this character's.
function Backup:CurrentOriginals()
	local out = {}
	for id, def in pairs(ns.Registry.byId) do
		local o = self:GetOriginalEntry(def)
		if o then out[id] = o end
	end
	return out
end

-- Named backup of every available managed setting, with exact raw snapshots.
function Backup:Create(name, reason)
	local values = {}
	for _, def in ipairs(ns.Registry.ordered) do
		if not def.disabled and def.control ~= "readonly" and def.provider ~= "diagnostic" and ns.Providers:IsAvailable(def) then
			local ok, v = pcall(ns.Providers.Get, ns.Providers, def)
			if ok and v ~= nil then values[def.id] = entryFor(def, v, ns.Providers:Snapshot(def)) end
		end
	end
	local list = ns.db.backups
	list[#list + 1] = { name = name, time = Util.Now(), reason = reason, build = Compat.buildString,
		owner = charKey(), version = 2, values = values }
	while #list > ns.MAX_BACKUPS do table.remove(list, 1) end
	return list[#list]
end

function Backup:List()
	return ns.db.backups
end

function Backup:Delete(index)
	table.remove(ns.db.backups, index)
end

-- Normalise a backup entry (v2 tables, or v1 plain canonical values).
local function normalise(backup, id, entry)
	if type(entry) == "table" and entry.value ~= nil then return entry end
	local def = ns.Registry:Get(id)
	return { value = entry, scope = def and def.scope, owner = backup.owner }
end

-- Canonical values in a backup that may be restored on the current character, plus the
-- entries skipped and why. Character values from another (or an unknown) character are skipped.
function Backup:RestorableValues(backup)
	local values, skipped = {}, {}
	local me = charKey()
	for id, raw in pairs(backup.values) do
		local e = normalise(backup, id, raw)
		local def = ns.Registry:Get(id)
		if not def then
			skipped[#skipped + 1] = { id = id, reason = "unknown setting" }
		elseif def.scope == "character" and e.owner ~= me then
			skipped[#skipped + 1] = { id = id, reason = e.owner and ("belongs to " .. e.owner) or "character unknown (old backup)" }
		else
			values[id] = e
		end
	end
	table.sort(skipped, function(a, b) return a.id < b.id end)
	return values, skipped
end

-- Canonical view for comparison/preview.
function Backup:CanonicalValues(backup)
	local values = {}
	for id, e in pairs((self:RestorableValues(backup))) do values[id] = e.value end
	return values
end

-- Stage a backup's values (optionally only some ids). Raw snapshots are staged too, so
-- applying restores each CVar exactly (a preset's custom child values included).
-- Returns staged count and a report { cleared, replaced, skipped }.
function Backup:StageRestore(backup, filter)
	local values, skipped = self:RestorableValues(backup)
	local report = { staged = 0, cleared = 0, replaced = 0, skipped = skipped }
	for id, e in pairs(values) do
		local def = ns.Registry:Get(id)
		if def and (not filter or filter[id]) and ns.Values.Validate(def, e.value) then
			local outcome, replaced = ns.Changes:StageTarget(def, e.value, e.raw, "backup")
			if outcome == "staged" then report.staged = report.staged + 1 end
			if outcome == "cleared" then report.cleared = report.cleared + 1 end
			if replaced then report.replaced = report.replaced + 1 end
		end
	end
	ns.Callbacks:Fire("PendingChanged")
	return report.staged, report
end

-- Stage originals (pre-EverSettings values) for the current character's scopes.
function Backup:StageOriginals(filter)
	local report = { staged = 0, cleared = 0, replaced = 0, skipped = {} }
	for id, o in pairs(self:CurrentOriginals()) do
		local def = ns.Registry:Get(id)
		if def and (not filter or filter[id]) and ns.Values.Validate(def, o.value) then
			local outcome, replaced = ns.Changes:StageTarget(def, o.value, o.raw, "originals")
			if outcome == "staged" then report.staged = report.staged + 1 end
			if outcome == "cleared" then report.cleared = report.cleared + 1 end
			if replaced then report.replaced = report.replaced + 1 end
		end
	end
	ns.Callbacks:Fire("PendingChanged")
	return report.staged, report
end
