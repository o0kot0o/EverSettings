-- Profiles, backups and original values. Every restore or profile application stages
-- changes for review; nothing is written until the player presses Apply.
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local Profiles, Backup, Values, Providers, Registry = ns.Profiles, ns.Backup, ns.Values, ns.Providers, ns.Registry

local function CreateNavRow(list)
	local b = CreateFrame("Button", nil, list)
	b.hl = b:CreateTexture(nil, "BACKGROUND")
	b.hl:SetAllPoints()
	b.label = UI.Text(b, "body", "text")
	b.label:SetPoint("LEFT", 14, 0)
	b.label:SetPoint("RIGHT", -60, 0)
	b.meta = UI.Text(b, 10, "textDim", "RIGHT")
	b.meta:SetPoint("RIGHT", -10, 0)
	b:SetScript("OnClick", function(self) self.page:SelectItem(self.item) end)
	b:SetScript("OnEnter", function(self) if not self.selected then UI.SetColor(self.hl, Theme.colors.rowHover); self.hl:Show() end end)
	b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
	return b
end

local function UpdateNavRow(b, item, list)
	b.page, b.item = list.page, item
	b.label:SetText(item.label)
	b.meta:SetText(item.meta or "")
	b.selected = list.page.selected and list.page.selected.key == item.key
	if b.selected then
		UI.SetColor(b.hl, Theme.colors.rowSelected)
		b.hl:Show()
	else
		b.hl:Hide()
	end
	UI.SetTextColor(b.label, item.active and "accent" or "text")
end

local function CreateGroupLabel(list)
	local f = CreateFrame("Frame", nil, list)
	f.label = UI.Text(f, "overline", "textDim")
	f.label:SetPoint("BOTTOMLEFT", 14, 6)
	return f
end
local function UpdateGroupLabel(f, item) f.label:SetText(item.label) end

local function CreateDiffRow(list)
	local r = CreateFrame("Frame", nil, list)
	r.name = UI.Text(r, "label", "text")
	r.name:SetPoint("LEFT", 12, 0)
	r.name:SetWidth(220)
	r.from = UI.Text(r, 11, "textMuted", "RIGHT")
	r.from:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
	r.from:SetWidth(130)
	r.arrow = UI.Icon(r, "uitools-icon-chevron-right", 9, "textDim")
	r.arrow:SetPoint("LEFT", r.from, "RIGHT", 8, 0)
	r.to = UI.Text(r, 11, "accent")
	r.to:SetPoint("LEFT", r.arrow, "RIGHT", 8, 0)
	r.to:SetPoint("RIGHT", -12, 0)
	r.divider = UI.Line(r, "border", true)
	r.divider:SetPoint("BOTTOMLEFT", 8, 0)
	r.divider:SetPoint("BOTTOMRIGHT", -8, 0)
	return r
end
local function UpdateDiffRow(r, item)
	r.name:SetText(item.label)
	r.from:SetText(item.from or "")
	r.to:SetText(item.to or "")
	r.arrow:SetShown(item.to ~= nil)
	UI.SetTextColor(r.to, item.toColor or "accent")
end

