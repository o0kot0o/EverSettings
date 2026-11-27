-- Dedicated getter/setter API provider, for settings that are not plain CVars.
local _, ns = ...

local Compat = ns.Compat
local API = { handlers = {} }
ns.APIHandlers = API.handlers

-- Trivial (low-level) quest tracking on the minimap, as Forever's
-- Camelot/InterfaceOverrides.lua CreateQuestSettings does it.
API.handlers.trivialQuestTracking = {
	IsAvailable = function()
		if not (C_Minimap and C_Minimap.IsFilteredOut and C_Minimap.SetTracking) then
			return false, "C_Minimap tracking API unavailable"
		end
		if not (Enum and Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter.TrivialQuests) then
			return false, "Enum.MinimapTrackingFilter.TrivialQuests unavailable"
		end
		if not (MinimapUtil and MinimapUtil.GetFilterIndexForFilterID) then
			return false, "MinimapUtil.GetFilterIndexForFilterID unavailable"
		end
		return true
	end,
	Get = function()
		return not C_Minimap.IsFilteredOut(Enum.MinimapTrackingFilter.TrivialQuests)
	end,
	GetDefault = function() return false end,
	Set = function(_, value)
		local index = MinimapUtil.GetFilterIndexForFilterID(Enum.MinimapTrackingFilter.TrivialQuests)
		if not index then return false, "tracking filter not found" end
		C_Minimap.SetTracking(index, value and true or false)
		return true
	end,
	GetRaw = function()
		return "C_Minimap.IsFilteredOut(TrivialQuests) = " .. tostring(C_Minimap.IsFilteredOut(Enum.MinimapTrackingFilter.TrivialQuests))
	end,
}

local function handler(def) return API.handlers[def.api] end

function API:IsAvailable(def)
	local h = handler(def)
	if not h then return false, "unknown API handler '" .. tostring(def.api) .. "'" end
	if h.IsAvailable then return h.IsAvailable(def) end
	return true
end

function API:GetRestriction(def)
	if def.restrictions.combat and Compat.InCombat() then return "Cannot be changed during combat." end
	local h = handler(def)
	if not h.Set then return "This setting is read-only." end
	return nil
end

function API:Get(def) return handler(def).Get(def) end
function API:GetDefault(def) local h = handler(def); return h.GetDefault and h.GetDefault(def) end
function API:Set(def, value) return handler(def).Set(def, value) end
function API:GetRaw(def) local h = handler(def); return h.GetRaw and h.GetRaw(def) or "" end

ns.Providers:Register("api", API)
