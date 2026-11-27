-- Main window: header (identity, profile, search, Details, help, close), sidebar navigation,
-- page area, optional resizable inspector ("Details") and footer (pending changes, undo/redo,
-- discard, reset category, apply).
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local Changes, Registry = ns.Changes, ns.Registry
local M = Theme.metrics

local Window = {}
ns.Window = Window

local MIN_CONTENT_WIDTH = 440 -- the settings list never gets narrower than this

-- Sidebar -------------------------------------------------------------------------------
local function CreateNavGroup(list)
	local f = CreateFrame("Frame", nil, list)
	f.line = UI.Line(f, "border", true)
	f.line:SetPoint("TOPLEFT", 14, -6)
	f.line:SetPoint("TOPRIGHT", -14, -6)
	f.label = UI.Text(f, "overline", "textDim")
	f.label:SetPoint("BOTTOMLEFT", 16, 6)
	return f
end
local function UpdateNavGroup(f, item)
	f.label:SetText(item.label)
	f.line:SetShown(not item.first)
end

local function CreateNavItem(list)
	local b = CreateFrame("Button", nil, list)
	b.hl = b:CreateTexture(nil, "BACKGROUND")
	b.hl:SetPoint("TOPLEFT", 8, -1)
	b.hl:SetPoint("BOTTOMRIGHT", -8, 1)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetPoint("TOPLEFT", 8, -5)
	b.bar:SetPoint("BOTTOMLEFT", 8, 5)
	b.bar:SetWidth(3)
	UI.SetColor(b.bar, "accent")
	b.icon = UI.Icon(b, "graphics", 16, "textMuted")
	b.icon:SetPoint("LEFT", 20, 0)
	b.label = UI.Text(b, "nav", "text")
	b.label:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
	b.label:SetPoint("RIGHT", -46, 0)
	b.count = UI.Text(b, "meta", "textDim", "RIGHT")
	b.count:SetPoint("RIGHT", -16, 0)
	b.count:SetWidth(32)
	b:SetScript("OnClick", function(self) Window:Navigate(self.key) end)
	b:SetScript("OnEnter", function(self) self.hovered = true; self:UpdateVisual() end)
	b:SetScript("OnLeave", function(self) self.hovered = false; self:UpdateVisual() end)
	function b:UpdateVisual()
		if self.selected then
			UI.SetColor(self.hl, "navSelected")
			self.hl:Show()
		elseif self.hovered then
			UI.SetColor(self.hl, "rowHover")
			self.hl:Show()
		else
			self.hl:Hide()
		end
		self.bar:SetShown(self.selected)
		UI.SetFont(self.label, self.selected and "navActive" or "nav", "text")
		UI.SetTextColor(self.label, self.selected and "text" or ((self.hovered and "text") or (self.dim and "textDim" or "textMuted")))
		UI.SetIconColor(self.icon, self.selected and "accent" or (self.dim and "textDim" or "textMuted"))
		UI.SetTextColor(self.count, self.selected and "textMuted" or "textDim")
	end
	return b
end

local function UpdateNavItem(b, item)
	b.key, b.dim = item.key, item.dim
	b.label:SetText(item.label)
	b.count:SetText(item.count and tostring(item.count) or "")
	UI.SetIcon(b.icon, item.icon, "textMuted")
	b.selected = Window.currentKey == item.key
	b:UpdateVisual()
end

