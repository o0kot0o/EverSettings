local _, ns = ...

describe("external changes", function()
	it("are detected through CVAR_UPDATE and recorded, without writing back", function()
		local changed
		ns.Callbacks:Register("ValueChanged", "test", function(_, id, source) changed = id .. ":" .. source end)
		MOCK.setCVarRaw("autoLootDefault", "1") -- e.g. Blizzard's options or another addon
		ns.Callbacks:Unregister("ValueChanged", "test")
		eq(changed, "qol.autoLoot:external")
		eq(writes(), 1, "only the external write happened")
		local last = ns.db.history[#ns.db.history]
		eq(last.source, "external")
		eq(last.new, true)
	end)

	it("drop a pending change the outside world already made", function()
		ns.Changes:Stage(def("qol.autoLoot"), true)
		MOCK.setCVarRaw("autoLootDefault", "1")
		eq(ns.Changes:Count(), 0)
	end)

	it("leave a different pending change in place", function()
		ns.Changes:Stage(def("graphics.gamma"), 2)
		MOCK.setCVarRaw("Gamma", "1.5")
		near(ns.Changes.pending["graphics.gamma"], 2)
	end)

	it("are found by polling when no event fires", function()
		MOCK.cvars.lootundermouse = "0" -- silent change
		truthy(ns.Sync:Poll({ def("qol.lootUnderMouse") }))
		eq(ns.db.history[#ns.db.history].id, "qol.lootUnderMouse")
	end)

	it("are not reported for EverSettings' own applies", function()
		ns.Changes:Stage(def("graphics.gamma"), 1.5)
		ns.Changes:ApplyAll()
		eq(#ns.db.history, 1)
		eq(ns.db.history[1].source, "apply")
	end)
end)
