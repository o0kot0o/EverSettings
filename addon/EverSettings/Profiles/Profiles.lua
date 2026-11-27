-- User profiles: named sets of setting values. Applying a profile never writes directly:
-- it creates a backup and stages the differences, which the player reviews and applies.
local _, ns = ...

local Util, Values, Providers = ns.Util, ns.Values, ns.Providers
local Profiles = { VERSION = 1 }
ns.Profiles = Profiles

local MAX_NAME = 48

function Profiles:ValidateName(name, allowExisting)
	name = Util.Trim(name)
	if name == "" then return nil, "Enter a profile name." end
	if #name > MAX_NAME then return nil, ("Names can be at most %d characters."):format(MAX_NAME) end
	if name:find("%c") then return nil, "Names cannot contain control characters." end
	if not allowExisting and ns.db.profiles[name] then return nil, "A profile with that name already exists." end
	return name
end

function Profiles:List()
	return Util.SortedKeys(ns.db.profiles, function(a, b) return a:lower() < b:lower() end)
end

function Profiles:Get(name) return ns.db.profiles[name] end

function Profiles:GetActive()
	local name = ns.db.activeProfile
	if name and ns.db.profiles[name] then return name end
	return nil
end

function Profiles:SetActive(name)
	ns.db.activeProfile = name
	ns.Callbacks:Fire("ProfilesChanged")
end

-- Current game values for every editable, available managed setting.
function Profiles:CaptureCurrent()
	local values = {}
	for _, def in ipairs(ns.Registry.ordered) do
		if not def.disabled and def.control ~= "readonly" and Providers:IsAvailable(def) then
			local v = Providers:Get(def)
			if v ~= nil and Values.Validate(def, v) then values[def.id] = v end
		end
	end
	return values
end

local function newProfile(name, values)
	local now = Util.Now()
	return { version = Profiles.VERSION, name = name, created = now, modified = now, values = values,
		build = ns.Compat.buildString }
end

function Profiles:Save(name)
	local p = ns.db.profiles[name]
	if not p then return self:SaveAs(name) end
	p.values = self:CaptureCurrent()
	p.modified = Util.Now()
	p.build = ns.Compat.buildString
	ns.Callbacks:Fire("ProfilesChanged")
	return p
end

function Profiles:SaveAs(name)
	local valid, err = self:ValidateName(name)
	if not valid then return nil, err end
	ns.db.profiles[valid] = newProfile(valid, self:CaptureCurrent())
	self:SetActive(valid)
	return ns.db.profiles[valid]
end

function Profiles:Rename(old, new)
	local p = ns.db.profiles[old]
	if not p then return nil, "Profile not found." end
	local valid, err = self:ValidateName(new, true)
	if not valid then return nil, err end
	if valid ~= old and ns.db.profiles[valid] then return nil, "A profile with that name already exists." end
	ns.db.profiles[old] = nil
	p.name = valid
	ns.db.profiles[valid] = p
	if ns.db.activeProfile == old then ns.db.activeProfile = valid end
	ns.Callbacks:Fire("ProfilesChanged")
	return p
end

function Profiles:Duplicate(name, newName)
	local p = ns.db.profiles[name]
	if not p then return nil, "Profile not found." end
	local valid, err = self:ValidateName(newName)
	if not valid then return nil, err end
	local copy = Util.CopyTable(p)
	copy.name, copy.created, copy.modified = valid, Util.Now(), Util.Now()
	ns.db.profiles[valid] = copy
	ns.Callbacks:Fire("ProfilesChanged")
	return copy
end

function Profiles:Delete(name)
	if not ns.db.profiles[name] then return false end
	ns.db.profiles[name] = nil
	if ns.db.activeProfile == name then ns.db.activeProfile = nil end
	ns.Callbacks:Fire("ProfilesChanged")
	return true
end

