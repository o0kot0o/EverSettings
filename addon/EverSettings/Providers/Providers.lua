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

function Providers:Set(def, value)
	local restriction = self:GetRestriction(def)
	if restriction then return false, restriction end
	return call(def, "Set", value)
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
