-- Main window: header (title, profile, search, help, close), sidebar navigation, page area,
-- collapsible inspector and footer (pending changes, discard, reset category, undo/redo, apply).
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local Changes, Registry = ns.Changes, ns.Registry
local M = Theme.metrics

local Window = {}
ns.Window = Window

local function CreateNavGroup(list)
	local f = CreateFrame("Frame", nil, list)
	f.label = UI.Text(f, 10, "textDim")
	f.label:SetPoint("BOTTOMLEFT", 16, 6)
	return f
end
local function UpdateNavGroup(f, item) f.label:SetText(item.label) end

local function CreateNavItem(list)
	local b = CreateFrame("Button", nil, list)
	b.hl = b:CreateTexture(nil, "BACKGROUND")
	b.hl:SetAllPoints()
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetPoint("TOPLEFT", 0, -4)
	b.bar:SetPoint("BOTTOMLEFT", 0, 4)
	b.bar:SetWidth(3)
	UI.SetColor(b.bar, Theme.colors.accent)
	b.label = UI.Text(b, 12, "text")
	b.label:SetPoint("LEFT", 16, 0)
	b.label:SetPoint("RIGHT", -40, 0)
	b.count = UI.Text(b, 10, "textDim", "RIGHT")
	b.count:SetPoint("RIGHT", -12, 0)
	b:SetScript("OnClick", function(self) Window:Navigate(self.key) end)
	b:SetScript("OnEnter", function(self) if not self.selected then UI.SetColor(self.hl, Theme.colors.rowHover); self.hl:Show() end end)
	b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
	return b
end

local function UpdateNavItem(b, item)
	b.key = item.key
	b.label:SetText(item.label)
	b.count:SetText(item.count and tostring(item.count) or "")
	b.selected = Window.currentKey == item.key
	b.bar:SetShown(b.selected)
	if b.selected then
		UI.SetColor(b.hl, Theme.colors.rowSelected)
		b.hl:Show()
	else
		b.hl:Hide()
	end
	UI.SetTextColor(b.label, b.selected and "text" or (item.dim and "textDim" or "textMuted"))
end