-- Differences between a profile and the live game.
-- Returns { diffs = { {def, current, value} }, same = n, unknown = { ids }, invalid = { {id, reason} } }
function Profiles:Compare(profile, categoryFilter)
	local result = { diffs = {}, same = 0, unknown = {}, invalid = {}, unavailable = {} }
	for _, id in ipairs(Util.SortedKeys(profile.values)) do
		local value = profile.values[id]
		local def = ns.Registry:Get(id)
		if not def or def.disabled or def.control == "readonly" then
			result.unknown[#result.unknown + 1] = id
		elseif not categoryFilter or categoryFilter[def.category] then
			local ok, reason = Values.Validate(def, value)
			if not ok then
				result.invalid[#result.invalid + 1] = { id = id, reason = reason }
			elseif not Providers:IsAvailable(def) then
				result.unavailable[#result.unavailable + 1] = id
			else
				local current = Providers:Get(def)
				if Values.Equal(def, current, value) then
					result.same = result.same + 1
				else
					result.diffs[#result.diffs + 1] = { def = def, current = current, value = value }
				end
			end
		end
	end
	return result
end

-- Categories present in a profile: { [categoryId] = count }
function Profiles:GetCategories(profile)
	local cats = {}
	for id in pairs(profile.values) do
		local def = ns.Registry:Get(id)
		if def then cats[def.category] = (cats[def.category] or 0) + 1 end
	end
	return cats
end

-- Stage the profile's differences (reconciled with pending edits). The live values are
-- backed up when the change is actually applied (Changes:ApplyList), not at staging time.
-- Returns staged count and { staged, cleared, replaced }.
function Profiles:StageApply(profile, categoryFilter)
	local report = { staged = 0, cleared = 0, replaced = 0 }
	for _, id in ipairs(Util.SortedKeys(profile.values)) do
		local def = ns.Registry:Get(id)
		local value = profile.values[id]
		if def and not def.disabled and def.control ~= "readonly" and (not categoryFilter or categoryFilter[def.category])
			and Values.Validate(def, value) and Providers:IsAvailable(def) then
			local outcome, replaced = ns.Changes:StageTarget(def, value, nil, "profile:" .. (profile.name or "?"))
			if outcome == "staged" then report.staged = report.staged + 1 end
			if outcome == "cleared" then report.cleared = report.cleared + 1 end
			if replaced then report.replaced = report.replaced + 1 end
		end
	end
	ns.Callbacks:Fire("PendingChanged")
	return report.staged, report
end

function Profiles:Export(name)
	local p = ns.db.profiles[name]
	if not p then return nil, "Profile not found." end
	return ns.Serializer.Encode(p)
end

-- Parse and validate imported text. Returns profile (not yet saved), report.
function Profiles:ParseImport(text)
	local parsed, err = ns.Serializer.Decode(text)
	if not parsed then return nil, err end
	local report = { accepted = 0, rejected = {} }
	local values = {}
	for id, value in pairs(parsed.values) do
		local def = ns.Registry:Get(id)
		if not def then
			report.rejected[#report.rejected + 1] = { id = id, reason = "unknown setting" }
		elseif def.control == "readonly" or def.disabled then
			report.rejected[#report.rejected + 1] = { id = id, reason = "not editable" }
		else
			local ok, reason = Values.Validate(def, value)
			if ok then
				values[id] = value
				report.accepted = report.accepted + 1
			else
				report.rejected[#report.rejected + 1] = { id = id, reason = reason }
			end
		end
	end
	for _, m in ipairs(parsed.malformed) do
		report.rejected[#report.rejected + 1] = { id = m, reason = "malformed entry" }
	end
	table.sort(report.rejected, function(a, b) return tostring(a.id) < tostring(b.id) end)
	local profile = newProfile(parsed.name or "Imported", values)
	return profile, report
end

function Profiles:SaveImported(profile, name)
	local valid, err = self:ValidateName(name)
	if not valid then return nil, err end
	profile.name = valid
	ns.db.profiles[valid] = profile
	ns.Callbacks:Fire("ProfilesChanged")
	return profile
end
