-- Staged changes and the safe apply pipeline.
--
-- Nothing is written to the game until Apply. Applying:
--   1. validates the requested value            5. writes through the setting's provider
--   2. checks dependencies (warnings)           6. reads the value back
--   3. checks combat and client restrictions    7. classifies: success, clamped, rejected, failed
--   4. records the original value (first time)  8. records history and reports every result
local _, ns = ...

local Values, Providers = ns.Values, ns.Providers
local Changes = { pending = {} }
ns.Changes = Changes

local function fire() ns.Callbacks:Fire("PendingChanged") end

function Changes:Stage(def, value)
	if def.disabled or def.control == "readonly" then return false, "not editable" end
	local current = Providers:Get(def)
	if Values.Equal(def, current, value) then
		self.pending[def.id] = nil
	else
		self.pending[def.id] = value
	end
	fire()
	return true
end

function Changes:Unstage(id)
	if self.pending[id] ~= nil then
		self.pending[id] = nil
		fire()
	end
end

function Changes:GetPending(id)
	local v = self.pending[id]
	return v, v ~= nil
end

function Changes:Count()
	return ns.Util.Count(self.pending)
end

function Changes:DiscardAll()
	if next(self.pending) then
		self.pending = {}
		fire()
	end
end

-- Value the UI should display: pending if staged, otherwise the live game value.
function Changes:GetEffective(def)
	local v, has = self:GetPending(def.id)
	if has then return v, true end
	return Providers:Get(def), false
end

function Changes:IsModified(def)
	local current = Providers:Get(def)
	local default = Providers:GetDefault(def)
	if current == nil or default == nil then return false end
	return not Values.Equal(def, current, default)
end

function Changes:StageDefault(def)
	local default = Providers:GetDefault(def)
	if default == nil then return false, "no known default" end
	return self:Stage(def, default)
end

-- Stage factory defaults for every editable, available setting in a category.
function Changes:StageCategoryDefaults(categoryId)
	local count = 0
	for _, section in ipairs(ns.Registry:GetCategorySections(categoryId)) do
		for _, def in ipairs(section.defs) do
			if def.control ~= "readonly" and Providers:IsAvailable(def) and not Providers:GetRestriction(def) then
				local default = Providers:GetDefault(def)
				if default ~= nil and Values.Validate(def, default) then
					local current = Providers:Get(def)
					if not Values.Equal(def, current, default) then
						self.pending[def.id] = default
						count = count + 1
					end
				end
			end
		end
	end
	if count > 0 then fire() end
	return count
end

local function DependencyWarnings(def)
	local warnings
	for _, dep in ipairs(def.dependencies or {}) do
		local other = ns.Registry:Get(dep.id)
		if other then
			local v, has = Changes:GetPending(other.id)
			if not has then v = Providers:Get(other) end
			if not Values.Equal(other, v, dep.value) then
				warnings = warnings or {}
				warnings[#warnings + 1] = dep.reason or ("depends on " .. other.name)
			end
		end
	end
	return warnings
end

function Changes:ApplyAll()
	local list = {}
	for id, value in pairs(self.pending) do
		local def = ns.Registry:Get(id)
		if def then list[#list + 1] = { def = def, value = value } end
	end
	return self:ApplyList(list, "apply")
end

-- Apply only the given ids from the pending set (e.g. a single setting).
function Changes:ApplyIds(ids)
	local list = {}
	for _, id in ipairs(ids) do
		local def, value = ns.Registry:Get(id), self.pending[id]
		if def and value ~= nil then list[#list + 1] = { def = def, value = value } end
	end
	return self:ApplyList(list, "apply")
end

-- changes: list of { def = ..., value = canonical }.
function Changes:ApplyList(changes, source)
	table.sort(changes, function(a, b)
		local oa, ob = a.def.applyOrder or 0, b.def.applyOrder or 0
		if oa ~= ob then return oa < ob end
		return a.def.id < b.def.id
	end)

	local report = {
		source = source, results = {}, notices = {},
		counts = { success = 0, clamped = 0, rejected = 0, failed = 0, restricted = 0 },
	}
	local operation = {}
	local noticeSeen = {}
	ns.Sync:BeginApply()
	for _, change in ipairs(changes) do
		local def, value = change.def, change.value
		local r = { id = def.id, name = def.name, requested = value }
		local ok, err = Values.Validate(def, value)
		if not ok then
			r.status, r.message = "failed", "Invalid value: " .. tostring(err)
		else
			local restriction = Providers:GetRestriction(def)
			if restriction then
				r.status, r.message = "restricted", restriction
			else
				r.warnings = DependencyWarnings(def)
				local before = Providers:Get(def)
				ns.Backup:RecordOriginal(def, before)
				local setOk, setErr = Providers:Set(def, value)
				local after = Providers:Get(def)
				r.before, r.after = before, after
				if Values.Equal(def, after, value) then
					r.status = "success"
				elseif setOk == false then
					r.status, r.message = "failed", tostring(setErr or "write failed")
				elseif Values.Equal(def, after, before) then
					r.status, r.message = "rejected", "The client kept the previous value."
				else
					r.status = "clamped"
					r.message = ("The client stored %s instead."):format(Values.Format(def, after))
				end
				if r.status == "success" or r.status == "clamped" then
					operation[#operation + 1] = { id = def.id, old = before, new = after }
					ns.History:Add({ id = def.id, old = before, new = after, result = r.status, source = source })
					ns.Sync:Remember(def, after)
					if def.apply ~= "immediate" and not noticeSeen[def.apply] then
						noticeSeen[def.apply] = true
						report.notices[#report.notices + 1] = def.apply
					end
				end
			end
		end
		report.counts[r.status] = report.counts[r.status] + 1
		report.results[#report.results + 1] = r
		if r.status ~= "restricted" then
			self.pending[def.id] = nil
		end
	end
	ns.Sync:EndApply()
	ns.History:PushOperation(operation, source)
	for _, r in ipairs(report.results) do
		ns.Callbacks:Fire("ValueChanged", r.id, source)
	end
	fire()
	ns.Callbacks:Fire("ApplyFinished", report)
	return report
end

function Changes:FormatReport(report)
	local c = report.counts
	local parts = { ("%d applied"):format(c.success) }
	if c.clamped > 0 then parts[#parts + 1] = ("%d adjusted by client"):format(c.clamped) end
	if c.rejected > 0 then parts[#parts + 1] = ("%d rejected"):format(c.rejected) end
	if c.failed > 0 then parts[#parts + 1] = ("%d failed"):format(c.failed) end
	if c.restricted > 0 then parts[#parts + 1] = ("%d restricted (kept pending)"):format(c.restricted) end
	local text = table.concat(parts, ", ")
	for _, notice in ipairs(report.notices) do
		if notice == "reload" then text = text .. ". Some changes need /reload."
		elseif notice == "restart" then text = text .. ". Some changes need a full game restart."
		elseif notice == "gxrestart" then text = text .. ". The graphics device restarted." end
	end
	return text
end
