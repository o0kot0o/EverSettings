-- One settings row: favorite star, name and badges, one-line description, the correct
-- control for the setting, an individual reset button and a modified/pending indicator.
local _, ns = ...

local Theme, UI, L = ns.Theme, ns.UI, ns.L
local Values, Providers, Changes = ns.Values, ns.Providers, ns.Changes

local APPLY_BADGES = { restart = "RESTART", reload = "RELOAD", gxrestart = "GX RESTART" }

local function EnsureControl(r, kind)
	if r.controls[kind] then return r.controls[kind] end
	local c
	if kind == "slider" then
		c = UI.CreateNumericControl(r.controlArea)
		c:SetPoint("RIGHT")
	elseif kind == "toggle" then
		c = UI.CreateToggle(r.controlArea)
		c:SetPoint("RIGHT", -2, 0)
	elseif kind == "dropdown" then
		c = UI.CreateDropdown(r.controlArea, 220)
		c:SetPoint("RIGHT")
	elseif kind == "value" then
		c = UI.Text(r.controlArea, 12, "textMuted", "RIGHT")
		c:SetPoint("RIGHT", -2, 0)
		c:SetWidth(r.controlArea:GetWidth())
	end
	r.controls[kind] = c
	return c
end

function UI.CreateSettingRow(list)
	local r = CreateFrame("Button", nil, list)
	r:RegisterForClicks("LeftButtonUp")
	r.hl = r:CreateTexture(nil, "BACKGROUND")
	r.hl:SetAllPoints()
	r.state = r:CreateTexture(nil, "ARTWORK")
	r.state:SetPoint("TOPLEFT", 0, -6)
	r.state:SetPoint("BOTTOMLEFT", 0, 6)
	r.state:SetWidth(3)
	r.divider = UI.Line(r, "border", true)
	r.divider:SetPoint("BOTTOMLEFT", 12, 0)
	r.divider:SetPoint("BOTTOMRIGHT", -12, 0)

	r.fav = CreateFrame("Button", nil, r)
	r.fav:SetSize(18, 18)
	r.fav:SetPoint("LEFT", 10, 0)
	r.fav.icon = UI.Icon(r.fav, "auctionhouse-icon-favorite-off", 13, "textDim")
	r.fav.icon:SetPoint("CENTER")
	r.fav:SetScript("OnClick", function()
		local id = r.def and r.def.id
		if not id then return end
		ns.db.favorites[id] = (not ns.db.favorites[id]) or nil
		ns.Callbacks:Fire("FavoritesChanged")
	end)
	UI.AttachTooltip(r.fav, function() return ns.db.favorites[r.def.id] and "Remove from favorites" or "Add to favorites" end)

	r.name = UI.Text(r, 13, "text")
	r.name:SetPoint("TOPLEFT", 34, -9)
	r.badges = {}
	for i = 1, 3 do
		local b = UI.CreateBadge(r)
		b:Hide()
		r.badges[i] = b
	end

	r.reset = UI.CreateIconButton(r, "uitools-icon-refresh", 12, nil)
	r.reset:SetPoint("RIGHT", -8, 0)
	UI.AttachTooltip(r.reset, function()
		local def = r.def
		local d = def and Providers:GetDefault(def)
		return L.RESET, d ~= nil and ("Factory default: " .. Values.Format(def, d)) or "No known default"
	end)

	r.controlArea = CreateFrame("Frame", nil, r)
	r.controlArea:SetSize(Theme.metrics.controlWidth, 24)
	r.controlArea:SetPoint("RIGHT", r.reset, "LEFT", -8, 0)
	r.controls = {}

	-- Text spans from the star to the control area. Both anchors share the same top edge so the
	-- font string's height comes from its text (a plain RIGHT anchor would over-constrain it).
	local textRight = -(8 + 22 + 8 + Theme.metrics.controlWidth + 16)
	r.desc = UI.Text(r, 11, "textMuted")
	r.desc:SetPoint("TOPLEFT", 34, -29)
	r.desc:SetPoint("TOPRIGHT", r, "TOPRIGHT", textRight, -29)
	r.name:SetPoint("TOPRIGHT", r, "TOPRIGHT", textRight, -9)

	r:SetScript("OnEnter", function(self) self.hovered = true; self:UpdateHighlight() end)
	r:SetScript("OnLeave", function(self) self.hovered = false; self:UpdateHighlight() end)
	r:SetScript("OnClick", function(self)
		if self.page and self.def then self.page:Select(self.def.id) end
	end)

	function r:UpdateHighlight()
		local selected = self.page and self.def and self.page.selectedId == self.def.id
		if selected then
			UI.SetColor(self.hl, Theme.colors.rowSelected)
			self.hl:Show()
		elseif self.hovered then
			UI.SetColor(self.hl, Theme.colors.rowHover)
			self.hl:Show()
		else
			self.hl:Hide()
		end
	end
	return r
end

