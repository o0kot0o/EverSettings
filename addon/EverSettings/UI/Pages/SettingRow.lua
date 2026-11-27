-- One settings row.
--
--   [pending bar][modified dot][star] Name  technical  BADGES              [control][unit] [reset]
--                                     Description, up to two lines
--
-- Controls share one right-aligned column whose width depends only on the list width, so
-- slider and edit-box widths are identical across rows. The active control is never hidden
-- or re-created during a refresh (hiding a slider cancels a drag in progress).
local _, ns = ...

local Theme, UI, L = ns.Theme, ns.UI, ns.L
local Values, Providers, Changes = ns.Values, ns.Providers, ns.Changes
local M = Theme.metrics

local APPLY_BADGES = { restart = "RESTART", reload = "RELOAD", gxrestart = "GX RESTART" }
local TEXT_LEFT = 46
local RIGHT_RESERVE = 8 + 26 + 10 -- reset button and gaps to the right of the control column

-- Row descriptions are short, so errors are kept compact ("Allowed 0.3 to 2.8").
function UI.FormatError(message)
	message = tostring(message or "invalid value")
	return message:sub(1, 1):upper() .. message:sub(2)
end

local function EnsureControl(r, kind)
	if r.controls[kind] then return r.controls[kind] end
	local c
	local alignRight = -(M.unitWidth + 4) -- line toggles/dropdowns up with the edit boxes
	if kind == "slider" then
		c = UI.CreateNumericControl(r.controlArea)
		c:SetPoint("RIGHT")
	elseif kind == "toggle" then
		c = UI.CreateToggle(r.controlArea)
		c:SetPoint("RIGHT", alignRight, 0)
	elseif kind == "dropdown" then
		c = UI.CreateDropdown(r.controlArea, M.sliderWide + 10 + M.editWidth)
		c:SetPoint("RIGHT", alignRight, 0)
	elseif kind == "value" then
		c = UI.Text(r.controlArea, "body", "textMuted", "RIGHT")
		c:SetPoint("RIGHT", alignRight, 0)
	end
	r.controls[kind] = c
	return c
end

function UI.CreateSettingRow(list)
	local r = CreateFrame("Button", nil, list)
	r:RegisterForClicks("LeftButtonUp")
	r.hl = r:CreateTexture(nil, "BACKGROUND")
	r.hl:SetAllPoints()
	r.pendingBar = r:CreateTexture(nil, "ARTWORK")
	r.pendingBar:SetPoint("TOPLEFT", 0, -6)
	r.pendingBar:SetPoint("BOTTOMLEFT", 0, 6)
	r.pendingBar:SetWidth(3)
	UI.SetColor(r.pendingBar, "warning")
	r.modifiedDot = UI.Icon(r, "dot", 8, "accent")
	r.modifiedDot:SetPoint("TOPLEFT", 10, -15)
	r.divider = UI.Line(r, "border", true)
	r.divider:SetPoint("BOTTOMLEFT", 16, 0)
	r.divider:SetPoint("BOTTOMRIGHT", -16, 0)

	r.fav = CreateFrame("Button", nil, r)
	r.fav:SetSize(20, 20)
	r.fav:SetPoint("TOPLEFT", 20, -9)
	r.fav.icon = UI.Icon(r.fav, "star", 14, "textDim")
	r.fav.icon:SetPoint("CENTER")
	r.fav:SetScript("OnClick", function()
		local id = r.def and r.def.id
		if not id then return end
		ns.db.favorites[id] = (not ns.db.favorites[id]) or nil
		ns.Callbacks:Fire("FavoritesChanged")
	end)
	r.fav:SetScript("OnEnter", function(self)
		r.hovered = true
		r:UpdateHighlight()
		UI.ShowTooltip(self, ns.db.favorites[r.def.id] and "Remove from favorites" or "Add to favorites")
	end)
	r.fav:SetScript("OnLeave", function() UI.HideTooltip(); r:CheckHover() end)

	r.name = UI.Text(r, "settingName", "text")
	r.name:SetPoint("TOPLEFT", TEXT_LEFT, -12)
	r.technical = UI.Text(r, "technical", "textDim")
	r.badges = {}
	for i = 1, 3 do
		local b = UI.CreateBadge(r)
		b:Hide()
		r.badges[i] = b
	end
	r.lock = UI.Icon(r, "lock", 12, "warning")
	r.lock:SetPoint("TOPLEFT", TEXT_LEFT, -33)

	r.reset = UI.CreateIconButton(r, "reset", 14, nil)
	r.reset:SetPoint("RIGHT", -8, 0)
	UI.AttachTooltip(r.reset, function()
		local def = r.def
		local d = def and Providers:GetDefault(def)
		return L.RESET, d ~= nil and ("Factory default: " .. Values.Format(def, d)) or "No known default"
	end)
	r.reset:HookScript("OnEnter", function() r.hovered = true; r:UpdateHighlight() end)
	r.reset:HookScript("OnLeave", function() r:CheckHover() end)

	r.controlArea = CreateFrame("Frame", nil, r)
	r.controlArea:SetHeight(28)
	r.controlArea:SetPoint("RIGHT", -RIGHT_RESERVE, 0)
	r.controls = {}

	r.desc = UI.Text(r, "settingDesc", "textMuted")
	r.desc:SetWordWrap(true)
	r.desc:SetMaxLines(2)
	r.desc:SetJustifyV("TOP")
	r.desc:SetSpacing(2)

	r:SetScript("OnEnter", function(self)
		self.hovered = true
		self:UpdateHighlight()
		-- Full description when the visible text had to be shortened.
		if self.def and self.desc:IsTruncated() then
			UI.ShowTooltip(self, self.def.name, self.def.description, "ANCHOR_CURSOR")
		end
	end)
	r:SetScript("OnLeave", function(self)
		UI.HideTooltip()
		self:CheckHover()
	end)
	r:SetScript("OnClick", function(self)
		if self.page and self.def then self.page:Select(self.def.id) end
	end)
	r:SetScript("OnDoubleClick", function(self)
		if self.page and self.def then
			self.page:Select(self.def.id)
			self.page.window:SetInspectorShown(true)
		end
	end)

	-- Hover persists while the cursor is over a child (star, reset, controls).
	function r:CheckHover()
		self.hovered = self:IsMouseOver() and true or false
		self:UpdateHighlight()
	end

	function r:UpdateHighlight()
		local selected = self.page and self.def and self.page.selectedId == self.def.id
		if selected then
			UI.SetColor(self.hl, "rowSelected")
			self.hl:Show()
		elseif self.hovered then
			UI.SetColor(self.hl, "rowHover")
			self.hl:Show()
		else
			self.hl:Hide()
		end
		local fav = self.def and ns.db.favorites[self.def.id]
		self.fav:SetAlpha((fav or self.hovered or selected) and 1 or 0)
	end
	return r
