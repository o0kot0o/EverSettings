-- Change history (persistent) and undo/redo (session only).
local _, ns = ...

local Util = ns.Util
local History = { undoStack = {}, redoStack = {} }
ns.History = History

-- record = { time, id, old, new, result, source }   source: "apply" | "undo" | "redo" | "external" | "profile" | "restore"
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

-- An operation is the set of successful changes from one apply: { { id, old, new }, ... }
function History:PushOperation(op, source)
	if #op == 0 then return end
	if source == "undo" then
		self.redoStack[#self.redoStack + 1] = op
	else
		self.undoStack[#self.undoStack + 1] = op
		if source ~= "redo" then
			self.redoStack = {}
		end
	end
end

function History:CanUndo() return #self.undoStack > 0 end
function History:CanRedo() return #self.redoStack > 0 end

local function apply(op, useOld, source)
	local changes = {}
	for _, c in ipairs(op) do
		local def = ns.Registry:Get(c.id)
		-- Explicit branch: `useOld and c.old or c.new` breaks when the old value is false.
		local value
		if useOld then value = c.old else value = c.new end
		if def and value ~= nil then changes[#changes + 1] = { def = def, value = value } end
	end
	return ns.Changes:ApplyList(changes, source)
end

function History:Undo()
	local op = table.remove(self.undoStack)
	if not op then return nil end
	return apply(op, true, "undo")
end

-- The redo stack holds the operations produced by undo, so redoing means reverting them.
function History:Redo()
	local op = table.remove(self.redoStack)
	if not op then return nil end
	return apply(op, true, "redo")
end
