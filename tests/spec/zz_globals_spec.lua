-- Runs last: after every other spec has exercised the addon, check it leaked no globals.
local _, ns = ...

local ALLOWED = {
	EverSettingsDB = true, SLASH_EVERSETTINGS1 = true, SLASH_EVERSETTINGS2 = true,
	EverSettingsMainFrame = true, EverSettingsDialog = true,
}
-- Test-harness globals.
local HARNESS = {
	PRE_GLOBALS = true, ES_NS = true, ES_LOAD_MS = true, ES_FILES = true, BOOT_WRITES = true, BOOT_PRINTED = true,
	SPEC_RESULTS = true, SPEC_FILE = true, describe = true, it = true, eq = true, near = true, truthy = true,
	falsy = true, contains = true, raw = true, def = true, writes = true, reset_state = true, ES_PWNED = true,
}

describe("globals", function()
	it("the addon only creates its documented globals", function()
		local leaked = {}
		for k in pairs(_G) do
			if not PRE_GLOBALS[k] and not ALLOWED[k] and not HARNESS[k] and not tostring(k):match("^EverSettingsFont_") then
				leaked[#leaked + 1] = tostring(k)
			end
		end
		table.sort(leaked)
		eq(#leaked, 0, "leaked globals: " .. table.concat(leaked, ", "))
	end)
end)
