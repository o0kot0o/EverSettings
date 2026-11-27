-- Settings list page. One page instance renders every list view: a category, All Settings,
-- Favorites, Modified, Recently Changed and search results.
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local Registry, Changes, Providers = ns.Registry, ns.Changes, ns.Providers

local function CreateSectionHeader(list)
	local h = CreateFrame("Button", nil, list)
	h.bg = UI.Background(h, "section")
	h.chevron = UI.Icon(h, "uitools-icon-chevron-down", 10, "textMuted")
	h.chevron:SetPoint("LEFT", 14, 0)
	h.label = UI.Text(h, 12, "text")
	h.label:SetPoint("LEFT", 32, 0)
	h.count = UI.Text(h, 11, "textDim")
	h.count:SetPoint("LEFT", h.label, "RIGHT", 8, 0)
	h:SetScript("OnClick", function(self)
		local collapsed = ns.db.ui.collapsed
		collapsed[self.key] = (not collapsed[self.key]) or nil
		self.page:Rebuild(true)
	end)
	return h
end

local function UpdateSectionHeader(h, item, list)
	h.key, h.page = item.key, list.page
	h.label:SetText(item.label)
	h.count:SetText(item.count and tostring(item.count) or "")
	local collapsed = ns.db.ui.collapsed[item.key]
	UI.SetIcon(h.chevron, collapsed and "uitools-icon-chevron-right" or "uitools-icon-chevron-down", "textMuted")
	h.label:SetFontObject(Theme:Font(item.level == 1 and 14 or 12, "text"))
	UI.SetColor(h.bg, item.level == 1 and Theme.colors.content or Theme.colors.section)
end

local function CreateNotice(list)
	local n = CreateFrame("Frame", nil, list)
	n.title = UI.Text(n, 13, "text")
	n.title:SetPoint("TOPLEFT", 34, -16)
	n.title:SetPoint("TOPRIGHT", -24, -16)
	n.body = UI.Text(n, 11, "textMuted")
	n.body:SetPoint("TOPLEFT", n.title, "BOTTOMLEFT", 0, -6)
	n.body:SetPoint("TOPRIGHT", n.title, "BOTTOMRIGHT", 0, -6)
	n.body:SetWordWrap(true)
	n.body:SetJustifyV("TOP")
	n.button = UI.CreateButton(n, "", "secondary", 150, 24)
	n.button:SetPoint("TOPLEFT", n.body, "BOTTOMLEFT", 0, -10)
	return n
end

local function UpdateNotice(n, item)
	n.title:SetText(item.title or "")
	n.body:SetText(item.body or "")
	if item.buttonText then
		n.button:SetText(item.buttonText)
		n.button:SetScript("OnClick", item.onClick)
		n.button:Show()
	else
		n.button:Hide()
	end
end

