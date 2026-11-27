-- Staged changes and the safe apply pipeline.
--
-- Nothing is written to the game until Apply. Applying (issue #5):
--   1. previews the batch: validation, write sets, overlapping writes and dependency
--      warnings, all computed from the effective values BEFORE any write
--   2. per item: checks restrictions, snapshots the exact raw state of every CVar it can
--      write, records the original value (first time, per scope), writes through the
--      provider's raw write plan (checked, verified per CVar, rolled back on partial failure)
--   3. classifies: success, clamped, rejected, failed, partial (multi-CVar write that only
--      partly succeeded), unknown (value could not be read back), restricted
--   4. verifies the final state of the whole batch, journals every actual mutation with raw
--      before/after snapshots (also for unsuccessful items), and refreshes every setting that
--      shares a written CVar without logging our own side effects as external changes
-- Failed, rejected, partial, unknown and restricted requests stay pending for review or retry.
-- Every item runs protected, so the sync guard is always released.
local _, ns = ...

local Values, Providers = ns.Values, ns.Providers
local Changes = {
	pending = {},       -- [id] = canonical value to apply
	pendingRaw = {},    -- [id] = exact raw snapshot to restore (backups/originals)
	pendingOrigin = {}, -- [id] = "user" | "profile:<name>" | "backup" | "originals" | "defaults"
}
ns.Changes = Changes

local STATUSES = { "success", "clamped", "rejected", "failed", "partial", "unknown", "restricted" }

local function fire() ns.Callbacks:Fire("PendingChanged") end

local function safeGet(def)
	local ok, v = pcall(Providers.Get, Providers, def)
	if ok then return v end
	return nil
end

local function rawMatches(def, snap)
	return #Providers.SnapshotDiff(snap, Providers:Snapshot(def)) == 0
end

-- Staging ---------------------------------------------------------------------------------

-- Stage a target value (and optionally an exact raw snapshot). Reconciles with the live
-- value: if the game already has the target, any pending entry is cleared instead.
-- Returns outcome ("staged" | "cleared" | "unchanged") and whether a different pending edit
-- was replaced.
function Changes:StageTarget(def, value, raw, origin)
	if def.disabled or def.control == "readonly" then return "unchanged", false end
	local existing = self.pending[def.id]
	local replaced = existing ~= nil and not Values.Equal(def, existing, value)
	local live = safeGet(def)
	local atTarget = Values.Equal(def, live, value) and (raw == nil or rawMatches(def, raw))
	if atTarget then
		if existing ~= nil then
			self.pending[def.id], self.pendingRaw[def.id], self.pendingOrigin[def.id] = nil, nil, nil
			return "cleared", replaced
		end
		return "unchanged", false
	end
	self.pending[def.id] = value
	self.pendingRaw[def.id] = raw
	self.pendingOrigin[def.id] = origin or "user"
	return "staged", replaced
end

function Changes:Stage(def, value)
	if def.disabled or def.control == "readonly" then return false, "not editable" end
	self:StageTarget(def, value, nil, "user")
	fire()
	return true
end

function Changes:Unstage(id)
	if self.pending[id] ~= nil then
		self.pending[id], self.pendingRaw[id], self.pendingOrigin[id] = nil, nil, nil
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
		self.pending, self.pendingRaw, self.pendingOrigin = {}, {}, {}
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

-- Stage factory defaults for every editable, available setting in a category, reconciling
-- pending edits: a pending non-default value is cleared when the live value is already the
-- default. Returns staged count and { staged, cleared, replaced, restricted }.
function Changes:StageCategoryDefaults(categoryId)
	local report = { staged = 0, cleared = 0, replaced = 0, restricted = 0 }
	for _, section in ipairs(ns.Registry:GetCategorySections(categoryId)) do
		for _, def in ipairs(section.defs) do
			if def.control ~= "readonly" and def.provider ~= "diagnostic" and Providers:IsAvailable(def) then
				if Providers:GetRestriction(def) then
					report.restricted = report.restricted + 1
				else
					local default = Providers:GetDefault(def)
					if default ~= nil and Values.Validate(def, default) then
						local outcome, replaced = self:StageTarget(def, default, nil, "defaults")
						if outcome == "staged" then report.staged = report.staged + 1 end
						if outcome == "cleared" then report.cleared = report.cleared + 1 end
						if replaced then report.replaced = report.replaced + 1 end
					end
				end
			end
		end
	end
	if report.staged + report.cleared > 0 then fire() end
	return report.staged, report
end

-- Preview -----------------------------------------------------------------------------------

local function sortChanges(changes)
	table.sort(changes, function(a, b)
		local oa, ob = a.def.applyOrder or 0, b.def.applyOrder or 0
		if oa ~= ob then return oa < ob end
		return a.def.id < b.def.id
	end)
end

-- Dependency warnings against the effective state of the whole batch before any write.
local function dependencyWarnings(def, batchValues)
	local warnings
	for _, dep in ipairs(def.dependencies or {}) do
		local other = ns.Registry:Get(dep.id)
		if other then
			local v = batchValues[other.id]
			if v == nil then v = Changes.pending[other.id] end
			if v == nil then v = safeGet(other) end
			if not Values.Equal(other, v, dep.value) then
				warnings = warnings or {}
				warnings[#warnings + 1] = dep.reason or ("depends on " .. other.name)
			end
		end
	end
	return warnings
end

-- Returns { items = sorted changes, overlaps = { { cvar, ids = {...}, winner } }, warnings = { [id] = {...} } }.
-- Overlap rule: changes apply in applyOrder, so the last change writing a CVar wins (an
-- explicitly staged quality setting overrides the graphics preset).
function Changes:Preview(changes)
	sortChanges(changes)
	local batchValues = {}
	for _, c in ipairs(changes) do batchValues[c.def.id] = c.value end
	local writers, order = {}, {}
	local warnings = {}
	for _, c in ipairs(changes) do
		warnings[c.def.id] = dependencyWarnings(c.def, batchValues)
		for _, name in ipairs(Providers:WriteSet(c.def)) do
			if not writers[name] then writers[name] = {}; order[#order + 1] = name end
			table.insert(writers[name], c.def.id)
		end
	end
	local overlaps = {}
	for _, name in ipairs(order) do
		local ids = writers[name]
		if #ids > 1 then overlaps[#overlaps + 1] = { cvar = name, ids = ids, winner = ids[#ids] } end
	end
	return { items = changes, overlaps = overlaps, warnings = warnings }
end

function Changes:PendingList()
	local list = {}
	for id, value in pairs(self.pending) do
		local def = ns.Registry:Get(id)
		if def then
			list[#list + 1] = { def = def, value = value, raw = self.pendingRaw[id], origin = self.pendingOrigin[id] }
		end
	end
	return list
end

function Changes:PreviewPending()
	return self:Preview(self:PendingList())
end

-- Apply ---------------------------------------------------------------------------------------

function Changes:ApplyAll()
	return self:ApplyList(self:PendingList(), "apply")
end

-- Apply only the given ids from the pending set (e.g. a single setting).
function Changes:ApplyIds(ids)
	local list = {}
	for _, id in ipairs(ids) do
		local def, value = ns.Registry:Get(id), self.pending[id]
		if def and value ~= nil then
			list[#list + 1] = { def = def, value = value, raw = self.pendingRaw[id], origin = self.pendingOrigin[id] }
		end
	end
	return self:ApplyList(list, "apply")
end

local function newReport(source)
	local counts = {}
	for _, s in ipairs(STATUSES) do counts[s] = 0 end
	return { source = source, results = {}, notices = {}, counts = counts, overlaps = {}, journal = {} }
end

-- Apply one change. Returns the result record; may raise (caller protects it).
local function applyOne(self, change, warnings, report)
	local def, value = change.def, change.value
	local r = { id = def.id, name = def.name, requested = value, warnings = warnings }
	local ok, err = Values.Validate(def, value)
	if not ok then
		r.status, r.message = "failed", "Invalid value: " .. tostring(err)
		return r
	end
	local restriction = Providers:GetRestriction(def)
	if restriction then
		r.status, r.message = "restricted", restriction
		return r
	end

	local rawBefore = Providers:Snapshot(def)
	local before = safeGet(def)
	ns.Backup:RecordOriginal(def, before, rawBefore)

	local setOk, setMsg, plan
	if change.raw then
		-- Exact restore from a backup or originals snapshot.
		local status, msg, result = Providers:RestoreSnapshot(def, change.raw)
		if status == "restricted" then
			r.status, r.message = "restricted", msg
			return r
		end
		setOk, setMsg, plan = (status == "success" or status == "noop"), msg, result
	else
		local okCall, a, b, c = pcall(Providers.Set, Providers, def, value)
		if okCall then
			setOk, setMsg, plan = a, b, c
		else
			setOk, setMsg = false, "error: " .. tostring(a)
		end
	end

	local after = safeGet(def)
	local rawAfter = Providers:Snapshot(def)
	local mutated = Providers.SnapshotDiff(rawBefore, rawAfter)
	r.before, r.after, r.rawBefore, r.rawAfter, r.mutated, r.plan = before, after, rawBefore, rawAfter, mutated, plan

	if plan and plan.preflightError then
		r.status, r.message = "failed", plan.preflightError
	elseif plan and plan.partial then
		r.status, r.message = "partial", Providers.DescribePlan(plan)
	elseif after == nil then
		r.status, r.message = "unknown", "The value could not be read back."
	elseif Values.Equal(def, after, value) and (plan == nil or plan.allOk) then
		r.status = "success"
	elseif Values.Equal(def, after, value) then
		r.status, r.message = "clamped", Providers.DescribePlan(plan)
	elseif #mutated == 0 then
		-- Nothing changed: an error from the write is a failure, a silent refusal (SetCVar's
		-- ReturnNothing preconditions) is a rejection.
		local writeError = (plan == nil and setOk == false)
		for _, e in ipairs(plan and plan.entries or {}) do
			if e.outcome == "failed" then writeError = true end
		end
		if writeError then
			r.status, r.message = "failed", tostring(setMsg or "write failed")
		else
			r.status, r.message = "rejected", "The client kept the previous value."
		end
	else
		r.status = "clamped"
		r.message = ("The client stored %s instead."):format(Values.Format(def, after))
	end

	-- Journal every actual mutation, successful or not, so it can be undone exactly.
	if #mutated > 0 or (def.provider == "api" and not Values.Equal(def, before, after)) then
		report.journal[#report.journal + 1] = {
			id = def.id, before = before, after = after, rawBefore = rawBefore, rawAfter = rawAfter, status = r.status,
		}
		ns.History:Add({ id = def.id, old = before, new = after, result = r.status, source = report.source })
	end
	return r
end

-- changes: list of { def, value, raw?, origin? }.
function Changes:ApplyList(changes, source)
	local preview = self:Preview(changes)
	local report = newReport(source)
	report.overlaps = preview.overlaps

	-- A profile is backed up with the live values immediately before it is applied.
	local profiles = {}
	for _, c in ipairs(preview.items) do
		local name = c.origin and c.origin:match("^profile:(.+)$")
		if name then profiles[name] = true end
	end
	for name in pairs(profiles) do
		pcall(ns.Backup.Create, ns.Backup, ("Before applying profile '%s'"):format(name), "profile")
	end

	ns.Sync:BeginApply()
	local okBatch, batchErr = pcall(function()
		for _, change in ipairs(preview.items) do
			local okItem, r = pcall(applyOne, self, change, preview.warnings[change.def.id], report)
			if not okItem then
				r = { id = change.def.id, name = change.def.name, requested = change.value, status = "failed", message = "error: " .. tostring(r) }
			end
			report.results[#report.results + 1] = r
		end
	end)
	ns.Sync:EndApply()
	if not okBatch then
		report.error = tostring(batchErr)
		ns:Print("apply stopped by an error: %s", report.error)
	end

	-- Verify the final state of the batch: a later change in the same batch may legitimately
	-- override an earlier one (preset, then an explicit quality setting).
	for i, r in ipairs(report.results) do
		if r.status == "success" or r.status == "clamped" then
			local def = ns.Registry:Get(r.id)
			local final = safeGet(def)
			if not Values.Equal(def, final, r.after) then
				local writeSet = {}
				for _, name in ipairs(Providers:WriteSet(def)) do writeSet[name] = true end
				for j = i + 1, #report.results do
					for _, name in ipairs(report.results[j].mutated or {}) do
						if writeSet[name] then r.overriddenBy = report.results[j].name end
					end
				end
				if r.overriddenBy then
					r.note = ("then partly overridden by %s"):format(r.overriddenBy)
				else
					r.status, r.message = "unknown", "The value changed again after it was applied."
				end
				r.after = final
			end
		end
	end

	-- Pending: only a successfully applied request leaves the pending list.
	local noticeSeen = {}
	for _, r in ipairs(report.results) do
		report.counts[r.status] = (report.counts[r.status] or 0) + 1
		local def = ns.Registry:Get(r.id)
		if (r.status == "success" or r.status == "clamped") and def then
			if self.pending[r.id] ~= nil and Values.Equal(def, self.pending[r.id], r.requested) then
				self.pending[r.id], self.pendingRaw[r.id], self.pendingOrigin[r.id] = nil, nil, nil
			end
			if def.apply ~= "immediate" and not noticeSeen[def.apply] then
				noticeSeen[def.apply] = true
				report.notices[#report.notices + 1] = def.apply
			end
		end
	end

	ns.History:PushOperation(report.journal, source)
	self:RefreshAffected(report.results, source)
	fire()
	ns.Callbacks:Fire("ApplyFinished", report)
	return report
end

-- Refresh every definition that shares a CVar with what was written (aliases, preset
-- children) and record their new values as our own, so polling does not report them as
-- external changes.
function Changes:RefreshAffected(results, source)
	local affected = {}
	for _, r in ipairs(results) do
		affected[r.id] = true
		for _, name in ipairs(r.mutated or {}) do
			for _, d in ipairs(ns.Registry:GetByCVar(name) or {}) do affected[d.id] = true end
		end
	end
	for id in pairs(affected) do
		local def = ns.Registry:Get(id)
		if def and def.provider ~= "diagnostic" then
			ns.Sync:Remember(def, safeGet(def))
			ns.Callbacks:Fire("ValueChanged", id, source)
		end
	end
end

-- Undo / redo -----------------------------------------------------------------------------------

-- Restore journal entries to their exact raw "before" state, newest first. Entries whose
-- CVars changed outside EverSettings since are reported as conflicts and left alone.
-- Restricted or failed entries are returned for retry. Pending edits are never touched.
-- Returns report { results, counts, retained, journal }.
function Changes:RestoreEntries(entries, source)
	local report = { source = source, results = {}, retained = {}, journal = {},
		counts = { success = 0, conflict = 0, failed = 0, restricted = 0, noop = 0 } }
	ns.Sync:BeginApply()
	local okBatch, batchErr = pcall(function()
		for i = #entries, 1, -1 do
			local e = entries[i]
			local def = ns.Registry:Get(e.id)
			local r = { id = e.id, name = def and def.name or e.id }
			if not def then
				r.status, r.message = "failed", "setting no longer exists"
			else
				local rawNow = Providers:Snapshot(def)
				local now = safeGet(def)
				local okCall, status, msg = pcall(Providers.RestoreSnapshot, Providers, def, e.rawBefore, e.rawAfter)
				if not okCall then status, msg = "failed", "error: " .. tostring(status) end
				r.status, r.message = status, msg
				local rawAfter = Providers:Snapshot(def)
				r.mutated = Providers.SnapshotDiff(rawNow, rawAfter)
				if status == "success" then
					local after = safeGet(def)
					report.journal[#report.journal + 1] = { id = e.id, before = now, after = after, rawBefore = rawNow, rawAfter = rawAfter, status = "success" }
					ns.History:Add({ id = e.id, old = now, new = after, result = "success", source = source })
				elseif status == "failed" or status == "restricted" then
					-- Keep for retry, based on the state we leave it in now.
					report.retained[#report.retained + 1] = { id = e.id, before = e.before, after = now, rawBefore = e.rawBefore, rawAfter = rawAfter, status = e.status }
				end
				if self.pending[e.id] ~= nil then r.pendingKept = true end
			end
			report.counts[r.status] = (report.counts[r.status] or 0) + 1
			report.results[#report.results + 1] = r
		end
	end)
	ns.Sync:EndApply()
	if not okBatch then report.error = tostring(batchErr) end
	-- Retained entries keep their original order for the next attempt.
	local retained = {}
	for i = #report.retained, 1, -1 do retained[#retained + 1] = report.retained[i] end
	report.retained = retained
	self:RefreshAffected(report.results, source)
	ns.Callbacks:Fire("ApplyFinished", report)
	return report
end

function Changes:FormatReport(report)
	local c = report.counts
	local parts = {}
	if report.retained then
		parts[#parts + 1] = ("%d restored"):format(c.success or 0)
		if (c.conflict or 0) > 0 then parts[#parts + 1] = ("%d skipped (changed outside EverSettings)"):format(c.conflict) end
		if #report.retained > 0 then parts[#parts + 1] = ("%d kept for retry"):format(#report.retained) end
	else
		parts[#parts + 1] = ("%d applied"):format(c.success)
		if c.clamped > 0 then parts[#parts + 1] = ("%d adjusted by client"):format(c.clamped) end
		if c.partial > 0 then parts[#parts + 1] = ("%d partly applied"):format(c.partial) end
		if c.unknown > 0 then parts[#parts + 1] = ("%d unconfirmed"):format(c.unknown) end
		if c.rejected > 0 then parts[#parts + 1] = ("%d rejected"):format(c.rejected) end
		if c.failed > 0 then parts[#parts + 1] = ("%d failed"):format(c.failed) end
		if c.restricted > 0 then parts[#parts + 1] = ("%d restricted"):format(c.restricted) end
	end
	local text = table.concat(parts, ", ")
	local kept = (c.rejected or 0) + (c.failed or 0) + (c.partial or 0) + (c.unknown or 0) + (c.restricted or 0)
	if not report.retained and kept > 0 then text = text .. " (kept pending for review)" end
	for _, notice in ipairs(report.notices or {}) do
		if notice == "reload" then text = text .. ". Some changes need /reload."
		elseif notice == "restart" then text = text .. ". Some changes need a full game restart."
		elseif notice == "gxrestart" then text = text .. ". The graphics device restarted." end
	end
	return text
end
