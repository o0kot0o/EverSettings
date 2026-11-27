-- Tiny spec framework and shared helpers for the offline tests.
SPEC_RESULTS = {}
local ns = ES_NS
local currentGroup = ""

function describe(name, fn)
	local previous = currentGroup
	currentGroup = (previous ~= "" and (previous .. " / ") or "") .. name
	fn()
	currentGroup = previous
end

-- Restore a clean game and addon state before each test.
function reset_state()
	for k, v in pairs(MOCK.defaults) do MOCK.cvars[k] = v end
	wipe(MOCK.setLog); wipe(MOCK.clamp); wipe(MOCK.reject); wipe(MOCK.readOnly); wipe(MOCK.locked)
	MOCK.combat = false
	MOCK.minimapFiltered = { [1024] = true }
	wipe(ns.Changes.pending)
	wipe(ns.db.history); wipe(ns.db.originals); wipe(ns.db.profiles); wipe(ns.db.backups); wipe(ns.db.favorites)
	ns.db.activeProfile = nil
	ns.History.undoStack, ns.History.redoStack = {}, {}
	ns.Sync:Prime()
end

function it(name, fn)
	reset_state()
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback("", 2):sub(1, 900) end)
	table.insert(SPEC_RESULTS, { file = SPEC_FILE, name = currentGroup .. " :: " .. name, ok = ok, err = err })
end

local function fmt(v)
	if type(v) == "string" then return ("%q"):format(v) end
	return tostring(v)
end

function eq(actual, expected, msg)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", fmt(expected), fmt(actual)), 2)
	end
end

function near(actual, expected, msg)
	if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
		error(("%sexpected ~%s, got %s"):format(msg and (msg .. ": ") or "", fmt(expected), fmt(actual)), 2)
	end
end

function truthy(v, msg) if not v then error((msg or "expected truthy value") .. ", got " .. fmt(v), 2) end end
function falsy(v, msg) if v then error((msg or "expected falsy value") .. ", got " .. fmt(v), 2) end end

function contains(list, value, msg)
	for _, v in ipairs(list) do if v == value then return end end
	error((msg or "list does not contain") .. " " .. fmt(value), 2)
end

function raw(name) return MOCK.cvars[name:lower()] end
function def(id) return assert(ns.Registry:Get(id), "no definition " .. id) end

-- Count SetCVar calls made with a given name since reset.
function writes(name)
	local n = 0
	for _, w in ipairs(MOCK.setLog) do if not name or w.name:lower() == name:lower() then n = n + 1 end end
	return n
end
