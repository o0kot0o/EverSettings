-- EverSettings' own preferences. These affect only this addon's window, so they apply
-- immediately (no staging) and are stored in EverSettingsDB.
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local M = Theme.metrics

-- Pseudo-definition so the interface scale uses the standard slider + edit box control.
local SCALE_DEF = {
	id = "eversettings.scale", name = "Interface scale", valueType = "number", control = "slider",
	min = M.scaleMin, max = M.scaleMax, step = M.scaleStep, displayScale = 100, suffix = "%", decimals = 0,
	rangeSource = "EverSettings preference",
}

local function CreatePrefRow(parent, y, name, description)
	local r = CreateFrame("Frame", nil, parent)
	r:SetPoint("TOPLEFT", 0, y)
	r:SetPoint("TOPRIGHT", 0, y)
	r:SetHeight(M.rowHeight)
	r.name = UI.Text(r, "settingName", "text")
	r.name:SetPoint("TOPLEFT", M.padding, -12)
	r.name:SetText(name)
	r.desc = UI.Text(r, "settingDesc", "textMuted")
	r.desc:SetPoint("TOPLEFT", M.padding, -31)
	r.desc:SetPoint("TOPRIGHT", r, "TOPRIGHT", -(Theme.ControlWidth(0) + 60), -31)
	r.desc:SetWordWrap(true)
	r.desc:SetMaxLines(2)
	r.desc:SetText(description)
	r.control = CreateFrame("Frame", nil, r)
	r.control:SetSize(Theme.ControlWidth(0), 28)
	r.control:SetPoint("RIGHT", -44, 0)
	local line = UI.Line(r, "border", true)
	line:SetPoint("BOTTOMLEFT", 16, 0)
	line:SetPoint("BOTTOMRIGHT", -16, 0)
	return r
end

function UI.CreatePreferencesPage(parent, window)
	local page = CreateFrame("Frame", nil, parent)
	page.window = window

	page.title = UI.Text(page, "pageTitle", "text")
	page.title:SetPoint("TOPLEFT", M.padding, -16)
	page.title:SetText(L.PREFERENCES)
	page.desc = UI.Text(page, "pageDesc", "textMuted")
	page.desc:SetPoint("TOPLEFT", M.padding, -44)
	page.desc:SetText("How the EverSettings window looks and behaves. These do not change any game setting and apply immediately.")

	local y = -76
	-- Interface scale
	local scaleRow = CreatePrefRow(page, y, "Interface scale",
		"Size of the EverSettings window, independent of the game's UI scale. Increase it if text is hard to read.")
	local scale = UI.CreateNumericControl(scaleRow.control)
	scale:SetPoint("RIGHT")
	scale:SetUnit("%")
	scale:SetSliderWidth(M.sliderNarrow)
	scale:Setup(SCALE_DEF, M.scaleMin, M.scaleMax, M.scaleStep, function(value)
		window:SetScale(value)
		page.scaleRowError = nil
		scaleRow.desc:SetText("Size of the EverSettings window, independent of the game's UI scale. Increase it if text is hard to read.")
		UI.SetTextColor(scaleRow.desc, "textMuted")
	end, function(message)
		scaleRow.desc:SetText(message and UI.FormatError(message) or "Size of the EverSettings window, independent of the game's UI scale. Increase it if text is hard to read.")
		UI.SetTextColor(scaleRow.desc, message and "error" or "textMuted")
	end)
	page.scaleControl = scale
	y = y - M.rowHeight

	local function ToggleRow(name, description, get, set)
		local row = CreatePrefRow(page, y, name, description)
		local t = UI.CreateToggle(row.control)
		t:SetPoint("RIGHT", -(M.unitWidth + 4), 0)
		t.onToggle = function(value)
			set(value)
			t:SetChecked(get())
			ns.Callbacks:Fire("PreferencesChanged")
		end
		row.toggle, row.get = t, get
		y = y - M.rowHeight
		return row
	end

	page.detailsRow = ToggleRow("Show Details panel",
		"Keep the Details panel (full description, values, sources and verification) open beside the list. You can also use the Details button or double-click a setting.",
		function() return ns.db.window.inspector end,
		function(v) window:SetInspectorShown(v, true) end)
	page.technicalRow = ToggleRow("Show technical names",
		"Show the console variable name next to each setting. Useful when comparing with guides or the console.",
		function() return ns.db.ui.showTechnical end,
		function(v) ns.db.ui.showTechnical = v and true or false end)
	page.hideEmptyRow = ToggleRow("Hide empty categories",
		"Hide sidebar categories that have no researched settings yet.",
		function() return ns.db.ui.hideEmpty end,
		function(v) ns.db.ui.hideEmpty = v and true or false end)

	local resetRow = CreatePrefRow(page, y, "Reset window layout",
		"Restore the default window position, size, interface scale and Details panel width.")
	local reset = UI.CreateButton(resetRow.control, "Reset layout", "secondary", 120, 28)
	reset:SetPoint("RIGHT", -(M.unitWidth + 4), 0)
	reset:SetScript("OnClick", function()
		window:ResetPosition()
		window:SetScale(1)
		window:SetInspectorWidth(M.inspectorWidth)
		page:Open()
		window:SetStatus("Window layout reset.", "accent")
	end)
	page.resetButton = reset

	function page:Open()
		scale:SetValue(window:ClampScale(ns.db.window.scale))
		for _, row in ipairs({ self.detailsRow, self.technicalRow, self.hideEmptyRow }) do
			row.toggle:SetChecked(row.get())
		end
	end
	return page
end
