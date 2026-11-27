local _, ns = ...

describe("boot", function()
	it("loads every TOC file and initialises saved variables", function()
		truthy(ns.db, "saved variables")
		eq(ns.db.dbVersion, ns.DB_VERSION)
		truthy(EverSettingsDB == ns.db, "global saved variable table")
		truthy(ns.Registry.finalized, "registry finalized")
	end)

	it("detects the Forever client", function()
		truthy(ns.Compat.isForever)
		eq(ns.Compat.build.interface, 16001)
		truthy(ns.Compat.caps.ConsoleGetAllCommands)
		truthy(ns.Compat.caps.GetCVarInfo)
	end)

	it("does not modify any game setting on install or login", function()
		eq(BOOT_WRITES, 0, "SetCVar calls during load, login and startup timers")
	end)

	it("prints nothing alarming during boot", function()
		for _, line in ipairs(BOOT_PRINTED) do
			falsy(line:find("error") or line:find("failed"), "boot output: " .. line)
		end
	end)

	it("captures the initial snapshot", function()
		local snap = ns.db.snapshots.initial
		truthy(snap, "initial snapshot")
		truthy(ns.Util.Count(snap.values) > 1000, "snapshot covers the catalog")
		truthy(ns.db.characterSnapshots["Tester-TestRealm"], "character snapshot")
		eq(ns.db.characterSnapshots["Tester-TestRealm"].values.showQuestLevel, "0", "character-scoped CVar stored per character")
	end)

	it("registers both slash commands", function()
		eq(SLASH_EVERSETTINGS1, "/eversettings")
		eq(SLASH_EVERSETTINGS2, "/es")
		truthy(SlashCmdList.EVERSETTINGS)
	end)

	it("handles unknown slash commands gracefully", function()
		SlashCmdList.EVERSETTINGS("nonsense")
		SlashCmdList.EVERSETTINGS("help")
		SlashCmdList.EVERSETTINGS("diag")
		eq(writes(), 0)
	end)

	it("loads quickly", function()
		truthy(ES_LOAD_MS < 2000, "addon files load in under 2s offline, took " .. ES_LOAD_MS)
	end)
end)
