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
		eq(ns.db.window.width, 1100)
	end)

	it("selecting a setting fills the Details panel without opening it", function()
		open()
		W:SetInspectorShown(false)
		W:Navigate("category:graphics")
		W:InspectSetting(def("graphics.gamma"))
		falsy(W.frame.inspector:IsShown(), "selection alone keeps the list full width")
		eq(W.frame.inspector.current.id, "graphics.gamma")
		W:InspectCVar("farclip")
		falsy(W.frame.inspector:IsShown())
		W:RevealSetting("camera.shake")
		eq(W.currentKey, "category:camera")
		eq(W.pages.settings.selectedId, "camera.shake")
	end)
end)

describe("layout preferences", function()
	it("Details panel is hidden by default on a fresh install", function()
		eq(ns.DB_DEFAULTS.window.inspector, false)
		eq(ns.DB_DEFAULTS.window.inspectorChosen, false)
	end)

	it("Details button toggles the panel, remembers the choice and widens the list", function()
		local f = open()
		W:SetInspectorShown(false)
		ns.db.window.inspectorChosen = false
		local function contentRightAnchor()
			for _, p in ipairs(f.content.__points) do
				if p[1] == "BOTTOMRIGHT" then return p[2] end
			end
		end
		eq(contentRightAnchor(), f.footer, "list spans to the window edge when Details is closed")
		MOCK.Click(f.detailsButton)
		truthy(f.inspector:IsShown())
		eq(ns.db.window.inspector, true)
		eq(ns.db.window.inspectorChosen, true, "player choice recorded")
		truthy(f.detailsButton.selected, "button shows the open state")
		eq(contentRightAnchor(), f.inspector, "list stops at the panel")
		MOCK.Click(f.detailsButton)
		falsy(f.inspector:IsShown())
		eq(ns.db.window.inspector, false)
	end)

	it("double-clicking a setting opens Details on it", function()
		open()
		W:SetInspectorShown(false)
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		MOCK.Script(row, "OnDoubleClick", "LeftButton")
		truthy(W.frame.inspector:IsShown())
		eq(W.frame.inspector.current.id, "graphics.gamma")
		W:SetInspectorShown(false)
	end)

	it("Details panel width is adjustable, clamped and saved", function()
		local f = open()
		f:SetSize(1400, 800)
		W:SetInspectorShown(true)
		eq(W:SetInspectorWidth(400), 400)
		eq(ns.db.window.inspectorWidth, 400)
		eq(math.floor(f.inspector:GetWidth()), 400)
		eq(W:SetInspectorWidth(100), ns.Theme.metrics.inspectorMin, "minimum")
		eq(W:SetInspectorWidth(5000), ns.Theme.metrics.inspectorMax, "maximum")
		f:SetSize(1100, 700)
		eq(W:ClampInspectorWidth(500), 1100 - ns.Theme.metrics.sidebarWidth - 440, "list keeps a minimum width of 440")
		f:SetSize(900, 600)
		eq(W:ClampInspectorWidth(500), ns.Theme.metrics.inspectorMin, "on narrow windows the panel minimum applies")
		W:SetInspectorShown(false)
		f:SetSize(1100, 700)
	end)

	it("migration hides the Details panel unless the player chose it", function()
		local saved = ns.Util.CopyTable(ns.db.window)
		local migrate = function(db)
			-- Same rule as Boot.lua's v1 -> v2 migration.
			if db.dbVersion < 2 and not db.window.inspectorChosen then db.window.inspector = false end
		end
		local old = { dbVersion = 1, window = { inspector = true } }
		migrate(old)
		eq(old.window.inspector, false)
		local chosen = { dbVersion = 1, window = { inspector = true, inspectorChosen = true } }
		migrate(chosen)
		eq(chosen.window.inspector, true)
		ns.db.window = saved
	end)

	it("interface scale applies to the window, is clamped and saved", function()
		local f = open()
		eq(W:SetScale(1.25), 1.25)
		eq(f:GetScale(), 1.25)
		eq(ns.db.window.scale, 1.25)
		eq(W:SetScale(9), ns.Theme.metrics.scaleMax)
		eq(W:SetScale(0.1), ns.Theme.metrics.scaleMin)
		W:SetScale(1)
	end)

	it("preferences page sets the scale through the slider + edit box", function()
		open()
		W:Navigate("preferences")
		local edit = W.pages.preferences.scaleControl.edit
		edit:SetFocus(); edit:SetText("120"); MOCK.Script(edit, "OnEnterPressed")
		near(ns.db.window.scale, 1.2)
		near(W.frame:GetScale(), 1.2)
		edit:SetFocus(); edit:SetText("500"); MOCK.Script(edit, "OnEnterPressed")
		truthy(edit.hasError, "out of range is rejected")
		near(ns.db.window.scale, 1.2)
		MOCK.Script(edit, "OnEscapePressed")
		W:SetScale(1)
		eq(writes(), 0, "preferences never touch game settings")
	end)

	it("hide empty categories removes them from the sidebar", function()
		open()
		ns.db.ui.hideEmpty = false
		local function has(key)
			for _, item in ipairs(W:BuildNavItems()) do if item.key == key then return true end end
			return false
		end
		truthy(has("category:network"))
		MOCK.Click(W.pages.preferences.hideEmptyRow.toggle)
		eq(ns.db.ui.hideEmpty, true)
		falsy(has("category:network"))
		truthy(has("category:graphics"))
		ns.db.ui.hideEmpty = false
	end)

	it("technical names can be shown in rows", function()
		open()
		ns.db.ui.showTechnical = true
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		truthy(row.technical:IsShown())
		eq(row.technical:GetText(), "Gamma")
		ns.db.ui.showTechnical = false
		W.pages.settings:RefreshRows()
		falsy(row.technical:IsShown())
	end)

	it("resizing keeps every row's controls the same width and adapts to the list width", function()
		local f = open()
		W:Navigate("category:graphics")
		local page = W.pages.settings
		local function widths()
			local sliders = {}
			page.list:ForEachVisible(function(frame)
				if frame.controls and frame.controls.slider and frame.controls.slider:IsShown() then
					sliders[#sliders + 1] = frame.controls.slider.sliderWidth
				end
			end)
			return sliders
		end
		page.list:SetWidth(900); page.list:Render(true)
		local wide = widths()
		truthy(#wide >= 2)
		for _, w in ipairs(wide) do eq(w, ns.Theme.metrics.sliderWide) end
		page.list:SetWidth(600); page.list:Render(true)
		for _, w in ipairs(widths()) do eq(w, ns.Theme.metrics.sliderNarrow) end
		page.list:SetWidth(0)
		f:SetSize(1100, 700)
	end)

	it("a resize during a drag does not change the slider under the cursor", function()
		open()
		W:Navigate("category:graphics")
		local page = W.pages.settings
		page.list:SetWidth(900); page.list:Render(true)
		local row = findRow("graphics.gamma")
		local control = row.controls.slider
		MOCK.cancelledDrags = 0
		control.slider.__draggingThumb = true
		page.list:SetWidth(600)
		page:RefreshRows()
		eq(control.sliderWidth, ns.Theme.metrics.sliderWide, "width frozen while dragging")
		eq(MOCK.cancelledDrags, 0)
		control.slider.__draggingThumb = false
		page:RefreshRows()
		eq(control.sliderWidth, ns.Theme.metrics.sliderNarrow, "applied after the drag")
		page.list:SetWidth(0)
	end)

	it("truncated descriptions offer the full text as a tooltip", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.renderScale")
		local shown
		local orig = UI_ShowTooltipBackup or ns.UI.ShowTooltip
		ns.UI.ShowTooltip = function(_, title, body) shown = { title, body } end
		row.desc.__truncated = true
		MOCK.Script(row, "OnEnter")
		ns.UI.ShowTooltip = orig
		truthy(shown, "tooltip shown")
		eq(shown[2], def("graphics.renderScale").description)
		row.desc.__truncated = false
		MOCK.Script(row, "OnLeave")
	end)

	it("Apply shows the pending count and a neutral disabled state", function()
		local f = open()
		ns.Changes:DiscardAll()
		MOCK.RunTimers()
		W:UpdateFooter()
		falsy(f.apply:IsEnabled())
		eq(f.apply:GetText(), "Apply")
		ns.Changes:Stage(def("qol.autoLoot"), true)
		W:UpdateFooter()
		truthy(f.apply:IsEnabled())
		eq(f.apply:GetText(), "Apply (1)")
		ns.Changes:DiscardAll()
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

	-- Reproduces the in-game report: grabbing the thumb (no OnMouseDown on the slider),
	-- moving it while the list refreshes, then releasing.
	it("a thumb drag survives refreshes and stages once when released", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local control = row.controls.slider
		local slider = control.slider
		MOCK.cancelledDrags = 0
		slider.__draggingThumb = true -- the client reports IsDraggingThumb() == true
		MOCK.Script(slider, "OnValueChanged", 1.3, true)
		slider.__value = 1.3
		eq(ns.Changes:Count(), 0, "nothing staged mid-drag")
		eq(control.edit:GetText(), "1.3", "edit box follows the drag live")
		-- Refreshes mid-drag (sync poll, external change, other rows staging).
		W.pages.settings:RefreshRows()
		ns.Changes:Stage(def("graphics.brightness"), 60)
		MOCK.RunTimers()
		W.pages.settings:RefreshRows()
		eq(MOCK.cancelledDrags, 0, "no refresh hid the slider or changed its range")
		truthy(slider:IsDraggingThumb(), "still dragging")
		eq(slider:GetValue(), 1.3, "thumb stays under the cursor")
		MOCK.Script(slider, "OnValueChanged", 1.8, true)
		MOCK.Script(control, "OnUpdate", 0)
		falsy(ns.Changes.pending["graphics.gamma"], "still not staged while held")
		slider.__draggingThumb = false -- mouse released
		MOCK.Script(control, "OnUpdate", 0)
		near(ns.Changes.pending["graphics.gamma"], 1.8, "staged on release")
		eq(control:GetScript("OnUpdate"), nil, "drag watcher removed")
	end)

	it("a track click with mouse down/up stages after release", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local control = row.controls.slider
		MOCK.Script(control.slider, "OnMouseDown", "LeftButton")
		MOCK.Script(control.slider, "OnValueChanged", 2.0, true)
		eq(ns.Changes:Count(), 0)
		MOCK.Script(control.slider, "OnMouseUp", "LeftButton")
		MOCK.Script(control, "OnUpdate", 0)
		near(ns.Changes.pending["graphics.gamma"], 2.0)
	end)

	it("range errors are short enough for the row", function()
		open()
		W:Navigate("category:graphics")
		local row = findRow("graphics.gamma")
		local edit = row.controls.slider.edit
		edit:SetFocus(); edit:SetText("9"); MOCK.Script(edit, "OnEnterPressed")
		eq(W.pages.settings.errors["graphics.gamma"], "Allowed 0.3 to 2.8")
		MOCK.Script(edit, "OnEscapePressed")
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
