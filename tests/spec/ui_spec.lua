local _, ns = ...
local W = ns.Window

local function findRow(id)
	local page = W.pages.settings
	for index, item in ipairs(page.list.items) do
		if item.def and item.def.id == id then
			page.list:ScrollToIndex(index)
			for _, frame in pairs(page.list.active) do
				if frame.def and frame.def.id == id then return frame end
			end
		end
	end
	error("row not visible: " .. id)
end

local function open()
	if not (W.frame and W.frame:IsShown()) then SlashCmdList.EVERSETTINGS("") end
	MOCK.RunTimers()
	return W.frame
end

describe("main window", function()
	it("opens with /es and closes again", function()
		local f = open()
		truthy(f:IsShown())
		SlashCmdList.EVERSETTINGS("")
		falsy(f:IsShown())
		open()
		truthy(f:IsShown())
		contains(UISpecialFrames, "EverSettingsMainFrame", "Escape closes the window")
	end)

	it("navigates every sidebar entry without errors", function()
		open()
		for _, item in ipairs(W:BuildNavItems()) do
			if item.key then
				W:Navigate(item.key)
				MOCK.RunTimers()
				eq(W.currentKey, item.key)
			end
		end
		eq(writes(), 0, "browsing never writes")
	end)

	it("shows an empty-state notice for categories without researched settings", function()
		open()
		W:Navigate("category:network")
		local items = W.pages.settings.list.items
		eq(#items, 1)
		eq(items[1].type, "notice")
	end)

	it("searches across names, technical names and keywords", function()
		open()
		W:OnSearch("anisotropic")
		eq(W.currentKey, "search")
		local found = false
		for _, item in ipairs(W.pages.settings.list.items) do
			if item.def and item.def.id == "graphics.textureFiltering" then found = true end
		end
		truthy(found)
		W:OnSearch("cameraDistanceMaxZoomFactor")
		truthy(W.pages.settings.currentDefs[1].id == "camera.maxZoom")
		W:OnSearch("")
		falsy(W.currentKey == "search")
	end)

	it("remembers position and size", function()
		local f = open()
		f:SetSize(1000, 600)
		W:SavePosition()
		eq(ns.db.window.width, 1000)
		eq(ns.db.window.height, 600)
		W:ResetPosition()
		eq(ns.db.window.width, 1060)
	end)

	it("toggles the inspector and shows setting details", function()
		open()
		W:Navigate("category:graphics")
		W:InspectSetting(def("graphics.gamma"))
		truthy(W.frame.inspector:IsShown())
		W:SetInspectorShown(false)
		falsy(W.frame.inspector:IsShown())
		W:InspectCVar("farclip")
		truthy(W.frame.inspector:IsShown(), "inspecting re-opens the inspector")
		W:RevealSetting("camera.shake")
		eq(W.currentKey, "category:camera")
		eq(W.pages.settings.selectedId, "camera.shake")
	end)
end)

describe("numeric slider + edit box", function()
	it("stages an exact typed value on Enter", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local control = row.controls.slider
		truthy(control:IsShown())
		local edit = control.edit
		edit:SetFocus()
		edit:SetText("1.23")
		MOCK.Script(edit, "OnEnterPressed")
		near(ns.Changes.pending["graphics.gamma"], 1.23)
		near(control.slider:GetValue(), 1.23, "slider follows the typed value")
		eq(writes(), 0)
	end)

	it("flags invalid input and does not stage it", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local edit = row.controls.slider.edit
		edit:SetFocus()
		edit:SetText("9")
		MOCK.Script(edit, "OnEnterPressed")
		truthy(edit.hasError, "error state")
		truthy(edit:HasFocus(), "keeps focus for correction")
		eq(ns.Changes:Count(), 0)
		truthy(W.pages.settings.errors["graphics.gamma"])
		MOCK.Script(edit, "OnEscapePressed")
		falsy(edit.hasError)
		eq(edit:GetText(), "1", "escape restores the shown value")
	end)

	it("dragging the slider stages on-step values", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local slider = row.controls.slider.slider
		MOCK.Script(slider, "OnValueChanged", 1.6400001, true)
		near(ns.Changes.pending["graphics.gamma"], 1.6)
		eq(row.controls.slider.edit:GetText(), "1.6")
	end)

	it("a held drag is not interrupted by refreshes and stages once on release", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local control = row.controls.slider
		local slider = control.slider
		MOCK.Script(slider, "OnMouseDown", "LeftButton")
		MOCK.Script(slider, "OnValueChanged", 1.3, true)
		slider.__value = 1.3
		eq(ns.Changes:Count(), 0, "nothing staged mid-drag")
		eq(control.edit:GetText(), "1.3", "edit box follows the drag live")
		-- A refresh mid-drag (poll, external change) must not reset the range or move the thumb.
		local setMinMaxCalls = 0
		local orig = slider.SetMinMaxValues
		rawset(slider, "SetMinMaxValues", function(...) setMinMaxCalls = setMinMaxCalls + 1; return orig(...) end)
		W.pages.settings:RefreshRows()
		eq(setMinMaxCalls, 0, "range not re-applied during drag")
		eq(slider:GetValue(), 1.3, "thumb stays under the cursor")
		MOCK.Script(slider, "OnValueChanged", 1.8, true)
		MOCK.Script(slider, "OnMouseUp", "LeftButton")
		rawset(slider, "SetMinMaxValues", nil)
		eq(ns.Changes:Count(), 1)
		near(ns.Changes.pending["graphics.gamma"], 1.8)
	end)

	it("percent settings show and accept percentages", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.uiScale")
		eq(row.controls.slider.edit:GetText(), "100")
		local edit = row.controls.slider.edit
		edit:SetFocus(); edit:SetText("85"); MOCK.Script(edit, "OnEnterPressed")
		near(ns.Changes.pending["graphics.uiScale"], 0.85)
	end)
end)

describe("toggle, dropdown and reset", function()
	it("toggle stages the opposite value", function()
		open()
		W:Navigate("category:qol")
		local row = findRow("qol.autoLoot")
		MOCK.Click(row.controls.toggle)
		eq(ns.Changes.pending["qol.autoLoot"], true)
	end)

	it("dropdown shows labels and stages the selected value", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.textureFiltering")
		local dd = row.controls.dropdown
		eq(dd.text:GetText(), "16x Anisotropic")
		dd.onSelect(2)
		eq(ns.Changes.pending["graphics.textureFiltering"], 2)
	end)

	it("reset stages the factory default", function()
		MOCK.cvars.gamma = "2"
		ns.Sync:Prime()
		open()
		W:Navigate("category:graphics")
		MOCK.RunTimers()
		local row = findRow("graphics.gamma")
		truthy(row.reset:IsEnabled())
		MOCK.Click(row.reset)
		near(ns.Changes.pending["graphics.gamma"], 1)
	end)

	it("restricted settings are disabled with an explanation", function()
		MOCK.combat = true
		open()
		W:Navigate("category:qol")
		local row = findRow("qol.autoStand")
		falsy(row.controls.toggle:IsEnabled())
		truthy(row.desc:GetText():find("combat"))
		MOCK.combat = false
	end)

	it("footer apply runs the pipeline", function()
		open()
		ns.Changes:Stage(def("qol.autoLoot"), true)
		MOCK.RunTimers()
		truthy(W.frame.apply:IsEnabled())
		MOCK.Click(W.frame.apply)
		eq(raw("autoLootDefault"), "1")
		truthy(W.frame.statusText:GetText():find("1 applied"))
	end)
end)

describe("other pages", function()
	it("CVar browser filters a large list quickly", function()
		open()
		W:Navigate("browser")
		local page = W.pages.browser
		truthy(#page.list.items >= ns.CVarCatalog.meta.numCVars)
		local t = os.clock()
		page.filterDropdown.onSelect("unclassified")
		page.query = "camera"; page:Rebuild()
		local elapsed = os.clock() - t
		truthy(#page.list.items > 0 and #page.list.items < ns.CVarCatalog.meta.numCVars, "filtered count " .. #page.list.items)
		for _, item in ipairs(page.list.items) do
			falsy(ns.Registry:IsCVarClassified(item.name), "unclassified filter excludes " .. item.name)
		end
		truthy(elapsed < 0.5, "filtering took " .. elapsed)
		local frames = 0
		for _ in pairs(page.list.active) do frames = frames + 1 end
		truthy(frames < 40, "list is virtualized (" .. frames .. " row frames)")
	end)

	it("profiles page saves and stages a profile", function()
		open()
		W:Navigate("profiles")
		local p = assert(ns.Profiles:SaveAs("UI Test"))
		p.values["graphics.gamma"] = 2
		local page = W.pages.profiles
		page:Rebuild()
		page:SelectItem({ kind = "profile", name = "UI Test", key = "p:UI Test" })
		truthy(page.detail.stage:IsEnabled())
		MOCK.Click(page.detail.stage)
		near(ns.Changes.pending["graphics.gamma"], 2)
		eq(writes(), 0)
	end)

	it("diagnostics page renders the report", function()
		open()
		W:Navigate("diagnostics")
		truthy(#W.pages.diagnostics.report > 200)
	end)
end)
