-- Keeps displayed values in sync with changes made outside EverSettings (Blizzard's
-- options, other addons, console commands). It only ever READS: external changes are
-- shown and recorded, never overwritten.
local _, ns = ...

local Values, Providers = ns.Values, ns.Providers
local Sync = { cache = {}, applying = 0 }
ns.Sync = Sync

function Sync:BeginApply() self.applying = self.applying + 1 end
function Sync:EndApply() self.applying = math.max(0, self.applying - 1) end

function Sync:Remember(def, value)
	self.cache[def.id] = value
end

-- Read every available setting once so later changes can be detected.
function Sync:Prime()
	for _, def in ipairs(ns.Registry.ordered) do
		if not def.disabled and def.provider ~= "diagnostic" and Providers:IsAvailable(def) then
			self.cache[def.id] = Providers:Get(def)
		end
	end
end

-- Compare a setting's live value with the last known value; returns true if it changed.
function Sync:Check(def, source)
	if def.disabled or def.provider == "diagnostic" then return false end
	local current = Providers:Get(def)
	local known = self.cache[def.id]
	if Values.Equal(def, current, known) then return false end
	self.cache[def.id] = current
	if self.applying == 0 then
		ns.History:Add({ id = def.id, old = known, new = current, result = "external", source = source or "external" })
		-- If the outside change already produced the pending value, drop the pending entry.
		local pending, has = ns.Changes:GetPending(def.id)
		if has and Values.Equal(def, pending, current) then
			ns.Changes:Unstage(def.id)
		end
	end
	ns.Callbacks:Fire("ValueChanged", def.id, source or "external")
	return true
end

-- CVAR_UPDATE payload on Forever is (cvarName, value); see Blizzard's handlers in
-- Blizzard_AccessibilityTemplates and Blizzard_CharacterCreate/Camelot.
function Sync:OnCVarUpdate(name)
	if type(name) ~= "string" or self.applying > 0 then return end
	local defs = ns.Registry:GetByCVar(name)
	if not defs then return end
	for _, def in ipairs(defs) do
		self:Check(def, "external")
	end
end

-- Fallback for changes that do not raise CVAR_UPDATE: poll a set of definitions
-- (the UI passes only the rows currently visible).
function Sync:Poll(defs)
	local changed = false
	for _, def in ipairs(defs) do
		if self:Check(def, "external") then changed = true end
	end
	return changed
end