local function SetBadges(r, list)
	local x = nil
	for i, b in ipairs(r.badges) do
		local entry = list[i]
		if entry then
			b:Set(entry[1], entry[2])
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint("LEFT", r.name, "LEFT", math.min(r.name:GetStringWidth(), r.name:GetWidth() or 9999) + 8, 0)
			else
				b:SetPoint("LEFT", r.badges[i - 1], "RIGHT", 4, 0)
			end
		else
			b:Hide()
		end
	end
end

function UI.UpdateSettingRow(r, item, list)
	local def = item.def
	local page = list.page
	r.def, r.page = def, page

	local effective, isPending = Changes:GetEffective(def)
	local available, unavailableReason = Providers:IsAvailable(def)
	local restriction = Providers:GetRestriction(def)
	local default = Providers:GetDefault(def)
	local current = available and Providers:Get(def) or nil
	local modified = current ~= nil and default ~= nil and not Values.Equal(def, current, default)
	local editable = available and not restriction

	-- Name, favorite, indicator ------------------------------------------------
	r.name:SetText(def.name)
	UI.SetTextColor(r.name, available and "text" or "textDim")
	local fav = ns.db.favorites[def.id]
	UI.SetIcon(r.fav.icon, fav and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off", fav and "warning" or "textDim")
	if isPending then
		UI.SetColor(r.state, Theme.colors.warning)
		r.state:Show()
	elseif modified then
		UI.SetColor(r.state, Theme.colors.accent)
		r.state:Show()
	else
		r.state:Hide()
	end

	-- Badges -------------------------------------------------------------------
	local badges = {}
	if isPending then badges[#badges + 1] = { "PENDING", "warning" } end
	local status = def.statusSummary
	if status ~= "source" and status ~= "verified" then
		badges[#badges + 1] = { Theme.statusLabels[status] or status:upper(), status }
	end
	if APPLY_BADGES[def.apply] then badges[#badges + 1] = { APPLY_BADGES[def.apply], "info" } end
	if def.classification == "hidden" and #badges < 3 then badges[#badges + 1] = { "HIDDEN", "textMuted" } end
	SetBadges(r, badges)

	-- Description / error / restriction -------------------------------------------
	local err = page and page.errors[def.id]
	if err then
		r.desc:SetText(err)
		UI.SetTextColor(r.desc, "error")
	elseif not available then
		r.desc:SetText(unavailableReason or "Unavailable on this client.")
		UI.SetTextColor(r.desc, "textDim")
	elseif restriction and def.control ~= "readonly" then
		r.desc:SetText(restriction)
		UI.SetTextColor(r.desc, "warning")
	else
		r.desc:SetText(def.description)
		UI.SetTextColor(r.desc, "textMuted")
	end

	-- Control ----------------------------------------------------------------------
	for _, c in pairs(r.controls) do c:Hide() end
	local kind = def.control
	local function commit(value)
		local ok, verr = Values.Validate(def, value)
		if not ok then
			page.errors[def.id] = "Invalid value: " .. tostring(verr)
			UI.UpdateSettingRow(r, item, list)
			return
		end
		page.errors[def.id] = nil
		Changes:Stage(def, value)
	end

	if not available or kind == "readonly" or kind == "number" or kind == "text" then
		local c = EnsureControl(r, "value")
		c:SetText(current ~= nil and Values.Format(def, current) or "—")
		c:Show()
	elseif kind == "slider" then
		local c = EnsureControl(r, "slider")
		local lo, hi, step = Providers:GetRange(def)
		if lo then
			c:Setup(def, lo, hi, step, commit, function(message)
				page.errors[def.id] = message and ("Invalid value: " .. message) or nil
				r.desc:SetText(message and page.errors[def.id] or def.description)
				UI.SetTextColor(r.desc, message and "error" or "textMuted")
			end)
			c:SetValue(effective)
			c:SetEnabled(editable)
			c:Show()
		else
			local v = EnsureControl(r, "value")
			v:SetText((current ~= nil and Values.Format(def, current) or "—") .. "  (range unavailable)")
			v:Show()
		end
	elseif kind == "toggle" then
		local c = EnsureControl(r, "toggle")
		c:SetChecked(effective and true or false)
		c:SetToggleEnabled(editable)
		c.onToggle = commit
		c:Show()
	elseif kind == "dropdown" then
		local c = EnsureControl(r, "dropdown")
		c:SetOptions(Providers:GetOptions(def))
		c:SetValue(effective)
		c:SetDropdownEnabled(editable)
		c.onSelect = commit
		c:Show()
	end

	-- Reset ---------------------------------------------------------------------------
	local canReset = editable and kind ~= "readonly" and default ~= nil and not Values.Equal(def, effective, default)
	r.reset:SetEnabled(canReset)
	r.reset:SetShown(kind ~= "readonly" and def.provider ~= "diagnostic")
	r.reset:SetScript("OnClick", function()
		page.errors[def.id] = nil
		Changes:StageDefault(def)
	end)

	r:UpdateHighlight()
end
