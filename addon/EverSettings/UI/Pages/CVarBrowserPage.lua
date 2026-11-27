-- Technical CVar browser: every catalogued or discovered variable, read-only.
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local Compat, Registry = ns.Compat, ns.Registry

local CONSOLE_CATEGORY = { [0] = "Debug", "Graphics", "Console", "Combat", "Game", "Default", "Net", "Sound", "Gm", "Reveal", "None" }
ns.CONSOLE_CATEGORY = CONSOLE_CATEGORY

local FILTERS = {
	{ value = "all", label = "All variables" },
	{ value = "unclassified", label = "Unclassified" },
	{ value = "settings", label = "In Blizzard's settings window" },
	{ value = "ui", label = "Used by other Blizzard UI" },
	{ value = "hidden", label = "Hidden (console only)" },
	{ value = "changed", label = "Different from default" },
	{ value = "new", label = "New in this client" },
	{ value = "secure", label = "Secure" },
}

local function CreateRow(list)
	local r = CreateFrame("Button", nil, list)
	r.hl = r:CreateTexture(nil, "BACKGROUND")
	r.hl:SetAllPoints()
	UI.SetColor(r.hl, Theme.colors.rowHover)
	r.hl:Hide()
	r.name = UI.Text(r, "settingName", "text")
	r.name:SetPoint("TOPLEFT", 16, -6)
	r.value = UI.Text(r, "small", "text", "RIGHT")
	r.value:SetPoint("TOPRIGHT", -16, -6)
	r.value:SetWidth(260)
	r.help = UI.Text(r, "settingDesc", "textMuted")
	r.help:SetPoint("TOPLEFT", 16, -22)
	r.help:SetPoint("TOPRIGHT", -16, -22)
	r.flags = UI.Text(r, 10, "textDim", "RIGHT")
	r.flags:SetPoint("TOPRIGHT", r.value, "TOPLEFT", -10, 0)
	r.divider = UI.Line(r, "border", true)
	r.divider:SetPoint("BOTTOMLEFT", 12, 0)
	r.divider:SetPoint("BOTTOMRIGHT", -12, 0)
	r:SetScript("OnEnter", function(self) self.hl:Show() end)
	r:SetScript("OnLeave", function(self) self.hl:Hide() end)
	r:SetScript("OnClick", function(self) self.page.window:InspectCVar(self.cvarName) end)
	return r
end

local function UpdateRow(r, item, list)
	r.page, r.cvarName = list.page, item.name
	local entry = item.entry
	local value = Compat.GetCVar(item.name)
	local default = entry and entry[1] or Compat.GetCVarDefault(item.name)
	local changed = value ~= nil and default ~= nil and tostring(value) ~= tostring(default)
		and not (tonumber(value) and tonumber(default) and Util.NearlyEqual(tonumber(value), tonumber(default)))
	local classified = Registry:IsCVarClassified(item.name)
	r.name:SetText(item.name .. (classified and Theme:Colorize("  managed", "accent") or ""))
	if value == nil then
		r.value:SetText(Theme:Colorize("not present in client", "textDim"))
	else
		local shown = #value > 40 and (value:sub(1, 37) .. "...") or value
		r.value:SetText((changed and Theme:Colorize(shown, "warning") or shown) .. Theme:Colorize(("   default %s"):format(tostring(default)), "textDim"))
	end
	local flags = {}
	if entry then
		if Registry.HasFlag(entry[3], Registry.FLAG_ACCOUNT) then flags[#flags + 1] = "ACCOUNT" end
		if Registry.HasFlag(entry[3], Registry.FLAG_CHARACTER) then flags[#flags + 1] = "CHARACTER" end
		if Registry.HasFlag(entry[3], Registry.FLAG_SECURE) then flags[#flags + 1] = "SECURE" end
	else
		flags[#flags + 1] = "NEW"
	end
	r.flags:SetText(table.concat(flags, "  "))
	local help = entry and entry[5] or item.help or ""
	r.help:SetText(help ~= "" and help or Theme:Colorize("No description provided by the client.", "textDim"))
end

function UI.CreateCVarBrowserPage(parent, window)
	local page = CreateFrame("Frame", nil, parent)
	page.window = window
	page.filter, page.query = "all", ""

	page.title = UI.Text(page, "pageTitle", "text")
	page.title:SetPoint("TOPLEFT", Theme.metrics.padding, -16)
	page.title:SetText(L.CVAR_BROWSER)
	page.desc = UI.Text(page, "pageDesc", "textMuted")
	page.desc:SetPoint("TOPLEFT", Theme.metrics.padding, -40)
	page.desc:SetPoint("TOPRIGHT", -Theme.metrics.padding, -40)
	page.desc:SetText("Read-only. Unknown variables stay read-only until their purpose and safe values are researched.")

	page.search = UI.CreateSearchBox(page, 240, "Filter by name or description", function(text)
		page.query = Util.Trim(text):lower()
		page:Rebuild()
	end)
	page.search:SetPoint("TOPLEFT", Theme.metrics.padding, -62)
	page.filterDropdown = UI.CreateDropdown(page, 230)
	page.filterDropdown:SetPoint("LEFT", page.search, "RIGHT", 10, 0)
	page.filterDropdown:SetOptions(FILTERS)
	page.filterDropdown:SetValue("all")
	page.filterDropdown.onSelect = function(value)
		page.filter = value
		page.filterDropdown:SetValue(value)
		page:Rebuild()
	end
	page.count = UI.Text(page, "meta", "textMuted", "RIGHT")
	page.count:SetPoint("TOPRIGHT", -Theme.metrics.padding, -68)

	local list = UI.CreateScrollList(page)
	list.page = page
	list:SetPoint("TOPLEFT", 0, -98)
	list:SetPoint("BOTTOMRIGHT")
	list:RegisterType("cvar", 42, CreateRow, UpdateRow)
	page.list = list

	function page:Rebuild()
		local items = {}
		local catalog = ns.CVarCatalog and ns.CVarCatalog.cvars or {}
		local filter, query = self.filter, self.query
		local function consider(name, entry, help)
			if filter == "unclassified" and Registry:IsCVarClassified(name) then return end
			if filter == "settings" and not (entry and entry[4] == 2) then return end
			if filter == "ui" and not (entry and entry[4] == 1) then return end
			if filter == "hidden" and not (entry and entry[4] == 0) then return end
			if filter == "new" and entry then return end
			if filter == "secure" and not (entry and Registry.HasFlag(entry[3], Registry.FLAG_SECURE)) then return end
			if filter == "changed" then
				local v, d = Compat.GetCVar(name), entry and entry[1]
				if v == nil or d == nil or tostring(v) == tostring(d) then return end
				if tonumber(v) and tonumber(d) and Util.NearlyEqual(tonumber(v), tonumber(d)) then return end
			end
			if query ~= "" and not Util.MatchesQuery(query, name, entry and entry[5] or help) then return end
			items[#items + 1] = { type = "cvar", name = name, entry = entry, help = help }
		end
		self.sortedNames = self.sortedNames or Util.SortedKeys(catalog, function(a, b) return a:lower() < b:lower() end)
		for _, name in ipairs(self.sortedNames) do
			consider(name, catalog[name])
		end
		local d = ns.Discovery.last
		if d and d.available then
			for _, name in ipairs(d.new) do
				local info = d.clientCVars[name]
				consider(name, nil, info and info.help)
			end
		end
		self.count:SetText(("%d variables"):format(#items))
		list:SetItems(items)
	end

	function page:Open()
		self:Rebuild()
	end

	return page
end
