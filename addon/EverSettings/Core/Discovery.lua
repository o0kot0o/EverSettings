-- Runtime settings discovery. Strictly read-only: enumerates the client's console
-- registry with ConsoleGetAllCommands(), separates variables from commands, and compares
-- the result with the bundled catalog. It never writes to or "tests" any variable.
local _, ns = ...

local Compat, Util = ns.Compat, ns.Util
local Discovery = { last = nil }
ns.Discovery = Discovery

local MAX_LISTED = 200 -- cap stored name lists to keep SavedVariables small

local function numericOrString(a, b)
	local na, nb = tonumber(a), tonumber(b)
	if na and nb then return Util.NearlyEqual(na, nb, 1e-6) end
	return tostring(a) == tostring(b)
end

function Discovery:Run()
	local result = {
		time = Util.Now(), build = Compat.buildString, available = false,
		numCVars = 0, numCommands = 0, new = {}, missing = {}, changedDefaults = {}, byCategory = {},
		clientCVars = {},
	}
	if not Compat.caps.ConsoleGetAllCommands then
		self.last = result
		ns.Callbacks:Fire("DiscoveryFinished", result)
		return result
	end
	local ok, commands = pcall(ConsoleGetAllCommands)
	if not ok or type(commands) ~= "table" then
		result.error = tostring(commands)
		self.last = result
		ns.Callbacks:Fire("DiscoveryFinished", result)
		return result
	end
	result.available = true
	local catalog = ns.CVarCatalog and ns.CVarCatalog.cvars or {}
	local seen = {}
	for _, info in ipairs(commands) do
		local name = info.command
		if type(name) == "string" then
			if info.commandType == Compat.CONSOLE_COMMAND_TYPE_CVAR then
				result.numCVars = result.numCVars + 1
				seen[name:lower()] = true
				local entry, canonical = ns.Registry.FindCatalogEntry(name)
				result.clientCVars[name] = { help = info.help, category = info.category }
				local cat = tonumber(info.category) or -1
				result.byCategory[cat] = (result.byCategory[cat] or 0) + 1
				if not entry then
					result.new[#result.new + 1] = name
				else
					local clientDefault = Compat.GetCVarDefault(name)
					if clientDefault ~= nil and not numericOrString(clientDefault, entry[1]) then
						result.changedDefaults[#result.changedDefaults + 1] = { name = canonical, catalog = entry[1], client = clientDefault }
					end
				end
			else
				result.numCommands = result.numCommands + 1
			end
		end
	end
	for name in pairs(catalog) do
		if not seen[name:lower()] then
			result.missing[#result.missing + 1] = name
		end
	end
	table.sort(result.new)
	table.sort(result.missing)
	table.sort(result.changedDefaults, function(a, b) return a.name < b.name end)
	self.last = result
	self:Persist(result)
	ns.Callbacks:Fire("DiscoveryFinished", result)
	return result
end

-- Store a compact summary per build so changes between game updates can be reported.
function Discovery:Persist(result)
	if not ns.db then return end
	local store = ns.db.discovery
	local function cap(list)
		local out = {}
		for i = 1, math.min(#list, MAX_LISTED) do out[i] = list[i] end
		return out
	end
	local previousBuild = store.lastBuild
	store.byBuild = store.byBuild or {}
	store.byBuild[result.build] = {
		time = result.time, numCVars = result.numCVars, numCommands = result.numCommands,
		new = cap(result.new), missing = cap(result.missing), numNew = #result.new, numMissing = #result.missing,
		numChangedDefaults = #result.changedDefaults, changedDefaults = cap(result.changedDefaults),
	}
	if previousBuild and previousBuild ~= result.build then
		store.previousBuild = previousBuild
	end
	store.lastBuild = result.build
end

-- Unclassified = discovered (or catalogued) variables without a curated definition.
function Discovery:GetUnclassifiedCount()
	local n = 0
	for name in pairs(ns.CVarCatalog and ns.CVarCatalog.cvars or {}) do
		if not ns.Registry:IsCVarClassified(name) then n = n + 1 end
	end
	if self.last then n = n + #self.last.new end
	return n
end
