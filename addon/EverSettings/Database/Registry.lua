-- Setting definition registry. Definitions are plain data tables registered at load time;
-- Finalize() validates them and derives metadata from the bundled CVar catalog.
local _, ns = ...

local Util = ns.Util
local Registry = {
	ordered = {},     -- definitions in registration order
	byId = {},
	byCategory = {},  -- [categoryId] = { [subId] = { defs... } }
	byCVar = {},      -- [lower cvar name] = { defs... }
	errors = {},      -- validation errors (definitions with errors are disabled)
	warnings = {},
	finalized = false,
}
ns.Registry = Registry

local catalogIndex -- [lower name] = canonical name

local function BuildCatalogIndex()
	catalogIndex = {}
	local catalog = ns.CVarCatalog
	if not catalog then return end
	for name in pairs(catalog.cvars) do
		catalogIndex[name:lower()] = name
	end
end

-- Returns entry, canonicalName. Entry layout: { default, consoleCategory, flags, exposure, help }.
function Registry.FindCatalogEntry(name)
	if not name then return nil end
	if not catalogIndex then BuildCatalogIndex() end
	local canonical = catalogIndex[name:lower()]
	if not canonical then return nil end
	return ns.CVarCatalog.cvars[canonical], canonical
end

local FLAG_ACCOUNT, FLAG_CHARACTER, FLAG_SECURE = 1, 2, 4
Registry.FLAG_ACCOUNT, Registry.FLAG_CHARACTER, Registry.FLAG_SECURE = FLAG_ACCOUNT, FLAG_CHARACTER, FLAG_SECURE

local function HasFlag(flags, flag)
	return flags and (flags % (flag * 2)) >= flag
end
Registry.HasFlag = HasFlag

function Registry.ScopeFromFlags(flags)
	if HasFlag(flags, FLAG_CHARACTER) then return "character" end
	if HasFlag(flags, FLAG_ACCOUNT) then return "account" end
	return "machine"
end

function Registry:Define(def)
	if self.finalized then
		error("EverSettings: definitions must be registered before Finalize()")
	end
	self.ordered[#self.ordered + 1] = def
end

-- Convenience: register several definitions sharing common fields.
function Registry:DefineGroup(common, defs)
	for _, def in ipairs(defs) do
		for k, v in pairs(common) do
			if def[k] == nil then def[k] = v end
		end
		self:Define(def)
	end
end

local function SummaryStatus(def)
	if def.status then return def.status end
	local v = def.verification or {}
	for _, state in pairs(v) do
		if state == "unsupported" then return "unsupported" end
	end
	if v.effect == "verified" then return "verified" end
	if def.classification == "experimental" then return "experimental" end
	return v.values or v.exists or "unknown"
end

function Registry:Finalize()
	if self.finalized then return end
	BuildCatalogIndex()
	local catalog = ns.CVarCatalog
	for _, def in ipairs(self.ordered) do
		local errors, warnings = ns.Schema.Validate(def, ns.Categories, catalog)
		if self.byId[def.id] then
			errors[#errors + 1] = def.id .. ": duplicate id"
		end
		for _, w in ipairs(warnings) do self.warnings[#self.warnings + 1] = w end
		if #errors > 0 then
			for _, e in ipairs(errors) do self.errors[#self.errors + 1] = e end
			def.disabled = true
			def.disabledReason = "Definition failed validation: " .. errors[1]
		end

		-- Derive catalog facts for every referenced CVar.
		def.cvarInfo = {}
		local names = def.cvars or (def.cvar and { def.cvar }) or {}
		for _, name in ipairs(names) do
			local entry, canonical = Registry.FindCatalogEntry(name)
			if entry then
				def.cvarInfo[#def.cvarInfo + 1] = {
					name = canonical, default = entry[1], consoleCategory = entry[2], flags = entry[3],
					exposure = entry[4], help = entry[5],
				}
			end
		end
		local primary = def.cvarInfo[1]
		if primary then
			if def.provider == "cvar" then def.cvar = primary.name end
			def.scope = def.scope or Registry.ScopeFromFlags(primary.flags)
			def.classification = def.classification or (primary.exposure == 2 and "standard" or "hidden")
			if HasFlag(primary.flags, FLAG_SECURE) then
				def.restrictions = def.restrictions or {}
				def.restrictions.secure = true
				if def.restrictions.combat == nil then def.restrictions.combat = true end
			end
		end
		def.scope = def.scope or "unknown"
		def.classification = def.classification or "hidden"
		def.apply = def.apply or "immediate"
		def.restrictions = def.restrictions or {}
		def.keywords = def.keywords or {}
		def.related = def.related or {}
		def.verification = def.verification or {}
		def.statusSummary = SummaryStatus(def)
		def.technical = def.technical or (def.cvars and table.concat(def.cvars, ", ")) or def.cvar or def.api or def.id

		if not self.byId[def.id] then
			self.byId[def.id] = def
			local cat = self.byCategory[def.category] or {}
			self.byCategory[def.category] = cat
			local sub = cat[def.subcategory] or {}
			cat[def.subcategory] = sub
			sub[#sub + 1] = def
			for _, info in ipairs(def.cvarInfo) do
				local key = info.name:lower()
				self.byCVar[key] = self.byCVar[key] or {}
				table.insert(self.byCVar[key], def)
			end
		end
	end
	self.finalized = true
end

function Registry:Get(id)
	return self.byId[id]
end

function Registry:GetByCVar(name)
	return name and self.byCVar[name:lower()]
end

-- Ordered list of { sub = subcategory, defs = {...} } for a category, skipping empty subcategories.
function Registry:GetCategorySections(categoryId)
	local cat = ns.Categories.byId[categoryId]
	local out = {}
	if not cat then return out end
	local byCat = self.byCategory[categoryId] or {}
	for _, sub in ipairs(cat.subcategories) do
		local defs = byCat[sub.id]
		if defs and #defs > 0 then
			out[#out + 1] = { sub = sub, defs = defs }
		end
	end
	return out
end

function Registry:CountCategory(categoryId)
	local n = 0
	for _, defs in pairs(self.byCategory[categoryId] or {}) do n = n + #defs end
	return n
end

function Registry:Search(query)
	query = Util.Trim(query):lower()
	local results = {}
	if query == "" then return results end
	for _, def in ipairs(self.ordered) do
		if self.byId[def.id] == def and Util.MatchesQuery(query, def.name, def.technical, def.description, def.keywords, def.id) then
			results[#results + 1] = def
		end
	end
	return results
end

-- True when a CVar is covered by at least one curated definition.
function Registry:IsCVarClassified(name)
	return self.byCVar[name:lower()] ~= nil
end
