-- Regression tests for the issue #5 safety review (ChatGPT, 2026-11-27).
local _, ns = ...
local Changes, Providers, History, Backup = ns.Changes, ns.Providers, ns.History, ns.Backup

local function result(report, id)
	for _, r in ipairs(report.results) do if r.id == id then return r end end
end

local function withOverride(tbl, key, fn, body)
	local orig = tbl[key]
	tbl[key] = fn
	local ok, err = pcall(body)
	tbl[key] = orig
	if not ok then error(err, 0) end
end

describe("#5 finding 1: composite writes and exact recovery", function()
	it("a silently rejected second CVar makes the write partial and rolls back the first", function()
		MOCK.reject.camerapitchmovespeed = true
		Changes:Stage(def("camera.mouseLookSpeed"), 200)
		local report = Changes:ApplyAll()
		local r = result(report, "camera.mouseLookSpeed")
		eq(r.status, "partial")
		eq(raw("cameraYawMoveSpeed"), "180.000000", "first CVar rolled back")
		eq(r.plan.rollback[1].outcome, "restored")
		eq(r.plan.entries[2].outcome, "rejected", "per-CVar outcome reported")
		eq(#report.journal, 0, "nothing changed in the end, so nothing to undo")
		near(Changes.pending["camera.mouseLookSpeed"], 200, "kept pending for review")
	end)

	it("a write error on a child is reported per CVar and rolled back", function()
		local origSet = C_CVar.SetCVar
		C_CVar.SetCVar = function(name, value)
			if name:lower() == "shakestrengthui" then error("boom") end
			return origSet(name, value)
		end
		Changes:Stage(def("camera.shake"), 0)
		local report = Changes:ApplyAll()
		C_CVar.SetCVar = origSet
		local r = result(report, "camera.shake")
		eq(r.status, "partial")
		eq(r.plan.entries[2].outcome, "failed")
		eq(raw("ShakeStrengthCamera"), "1.000000", "first child restored")
		truthy(r.message:find("rolled back"))
	end)

	it("the whole write set is checked before anything is written", function()
		MOCK.readOnly.camerapitchmovespeed = true
		Changes:Stage(def("camera.mouseLookSpeed"), 200)
		local report = Changes:ApplyAll()
		eq(result(report, "camera.mouseLookSpeed").status, "restricted")
		eq(writes(), 0, "no CVar touched")
	end)

	it("undo of a graphics preset restores custom child values exactly", function()
		MOCK.cvars.graphicsshadowquality = "5"
		MOCK.cvars.graphicsssao = "1"
		MOCK.cvars.graphicsgroundclutter = "7"
		ns.Sync:Prime()
		Changes:Stage(def("graphics.qualityPreset"), 0)
		local report = Changes:ApplyAll()
		eq(result(report, "graphics.qualityPreset").status, "success")
		eq(raw("graphicsShadowQuality"), "0")
		History:Undo()
		eq(raw("graphicsShadowQuality"), "5", "custom value, not a recomputed preset level")
		eq(raw("graphicsSSAO"), "1")
		eq(raw("graphicsGroundClutter"), "7")
		eq(raw("graphicsQuality"), "5")
	end)

	it("an unreadable value after writing is reported as unknown, not as adjusted", function()
		local h = ns.Composites.ratio
		local writes0 = 0
		withOverride(h, "Get", function(d) if writes0 > 0 then error("getter broke") end return tonumber(MOCK.cvars.camerayawmovespeed) end, function()
			Changes:Stage(def("camera.mouseLookSpeed"), 200)
			writes0 = 1
			local report = Changes:ApplyAll()
			eq(result(report, "camera.mouseLookSpeed").status, "unknown")
		end)
		eq(ns.Sync.applying, 0, "sync guard released")
	end)
end)

describe("#5 finding 2: overlapping settings and sync", function()
	it("previews overlapping write sets and the winner", function()
		Changes:Stage(def("graphics.qualityPreset"), 0)
		Changes:Stage(def("graphics.shadowQuality"), 5)
		local preview = Changes:PreviewPending()
		local found
		for _, o in ipairs(preview.overlaps) do
			if o.cvar == "graphicsShadowQuality" then found = o end
		end
		truthy(found, "overlap reported")
		eq(found.winner, "graphics.shadowQuality")
	end)

	it("preset side effects on other rows are not logged as external changes", function()
		Changes:Stage(def("graphics.qualityPreset"), 0)
		Changes:ApplyAll()
		local before = #ns.db.history
		falsy(ns.Sync:Poll({ def("graphics.shadowQuality"), def("graphics.ssao"), def("graphics.viewDistance") }), "poll finds nothing new")
		eq(#ns.db.history, before)
	end)

	it("a child failing inside a preset batch is reported for both settings", function()
		MOCK.reject.graphicsshadowquality = true
		Changes:Stage(def("graphics.qualityPreset"), 0)
		Changes:Stage(def("graphics.shadowQuality"), 5)
		local report = Changes:ApplyAll()
		eq(result(report, "graphics.qualityPreset").status, "partial")
		eq(result(report, "graphics.shadowQuality").status, "rejected")
		eq(raw("graphicsQuality"), "5", "preset rolled back")
		eq(Changes:Count(), 2, "both kept pending")
	end)

	it("dependency warnings use the batch's effective values before any write", function()
		Changes:Stage(def("graphics.uiScale"), 0.8)
		Changes:Stage(def("graphics.useUiScale"), true)
		local report = Changes:ApplyAll()
		falsy(result(report, "graphics.uiScale").warnings, "Use UI Scale is staged in the same batch")
	end)
end)

describe("#5 finding 3: undo/redo integrity", function()
	it("restricted undo entries stay on the stack for retry", function()
		Changes:Stage(def("graphics.gamma"), 1.5)
		Changes:Stage(def("qol.autoStand"), false)
		Changes:ApplyAll()
		MOCK.combat = true
		local report = History:Undo()
		eq(raw("Gamma"), "1.000000", "gamma restored")
		eq(raw("autoStand"), "0", "secure value untouched in combat")
		eq(#report.retained, 1)
		truthy(History:CanUndo(), "retained entry can be retried")
		truthy(History:CanRedo(), "restored part can be redone")
		MOCK.combat = false
		History:Undo()
		eq(raw("autoStand"), "1")
	end)

	it("external changes made after an apply are not overwritten by undo", function()
		Changes:Stage(def("graphics.gamma"), 1.5)
		Changes:ApplyAll()
		MOCK.setCVarRaw("Gamma", "2")
		local report = History:Undo()
		eq(raw("Gamma"), "2", "external value kept")
		eq(report.counts.conflict, 1)
	end)

	it("undo keeps the player's pending edits", function()
		Changes:Stage(def("graphics.gamma"), 1.5)
		Changes:ApplyAll()
		Changes:Stage(def("graphics.gamma"), 2.2)
		local report = History:Undo()
		near(Changes.pending["graphics.gamma"], 2.2, "pending edit preserved")
		truthy(report.results[1].pendingKept)
		eq(raw("Gamma"), "1.000000")
	end)

	it("redo after undo reapplies the exact values", function()
		Changes:Stage(def("camera.mouseLookSpeed"), 200)
		Changes:ApplyAll()
		History:Undo()
		eq(raw("cameraPitchMoveSpeed"), "90.000000")
		History:Redo()
		eq(raw("cameraYawMoveSpeed"), "200")
		eq(raw("cameraPitchMoveSpeed"), "100")
	end)
end)

describe("#5 finding 4: character scope", function()
	it("each character keeps its own originals for character-scoped settings", function()
		Changes:Stage(def("questing.showQuestLevel"), true)
		Changes:ApplyAll()
		eq(Backup:GetOriginal(def("questing.showQuestLevel")), false)
		MOCK.charName = "Alt"
		MOCK.cvars.showquestlevel = "1" -- the alt's own value
		ns.Sync:Prime()
		Changes:Stage(def("questing.showQuestLevel"), false)
		Changes:ApplyAll()
		eq(Backup:GetOriginal(def("questing.showQuestLevel")), true, "Alt's original")
		MOCK.charName = nil
		eq(Backup:GetOriginal(def("questing.showQuestLevel")), false, "Tester's original unchanged")
	end)

	it("a backup never restores another character's character-scoped values", function()
		MOCK.cvars.showquestlevel = "1"
		local b = Backup:Create("main", "test")
		eq(b.values["questing.showQuestLevel"].owner, "Tester-TestRealm")
		eq(b.values["questing.showQuestLevel"].scope, "character")
		truthy(b.values["questing.showQuestLevel"].build)
		eq(b.values["questing.showQuestLevel"].provider, "cvar")
		MOCK.charName = "Alt"
		MOCK.cvars.showquestlevel = "0"
		MOCK.cvars.autolootdefault = "1"
		local n, rep = Backup:StageRestore(b)
		eq(Changes.pending["questing.showQuestLevel"], nil, "not restored on Alt")
		eq(Changes.pending["qol.autoLoot"], false, "account setting restorable")
		local skipped = false
		for _, s in ipairs(rep.skipped) do
			if s.id == "questing.showQuestLevel" then skipped = s.reason:find("Tester") ~= nil end
		end
		truthy(skipped, "skip reason names the owner")
	end)

	it("legacy unscoped originals migrate without guessing a character", function()
		ns.db.originals = {
			["graphics.gamma"] = { value = 1.2, time = 1 },
			["questing.showQuestLevel"] = { value = true, time = 1 },
		}
		Backup:Migrate()
		near(ns.db.originalsScoped.machine["graphics.gamma"].value, 1.2)
		truthy(ns.db.originalsLegacy["questing.showQuestLevel"], "character original kept aside")
		eq(Backup:GetOriginal(def("questing.showQuestLevel")), nil, "not restorable automatically")
		eq(next(ns.db.originals), nil)
	end)
end)

describe("#5 finding 5: staging reconciliation", function()
	it("category reset clears a pending non-default edit when the live value is already default", function()
		Changes:Stage(def("qol.autoLoot"), true) -- default false, live false
		local n, rep = Changes:StageCategoryDefaults("qol")
		eq(Changes.pending["qol.autoLoot"], nil)
		truthy(rep.cleared >= 1)
	end)

	it("handles pending zero values", function()
		Changes:Stage(def("graphics.textureFiltering"), 0) -- default 5
		local _, rep = Changes:StageCategoryDefaults("graphics")
		eq(Changes.pending["graphics.textureFiltering"], nil, "pending 0 reconciled away")
		truthy(rep.cleared >= 1)
	end)

	it("reports replaced pending edits", function()
		MOCK.cvars.gamma = "2"
		Changes:Stage(def("graphics.gamma"), 1.5)
		local _, rep = Changes:StageCategoryDefaults("graphics")
		near(Changes.pending["graphics.gamma"], 1)
		truthy(rep.replaced >= 1)
	end)

	it("staging a target equal to the live value is a no-op", function()
		eq((Changes:StageTarget(def("graphics.gamma"), 1)), "unchanged")
		eq(Changes:Count(), 0)
	end)
end)

describe("#5 finding 6: apply cleanup", function()
	it("a throwing setter fails only its own item and the sync guard is released", function()
		local P = Providers.types.cvar
		local orig = P.Set
		P.Set = function(self, d, v)
			if d.id == "graphics.gamma" then error("setter exploded") end
			return orig(self, d, v)
		end
		Changes:Stage(def("graphics.gamma"), 1.5)
		Changes:Stage(def("qol.autoLoot"), true)
		local ok, report = pcall(Changes.ApplyAll, Changes)
		P.Set = orig
		truthy(ok, "apply did not raise")
		eq(result(report, "graphics.gamma").status, "failed")
		truthy(result(report, "graphics.gamma").message:find("exploded"))
		eq(result(report, "qol.autoLoot").status, "success", "other items still applied")
		eq(ns.Sync.applying, 0)
		near(Changes.pending["graphics.gamma"], 1.5, "failed request kept for retry")
	end)

	it("a throwing callback does not break the apply", function()
		ns.Callbacks:Register("ValueChanged", "bad", function() error("callback broke") end)
		Changes:Stage(def("graphics.gamma"), 1.5)
		local ok, report = pcall(Changes.ApplyAll, Changes)
		ns.Callbacks:Unregister("ValueChanged", "bad")
		truthy(ok)
		eq(report.counts.success, 1)
		eq(ns.Sync.applying, 0)
	end)

	it("rejected requests stay pending; successful ones leave", function()
		MOCK.reject.gamma = true
		Changes:Stage(def("graphics.gamma"), 1.5)
		Changes:Stage(def("qol.autoLoot"), true)
		Changes:ApplyAll()
		near(Changes.pending["graphics.gamma"], 1.5)
		eq(Changes.pending["qol.autoLoot"], nil)
	end)

	it("no history or undo entry is recorded when nothing changed", function()
		local report = Changes:ApplyList({ { def = def("graphics.gamma"), value = 1 } }, "apply")
		eq(report.counts.success, 1)
		eq(#ns.db.history, 0)
		falsy(History:CanUndo())
	end)
end)

describe("#5 suggestions: import hardening", function()
	local S = ns.Serializer
	local function wrap(payload) return S.PREFIX .. payload .. ";#" .. S.Checksum(payload) end

	it("rejects oversize input before processing", function()
		local bad, err = S.Decode(string.rep(" ", S.MAX_INPUT + 1))
		eq(bad, nil); truthy(err:find("too long"))
	end)
	it("rejects too many entries", function()
		local parts = { "n=x", "t=0" }
		for i = 1, S.MAX_ENTRIES + 5 do parts[#parts + 1] = ("a.b%d=b1"):format(i) end
		local bad, err = S.Decode(wrap(table.concat(parts, ";")))
		eq(bad, nil); truthy(err:find("too many"))
	end)
	it("rejects duplicate keys and duplicate metadata", function()
		local bad, err = S.Decode(wrap("n=x;t=0;graphics.gamma=n1;graphics.gamma=n2"))
		eq(bad, nil); truthy(err:find("duplicate"))
		bad, err = S.Decode(wrap("n=x;n=y;t=0"))
		eq(bad, nil); truthy(err:find("duplicate"))
	end)
	it("rejects malformed percent escapes", function()
		local bad, err = S.Decode(wrap("n=bad%zzname;t=0"))
		eq(bad, nil)
		local p = S.Decode(wrap("n=x;t=0;interface.whisperMode=sin%2line%g"))
		contains(p.malformed, "interface.whisperMode")
	end)
	it("rejects invalid checksum lengths", function()
		local payload = "n=x;t=0"
		local bad, err = S.Decode(S.PREFIX .. payload .. ";#" .. S.Checksum(payload):sub(2))
		eq(bad, nil); truthy(err:find("checksum"))
	end)
	it("rejects non-finite numbers", function()
		local p = S.Decode(wrap("n=x;t=0;graphics.gamma=n1e999;graphics.brightness=nnan"))
		contains(p.malformed, "graphics.gamma")
		contains(p.malformed, "graphics.brightness")
		local bad = S.Decode(wrap("n=x;t=1e999"))
		eq(bad, nil)
	end)
end)
