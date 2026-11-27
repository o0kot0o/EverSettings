-- Dropdown built from EverSettings' own frames (Blizzard's Menu system is avoided because
-- opening it from addon code can taint the controller UI on Forever).
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

local ROW_HEIGHT, MAX_ROWS = 24, 12
local popup, blocker

local function ClosePopup()
	if popup then popup:Hide() end
	if blocker then blocker:Hide() end
end
UI.CloseDropdown = ClosePopup

local function EnsurePopup()
	if popup then return popup end
	blocker = CreateFrame("Button", nil, UIParent)
	blocker:SetAllPoints(UIParent)
	blocker:SetFrameStrata("FULLSCREEN")
	blocker:RegisterForClicks("AnyUp")
	blocker:SetScript("OnClick", ClosePopup)
	blocker:Hide()

	popup = CreateFrame("Frame", nil, UIParent)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetClampedToScreen(true)
	UI.Background(popup, "section")
	UI.Border(popup, "borderStrong")
	popup.rows = {}
	popup.offset = 0
	popup:EnableMouseWheel(true)
	popup:SetScript("OnMouseWheel", function(self, delta)
		local maxOffset = math.max(0, #self.options - MAX_ROWS)
		self.offset = math.max(0, math.min(maxOffset, self.offset - delta))
		self:Render()
	end)
	popup:Hide()

	function popup:Render()
		for i = 1, math.min(#self.options, MAX_ROWS) do
			local row = self.rows[i]
			if not row then
				row = CreateFrame("Button", nil, self)
				row:SetHeight(ROW_HEIGHT)
				row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_HEIGHT)
				row:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * ROW_HEIGHT)
				row.hl = row:CreateTexture(nil, "BACKGROUND")
				row.hl:SetAllPoints()
				UI.SetColor(row.hl, Theme.colors.controlHover)
				row.hl:Hide()
				row.check = UI.Icon(row, "common-icon-checkmark", 12, "accent")
				row.check:SetPoint("LEFT", 8, 0)
				row.text = UI.Text(row, 12, "text")
				row.text:SetPoint("LEFT", 26, 0)
				row.text:SetPoint("RIGHT", -8, 0)
				row:SetScript("OnEnter", function(r)
					r.hl:Show()
					local opt = r.option
					if opt and (opt.description or opt.disabled or opt.warning) then
						UI.ShowTooltip(r, opt.label, opt.disabled or opt.warning or opt.description)
					end
				end)
				row:SetScript("OnLeave", function(r) r.hl:Hide(); UI.HideTooltip() end)
				row:SetScript("OnClick", function(r)
					local opt = r.option
					if opt.disabled or opt.notSelectable then return end
					local owner = popup.owner
					ClosePopup()
					if owner and owner.onSelect then owner.onSelect(opt.value) end
				end)
				self.rows[i] = row
			end
			local opt = self.options[i + self.offset]
			row.option = opt
			row.text:SetText(opt.label)
			local unavailable = opt.disabled or opt.notSelectable
			UI.SetTextColor(row.text, unavailable and "textDim" or (opt.warning and "warning" or "text"))
			row.check:SetShown(opt.value == self.selected)
			row:Show()
		end
		for i = math.min(#self.options, MAX_ROWS) + 1, #self.rows do self.rows[i]:Hide() end
	end
	return popup
end

function UI.CreateDropdown(parent, width)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 200, 24)
	b.bg = UI.Background(b, "control")
	b.border = UI.Border(b, "border")
	b.text = UI.Text(b, 12, "text")
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -24, 0)
	b.arrow = UI.Icon(b, "uitools-icon-chevron-down", 10, "textMuted")
	b.arrow:SetPoint("RIGHT", -8, 0)
	b.options = {}

	function b:SetOptions(options)
		self.options = options or {}
	end
	function b:SetValue(value)
		self.value = value
		for _, opt in ipairs(self.options) do
			if opt.value == value then
				self.text:SetText(opt.label)
				return
			end
		end
		self.text:SetText(value == nil and "—" or (tostring(value) .. " (undocumented)"))
	end
	function b:SetDropdownEnabled(enabled)
		self:SetEnabled(enabled)
		self:SetAlpha(enabled and 1 or 0.4)
	end
	b:SetScript("OnEnter", function(self) UI.SetColor(self.bg, Theme.colors.controlHover) end)
	b:SetScript("OnLeave", function(self) UI.SetColor(self.bg, Theme.colors.control) end)
	b:SetScript("OnHide", function(self) if popup and popup.owner == self then ClosePopup() end end)
	b:SetScript("OnClick", function(self)
		local p = EnsurePopup()
		if p:IsShown() and p.owner == self then ClosePopup() return end
		p.owner, p.options, p.selected, p.offset = self, self.options, self.value, 0
		local rows = math.min(#self.options, MAX_ROWS)
		p:SetSize(math.max(self:GetWidth(), 160), rows * ROW_HEIGHT + 2)
		p:ClearAllPoints()
		p:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		-- Scroll so the selected option is visible.
		for i, opt in ipairs(self.options) do
			if opt.value == self.value and i > MAX_ROWS then p.offset = math.min(i - 1, #self.options - MAX_ROWS) end
		end
		p:Render()
		blocker:Show()
		p:Show()
	end)
	return b
end