function Window:BuildNavItems()
	local items = { { type = "group", label = "LIBRARY" } }
	local favCount = Util.Count(ns.db.favorites)
	items[#items + 1] = { type = "item", key = "favorites", label = L.FAVORITES, count = favCount > 0 and favCount or nil }
	items[#items + 1] = { type = "item", key = "modified", label = L.MODIFIED }
	items[#items + 1] = { type = "item", key = "recent", label = L.RECENT }
	items[#items + 1] = { type = "item", key = "all", label = L.ALL_SETTINGS, count = #Registry.ordered }
	items[#items + 1] = { type = "group", label = "CATEGORIES" }
	for _, cat in ipairs(ns.Categories.list) do
		local n = Registry:CountCategory(cat.id)
		items[#items + 1] = { type = "item", key = "category:" .. cat.id, label = cat.name, count = n > 0 and n or nil, dim = n == 0 }
	end
	items[#items + 1] = { type = "group", label = "TOOLS" }
	items[#items + 1] = { type = "item", key = "browser", label = L.CVAR_BROWSER, count = ns.CVarCatalog and ns.CVarCatalog.meta.numCVars }
	items[#items + 1] = { type = "item", key = "profiles", label = L.PROFILES }
	items[#items + 1] = { type = "item", key = "diagnostics", label = L.DIAGNOSTICS }
	return items
end

function Window:Create()
	if self.frame then return self.frame end
	local db = ns.db.window
	local f = CreateFrame("Frame", "EverSettingsMainFrame", UIParent)
	self.frame = f
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	f:EnableMouse(true)
	if f.SetResizeBounds then
		f:SetResizeBounds(M.minWidth, M.minHeight)
	elseif f.SetMinResize then
		f:SetMinResize(M.minWidth, M.minHeight)
	end
	f:SetSize(math.max(M.minWidth, db.width or 1060), math.max(M.minHeight, db.height or 680))
	f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
	UI.Background(f, "window")
	UI.Border(f, "borderStrong", "OVERLAY")
	f:Hide()
	tinsert(UISpecialFrames, "EverSettingsMainFrame")

	-- Header --------------------------------------------------------------------
	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(M.headerHeight)
	UI.Background(header, "header")
	local hl = UI.Line(header, "border", true)
	hl:SetPoint("BOTTOMLEFT")
	hl:SetPoint("BOTTOMRIGHT")
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); Window:SavePosition() end)
	f.header = header

	local title = UI.Text(header, 15, "text")
	title:SetPoint("LEFT", 16, 0)
	title:SetText(L.ADDON_TITLE)
	local version = UI.Text(header, 10, "textDim")
	version:SetPoint("LEFT", title, "RIGHT", 8, -1)
	version:SetText(ns.version)

	local close = UI.CreateIconButton(header, "uitools-icon-close", 12, L.CLOSE)
	close:SetPoint("RIGHT", -8, 0)
	close:SetScript("OnClick", function() f:Hide() end)
	local inspectorToggle = UI.CreateIconButton(header, "uitools-icon-external-window", 13, L.INSPECTOR)
	inspectorToggle:SetPoint("RIGHT", close, "LEFT", -2, 0)
	inspectorToggle:SetScript("OnClick", function() Window:SetInspectorShown(not ns.db.window.inspector) end)
	f.inspectorToggle = inspectorToggle
	local help = UI.CreateIconButton(header, "uitools-icon-settings", 13, L.HELP)
	help:SetPoint("RIGHT", inspectorToggle, "LEFT", -2, 0)
	help:SetScript("OnClick", function() UI.Alert("EverSettings " .. ns.version, L.HELP_TEXT) end)

	local search = UI.CreateSearchBox(header, 240, L.SEARCH_PLACEHOLDER, function(text)
		Window:OnSearch(text)
	end)
	search:SetPoint("RIGHT", help, "LEFT", -10, 0)
	f.search = search

	local profileLabel = UI.Text(header, 11, "textDim", "RIGHT")
	local profileDropdown = UI.CreateDropdown(header, 170)
	profileDropdown:SetPoint("LEFT", version, "RIGHT", 90, 1)
	profileLabel:SetPoint("RIGHT", profileDropdown, "LEFT", -8, 0)
	profileLabel:SetText("Profile")
	profileDropdown.onSelect = function(value)
		if value == "__manage" then
			Window:Navigate("profiles")
		elseif value == "__none" then
			ns.Profiles:SetActive(nil)
		else
			ns.Profiles:SetActive(value)
			Window:Navigate("profiles")
			Window.pages.profiles:SelectItem({ kind = "profile", name = value, key = "p:" .. value })
		end
		Window:UpdateProfileDropdown()
	end
	f.profileDropdown = profileDropdown
	local manage = UI.CreateButton(header, L.PROFILES, "ghost", 70, 24)
	manage:SetPoint("LEFT", profileDropdown, "RIGHT", 6, 0)
	manage:SetScript("OnClick", function() Window:Navigate("profiles") end)

	-- Footer ----------------------------------------------------------------------
	local footer = CreateFrame("Frame", nil, f)
	footer:SetPoint("BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", -1, 1)
	footer:SetHeight(M.footerHeight)
	UI.Background(footer, "header")
	local fl = UI.Line(footer, "border", true)
	fl:SetPoint("TOPLEFT")
	fl:SetPoint("TOPRIGHT")
	f.footer = footer

	f.apply = UI.CreateButton(footer, L.APPLY, "primary", 100, 28)
	f.apply:SetPoint("RIGHT", -24, 0)
	f.resetCategory = UI.CreateButton(footer, L.RESET_CATEGORY, "secondary", 120, 28)
	f.resetCategory:SetPoint("RIGHT", f.apply, "LEFT", -8, 0)
	f.discard = UI.CreateButton(footer, L.DISCARD, "secondary", 90, 28)
	f.discard:SetPoint("RIGHT", f.resetCategory, "LEFT", -8, 0)
	f.redo = UI.CreateButton(footer, L.REDO, "ghost", 60, 28)
	f.redo:SetPoint("RIGHT", f.discard, "LEFT", -16, 0)
	f.undo = UI.CreateButton(footer, L.UNDO, "ghost", 60, 28)
	f.undo:SetPoint("RIGHT", f.redo, "LEFT", -4, 0)
	f.pendingText = UI.Text(footer, 12, "textMuted")
	f.pendingText:SetPoint("LEFT", 16, 0)
	f.statusText = UI.Text(footer, 11, "textMuted")
	f.statusText:SetPoint("LEFT", f.pendingText, "RIGHT", 16, 0)
	f.statusText:SetPoint("RIGHT", f.undo, "LEFT", -12, 0)

	f.apply:SetScript("OnClick", function() Window:Apply() end)
	f.discard:SetScript("OnClick", function()
		local n = Changes:Count()
		if n >= 5 then
			UI.Confirm("Discard changes", ("Discard %d pending changes?"):format(n), L.DISCARD, function() Changes:DiscardAll() end)
		else
			Changes:DiscardAll()
		end
	end)
	f.resetCategory:SetScript("OnClick", function()
		local catId = Window.currentKey and Window.currentKey:match("^category:(.+)$")
		if not catId then return end
		local cat = ns.Categories.byId[catId]
		UI.Confirm(L.RESET_CATEGORY, ("Stage factory defaults for every editable setting in %s? You can review the changes before applying them."):format(cat.name),
			"Stage defaults", function()
				local n = Changes:StageCategoryDefaults(catId)
				Window:SetStatus(("%d default value(s) staged."):format(n), "accent")
			end)
	end)
	f.undo:SetScript("OnClick", function()
		local report = ns.History:Undo()
		if report then Window:SetStatus("Undo: " .. Changes:FormatReport(report), "accent") end
	end)
	f.redo:SetScript("OnClick", function()
		local report = ns.History:Redo()
		if report then Window:SetStatus("Redo: " .. Changes:FormatReport(report), "accent") end
	end)

	-- Sidebar -----------------------------------------------------------------------
	local sidebar = CreateFrame("Frame", nil, f)
	sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	sidebar:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
	sidebar:SetWidth(M.sidebarWidth)
	UI.Background(sidebar, "sidebar")
	local sl = UI.Line(sidebar, "border", false)
	sl:SetPoint("TOPRIGHT")
	sl:SetPoint("BOTTOMRIGHT")
	local nav = UI.CreateScrollList(sidebar)
	nav:SetPoint("TOPLEFT", 0, -6)
	nav:SetPoint("BOTTOMRIGHT", -1, 6)
	nav:RegisterType("group", 28, CreateNavGroup, UpdateNavGroup)
	nav:RegisterType("item", 28, CreateNavItem, UpdateNavItem)
	f.nav = nav

	-- Inspector -----------------------------------------------------------------------
	local inspector = UI.CreateInspector(f, self)
	inspector:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	inspector:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
	inspector:SetWidth(M.inspectorWidth)
	f.inspector = inspector

	-- Content -------------------------------------------------------------------------
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
	content:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
	UI.Background(content, "content")
	f.content = content

	self.pages = {
		settings = UI.CreateSettingsPage(content, self),
		browser = UI.CreateCVarBrowserPage(content, self),
		profiles = UI.CreateProfilesPage(content, self),
		diagnostics = UI.CreateDiagnosticsPage(content, self),
	}
	for _, page in pairs(self.pages) do
		page:SetAllPoints(content)
		page:Hide()
	end

	-- Resize grip -----------------------------------------------------------------------
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(footer:GetFrameLevel() + 5)
	grip.icon = UI.Icon(grip, "uitools-icon-window-resize", 12, "textDim")
	grip.icon:SetPoint("CENTER")
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); Window:SavePosition() end)

	f:SetScript("OnShow", function() Window:OnShow() end)
	f:SetScript("OnHide", function() Window:OnHide() end)

	self:SetInspectorShown(ns.db.window.inspector ~= false, true)
	self:RegisterCallbacks()
	return f
end

function Window:SetInspectorShown(shown, silent)
	ns.db.window.inspector = shown and true or false
	local f = self.frame
	f.inspector:SetShown(shown)
	f.content:ClearAllPoints()
	f.content:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", M.sidebarWidth, 0)
	if shown then
		f.content:SetPoint("BOTTOMRIGHT", f.inspector, "BOTTOMLEFT", 0, 0)
	else
		f.content:SetPoint("BOTTOMRIGHT", f.footer, "TOPRIGHT", 0, 0)
	end
	f.inspectorToggle:SetIconColor(shown and "accent" or "textMuted")
end

function Window:SavePosition()
	local f = self.frame
	local point, _, _, x, y = f:GetPoint(1)
	local db = ns.db.window
	db.point, db.x, db.y = point, x, y
	db.width, db.height = f:GetWidth(), f:GetHeight()
end

function Window:ResetPosition()
	local db = ns.db.window
	db.point, db.x, db.y, db.width, db.height = "CENTER", 0, 0, 1060, 680
	if self.frame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER")
		self.frame:SetSize(1060, 680)
	end
end

function Window:Navigate(key)
	if not key then return end
	local f = self.frame
	if key ~= "search" and f.search:GetText() ~= "" and not self.searchNavigating then
		f.search:SetText("")
		f.search:ClearFocus()
	end
	self.currentKey = key
	if key ~= "search" then ns.db.ui.lastPage = key end
	for _, page in pairs(self.pages) do page:Hide() end
	UI.CloseDropdown()
	local catId = key:match("^category:(.+)$")
	if catId then
		self.pages.settings:Show()
		self.pages.settings:Open("category", catId)
	elseif key == "favorites" or key == "modified" or key == "recent" or key == "all" then
		self.pages.settings:Show()
		self.pages.settings:Open(key)
	elseif key == "search" then
		self.pages.settings:Show()
		self.pages.settings:Open("search", self.searchQuery)
	elseif self.pages[key] then
		self.pages[key]:Show()
		self.pages[key]:Open()
	end
	f.resetCategory:SetEnabled(catId ~= nil and catId ~= "advanced")
	f.nav:SetItems(self:BuildNavItems(), true)
end

function Window:OnSearch(text)
	text = Util.Trim(text)
	if text == "" then
		if self.currentKey == "search" then self:Navigate(self.preSearchKey or "all") end
		return
	end
	if self.currentKey ~= "search" then self.preSearchKey = self.currentKey end
	self.searchQuery = text
	self.searchNavigating = true
	self:Navigate("search")
	self.searchNavigating = false
end

function Window:InspectSetting(def)
	if def then self.frame.inspector:ShowSetting(def) end
	if def and not ns.db.window.inspector then self:SetInspectorShown(true) end
end

function Window:InspectCVar(name)
	self.frame.inspector:ShowCVar(name)
	if not ns.db.window.inspector then self:SetInspectorShown(true) end
end

-- Navigate to a setting's category, expand its section and select it.
function Window:RevealSetting(id)
	local def = Registry:Get(id)
	if not def then return end
	ns.db.ui.collapsed[def.category .. "." .. def.subcategory] = nil
	self:Navigate("category:" .. def.category)
	local page = self.pages.settings
	for index, item in ipairs(page.list.items) do
		if item.def and item.def.id == id then
			page.list:ScrollToIndex(index)
			break
		end
	end
	page:Select(id)
end

function Window:SetStatus(text, colorKey)
	local f = self.frame
	if not f then return end
	f.statusText:SetText(text or "")
	UI.SetTextColor(f.statusText, colorKey or "textMuted")
end

function Window:UpdateFooter()
	local f = self.frame
	local n = Changes:Count()
	if n > 0 then
		f.pendingText:SetText(L.PENDING_FMT:format(n))
		UI.SetTextColor(f.pendingText, "warning")
	else
		f.pendingText:SetText(L.PENDING_NONE)
		UI.SetTextColor(f.pendingText, "textMuted")
	end
	f.apply:SetEnabled(n > 0)
	f.discard:SetEnabled(n > 0)
	f.undo:SetEnabled(ns.History:CanUndo())
	f.redo:SetEnabled(ns.History:CanRedo())
end

function Window:UpdateProfileDropdown()
	local f = self.frame
	local options = { { value = "__none", label = L.NO_PROFILE } }
	for _, name in ipairs(ns.Profiles:List()) do options[#options + 1] = { value = name, label = name } end
	options[#options + 1] = { value = "__manage", label = "Manage profiles..." }
	f.profileDropdown:SetOptions(options)
	f.profileDropdown:SetValue(ns.Profiles:GetActive() or "__none")
end

function Window:Apply()
	local n = Changes:Count()
	if n == 0 then return end
	local needsRestart = false
	for id in pairs(Changes.pending) do
		local def = Registry:Get(id)
		if def and (def.apply == "restart" or def.apply == "reload") then needsRestart = true end
	end
	local function run()
		local report = Changes:ApplyAll()
		local text = Changes:FormatReport(report)
		local bad = report.counts.failed + report.counts.rejected + report.counts.clamped + report.counts.restricted
		self:SetStatus(text, bad > 0 and "warning" or "success")
		for _, r in ipairs(report.results) do
			if r.status ~= "success" then
				ns:Print("%s: %s%s", r.name, r.status, r.message and (" - " .. r.message) or "")
			end
			for _, w in ipairs(r.warnings or {}) do ns:Print("%s: note - %s", r.name, w) end
		end
	end
	if n >= 10 or needsRestart then
		local body = ("Apply %d change(s)?"):format(n)
		if needsRestart then body = body .. "\n\nSome of these only take effect after a /reload or a full game restart." end
		UI.Confirm("Apply changes", body, L.APPLY, run)
	else
		run()
	end
end

-- Coalesce bursts of callbacks into one refresh per frame.
function Window:QueueRefresh(rebuild)
	self.needRebuild = self.needRebuild or rebuild
	if self.refreshQueued then return end
	self.refreshQueued = true
	ns.Compat.After(0, function()
		self.refreshQueued = false
		local rebuildNow = self.needRebuild
		self.needRebuild = false
		if not (self.frame and self.frame:IsShown()) then return end
		local page = self.pages.settings
		if page:IsShown() then
			if rebuildNow then page:Rebuild(true) else page:RefreshRows() end
		end
		self.frame.inspector:Refresh()
		self:UpdateFooter()
	end)
end

function Window:RegisterCallbacks()
	local C = ns.Callbacks
	C:Register("ValueChanged", self, function() self:QueueRefresh(self.pages.settings.mode == "modified") end)
	C:Register("PendingChanged", self, function() self:QueueRefresh(self.pages.settings.mode == "modified") end)
	C:Register("FavoritesChanged", self, function()
		self:QueueRefresh(self.pages.settings.mode == "favorites")
		if self.frame:IsShown() then self.frame.nav:SetItems(self:BuildNavItems(), true) end
	end)
	C:Register("HistoryChanged", self, function() self:QueueRefresh(self.pages.settings.mode == "recent") end)
	C:Register("ProfilesChanged", self, function() if self.frame:IsShown() then self:UpdateProfileDropdown() end end)
	C:Register("ApplyFinished", self, function() self:QueueRefresh(false) end)
end

function Window:OnShow()
	self:UpdateProfileDropdown()
	self:UpdateFooter()
	self:Navigate(self.currentKey or ns.db.ui.lastPage or "category:graphics")
	-- Poll visible rows for changes that do not raise CVAR_UPDATE (read-only).
	if C_Timer and C_Timer.NewTicker then
		self.ticker = C_Timer.NewTicker(1.5, function()
			local page = self.pages.settings
			if page:IsShown() then ns.Sync:Poll(page:GetVisibleDefs()) end
		end)
	end
end

function Window:OnHide()
	if self.ticker then self.ticker:Cancel(); self.ticker = nil end
	UI.CloseDropdown()
	local n = Changes:Count()
	if n > 0 then
		ns:Print("%d pending change(s) were not applied. Reopen EverSettings to review them.", n)
	end
end

function Window:OnCombatChanged()
	if self.frame and self.frame:IsShown() then self:QueueRefresh(false) end
end

function Window:Toggle()
	local f = self:Create()
	f:SetShown(not f:IsShown())
end