function UI.CreateProfilesPage(parent, window)
	local page = CreateFrame("Frame", nil, parent)
	page.window = window

	page.title = UI.Text(page, "pageTitle", "text")
	page.title:SetPoint("TOPLEFT", Theme.metrics.padding, -16)
	page.title:SetText(L.PROFILES)
	page.desc = UI.Text(page, "pageDesc", "textMuted")
	page.desc:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)
	page.desc:SetText("Profiles and backups contain values for researched settings only. Applying one stages its differences for review.")

	page.newButton = UI.CreateButton(page, "Save current as...", "primary", 140, 26)
	page.newButton:SetPoint("TOPRIGHT", -Theme.metrics.padding, -14)
	page.importButton = UI.CreateButton(page, "Import...", "secondary", 90, 26)
	page.importButton:SetPoint("RIGHT", page.newButton, "LEFT", -8, 0)

	-- Left navigation -------------------------------------------------------------
	local nav = UI.CreateScrollList(page)
	nav.page = page
	nav:SetPoint("TOPLEFT", 0, -64)
	nav:SetPoint("BOTTOMLEFT", 0, 0)
	nav:SetWidth(250)
	nav:RegisterType("group", 28, CreateGroupLabel, UpdateGroupLabel)
	nav:RegisterType("item", 30, CreateNavRow, UpdateNavRow)
	page.nav = nav
	local sep = UI.Line(page, "border", false)
	sep:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
	sep:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 0, 0)

	-- Detail panel ----------------------------------------------------------------
	local detail = CreateFrame("Frame", nil, page)
	detail:SetPoint("TOPLEFT", nav, "TOPRIGHT", 16, 0)
	detail:SetPoint("BOTTOMRIGHT", -Theme.metrics.padding, 0)
	page.detail = detail
	detail.name = UI.Text(detail, 15, "text")
	detail.name:SetPoint("TOPLEFT", 0, -4)
	detail.meta = UI.Text(detail, 11, "textMuted")
	detail.meta:SetPoint("TOPLEFT", 0, -26)
	detail.meta:SetPoint("TOPRIGHT", 0, -26)
	detail.buttons = CreateFrame("Frame", nil, detail)
	detail.buttons:SetPoint("TOPLEFT", detail.meta, "BOTTOMLEFT", 0, -10)
	detail.buttons:SetSize(600, 26)
	detail.buttonPool = {}
	detail.catLabel = UI.Text(detail, 11, "textDim")
	detail.catLabel:SetPoint("TOPLEFT", detail.buttons, "BOTTOMLEFT", 0, -14)
	detail.catLabel:SetText("APPLY THESE CATEGORIES")
	detail.cats = CreateFrame("Frame", nil, detail)
	detail.cats:SetPoint("TOPLEFT", detail.catLabel, "BOTTOMLEFT", 0, -6)
	detail.cats:SetSize(600, 20)
	detail.catBoxes = {}
	detail.summary = UI.Text(detail, 12, "text")
	detail.summary:SetPoint("TOPLEFT", detail.cats, "BOTTOMLEFT", 0, -10)
	detail.summary:SetPoint("TOPRIGHT", detail.cats, "BOTTOMRIGHT", -150, -10)
	detail.stage = UI.CreateButton(detail, "Stage changes", "primary", 140, 26)
	detail.stage:SetPoint("TOPRIGHT", detail.cats, "BOTTOMRIGHT", 0, -4)
	local diffs = UI.CreateScrollList(detail)
	diffs:SetPoint("TOPLEFT", detail.summary, "BOTTOMLEFT", 0, -8)
	diffs:SetPoint("BOTTOMRIGHT", 0, 8)
	diffs:RegisterType("diff", 28, CreateDiffRow, UpdateDiffRow)
	detail.diffs = diffs
	detail.empty = UI.Text(detail, 12, "textMuted")
	detail.empty:SetPoint("TOPLEFT", 0, -4)
	detail.empty:SetText("Select a profile or backup on the left, or save your current settings as a new profile.")

	local function SetButtons(list)
		for _, b in ipairs(detail.buttonPool) do b:Hide() end
		local prev
		for i, spec in ipairs(list) do
			local b = detail.buttonPool[i]
			if not b then
				b = UI.CreateButton(detail.buttons, "", "secondary", 90, 24)
				detail.buttonPool[i] = b
			end
			b:SetText(spec[1])
			b:SetWidth(math.max(70, b.label:GetStringWidth() + 24))
			b:SetScript("OnClick", spec[2])
			b:ClearAllPoints()
			if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT") end
			b:Show()
			prev = b
		end
	end

	local selectedCats = {}
	local function LayoutCategoryBoxes(cats)
		for _, cb in ipairs(detail.catBoxes) do cb:Hide() end
		local i, x, y = 0, 0, 0
		detail.cats:SetWidth(math.max(300, detail:GetWidth()))
		local width = math.max(300, detail:GetWidth() - 150)
		for _, cat in ipairs(ns.Categories.list) do
			local count = cats[cat.id]
			if count then
				i = i + 1
				local cb = detail.catBoxes[i]
				if not cb then
					cb = UI.CreateCheckbox(detail.cats, "")
					cb:SetWidth(170)
					detail.catBoxes[i] = cb
				end
				cb.label:SetText(("%s (%d)"):format(cat.name, count))
				if selectedCats[cat.id] == nil then selectedCats[cat.id] = true end
				cb:SetChecked(selectedCats[cat.id])
				local catId = cat.id
				cb.onChange = function(v) selectedCats[catId] = v; page:RefreshDetail() end
				if x + 170 > width then x, y = 0, y + 22 end
				cb:ClearAllPoints()
				cb:SetPoint("TOPLEFT", x, -y)
				cb:Show()
				x = x + 176
			end
		end
		detail.cats:SetHeight(i > 0 and (y + 22) or 1)
		detail.catLabel:SetShown(i > 0)
	end

	local function DiffItems(cmp)
		local items = {}
		for _, d in ipairs(cmp.diffs) do
			items[#items + 1] = { type = "diff", label = d.def.name, from = Values.Format(d.def, d.current), to = Values.Format(d.def, d.value) }
		end
		for _, id in ipairs(cmp.unknown) do
			items[#items + 1] = { type = "diff", label = id, from = "unknown or read-only here", toColor = "textDim" }
		end
		for _, x in ipairs(cmp.invalid) do
			items[#items + 1] = { type = "diff", label = x.id, from = "invalid: " .. tostring(x.reason), toColor = "error" }
		end
		for _, id in ipairs(cmp.unavailable) do
			items[#items + 1] = { type = "diff", label = id, from = "unavailable on this client", toColor = "textDim" }
		end
		return items
	end

	local function ValuesSource(item)
		if item.kind == "profile" then return Profiles:Get(item.name) end
		if item.kind == "backup" then return Backup:List()[item.index] end
		if item.kind == "originals" then
			local values = {}
			for id, o in pairs(ns.db.originals) do values[id] = o.value end
			return { name = "Original values", values = values }
		end
	end

	function page:RefreshDetail()
		local item = self.selected
		local source = item and ValuesSource(item)
		local show = source ~= nil
		for _, region in ipairs({ detail.name, detail.meta, detail.buttons, detail.cats, detail.catLabel, detail.summary, detail.stage, detail.diffs }) do
			region:SetShown(show)
		end
		detail.empty:SetShown(not show)
		if not show then return end

		local filter = {}
		local cats = Profiles:GetCategories(source)
		LayoutCategoryBoxes(cats)
		for id in pairs(cats) do if selectedCats[id] then filter[id] = true end end
		local cmp = Profiles:Compare(source, filter)
		detail.summary:SetText(("%d differ from your current settings, %d already match."):format(#cmp.diffs, cmp.same)
			.. ((#cmp.unknown + #cmp.invalid + #cmp.unavailable) > 0 and ("  %d entries will be skipped."):format(#cmp.unknown + #cmp.invalid + #cmp.unavailable) or ""))
		detail.diffs:SetItems(DiffItems(cmp))
		detail.stage:SetEnabled(#cmp.diffs > 0)
		detail.stage:SetScript("OnClick", function()
			local staged
			if item.kind == "profile" then
				staged = Profiles:StageApply(source, filter)
			else
				-- Backups and originals: stage only differences in the selected categories.
				local ids = {}
				for _, d in ipairs(cmp.diffs) do ids[d.def.id] = true end
				staged = item.kind == "backup" and Backup:StageRestore(source, ids) or Backup:StageOriginals(ids)
			end
			window:SetStatus(("%d change(s) staged. Review them, then press Apply."):format(staged or 0), "accent")
			page:RefreshDetail()
		end)

		detail.name:SetText(source.name or "?")
		if item.kind == "profile" then
			detail.meta:SetText(("Created %s  ·  Modified %s  ·  %d values  ·  build %s%s"):format(Util.FormatTime(source.created),
				Util.FormatTime(source.modified), Util.Count(source.values), tostring(source.build or "?"),
				Profiles:GetActive() == item.name and "  ·  active" or ""))
			detail.stage:SetText("Stage profile")
			local name = item.name
			SetButtons({
				{ "Set active", function() Profiles:SetActive(name) end },
				{ "Save current", function()
					UI.Confirm("Overwrite profile", ("Replace '%s' with your current settings?"):format(name), "Overwrite", function()
						Profiles:Save(name); window:SetStatus("Profile saved.", "success")
					end)
				end },
				{ "Rename", function()
					UI.Prompt("Rename profile", nil, name, "Rename", function(text)
						local p, err = Profiles:Rename(name, text)
						if not p then window:SetStatus(err, "error") return true end
						page.selected = { kind = "profile", name = p.name, key = "p:" .. p.name }
					end)
				end },
				{ "Duplicate", function()
					UI.Prompt("Duplicate profile", nil, name .. " copy", "Duplicate", function(text)
						local p, err = Profiles:Duplicate(name, text)
						if not p then window:SetStatus(err, "error") return true end
					end)
				end },
				{ "Export", function()
					UI.TextDialog("Export profile", "Copy this text (Ctrl+C) to share the profile. It contains setting values only.",
						Profiles:Export(name), "Close", nil, { noCancel = true, selectAll = true })
				end },
				{ "Delete", function()
					UI.Confirm("Delete profile", ("Delete '%s'? This cannot be undone."):format(name), "Delete", function()
						Profiles:Delete(name)
						page.selected = nil
					end)
				end },
			})
		elseif item.kind == "backup" then
			detail.meta:SetText(("Taken %s  ·  %d values  ·  build %s"):format(Util.FormatTime(source.time), Util.Count(source.values), tostring(source.build or "?")))
			detail.stage:SetText("Stage restore")
			local index = item.index
			SetButtons({
				{ "Delete backup", function()
					UI.Confirm("Delete backup", "Delete this backup? This cannot be undone.", "Delete", function()
						Backup:Delete(index)
						page.selected = nil
						page:Rebuild()
					end)
				end },
			})
		else
			detail.meta:SetText("Values each setting had before EverSettings changed it for the first time.")
			detail.stage:SetText("Stage originals")
			SetButtons({})
		end
	end

	function page:SelectItem(item)
		self.selected = item
		nav:RefreshVisible()
		self:RefreshDetail()
	end

	function page:Rebuild()
		local items = { { type = "group", label = "PROFILES" } }
		local active = Profiles:GetActive()
		for _, name in ipairs(Profiles:List()) do
			local p = Profiles:Get(name)
			items[#items + 1] = { type = "item", kind = "profile", name = name, key = "p:" .. name, label = name,
				meta = tostring(Util.Count(p.values)), active = name == active }
		end
		if #items == 1 then items[#items + 1] = { type = "item", kind = "none", key = "none", label = "No profiles yet", meta = "" } end
		items[#items + 1] = { type = "group", label = "BACKUPS" }
		local backups = Backup:List()
		for i = #backups, 1, -1 do
			local b = backups[i]
			items[#items + 1] = { type = "item", kind = "backup", index = i, key = "b:" .. i .. ":" .. tostring(b.time), label = b.name,
				meta = Util.FormatTime(b.time):sub(6) }
		end
		items[#items + 1] = { type = "group", label = "SAFETY" }
		items[#items + 1] = { type = "item", kind = "originals", key = "originals", label = "Original values", meta = tostring(Util.Count(ns.db.originals)) }
		nav:SetItems(items, true)
		if self.selected and self.selected.kind == "profile" and not Profiles:Get(self.selected.name) then self.selected = nil end
		self:RefreshDetail()
	end

	page.newButton:SetScript("OnClick", function()
		UI.Prompt("Save current settings", "Name for the new profile:", "", "Save", function(text)
			local p, err = Profiles:SaveAs(text)
			if not p then window:SetStatus(err, "error") return true end
			page.selected = { kind = "profile", name = p.name, key = "p:" .. p.name }
			window:SetStatus(("Profile '%s' saved with %d values."):format(p.name, Util.Count(p.values)), "success")
		end)
	end)

	page.importButton:SetScript("OnClick", function()
		UI.TextDialog("Import profile", "Paste an EverSettings profile string. It is validated against the local settings database; it can only contain setting values, never code.",
			"", "Import", function(text)
				local profile, report = Profiles:ParseImport(text)
				if not profile then
					window:SetStatus("Import failed: " .. tostring(report), "error")
					return true
				end
				local base = profile.name or "Imported"
				local name, n = base, 1
				while Profiles:Get(name) do n = n + 1; name = ("%s (%d)"):format(base, n) end
				Profiles:SaveImported(profile, name)
				page.selected = { kind = "profile", name = name, key = "p:" .. name }
				local msg = ("Imported '%s': %d values accepted"):format(name, report.accepted)
				if #report.rejected > 0 then msg = msg .. (", %d rejected (first: %s, %s)"):format(#report.rejected, report.rejected[1].id, report.rejected[1].reason) end
				window:SetStatus(msg, #report.rejected > 0 and "warning" or "success")
			end)
	end)

	function page:Open() self:Rebuild() end

	ns.Callbacks:Register("ProfilesChanged", page, function() if page:IsShown() then page:Rebuild() end end)
	ns.Callbacks:Register("PendingChanged", page, function() if page:IsShown() then page:RefreshDetail() end end)
	return page
end
