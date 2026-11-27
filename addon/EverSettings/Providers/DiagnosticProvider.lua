-- Read-only diagnostic information shown alongside settings.
local _, ns = ...

local Compat = ns.Compat
local Diagnostic = { handlers = {} }

Diagnostic.handlers.clientBuild = function()
	local b = Compat.build or {}
	return ("%s (build %s, %s)"):format(tostring(b.version), tostring(b.build), tostring(b.date))
end

Diagnostic.handlers.interfaceVersion = function()
	local b = Compat.build or {}
	return ("%s%s"):format(tostring(b.interface), Compat.isForever and " (Forever)" or " (not a Forever client?)")
end

Diagnostic.handlers.locale = function()
	return GetLocale and GetLocale() or "?"
end

Diagnostic.handlers.screenSize = function()
	if not GetPhysicalScreenSize then return "unavailable" end
	local w, h = GetPhysicalScreenSize()
	return ("%d x %d"):format(w or 0, h or 0)
end

Diagnostic.handlers.discoveredCVars = function()
	local d = ns.Discovery and ns.Discovery.last
	if not d then return "not run yet" end
	if not d.available then return "ConsoleGetAllCommands unavailable" end
	return ("%d variables, %d commands (%d not in bundled catalog)"):format(d.numCVars, d.numCommands, #d.new)
end

Diagnostic.handlers.catalogInfo = function()
	local m = ns.CVarCatalog and ns.CVarCatalog.meta or {}
	return ("%s CVars from build %s"):format(tostring(m.numCVars), tostring(m.cvarsBuild))
end

function Diagnostic:IsAvailable(def)
	if not self.handlers[def.diagnostic] then return false, "unknown diagnostic" end
	return true
end
function Diagnostic:GetRestriction() return "Read-only information." end
function Diagnostic:Get(def)
	local ok, v = pcall(self.handlers[def.diagnostic], def)
	return ok and v or ("error: " .. tostring(v))
end
function Diagnostic:GetDefault() return nil end
function Diagnostic:Set() return false, "read-only" end
function Diagnostic:GetRaw(def) return self:Get(def) end

ns.Providers:Register("diagnostic", Diagnostic)
