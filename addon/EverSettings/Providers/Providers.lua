-- Unified provider layer. The UI and the change pipeline only talk to providers through
-- this module, so they never need to know how a setting is stored.
--
-- Provider interface (all functions receive the definition):
--   IsAvailable(def)    -> ok, reason      can this setting be read on this client?
--   GetRestriction(def) -> nil | reason    why it cannot be written right now (read-only, combat...)
--   Get(def)            -> value | nil, err   canonical value (see Values.lua)
--   GetDefault(def)     -> value | nil
--   Set(def, value)     -> ok, err         write a canonical value (caller validates first)
--   GetRaw(def)         -> string          human readable raw storage value(s), for the inspector
local _, ns = ...

local Providers = { types = {} }
ns.Providers = Providers

function Providers:Register(name, impl)
	self.types[name] = impl
end

function Providers:For(def)
	return self.types[def.provider]
end

local function call(def, method, ...)
	local p = Providers:For(def)
	if not p or not p[method] then
		return nil, "no provider '" .. tostring(def.provider) .. "'"
	end
	local ok, a, b = pcall(p[method], p, def, ...)
	if not ok then
		return nil, tostring(a)
	end
	return a, b
end

function Providers:IsAvailable(def)
	if def.disabled then return false, def.disabledReason end
	if def.isAvailable then
		local ok, available, reason = pcall(def.isAvailable)
		if not ok then return false, "availability check failed: " .. tostring(available) end
		if not available then return false, reason or "Not supported on this client or hardware" end
	end
	local ok, reason = call(def, "IsAvailable")
	if ok == nil and reason then return false, reason end
	return ok and true or false, reason
end

-- Returns nil when writable, otherwise a user-facing reason.
function Providers:GetRestriction(def)
	local available, reason = self:IsAvailable(def)
	if not available then return reason or "Unavailable" end
	if def.control == "readonly" then
		return def.readOnlyReason or "Read-only: behaviour and safe values have not been researched yet."
	end
	local r = call(def, "GetRestriction")
	return r
end

function Providers:Get(def)
	return call(def, "Get")
end

function Providers:GetDefault(def)
	if def.defaultValue ~= nil then return def.defaultValue end
	return call(def, "GetDefault")
end

-- Returns ok, message, planResult (planResult for cvar/composite providers).
function Providers:Set(def, value)
	local restriction = self:GetRestriction(def)
	if restriction then return false, restriction end
	local p = self:For(def)
	if not p or not p.Set then return false, "no provider '" .. tostring(def.provider) .. "'" end
	return p:Set(def, value)
end

function Providers:GetRaw(def)
	local raw = call(def, "GetRaw")
	return raw
end

-- Range for sliders: static from the definition or computed at runtime (rangeFunc).
Providers.rangeFuncs = {}

function Providers:GetRange(def)
	if def.rangeFunc then
		local fn = self.rangeFuncs[def.rangeFunc]
		if fn then
			local ok, lo, hi, step = pcall(fn, def)
			if ok and type(lo) == "number" and type(hi) == "number" and lo < hi then
				return lo, hi, step or def.step
			end
		end
		return nil
	end
	return def.min, def.max, def.step
end

-- Camera FOV: GetCameraFOVDefaults() -> default, playerMin, playerMax (CameraDocumentation.lua).
Providers.rangeFuncs.cameraFov = function(def)
	if not GetCameraFOVDefaults then return nil end
	local _, lo, hi = GetCameraFOVDefaults()
	return lo, hi, def.step
end

-- Render scale: GetMinRenderScale()/GetMaxRenderScale(), as used by Blizzard's Graphics.lua.
Providers.rangeFuncs.renderScale = function(def)
	if not (GetMinRenderScale and GetMaxRenderScale) then return nil end
	return GetMinRenderScale(), GetMaxRenderScale(), def.step
end

-- Dropdown options: static list or computed (optionsFunc). Each option may be marked
-- disabled with a reason when the client reports it as unsupported on this hardware.
Providers.optionFuncs = {}

