-- Diagnostics: API capability report, database coverage and verification progress,
-- and a read-only consistency check of definitions against the running client.
local _, ns = ...

local Util = ns.Util
local Diagnostics = {}
ns.Diagnostics = Diagnostics

function Diagnostics:Coverage()
	local R = ns.Registry
	local c = {
		definitions = 0, editable = 0, readonly = 0, disabled = 0, available = 0, unavailable = 0,
		byStatus = {}, byProvider = {}, byCategory = {}, evidence = {},
		catalogTotal = 0, catalogClassified = 0, catalogStandard = 0, catalogHidden = 0, catalogUi = 0,
	}
	for _, aspect in ipairs(ns.Schema.EvidenceAspects) do c.evidence[aspect] = {} end
	for _, def in ipairs(R.ordered) do
		c.definitions = c.definitions + 1
		if def.disabled then c.disabled = c.disabled + 1 end
		if def.control == "readonly" then c.readonly = c.readonly + 1 else c.editable = c.editable + 1 end
		if ns.Providers:IsAvailable(def) then c.available = c.available + 1 else c.unavailable = c.unavailable + 1 end
		c.byStatus[def.statusSummary] = (c.byStatus[def.statusSummary] or 0) + 1
		c.byProvider[def.provider] = (c.byProvider[def.provider] or 0) + 1
		c.byCategory[def.category] = (c.byCategory[def.category] or 0) + 1
		-- Diagnostic rows are EverSettings' own readouts, not game settings: keep them out of
		-- the verification statistics.
		if def.provider ~= "diagnostic" then
			for _, aspect in ipairs(ns.Schema.EvidenceAspects) do
				local state = def.verification[aspect] or "unknown"
				c.evidence[aspect][state] = (c.evidence[aspect][state] or 0) + 1
			end
		end
	end
	for name, entry in pairs(ns.CVarCatalog and ns.CVarCatalog.cvars or {}) do
		c.catalogTotal = c.catalogTotal + 1
		if R:IsCVarClassified(name) then c.catalogClassified = c.catalogClassified + 1 end
		if entry[4] == 2 then c.catalogStandard = c.catalogStandard + 1
		elseif entry[4] == 1 then c.catalogUi = c.catalogUi + 1
		else c.catalogHidden = c.catalogHidden + 1 end
	end
	return c
end

-- Read-only checks of each definition against the running client.
function Diagnostics:CheckDefinitions()
	local issues = {}
	local Compat = ns.Compat
	for _, def in ipairs(ns.Registry.ordered) do
		for _, info in ipairs(def.cvarInfo or {}) do
			if Compat.GetCVar(info.name) == nil then
				issues[#issues + 1] = ("%s: CVar '%s' missing from client"):format(def.id, info.name)
			else
				local clientDefault = Compat.GetCVarDefault(info.name)
				if clientDefault and tostring(clientDefault) ~= tostring(info.default)
					and not (tonumber(clientDefault) and tonumber(info.default) and Util.NearlyEqual(tonumber(clientDefault), tonumber(info.default))) then
					issues[#issues + 1] = ("%s: default differs (catalog %s, client %s)"):format(def.id, tostring(info.default), tostring(clientDefault))
				end
				local live = Compat.GetCVarInfo(info.name)
				if live then
					local Registry = ns.Registry
					if live.secure ~= Registry.HasFlag(info.flags, Registry.FLAG_SECURE) then
						issues[#issues + 1] = ("%s: secure flag differs from catalog for %s"):format(def.id, info.name)
					end
				end
			end
		end
		if def.provider ~= "diagnostic" and ns.Providers:IsAvailable(def) then
			local v = ns.Providers:Get(def)
			if v ~= nil and def.control ~= "readonly" then
				local ok, reason = ns.Values.Validate(def, v)
				if not ok then
					issues[#issues + 1] = ("%s: current value %s is outside the researched values (%s)"):format(def.id, ns.Values.Format(def, v), tostring(reason))
				end
			end
		end
	end
	return issues
end

function Diagnostics:BuildReport()
	local lines = {}
	local function add(fmt, ...) lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
	local Compat = ns.Compat
	add("EverSettings %s diagnostics", ns.version)
	add("Client: %s, interface %s, Forever: %s", Compat.buildString, tostring(Compat.build.interface), tostring(Compat.isForever))
	add("")
	add("API capabilities:")
	for _, key in ipairs(Util.SortedKeys(Compat.caps)) do
		add("  %-24s %s", key, Compat.caps[key] and "yes" or "NO")
	end
	local c = self:Coverage()
	add("")
	add("Definitions: %d (%d editable, %d read-only, %d disabled by validation)", c.definitions, c.editable, c.readonly, c.disabled)
	add("Available on this client: %d, unavailable: %d", c.available, c.unavailable)
	add("Catalog: %d CVars, %d covered by definitions (%d settings-window, %d other UI, %d hidden)",
		c.catalogTotal, c.catalogClassified, c.catalogStandard, c.catalogUi, c.catalogHidden)
	add("Status: %s", self:FormatCounts(c.byStatus))
	add("Providers: %s", self:FormatCounts(c.byProvider))
	for _, aspect in ipairs(ns.Schema.EvidenceAspects) do
		add("Evidence %-8s %s", aspect .. ":", self:FormatCounts(c.evidence[aspect]))
	end
	local d = ns.Discovery.last
	add("")
	if d and d.available then
		add("Discovery: %d variables, %d commands; %d not in catalog, %d catalog entries not listed, %d defaults changed",
			d.numCVars, d.numCommands, #d.new, #d.missing, #d.changedDefaults)
		for i = 1, math.min(10, #d.new) do add("  new: %s", d.new[i]) end
		for i = 1, math.min(10, #d.changedDefaults) do
			local x = d.changedDefaults[i]
			add("  default changed: %s (catalog %s, client %s)", x.name, tostring(x.catalog), tostring(x.client))
		end
	else
		add("Discovery: %s", d and (d.error or "ConsoleGetAllCommands unavailable") or "not run")
	end
	if #ns.Registry.errors > 0 or #ns.Registry.warnings > 0 then
		add("")
		add("Definition validation:")
		for _, e in ipairs(ns.Registry.errors) do add("  ERROR %s", e) end
		for _, w in ipairs(ns.Registry.warnings) do add("  warning %s", w) end
	end
	local issues = self:CheckDefinitions()
	add("")
	add("Client consistency checks: %d issue(s)", #issues)
	for _, i in ipairs(issues) do add("  %s", i) end
	return table.concat(lines, "\n")
end

function Diagnostics:FormatCounts(t)
	local parts = {}
	for _, k in ipairs(Util.SortedKeys(t)) do parts[#parts + 1] = ("%s %d"):format(k, t[k]) end
	return #parts > 0 and table.concat(parts, ", ") or "none"
end

function Diagnostics:PrintSummary()
	local c = self:Coverage()
	ns:Print("%d definitions (%d available here). Catalog: %d CVars, %d covered.", c.definitions, c.available, c.catalogTotal, c.catalogClassified)
	local d = ns.Discovery.last
	if d and d.available then
		ns:Print("Discovery: %d variables, %d commands, %d new vs catalog, %d defaults changed.", d.numCVars, d.numCommands, #d.new, #d.changedDefaults)
	end
	if #ns.Registry.errors > 0 then
		ns:Print("|cffd9534f%d definition error(s)|r - open Diagnostics for details.", #ns.Registry.errors)
	end
end