function UI.CreateSettingsPage(parent, window)
	local page = CreateFrame("Frame", nil, parent)
	page.window = window
	page.errors = {}  -- [settingId] = validation message currently shown

	page.title = UI.Text(page, 18, "text")
	page.title:SetPoint("TOPLEFT", Theme.metrics.padding, -14)
	page.meta = UI.Text(page, 11, "textDim", "RIGHT")
	page.meta:SetPoint("TOPRIGHT", -Theme.metrics.padding, -18)
	page.desc = UI.Text(page, 12, "textMuted")
	page.desc:SetPoint("TOPLEFT", Theme.metrics.padding, -40)
	page.desc:SetPoint("TOPRIGHT", -Theme.metrics.padding, -40)

	local list = UI.CreateScrollList(page)
	list.page = page
	list:SetPoint("TOPLEFT", 0, -64)
	list:SetPoint("BOTTOMRIGHT", 0, 0)
	list:RegisterType("section", Theme.metrics.sectionHeight, CreateSectionHeader, UpdateSectionHeader)
	list:RegisterType("row", Theme.metrics.rowHeight, UI.CreateSettingRow, UI.UpdateSettingRow)
	list:RegisterType("notice", 110, CreateNotice, UpdateNotice)
	page.list = list

	local function AddDefs(items, defs, groupByCategory, collapsePrefix)
		if not groupByCategory then
			for _, def in ipairs(defs) do items[#items + 1] = { type = "row", def = def } end
			return
		end
		local byCat = {}
		for _, def in ipairs(defs) do
			byCat[def.category] = byCat[def.category] or {}
			table.insert(byCat[def.category], def)
		end
		for _, cat in ipairs(ns.Categories.list) do
			local group = byCat[cat.id]
			if group then
				local key = collapsePrefix .. cat.id
				items[#items + 1] = { type = "section", key = key, label = cat.name, count = #group, level = 1 }
				if not ns.db.ui.collapsed[key] then
					for _, def in ipairs(group) do items[#items + 1] = { type = "row", def = def } end
				end
			end
		end
	end

	local function CountStats(defs)
		local modified, pending = 0, 0
		for _, def in ipairs(defs) do
			if Changes:GetPending(def.id) ~= nil then pending = pending + 1 end
			if Providers:IsAvailable(def) and Changes:IsModified(def) then modified = modified + 1 end
		end
		return modified, pending
	end

	local function BrowserNotice()
		local unclassified = ns.Discovery:GetUnclassifiedCount()
		return {
			type = "notice", title = L.EMPTY_CATEGORY,
			body = L.EMPTY_CATEGORY_HINT .. (" (%d unclassified variables)"):format(unclassified),
			buttonText = "Open CVar Browser", onClick = function() window:Navigate("browser") end,
		}
	end

	-- mode: "category" (arg = id) | "all" | "favorites" | "modified" | "recent" | "search" (arg = query)
	function page:Open(mode, arg)
		self.mode, self.arg = mode, arg
		wipe(self.errors)
		self:Rebuild(false)
	end

	function page:Rebuild(keepScroll)
		local mode, arg = self.mode, self.arg
		local items, defs = {}, {}
		local title, description = "", ""
		if mode == "category" then
			local cat = ns.Categories.byId[arg]
			title, description = cat.name, cat.description
			for _, section in ipairs(Registry:GetCategorySections(arg)) do
				local key = arg .. "." .. section.sub.id
				items[#items + 1] = { type = "section", key = key, label = section.sub.name, count = #section.defs, level = 2 }
				for _, def in ipairs(section.defs) do defs[#defs + 1] = def end
				if not ns.db.ui.collapsed[key] then
					for _, def in ipairs(section.defs) do items[#items + 1] = { type = "row", def = def } end
				end
			end
			if #defs == 0 then
				items[#items + 1] = BrowserNotice()
			elseif arg == "advanced" then
				local n = BrowserNotice()
				n.title = L.CVAR_BROWSER
				n.body = "Every variable in the client's catalog, read-only, with its current value, default and storage flags."
				items[#items + 1] = n
			end
		else
			if mode == "all" then
				title, description = L.ALL_SETTINGS, "Every researched setting, grouped by category."
				for _, def in ipairs(Registry.ordered) do if Registry.byId[def.id] == def then defs[#defs + 1] = def end end
			elseif mode == "favorites" then
				title, description = L.FAVORITES, "Settings you have starred."
				for _, def in ipairs(Registry.ordered) do if ns.db.favorites[def.id] and Registry.byId[def.id] == def then defs[#defs + 1] = def end end
			elseif mode == "modified" then
				title, description = L.MODIFIED, "Settings whose game value differs from the factory default, or that have pending changes."
				for _, def in ipairs(Registry.ordered) do
					if Registry.byId[def.id] == def and def.provider ~= "diagnostic" and Providers:IsAvailable(def)
						and (Changes:IsModified(def) or Changes:GetPending(def.id) ~= nil) then
						defs[#defs + 1] = def
					end
				end
			elseif mode == "recent" then
				title, description = L.RECENT, "Most recently changed settings, by EverSettings or outside it."
				for _, id in ipairs(ns.History:GetRecentIds(50)) do defs[#defs + 1] = Registry:Get(id) end
			elseif mode == "search" then
				title = L.SEARCH_RESULTS
				description = ("Results for \"%s\""):format(arg or "")
				defs = Registry:Search(arg or "")
			end
			AddDefs(items, defs, mode ~= "recent", mode .. ":")
			if #defs == 0 then
				local msg = ({ favorites = L.EMPTY_FAVORITES, modified = L.EMPTY_MODIFIED, recent = L.EMPTY_RECENT, search = L.EMPTY_SEARCH })[mode]
				items[#items + 1] = { type = "notice", title = msg or "", body = "" }
			end
		end
		self.title:SetText(title)
		self.desc:SetText(description)
		local modified, pending = CountStats(defs)
		self.meta:SetText(("%d settings  ·  %d modified  ·  %d pending"):format(#defs, modified, pending))
		self.currentDefs = defs
		list:SetItems(items, keepScroll)
	end

	function page:RefreshRows()
		list:RefreshVisible()
		if self.currentDefs then
			local modified, pending = CountStats(self.currentDefs)
			self.meta:SetText(("%d settings  ·  %d modified  ·  %d pending"):format(#self.currentDefs, modified, pending))
		end
	end

	function page:Select(id)
		self.selectedId = id
		list:ForEachVisible(function(frame) if frame.UpdateHighlight then frame:UpdateHighlight() end end)
		window:InspectSetting(Registry:Get(id))
	end

	function page:GetVisibleDefs()
		local out = {}
		list:ForEachVisible(function(frame, item) if item and item.def then out[#out + 1] = item.def end end)
		return out
	end

	return page
end