function Providers:GetOptions(def)
	local options = def.options
	if def.optionsFunc then
		local fn = self.optionFuncs[def.optionsFunc]
		local ok, result = pcall(fn, def)
		options = ok and result or options
	end
	if not options then return {} end
	local out = {}
	for i, opt in ipairs(options) do
		local o = { value = opt.value, label = opt.label, description = opt.description, warning = opt.warning,
			notSelectable = opt.notSelectable }
		if def.optionSupport == "graphicsCVar" and IsGraphicsCVarValueSupported and def.cvar then
			local ok, code = pcall(IsGraphicsCVarValueSupported, def.cvar, opt.value)
			if ok and code and code ~= 0 then o.disabled = "Not supported on this system (code " .. tostring(code) .. ")" end
		elseif def.optionSupport == "graphicsQuality" and IsGraphicsSettingValueSupported and def.cvar then
			local ok, code = pcall(IsGraphicsSettingValueSupported, def.cvar, opt.value, false)
			if ok and code and code ~= 0 then o.disabled = "Not supported on this system (code " .. tostring(code) .. ")" end
		end
		out[i] = o
	end
	return out
end

-- Raw write plans ------------------------------------------------------------------------
-- Every write is expressed as a plan: an ordered list of { name, raw } CVar assignments.
-- ExecutePlan checks the whole plan before writing anything, verifies each CVar by reading
-- it back, and if a multi-CVar plan only partly succeeds it rolls back the CVars it changed
-- (through the same supported SetCVar API) and reports every outcome.
-- (Issue #5, finding 1.)

local Compat = ns.Compat

-- Compare raw CVar strings: numerically when both are numbers ("1" == "1.000000").
function Providers.RawEqual(a, b)
	if a == b then return true end
	if a == nil or b == nil or a == false or b == false then return false end
	local na, nb = tonumber(a), tonumber(b)
	if na and nb then return math.abs(na - nb) <= 1e-6 * math.max(1, math.abs(na), math.abs(nb)) end
	return tostring(a) == tostring(b)
end
local RawEqual = Providers.RawEqual

-- CVars a definition can write.
function Providers:WriteSet(def)
	if def.provider == "cvar" then return { def.cvar } end
	if def.provider == "composite" then return def.cvars end
	return {}
end

-- Exact raw state of everything a definition can write. Missing CVars are recorded as false.
-- API-backed settings have no raw CVars; their canonical value is kept under __api.
function Providers:Snapshot(def)
	local snap = {}
	for _, name in ipairs(self:WriteSet(def)) do
		local v = Compat.GetCVar(name)
		if v == nil then snap[name] = false else snap[name] = v end
	end
	if def.provider == "api" then
		local ok, v = pcall(self.Get, self, def)
		if ok then snap.__api = v end
	end
	return snap
end

-- Names whose raw values differ between two snapshots.
function Providers.SnapshotDiff(a, b)
	local diff = {}
	for name, v in pairs(a or {}) do
		if not RawEqual(v, b and b[name]) then diff[#diff + 1] = name end
	end
	for name, v in pairs(b or {}) do
		if a == nil or a[name] == nil then diff[#diff + 1] = name end
	end
	table.sort(diff)
	return diff
end

local function preflight(entries)
	for _, e in ipairs(entries) do
		if Compat.GetCVar(e.name) == nil then
			return ("'%s' does not exist in this client"):format(e.name)
		end
		local info = Compat.GetCVarInfo(e.name)
		if info then
			if info.readOnly then return ("'%s' is read-only"):format(e.name) end
			if info.locked then return ("'%s' is locked by the client"):format(e.name) end
			if info.secure and Compat.InCombat() then return ("'%s' is secure and cannot be changed in combat"):format(e.name) end
		end
	end
end

-- plan: list of { name, raw }. Returns a result table:
--   entries   { name, raw, before, after, outcome }   outcome: success|clamped|rejected|failed|unknown
--   allOk     every CVar holds exactly the requested raw value
--   partial   a multi-CVar plan where at least one CVar failed, was rejected or is unreadable
--   rollback  list of { name, outcome } for CVars restored after a partial failure
--   preflightError  set when nothing was written because the plan cannot be applied
function Providers:ExecutePlan(plan)
	-- Collapse duplicate names (last assignment wins) while keeping order.
	local entries, index = {}, {}
	for _, p in ipairs(plan) do
		local name, raw = p[1], p[2]
		if index[name] then
			entries[index[name]].raw = raw
		else
			entries[#entries + 1] = { name = name, raw = raw }
			index[name] = #entries
		end
	end
	local result = { entries = entries, allOk = true, partial = false, rollback = {} }
	result.preflightError = preflight(entries)
	if result.preflightError then
		result.allOk = false
		return result
	end
	for _, e in ipairs(entries) do e.before = Compat.GetCVar(e.name) end
	local bad = false
	for _, e in ipairs(entries) do
		local ok, err = Compat.SetCVar(e.name, e.raw)
		e.after = Compat.GetCVar(e.name)
		if e.after == nil then
			e.outcome = "unknown"
		elseif RawEqual(e.after, e.raw) then
			e.outcome = "success"
		elseif ok == false then
			e.outcome, e.error = "failed", err
		elseif RawEqual(e.after, e.before) then
			e.outcome = "rejected"
		else
			e.outcome = "clamped"
		end
		if e.outcome ~= "success" then result.allOk = false end
		if e.outcome == "failed" or e.outcome == "rejected" or e.outcome == "unknown" then bad = true end
	end
	if bad and #entries > 1 then
		result.partial = true
		for i = #entries, 1, -1 do
			local e = entries[i]
			if e.before ~= nil and e.after ~= nil and not RawEqual(e.after, e.before) then
				Compat.SetCVar(e.name, e.before)
				local now = Compat.GetCVar(e.name)
				local outcome = RawEqual(now, e.before) and "restored" or "not restored"
				result.rollback[#result.rollback + 1] = { name = e.name, outcome = outcome, value = now }
				e.after = now
			end
		end
	end
	return result
end

-- Human-readable per-CVar summary of a plan result.
function Providers.DescribePlan(result)
	if not result then return nil end
	if result.preflightError then return "Not applied: " .. result.preflightError end
	local parts = {}
	for _, e in ipairs(result.entries) do
		if e.outcome ~= "success" then
			parts[#parts + 1] = ("%s %s (wanted %s, now %s)"):format(e.name, e.outcome, tostring(e.raw), tostring(e.after))
		end
	end
	for _, r in ipairs(result.rollback) do
		parts[#parts + 1] = ("%s %s"):format(r.name, r.outcome == "restored" and "rolled back" or "could NOT be rolled back")
	end
	return #parts > 0 and table.concat(parts, "; ") or nil
end

-- Restore a definition to an exact raw snapshot. expected (optional): the raw state we last
-- left it in; CVars that changed since are reported as conflicts and not overwritten.
-- Returns status ("success"|"conflict"|"failed"|"restricted"|"noop"), message, planResult.
function Providers:RestoreSnapshot(def, snap, expected)
	if def.provider == "api" then
		if snap.__api == nil then return "noop" end
		local restriction = self:GetRestriction(def)
		if restriction then return "restricted", restriction end
		if expected and expected.__api ~= nil then
			local okGet, current = pcall(self.Get, self, def)
			if okGet and not ns.Values.Equal(def, current, expected.__api) then
				return "conflict", "changed outside EverSettings since"
			end
		end
		local ok, setOk, err = pcall(self.Set, self, def, snap.__api)
		if not ok or setOk == false then return "failed", tostring(err or setOk) end
		local okGet, now = pcall(self.Get, self, def)
		if okGet and ns.Values.Equal(def, now, snap.__api) then return "success" end
		return "failed", "read-back differs"
	end
	local conflicts, plan = {}, {}
	for name, raw in pairs(snap) do
		if name ~= "__api" and raw ~= false then
			local current = Compat.GetCVar(name)
			if expected and expected[name] ~= nil and not RawEqual(current, expected[name]) then
				conflicts[#conflicts + 1] = name
			elseif not RawEqual(current, raw) then
				plan[#plan + 1] = { name, raw }
			end
		end
	end
	if #conflicts > 0 then
		table.sort(conflicts)
		return "conflict", "changed outside EverSettings since: " .. table.concat(conflicts, ", ")
	end
	if #plan == 0 then return "noop" end
	table.sort(plan, function(a, b) return a[1] < b[1] end)
	if def.restrictions.combat and Compat.InCombat() then return "restricted", "Cannot be changed during combat." end
	local result = self:ExecutePlan(plan)
	if result.preflightError then return "restricted", result.preflightError, result end
	if result.allOk then return "success", nil, result end
	return "failed", Providers.DescribePlan(result), result
end
