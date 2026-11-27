local _, ns = ...
local Profiles, Serializer = ns.Profiles, ns.Serializer

describe("profile management", function()
	it("saves, renames, duplicates and deletes", function()
		local p = assert(Profiles:SaveAs("Raid"))
		truthy(ns.Util.Count(p.values) > 40, "captures managed settings")
		eq(Profiles:GetActive(), "Raid")
		falsy(Profiles:SaveAs("Raid"), "duplicate names rejected")
		falsy(Profiles:SaveAs("   "), "empty names rejected")
		assert(Profiles:Rename("Raid", "Raid Night"))
		eq(Profiles:GetActive(), "Raid Night")
		assert(Profiles:Duplicate("Raid Night", "Copy"))
		eq(#Profiles:List(), 2)
		truthy(Profiles:Delete("Copy"))
		eq(#Profiles:List(), 1)
	end)

	it("compares against the game and stages only selected categories", function()
		local p = assert(Profiles:SaveAs("Base"))
		p.values["graphics.gamma"] = 2
		p.values["qol.autoLoot"] = true
		local cmp = Profiles:Compare(p)
		eq(#cmp.diffs, 2)
		local n, backup = Profiles:StageApply(p, { graphics = true })
		eq(n, 1)
		truthy(backup, "backup created before applying")
		eq(#ns.db.backups, 1)
		near(ns.Changes.pending["graphics.gamma"], 2)
		eq(ns.Changes.pending["qol.autoLoot"], nil)
		eq(writes(), 0, "profiles never write directly")
	end)

	it("restores a backup selectively through the staging pipeline", function()
		local b = ns.Backup:Create("manual", "test")
		MOCK.cvars.gamma = "2"
		MOCK.cvars.autolootdefault = "1"
		local n = ns.Backup:StageRestore(b, { ["graphics.gamma"] = true })
		eq(n, 1)
		near(ns.Changes.pending["graphics.gamma"], 1)
		eq(writes(), 0)
	end)
end)

describe("export and import", function()
	it("round-trips a profile", function()
		local p = assert(Profiles:SaveAs("My; odd=name|#%"))
		p.values["interface.whisperMode"] = "popout_and_inline"
		local text = Serializer.Encode(p)
		eq(text:sub(1, 5), "!ES1;")
		local back, report = Profiles:ParseImport(text)
		truthy(back, tostring(report))
		eq(back.name, "My; odd=name|#%")
		eq(report.accepted, ns.Util.Count(p.values))
		eq(#report.rejected, 0)
		eq(back.values["interface.whisperMode"], "popout_and_inline")
		for id, v in pairs(p.values) do
			truthy(ns.Values.Equal(def(id), back.values[id], v), id)
		end
	end)

	it("detects tampering and truncation", function()
		local text = Serializer.Encode(assert(Profiles:SaveAs("T")))
		local bad, err = Profiles:ParseImport(text:gsub("graphics%.gamma=n1", "graphics.gamma=n2"))
		eq(bad, nil); truthy(err:find("checksum"))
		bad, err = Profiles:ParseImport(text:sub(1, #text - 20))
		eq(bad, nil)
		bad, err = Profiles:ParseImport("return os.exit()")
		eq(bad, nil); truthy(err:find("not an EverSettings profile"))
	end)

	it("rejects unknown settings, invalid values and never executes content", function()
		_G.ES_PWNED = nil
		local payload = "n=x;t=0;graphics.gamma=n99;qol.autoLoot=b1;evil.code=s_G.ES_PWNED%3Dtrue;graphics.farclip=n5000"
		local text = Serializer.PREFIX .. payload .. ";#" .. Serializer.Checksum(payload)
		local p, report = Profiles:ParseImport(text)
		truthy(p)
		eq(report.accepted, 1)
		eq(#report.rejected, 3)
		eq(p.values["qol.autoLoot"], true)
		eq(p.values["graphics.gamma"], nil)
		eq(_G.ES_PWNED, nil)
	end)
end)
