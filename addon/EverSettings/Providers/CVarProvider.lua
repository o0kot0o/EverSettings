-- Direct console-variable provider.
local _, ns = ...

local Compat = ns.Compat
local CVar = {}

local function exists(name)
	return Compat.GetCVar(name) ~= nil
end

function CVar:IsAvailable(def)
	if not Compat.caps.GetCVar then return false, "CVar API unavailable" end
	if not exists(def.cvar) then
		return false, ("'%s' does not exist in this client build"):format(def.cvar)
	end
	return true
end

function CVar:GetRestriction(def)
	local info = Compat.GetCVarInfo(def.cvar)
	if info then
		if info.readOnly then return "Read-only: the client does not allow this variable to be changed." end
		if info.locked then return "Locked by the client." end
		if info.secure and Compat.InCombat() then return "Secure variable: cannot be changed during combat." end
	end
	if def.restrictions.combat and Compat.InCombat() then
		return "Cannot be changed during combat."
	end
	if not Compat.caps.SetCVar then return "SetCVar API unavailable" end
	return nil
end

function CVar:Get(def)
	local raw = Compat.GetCVar(def.cvar)
	if raw == nil then return nil, "missing" end
	return ns.Values.FromRaw(def, raw)
end

function CVar:GetDefault(def)
	local raw = Compat.GetCVarDefault(def.cvar)
	if raw == nil and def.cvarInfo[1] then raw = def.cvarInfo[1].default end
	if raw == nil then return nil end
	return ns.Values.FromRaw(def, raw)
end

function CVar:Set(def, value)
	local raw = ns.Values.ToRaw(def, value)
	if raw == nil then return false, "value cannot be stored" end
	return Compat.SetCVar(def.cvar, raw)
end

function CVar:GetRaw(def)
	return ("%s = %s"):format(def.cvar, tostring(Compat.GetCVar(def.cvar)))
end

ns.Providers:Register("cvar", CVar)
