-- Diagnostics page: copyable report of API capabilities, coverage, discovery, validation
-- and recent history.
local _, ns = ...
local M = ns.Theme.metrics

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util

function UI.CreateDiagnosticsPage(parent, window)
	local page = CreateFrame("Frame", nil, parent)
	page.window = window

	page.title = UI.Text(page, "pageTitle", "text")
	page.title:SetPoint("TOPLEFT", Theme.metrics.padding, -16)
	page.title:SetText(L.DIAGNOSTICS)
	page.desc = UI.Text(page, "pageDesc", "textMuted")
	page.desc:SetPoint("TOPLEFT", M.padding, -44)
	page.desc:SetPoint("TOPRIGHT", -M.padding, -44)
	page.desc:SetText("Copy this report into a GitHub issue when reporting problems. Everything here is read-only.")

	page.refresh = UI.CreateButton(page, "Refresh", "secondary", 90, 26)
	page.refresh:SetPoint("TOPRIGHT", -Theme.metrics.padding, -14)
	page.discover = UI.CreateButton(page, "Run discovery", "secondary", 120, 26)
	page.discover:SetPoint("RIGHT", page.refresh, "LEFT", -8, 0)
	page.selectAll = UI.CreateButton(page, "Select all", "ghost", 90, 26)
	page.selectAll:SetPoint("RIGHT", page.discover, "LEFT", -8, 0)

	local scroll = CreateFrame("ScrollFrame", nil, page)
	scroll:SetPoint("TOPLEFT", Theme.metrics.padding, -64)
	scroll:SetPoint("BOTTOMRIGHT", -Theme.metrics.padding, Theme.metrics.padding)
	UI.Background(scroll, "input")
	UI.Border(scroll, "border")
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(Theme:Font(11, "text"))
	edit:SetTextInsets(10, 10, 10, 10)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	-- Keep the report read-only: restore it if the player types into it.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and page.report then self:SetText(page.report) end
	end)
	scroll:SetScrollChild(edit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 40)))
	end)
	scroll:SetScript("OnSizeChanged", function(self, w) edit:SetWidth(math.max(100, w)) end)
	page.edit = edit

	function page:Open()
		local lines = { ns.Diagnostics:BuildReport(), "", "Recent history (newest first):" }
		for _, r in ipairs(ns.History:GetRecent(40)) do
			local def = ns.Registry:Get(r.id)
			local fmt = function(v) return def and ns.Values.Format(def, v) or tostring(v) end
			lines[#lines + 1] = ("  %s  %-8s %-10s %s: %s -> %s"):format(Util.FormatTime(r.time), tostring(r.source), tostring(r.result),
				def and def.name or r.id, fmt(r.old), fmt(r.new))
		end
		self.report = table.concat(lines, "\n")
		edit:SetText(self.report)
		edit:SetCursorPosition(0)
		scroll:SetVerticalScroll(0)
	end

	page.refresh:SetScript("OnClick", function() page:Open() end)
	page.discover:SetScript("OnClick", function()
		ns.Discovery:Run()
		page:Open()
		window:SetStatus("Discovery finished (read-only).", "accent")
	end)
	page.selectAll:SetScript("OnClick", function()
		edit:SetFocus()
		edit:HighlightText()
	end)
	return page
end