function Window:BuildNavItems()
	local items = { { type = "group", label = "LIBRARY", first = true } }
	local favCount = Util.Count(ns.db.favorites)
	items[#items + 1] = { type = "item", key = "favorites", label = L.FAVORITES, icon = "favorites", count = favCount > 0 and favCount or nil }
	items[#items + 1] = { type = "item", key = "modified", label = L.MODIFIED, icon = "modified" }
	items[#items + 1] = { type = "item", key = "recent", label = L.RECENT, icon = "recent" }
	items[#items + 1] = { type = "item", key = "all", label = L.ALL_SETTINGS, icon = "all", count = #Registry.ordered }
	items[#items + 1] = { type = "group", label = "CATEGORIES" }
	for _, cat in ipairs(ns.Categories.list) do
		local n = Registry:CountCategory(cat.id)
		local key = "category:" .. cat.id
		if n > 0 or not ns.db.ui.hideEmpty or self.currentKey == key then
			items[#items + 1] = { type = "item", key = key, label = cat.name, icon = cat.id, count = n > 0 and n or nil, dim = n == 0 }
		end
	end
	items[#items + 1] = { type = "group", label = "TOOLS" }
	items[#items + 1] = { type = "item", key = "browser", label = L.CVAR_BROWSER, icon = "browser", count = ns.CVarCatalog and ns.CVarCatalog.meta.numCVars }
	items[#items + 1] = { type = "item", key = "profiles", label = L.PROFILES, icon = "profiles" }
	items[#items + 1] = { type = "item", key = "diagnostics", label = L.DIAGNOSTICS, icon = "diagnostics" }
	items[#items + 1] = { type = "item", key = "preferences", label = L.PREFERENCES, icon = "preferences" }
	return items
end

-- Construction ----------------------------------------------------------------------------
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
	f:SetScale(self:ClampScale(db.scale))
	f:SetSize(math.max(M.minWidth, db.width or 1100), math.max(M.minHeight, db.height or 700))
	f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
	UI.Background(f, "window")
	UI.Border(f, "borderStrong", "OVERLAY")
	f:Hide()
	tinsert(UISpecialFrames, "EverSettingsMainFrame")

	self:CreateHeader(f)
	self:CreateFooter(f)

	-- Sidebar
	local sidebar = CreateFrame("Frame", nil, f)
	sidebar:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, 0)
	sidebar:SetPoint("BOTTOMLEFT", f.footer, "TOPLEFT", 0, 0)
	sidebar:SetWidth(M.sidebarWidth)
	UI.Background(sidebar, "sidebar")
	local sl = UI.Line(sidebar, "border", false)
	sl:SetPoint("TOPRIGHT")
	sl:SetPoint("BOTTOMRIGHT")
	local nav = UI.CreateScrollList(sidebar)
	nav:SetPoint("TOPLEFT", 0, -4)
	nav:SetPoint("BOTTOMRIGHT", -1, 6)
	nav:RegisterType("group", 32, CreateNavGroup, UpdateNavGroup)
	nav:RegisterType("item", M.navItemHeight, CreateNavItem, UpdateNavItem)
	f.sidebar, f.nav = sidebar, nav

	-- Inspector ("Details") with a drag handle on its left edge to change its width.
	local inspector = UI.CreateInspector(f, self)
	inspector:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, 0)
	inspector:SetPoint("BOTTOMRIGHT", f.footer, "TOPRIGHT", 0, 0)
	f.inspector = inspector
	local grip = CreateFrame("Frame", nil, inspector)
	grip:SetPoint("TOPLEFT", -3, 0)
	grip:SetPoint("BOTTOMLEFT", -3, 0)
	grip:SetWidth(7)
	grip:EnableMouse(true)
	grip.line = grip:CreateTexture(nil, "OVERLAY")
	grip.line:SetPoint("TOP")
	grip.line:SetPoint("BOTTOM")
	grip.line:SetWidth(2)
	UI.SetColor(grip.line, "accent")
	grip.line:Hide()
	grip:SetScript("OnEnter", function(self) self.line:Show() end)
	grip:SetScript("OnLeave", function(self) if not self.dragging then self.line:Hide() end end)
	grip:SetScript("OnMouseDown", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", function()
			local x = GetCursorPosition() / f:GetEffectiveScale()
			local right = inspector:GetRight()
			if right then Window:SetInspectorWidth(right - x) end
		end)
	end)
	grip:SetScript("OnMouseUp", function(self)
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		if not self:IsMouseOver() then self.line:Hide() end
	end)
	f.inspectorGrip = grip

	-- Content
	local content = CreateFrame("Frame", nil, f)
	UI.Background(content, "content")
	f.content = content

	self.pages = {
		settings = UI.CreateSettingsPage(content, self),
		browser = UI.CreateCVarBrowserPage(content, self),
		profiles = UI.CreateProfilesPage(content, self),
		diagnostics = UI.CreateDiagnosticsPage(content, self),
		preferences = UI.CreatePreferencesPage(content, self),
	}
	for _, page in pairs(self.pages) do
		page:SetAllPoints(content)
		page:Hide()
	end

	-- Window resize grip
	local resize = CreateFrame("Button", nil, f)
	resize:SetSize(16, 16)
	resize:SetPoint("BOTTOMRIGHT", -2, 2)
	resize:SetFrameLevel(f.footer:GetFrameLevel() + 5)
	resize.icon = UI.Icon(resize, "uitools-icon-window-resize", 12, "textDim")
	resize.icon:SetPoint("CENTER")
	resize:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	resize:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); Window:SavePosition() end)

	f:SetScript("OnShow", function() Window:OnShow() end)
	f:SetScript("OnHide", function() Window:OnHide() end)
	f:SetScript("OnSizeChanged", function() Window:Layout() end)

	self:SetInspectorShown(db.inspector == true)
	self:RegisterCallbacks()
	self:Layout()
	return f
end

function Window:CreateHeader(f)
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

	-- Identity: accent tile with the logo glyph, name and version.
	local tile = UI.Icon(header, "rounded", 30, "accentDim")
	tile:SetPoint("LEFT", 14, 0)
	local logo = UI.Icon(header, "logo", 18, "accent")
	logo:SetPoint("CENTER", tile, "CENTER")
	local title = UI.Text(header, "windowTitle", "text")
	title:SetPoint("LEFT", tile, "RIGHT", 10, 0)
	title:SetText(L.ADDON_TITLE)
	local version = UI.CreateBadge(header)
	version:SetPoint("LEFT", title, "RIGHT", 8, 0)
	version:Set(ns.version, "textMuted")

	-- Profile selector and management.
	local profileLabel = UI.Text(header, "small", "textMuted", "RIGHT")
	profileLabel:SetPoint("LEFT", version, "RIGHT", 22, 0)
	profileLabel:SetText("Profile")
	local profileDropdown = UI.CreateDropdown(header, 190)
	profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", 8, 0)
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
	local manage = UI.CreateButton(header, "Manage", "ghost", 104, 28, "profiles")
	manage:FitWidth(104)
	manage:SetPoint("LEFT", profileDropdown, "RIGHT", 6, 0)
	manage:SetScript("OnClick", function() Window:Navigate("profiles") end)
	f.manageButton = manage

	-- Right side: close, help, Details, search.
	local close = UI.CreateIconButton(header, "close", 14, L.CLOSE)
	close:SetPoint("RIGHT", -10, 0)
	close:SetScript("OnClick", function() f:Hide() end)
	local help = UI.CreateIconButton(header, "help", 16, L.HELP)
	help:SetPoint("RIGHT", close, "LEFT", -2, 0)
	help:SetScript("OnClick", function() UI.Alert("EverSettings " .. ns.version, L.HELP_TEXT) end)
	local details = UI.CreateButton(header, L.DETAILS, "secondary", 96, 30, "details")
	details:SetPoint("RIGHT", help, "LEFT", -8, 0)
	details:SetScript("OnClick", function() Window:SetInspectorShown(not ns.db.window.inspector, true) end)
	UI.AttachTooltip(details, L.DETAILS, "Show or hide the panel with the full description, values, sources and verification status of the selected setting. Double-click a setting to open it.")
	f.detailsButton = details
	local search = UI.CreateSearchBox(header, 300, L.SEARCH_PLACEHOLDER, function(text) Window:OnSearch(text) end)
	search:SetPoint("RIGHT", details, "LEFT", -12, 0)
	f.search = search
end

function Window:CreateFooter(f)
	local footer = CreateFrame("Frame", nil, f)
	footer:SetPoint("BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", -1, 1)
	footer:SetHeight(M.footerHeight)
	UI.Background(footer, "header")
	local fl = UI.Line(footer, "border", true)
	fl:SetPoint("TOPLEFT")
	fl:SetPoint("TOPRIGHT")
	f.footer = footer

	f.apply = UI.CreateButton(footer, L.APPLY, "primary", 112, 32)
	f.apply:SetPoint("RIGHT", -24, 0)
	f.resetCategory = UI.CreateButton(footer, L.RESET_CATEGORY, "secondary", 128, 32)
	f.resetCategory:SetPoint("RIGHT", f.apply, "LEFT", -8, 0)
	f.discard = UI.CreateButton(footer, L.DISCARD, "secondary", 96, 32)
	f.discard:SetPoint("RIGHT", f.resetCategory, "LEFT", -8, 0)
	f.redo = UI.CreateButton(footer, L.REDO, "ghost", 64, 32)
	f.redo:SetPoint("RIGHT", f.discard, "LEFT", -16, 0)
	f.undo = UI.CreateButton(footer, L.UNDO, "ghost", 64, 32)
	f.undo:SetPoint("RIGHT", f.redo, "LEFT", -4, 0)

	f.pendingPill = CreateFrame("Frame", nil, footer)
	f.pendingPill:SetPoint("LEFT", 16, 0)
	f.pendingPill:SetHeight(26)
	f.pendingPill.bg = UI.Background(f.pendingPill, "warningDim")
	f.pendingText = UI.Text(f.pendingPill, "label", "textMuted")
	f.pendingText:SetPoint("LEFT", 10, 0)
	f.statusText = UI.Text(footer, "small", "textMuted")
	f.statusText:SetPoint("LEFT", f.pendingPill, "RIGHT", 14, 0)
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
				local n, rep = Changes:StageCategoryDefaults(catId)
				local msg = ("%d default value(s) staged."):format(n)
				if rep.cleared > 0 then msg = msg .. (" %d pending edit(s) cleared (already at default)."):format(rep.cleared) end
				if rep.replaced > 0 then msg = msg .. (" %d pending edit(s) replaced."):format(rep.replaced) end
				if rep.restricted > 0 then msg = msg .. (" %d skipped (restricted)."):format(rep.restricted) end
				Window:SetStatus(msg, (rep.replaced > 0 or rep.restricted > 0) and "warning" or "accent")
			end)
	end)
	local function reportRestore(label, report)
		if not report then return end
		local warn = (report.counts.conflict or 0) > 0 or #report.retained > 0
		Window:SetStatus(label .. ": " .. Changes:FormatReport(report), warn and "warning" or "accent")
		for _, r in ipairs(report.results) do
			if r.status == "conflict" or r.status == "failed" or r.status == "restricted" then
				ns:Print("%s %s: %s%s", label, r.name, r.status, r.message and (" - " .. r.message) or "")
			end
			if r.pendingKept then ns:Print("%s: your pending edit was kept.", r.name) end
		end
	end
	f.undo:SetScript("OnClick", function() reportRestore("Undo", ns.History:Undo()) end)
	f.redo:SetScript("OnClick", function() reportRestore("Redo", ns.History:Redo()) end)
end

-- Layout ----------------------------------------------------------------------------------
function Window:ClampScale(scale)
	return Util.Clamp(tonumber(scale) or 1, M.scaleMin, M.scaleMax)
end

-- EverSettings' own interface scale, independent of the game's UI scale.
function Window:SetScale(scale)
	scale = self:ClampScale(scale)
	ns.db.window.scale = scale
	if self.frame then
		self.frame:SetScale(scale)
		self:Layout()
	end
	return scale
end

function Window:ClampInspectorWidth(width)
	local maxByWindow = M.inspectorMax
	if self.frame then
		maxByWindow = math.min(M.inspectorMax, self.frame:GetWidth() - M.sidebarWidth - MIN_CONTENT_WIDTH)
	end
	return math.floor(Util.Clamp(tonumber(width) or M.inspectorWidth, M.inspectorMin, math.max(M.inspectorMin, maxByWindow)))
end

function Window:SetInspectorWidth(width)
	width = self:ClampInspectorWidth(width)
	ns.db.window.inspectorWidth = width
	if self.frame then
		self.frame.inspector:SetPanelWidth(width)
		self:Layout()
	end
	return width
end

-- userChoice: the player toggled it (remembered across sessions).
function Window:SetInspectorShown(shown, userChoice)
	local db = ns.db.window
	db.inspector = shown and true or false
	if userChoice then db.inspectorChosen = true end
	local f = self.frame
	if not f then return end
	f.inspector:SetShown(db.inspector)
	if db.inspector then
		f.inspector:SetPanelWidth(self:ClampInspectorWidth(db.inspectorWidth))
	end
	f.detailsButton:SetSelected(db.inspector)
	self:Layout()
end

-- Responsive layout for the current window size.
function Window:Layout()
	local f = self.frame
	if not f then return end
	local width = f:GetWidth()
	f.content:ClearAllPoints()
	f.content:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", M.sidebarWidth, 0)
	if ns.db.window.inspector then
		local w = self:ClampInspectorWidth(ns.db.window.inspectorWidth)
		if w ~= math.floor(f.inspector:GetWidth()) then f.inspector:SetPanelWidth(w) end
		f.content:SetPoint("BOTTOMRIGHT", f.inspector, "BOTTOMLEFT", 0, 0)
	else
		f.content:SetPoint("BOTTOMRIGHT", f.footer, "TOPRIGHT", 0, 0)
	end
	-- Header: search shrinks first, then the Manage button hides on narrow windows.
	f.search:SetWidth(Util.Clamp(width - 780, 180, 340))
	f.manageButton:SetShown(width >= 1010)
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
	db.point, db.x, db.y, db.width, db.height = "CENTER", 0, 0, 1100, 700
	if self.frame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER")
		self.frame:SetSize(1100, 700)
		self:Layout()
	end
end

-- Navigation --------------------------------------------------------------------------------
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

-- Selecting updates the Details panel; it only opens when the player asks (Details button
-- or double-click), so the list keeps its full width by default.
function Window:InspectSetting(def)
	if def then self.frame.inspector:ShowSetting(def) end
end

function Window:InspectCVar(name)
	self.frame.inspector:ShowCVar(name)
	if not ns.db.window.inspector and not self.cvarHintShown then
		self.cvarHintShown = true
		self:SetStatus("Press Details to see this variable's flags, defaults and snapshot value.", "accent")
	end
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
		f.pendingPill.bg:Show()
		f.apply:SetText(("%s (%d)"):format(L.APPLY, n))
	else
		f.pendingText:SetText(L.PENDING_NONE)
		UI.SetTextColor(f.pendingText, "textDim")
		f.pendingPill.bg:Hide()
		f.apply:SetText(L.APPLY)
	end
	f.pendingPill:SetWidth(f.pendingText:GetStringWidth() + 20)
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
			+ report.counts.partial + report.counts.unknown
		self:SetStatus(text, bad > 0 and "warning" or "success")
		for _, r in ipairs(report.results) do
			if r.status ~= "success" then
				ns:Print("%s: %s%s", r.name, r.status, r.message and (" - " .. r.message) or "")
			end
			for _, w in ipairs(r.warnings or {}) do ns:Print("%s: note - %s", r.name, w) end
			if r.note then ns:Print("%s: %s", r.name, r.note) end
		end
	end
	-- Preview overlapping writes (e.g. the graphics preset and an explicit quality setting).
	local preview = Changes:PreviewPending()
	local overlapText
	if #preview.overlaps > 0 then
		local lines, seen = {}, {}
		for _, o in ipairs(preview.overlaps) do
			local key = table.concat(o.ids, ",")
			if not seen[key] then
				seen[key] = true
				local names = {}
				for _, id in ipairs(o.ids) do names[#names + 1] = Registry:Get(id).name end
				lines[#lines + 1] = ("%s write the same variable(s); %s is applied last and wins."):format(table.concat(names, " and "), Registry:Get(o.winner).name)
			end
		end
		overlapText = table.concat(lines, "\n")
	end
	Window.lastPreview = preview
	if n >= 10 or needsRestart or overlapText then
		local body = ("Apply %d change(s)?"):format(n)
		if overlapText then body = body .. "\n\n" .. overlapText end
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

function Window:RefreshNav()
	if self.frame and self.frame:IsShown() then self.frame.nav:SetItems(self:BuildNavItems(), true) end
end

function Window:RegisterCallbacks()
	local C = ns.Callbacks
	C:Register("ValueChanged", self, function() self:QueueRefresh(self.pages.settings.mode == "modified") end)
	C:Register("PendingChanged", self, function() self:QueueRefresh(self.pages.settings.mode == "modified") end)
	C:Register("FavoritesChanged", self, function()
		self:QueueRefresh(self.pages.settings.mode == "favorites")
		self:RefreshNav()
	end)
	C:Register("HistoryChanged", self, function() self:QueueRefresh(self.pages.settings.mode == "recent") end)
	C:Register("ProfilesChanged", self, function() if self.frame:IsShown() then self:UpdateProfileDropdown() end end)
	C:Register("ApplyFinished", self, function() self:QueueRefresh(false) end)
	C:Register("PreferencesChanged", self, function()
		self:RefreshNav()
		self:QueueRefresh(true)
	end)
end

function Window:OnShow()
	self:UpdateProfileDropdown()
	self:UpdateFooter()
	self:Layout()
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
