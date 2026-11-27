-- Composite provider: one control that drives several console variables, mirroring the
-- proxy settings in Blizzard's Forever settings definitions. Each handler documents the
-- Blizzard code it reproduces.
--
-- Handlers never write directly. Plan(def, value) returns the complete intended write set
-- ({ name, raw } list); the provider executes it with Providers:ExecutePlan, which checks
-- the whole set first, verifies every CVar, and rolls back on partial failure (issue #5).
local _, ns = ...

local Compat, Util = ns.Compat, ns.Util
local Composite = { handlers = {} }
ns.Composites = Composite.handlers

local function num(name)
	return tonumber(Compat.GetCVar(name))
end

-- Graphics quality preset (Graphics.lua OnGCChanged): the preset level plus every advanced
-- quality CVar set to GetGraphicsCVarValueForQualityLevel(cvar, level, raid), respecting
-- each setting's minimum (particle density has a minimum of 1) and only for features the
-- system supports.
Composite.handlers.graphicsPreset = {
	IsAvailable = function(def)
		if not Compat.caps.GraphicsQualityLevels then
			return false, "GetGraphicsCVarValueForQualityLevel is unavailable"
		end
		return true
	end,
	Get = function(def) return num(def.cvars[1]) end,
	GetDefault = function(def) return tonumber(Compat.GetCVarDefault(def.cvars[1])) end,
	Plan = function(def, value)
		local plan = { { def.cvars[1], tostring(value) } }
		for i = 2, #def.cvars do
			local child = def.cvars[i]
			local supported = true
			local cond = def.childCondition and def.childCondition[child]
			if cond then
				local fn = C_VideoOptions and C_VideoOptions[cond]
				supported = fn and fn() and true or false
			end
			if supported and Compat.GetCVar(child) ~= nil then
				local level = GetGraphicsCVarValueForQualityLevel(child, value, def.raid or false)
				if type(level) ~= "number" then
					return nil, ("no preset value for %s"):format(child)
				end
				local minimum = def.childMinimum and def.childMinimum[child]
				if minimum and level < minimum then level = minimum end
				plan[#plan + 1] = { child, tostring(level) }
			end
		end
		return plan
	end,
}

-- Primary value with a derived secondary CVar (Controls.lua Mouse Look Speed: pitch = yaw / 2;
-- Auto Follow Speed: pitch = yaw / 4).
Composite.handlers.ratio = {
	Get = function(def) return num(def.cvars[1]) end,
	GetDefault = function(def) return def.defaultValue end,
	Plan = function(def, value)
		return {
			{ def.cvars[1], Util.FormatNumber(value) },
			{ def.cvars[2], Util.FormatNumber(value / def.ratio) },
		}
	end,
}

-- Boolean mapped onto specific numeric values of one CVar (Graphics.lua Triple Buffering:
-- gxMaxFrameLatency 3 = enabled, 2 = disabled).
Composite.handlers.boolMap = {
	Get = function(def)
		local v = num(def.cvars[1])
		if v == def.onValue then return true end
		if v == def.offValue then return false end
		return nil, ("unrecognised value %s"):format(tostring(v))
	end,
	GetDefault = function(def)
		local d = tonumber(Compat.GetCVarDefault(def.cvars[1]))
		if d == def.onValue then return true elseif d == def.offValue then return false end
		return def.defaultValue
	end,
	Plan = function(def, value)
		return { { def.cvars[1], tostring(value and def.onValue or def.offValue) } }
	end,
}

-- Camera shake (Accessibility.lua): both ShakeStrengthCamera and ShakeStrengthUI set to
-- 0 (none), 0.25 (reduced) or 1 (full). Values set elsewhere that match none of these are
-- reported as "custom" instead of being mislabelled.
Composite.handlers.shakeLevel = {
	Get = function(def)
		local cam, ui = num(def.cvars[1]), num(def.cvars[2])
		if not cam or not ui then return nil, "missing" end
		for _, level in ipairs({ 0, 0.25, 1 }) do
			if Util.NearlyEqual(cam, level, 1e-3) and Util.NearlyEqual(ui, level, 1e-3) then
				return level
			end
		end
		return "custom"
	end,
	GetDefault = function(def) return 1 end,
	Plan = function(def, value)
		if type(value) ~= "number" then return nil, "choose None, Reduced or Full" end
		local v = Util.FormatNumber(value)
		return { { def.cvars[1], v }, { def.cvars[2], v } }
	end,
}

-- Motion sickness (Accessibility.lua): on = CameraKeepCharacterCentered 0 and
-- CameraReduceUnexpectedMovement 1.
Composite.handlers.motionSickness = {
	Get = function(def)
		local centered, reduce = num(def.cvars[1]), num(def.cvars[2])
		return (centered == 0) and (reduce == 1)
	end,
	GetDefault = function(def) return false end,
	Plan = function(def, value)
		return { { def.cvars[1], value and "0" or "1" }, { def.cvars[2], value and "1" or "0" } }
	end,
}

function Composite:IsAvailable(def)
	local h = self.handlers[def.composite]
	if not h then return false, "unknown composite handler '" .. tostring(def.composite) .. "'" end
	for _, name in ipairs(def.cvars) do
		if Compat.GetCVar(name) == nil then
			return false, ("'%s' does not exist in this client build"):format(name)
		end
	end
	if h.IsAvailable then return h.IsAvailable(def) end
	return true
end

function Composite:GetRestriction(def)
	for _, name in ipairs(def.cvars) do
		local info = Compat.GetCVarInfo(name)
		if info then
			if info.readOnly then return ("'%s' is read-only in this client."):format(name) end
			if info.locked then return ("'%s' is locked by the client."):format(name) end
			if info.secure and Compat.InCombat() then return ("'%s' is secure: cannot be changed during combat."):format(name) end
		end
	end
	if def.restrictions.combat and Compat.InCombat() then return "Cannot be changed during combat." end
	return nil
end

function Composite:Get(def) return self.handlers[def.composite].Get(def) end
function Composite:GetDefault(def) return self.handlers[def.composite].GetDefault(def) end
function Composite:Plan(def, value) return self.handlers[def.composite].Plan(def, value) end

-- Returns ok, message, planResult. ok is true only if every CVar in the write set holds
-- exactly the planned value.
function Composite:Set(def, value)
	local plan, err = self:Plan(def, value)
	if not plan then return false, err end
	local result = ns.Providers:ExecutePlan(plan)
	if result.preflightError then return false, result.preflightError, result end
	return result.allOk, ns.Providers.DescribePlan(result), result
end

function Composite:GetRaw(def)
	local parts = {}
	for _, name in ipairs(def.cvars) do parts[#parts + 1] = name .. " = " .. tostring(Compat.GetCVar(name)) end
	return table.concat(parts, "\n")
end

ns.Providers:Register("composite", Composite)