end

local function LayoutTitleLine(r, badges)
	-- Technical name (optional), then badges, after the name.
	local anchor, gap = r.name, 8
	local nameWidth = math.min(r.name:GetStringWidth(), r.name:GetWidth() or 9999)
	if r.technical:IsShown() then
		r.technical:ClearAllPoints()
		r.technical:SetPoint("LEFT", r.name, "LEFT", nameWidth + 8, 0)
		anchor, gap = r.technical, 8
	end
	for i, b in ipairs(r.badges) do
		local entry = badges[i]
		if entry then
			b:Set(entry[1], entry[2])
			b:ClearAllPoints()
			if i == 1 then
				if anchor == r.name then
					b:SetPoint("LEFT", r.name, "LEFT", nameWidth + gap, 0)
				else
					b:SetPoint("LEFT", anchor, "LEFT", math.min(anchor:GetStringWidth(), 220) + gap, 0)
				end
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
	-- Explicit branch: `available and Get() or nil` would turn a false value into nil.
	local current
	if available then current = Providers:Get(def) end
	local modified = current ~= nil and default ~= nil and not Values.Equal(def, current, default)
	local editable = available and not restriction
	local restricted = available and restriction and def.control ~= "readonly"

	-- Responsive column: same width on every row for a given list width.
	local controlWidth, sliderWidth = Theme.ControlWidth(list:GetWidth())
	r.controlArea:SetWidth(controlWidth)
	local textRight = -(RIGHT_RESERVE + controlWidth + 16)

	-- Name, technical name, indicators -----------------------------------------------
	r.name:ClearAllPoints()
	r.name:SetPoint("TOPLEFT", TEXT_LEFT, -12)
	r.name:SetPoint("TOPRIGHT", r, "TOPRIGHT", textRight, -12)
	r.name:SetText(def.name)
	UI.SetTextColor(r.name, available and "text" or "textDim")
	local showTech = ns.db.ui.showTechnical and def.technical and def.technical ~= ""
	r.technical:SetShown(showTech and true or false)
	if showTech then r.technical:SetText(def.technical) end
	local fav = ns.db.favorites[def.id]
	UI.SetIcon(r.fav.icon, fav and "star-filled" or "star", fav and "warning" or "textDim")
	r.pendingBar:SetShown(isPending)
	r.modifiedDot:SetShown(modified and not isPending)

	-- Badges ---------------------------------------------------------------------------
	local badges = {}
	if isPending then badges[#badges + 1] = { "PENDING", "warning" } end
	-- Values outside the researched range (set by another addon or the console) are flagged.
	if type(effective) == "number" and (def.control == "slider") then
		local lo, hi = Providers:GetRange(def)
		if lo and (effective < lo - 1e-9 or effective > hi + 1e-9) then
			local ext = def.extendedRange
			if ext and effective >= ext.min - 1e-9 and effective <= ext.max + 1e-9 then
				badges[#badges + 1] = { "EXTENDED", "warning" }
			else
				badges[#badges + 1] = { "OUT OF RANGE", "error" }
			end
		end
	end
	local status = def.statusSummary
	if status ~= "source" and status ~= "verified" then
		badges[#badges + 1] = { Theme.statusLabels[status] or status:upper(), status }
	end
	if APPLY_BADGES[def.apply] then badges[#badges + 1] = { APPLY_BADGES[def.apply], "info" } end
	if def.classification == "hidden" and #badges < 3 then badges[#badges + 1] = { "HIDDEN", "textMuted" } end
	LayoutTitleLine(r, badges)

	-- Description / error / restriction --------------------------------------------------
	r.lock:SetShown(restricted and true or false)
	r.desc:ClearAllPoints()
	r.desc:SetPoint("TOPLEFT", TEXT_LEFT + (restricted and 17 or 0), -31)
	r.desc:SetPoint("TOPRIGHT", r, "TOPRIGHT", textRight, -31)
	local err = page and page.errors[def.id]
	if err then
		r.desc:SetText(err)
		UI.SetTextColor(r.desc, "error")
	elseif not available then
		r.desc:SetText(unavailableReason or "Unavailable on this client.")
		UI.SetTextColor(r.desc, "textDim")
	elseif restricted then
		r.desc:SetText(restriction)
		UI.SetTextColor(r.desc, "warning")
	else
		r.desc:SetText(def.description)
		UI.SetTextColor(r.desc, "textMuted")
	end

	-- Control ------------------------------------------------------------------------------
	local kind = def.control
	local active
	if not available or kind == "readonly" or kind == "number" or kind == "text" then
		active = "value"
	elseif kind == "slider" then
		active = Providers:GetRange(def) and "slider" or "value"
	else
		active = kind
	end
	for name, c in pairs(r.controls) do
		if name ~= active then c:Hide() end
	end
	local function commit(value)
		local ok, verr = Values.Validate(def, value)
		if not ok then
			page.errors[def.id] = UI.FormatError(verr)
			UI.UpdateSettingRow(r, item, list)
			return
		end
		page.errors[def.id] = nil
		Changes:Stage(def, value)
	end

	if active == "value" then
		local c = EnsureControl(r, "value")
		local text = current ~= nil and Values.Format(def, current) or "—"
		if available and kind == "slider" then text = text .. "  (range unavailable)" end
		c:SetText(text)
		c:Show()
	elseif active == "slider" then
		local c = EnsureControl(r, "slider")
		local lo, hi, step = Providers:GetRange(def)
		local ext = def.extendedRange
		local sliderLo, sliderHi = lo, hi
		if ext then
			sliderLo, sliderHi = math.min(lo, ext.min), math.max(hi, ext.max)
			c:SetExtended(hi, ("Blizzard's slider stops at %s. Values up to %s are an extended range: %s")
				:format(Values.Format(def, hi), Values.Format(def, sliderHi), ext.source))
		else
			c:SetExtended(nil, nil)
		end
		c:SetSliderWidth(sliderWidth)
		c:SetUnit(def.suffix and ns.Util.Trim(def.suffix) or "")
		c:Setup(def, sliderLo, sliderHi, step, commit, function(message)
			page.errors[def.id] = message and UI.FormatError(message) or nil
			r.desc:SetText(message and page.errors[def.id] or def.description)
			UI.SetTextColor(r.desc, message and "error" or "textMuted")
		end)
		c:SetValue(effective)
		c:SetEnabled(editable)
		c:Show()
	elseif active == "toggle" then
		local c = EnsureControl(r, "toggle")
		c:SetChecked(effective and true or false)
		c:SetToggleEnabled(editable)
		c.onToggle = commit
		c:Show()
	elseif active == "dropdown" then
		local c = EnsureControl(r, "dropdown")
		c:SetWidth(sliderWidth + 10 + M.editWidth)
		c:SetOptions(Providers:GetOptions(def))
		c:SetValue(effective)
		c:SetDropdownEnabled(editable)
		c.onSelect = commit
		c:Show()
	end

	-- Reset: only offered when it would change something ------------------------------------
	local canReset = editable and kind ~= "readonly" and def.provider ~= "diagnostic"
		and default ~= nil and not Values.Equal(def, effective, default)
	r.reset:SetShown(canReset and true or false)
	r.reset:SetEnabled(canReset and true or false)
	r.reset:SetScript("OnClick", function()
		page.errors[def.id] = nil
		Changes:StageDefault(def)
	end)

	r:UpdateHighlight()
end
