-- Change history (persistent, canonical values) and undo/redo (session only, exact raw
-- journal entries).
--
-- An operation is the journal of one apply: every setting that actually changed, with raw
-- snapshots of all its CVars before and after (issue #5, finding 3). Undo restores the raw
-- "before" snapshots exactly; redo restores the state undo replaced. Entries that cannot be
-- restored right now (combat, failures) stay on the stack for retry; entries whose CVars were
-- changed outside EverSettings in the meantime are reported and not overwritten.
local _, ns = ...

local Util = ns.Util
local History = { undoStack = {}, redoStack = {} }
ns.History = History

-- record = { time, id, old, new, result, source }   source: "apply" | "undo" | "redo" | "external"
function History:Add(record)
	local list = ns.db.history
	record.time = record.time or Util.Now()
	list[#list + 1] = record
	while #list > ns.MAX_HISTORY do table.remove(list, 1) end
	ns.Callbacks:Fire("HistoryChanged")
end

function History:GetRecent(limit)
	local list = ns.db.history
	local out = {}
	for i = #list, math.max(1, #list - (limit or 50) + 1), -1 do
		out[#out + 1] = list[i]
	end
	return out
end

-- Distinct setting ids changed most recently, newest first.
function History:GetRecentIds(limit)
	local seen, out = {}, {}
	local list = ns.db.history
	for i = #list, 1, -1 do
		local r = list[i]
		if not seen[r.id] and ns.Registry:Get(r.id) then
			seen[r.id] = true
			out[#out + 1] = r.id
			if #out >= (limit or 50) then break end
		end
	end
	return out
end

-- Called by Changes:ApplyList with the journal of an apply.
function History:PushOperation(journal, source)
	if #journal == 0 then return end
	self.undoStack[#self.undoStack + 1] = journal
	self.redoStack = {}
end

function History:CanUndo() return #self.undoStack > 0 end
function History:CanRedo() return #self.redoStack > 0 end

local function step(from, to, source)
	local op = table.remove(from)
	if not op then return nil end
	local report = ns.Changes:RestoreEntries(op, source)
	if #report.retained > 0 then from[#from + 1] = report.retained end
	if #report.journal > 0 then to[#to + 1] = report.journal end
	return report
end

function History:Undo()
	return step(self.undoStack, self.redoStack, "undo")
end

function History:Redo()
	return step(self.redoStack, self.undoStack, "redo")
end
