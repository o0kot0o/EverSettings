-- API compatibility layer. Every game API EverSettings depends on is probed here,
-- so the rest of the addon can degrade gracefully when the Forever client differs
-- from what the research documents describe.
local _, ns = ...

local Compat = { caps = {} }
ns.Compat = Compat

local C_CVar = C_CVar

-- Enum.ConsoleCommandType.Cvar is 0 in Forever's ConsoleDocumentation.lua (build 71139).
local CONSOLE_COMMAND_TYPE_CVAR = (Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar) or 0
Compat.CONSOLE_COMMAND_TYPE_CVAR = CONSOLE_COMMAND_TYPE_CVAR

function Compat:Detect()
	local caps = self.caps
	caps.C_CVar = type(C_CVar) == "table"
	caps.GetCVarInfo = caps.C_CVar and type(C_CVar.GetCVarInfo) == "function"
	caps.GetCVar = (caps.C_CVar and type(C_CVar.GetCVar) == "function") or type(GetCVar) == "function"
	caps.GetCVarDefault = (caps.C_CVar and type(C_CVar.GetCVarDefault) == "function") or type(GetCVarDefault) == "function"
	caps.SetCVar = (caps.C_CVar and type(C_CVar.SetCVar) == "function") or type(SetCVar) == "function"
	caps.ConsoleGetAllCommands = type(ConsoleGetAllCommands) == "function"
	caps.InCombatLockdown = type(InCombatLockdown) == "function"
	caps.GraphicsQualityLevels = type(GetGraphicsCVarValueForQualityLevel) == "function"
	caps.GraphicsValueSupported = type(IsGraphicsSettingValueSupported) == "function"
	caps.CameraFOVDefaults = type(GetCameraFOVDefaults) == "function"
	caps.C_Timer = type(C_Timer) == "table" and type(C_Timer.After) == "function"
	caps.SetResizeBounds = true -- verified lazily by UI code with a method check

	local version, build, buildDate, interface = "?", "?", "?", 0
	if type(GetBuildInfo) == "function" then
		version, build, buildDate, interface = GetBuildInfo()
	end
	self.build = { version = version, build = build, date = buildDate, interface = tonumber(interface) or 0 }
	self.buildString = ("%s.%s"):format(tostring(version), tostring(build))
	self.isForever = self.build.interface >= 16000 and self.build.interface < 17000
	return caps
end

-- CVar names are case-insensitive in the client; the catalog preserves the dump's casing.
function Compat.GetCVar(name)
	if C_CVar and C_CVar.GetCVar then
		return C_CVar.GetCVar(name)
	elseif GetCVar then
		return GetCVar(name)
	end
end

function Compat.GetCVarDefault(name)
	if C_CVar and C_CVar.GetCVarDefault then
		return C_CVar.GetCVarDefault(name)
	elseif GetCVarDefault then
		return GetCVarDefault(name)
	end
end

-- Returns a table, or nil when the CVar does not exist (or the API is missing).
-- Signature from Forever's CVarDocumentation.lua: value, defaultValue, isStoredServerAccount,
-- isStoredServerCharacter, isLockedFromUser, isSecure, isReadOnly.
function Compat.GetCVarInfo(name)
	if not (C_CVar and C_CVar.GetCVarInfo) then return nil end
	local ok, value, defaultValue, account, character, locked, secure, readOnly = pcall(C_CVar.GetCVarInfo, name)
	if not ok or value == nil then return nil end
	return {
		value = value, defaultValue = defaultValue,
		account = account and true or false, character = character and true or false,
		locked = locked and true or false, secure = secure and true or false,
		readOnly = readOnly and true or false,
	}
end

-- SetCVar is documented with preconditions RequiresValidAndPublicCVar,
-- RequiresNonReadOnlyCVar and RequiresNonSecureCVar, all with FailureMode "ReturnNothing".
-- So a nil return is a silent refusal, not success. Callers must read back the value.
function Compat.SetCVar(name, value)
	local fn = (C_CVar and C_CVar.SetCVar) or SetCVar
	if not fn then return false, "SetCVar API unavailable" end
	local ok, result = pcall(fn, name, value)
	if not ok then return false, tostring(result) end
	if result == false then return false, "rejected by client" end
	if result == nil then return nil, "no result (possibly refused)" end
	return true
end

function Compat.InCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

function Compat.After(seconds, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

function Compat.GetCharacterKey()
	local name = UnitName and UnitName("player") or "Unknown"
	local realm = GetRealmName and GetRealmName() or "Unknown"
	return ("%s-%s"):format(tostring(name), tostring(realm))
end
