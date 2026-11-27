-- Flat buttons: primary (accent), secondary (neutral), ghost (text only) and icon buttons.
-- Disabled buttons of every style share one neutral look so enabled and disabled actions
-- are clearly distinguishable (a disabled Apply is grey, not dimmed teal).
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

local STYLES = {
	primary   = { bg = "accent", hover = "accentHover", text = "onAccent", border = nil },
	secondary = { bg = "control", hover = "controlHover", text = "text", border = "border" },
	ghost     = { bg = nil, hover = "control", text = "textMuted", hoverText = "text", border = nil },
	danger    = { bg = "control", hover = "controlHover", text = "error", border = "border" },
}

-- icon (optional): EverSettings icon name shown before the label.
function UI.CreateButton(parent, text, style, width, height, icon)
	local s = STYLES[style or "secondary"]
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 90, height or 28)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	if s.border then b.border = UI.Border(b, s.border) end
	b.label = UI.Text(b, "button", s.text, "CENTER")
	if icon then
		b.icon = UI.Icon(b, icon, 14, s.text)
		b.icon:SetPoint("LEFT", 10, 0)
		b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
		b.label:SetPoint("RIGHT", -10, 0)
		b.label:SetJustifyH("LEFT")
	else
		b.label:SetPoint("LEFT", 8, 0)
		b.label:SetPoint("RIGHT", -8, 0)
	end
	b.label:SetText(text or "")
	b.style = s

	function b:Refresh()
		local enabled = self:IsEnabled()
		local bgKey, textKey
		if not enabled then
			bgKey = s.bg and "controlDisabled" or nil
			textKey = "textDisabled"
		elseif self.selected then
			bgKey, textKey = "accentDim", "accent"
		elseif self.hovered then
			bgKey, textKey = s.hover, s.hoverText or s.text
		else
			bgKey, textKey = s.bg, s.text
		end
		if bgKey then
			UI.SetColor(self.bg, bgKey)
			self.bg:Show()
		else
			self.bg:Hide()
		end
		UI.SetTextColor(self.label, textKey)
		if self.icon then UI.SetIconColor(self.icon, textKey) end
		if self.border then self.border:SetColor(enabled and s.border or "border") end
	end
	function b:SetText(t) self.label:SetText(t) end
	function b:GetText() return self.label:GetText() end
	function b:SetSelected(v) self.selected = v and true or false; self:Refresh() end
	-- Width that fits the label (and icon).
	function b:FitWidth(min)
		local w = self.label:GetStringWidth() + (self.icon and 40 or 28)
		self:SetWidth(math.max(min or 0, w))
	end

	b:SetScript("OnEnter", function(self) self.hovered = true; self:Refresh() end)
	b:SetScript("OnLeave", function(self) self.hovered = false; self:Refresh() end)
	b:SetScript("OnEnable", b.Refresh)
	b:SetScript("OnDisable", b.Refresh)
	b:Refresh()
	return b
end

function UI.CreateIconButton(parent, icon, size, tooltip, colorKey)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size + 12, size + 12)
	b.hover = b:CreateTexture(nil, "BACKGROUND")
	b.hover:SetAllPoints()
	UI.SetColor(b.hover, "control")
	b.hover:Hide()
	b.icon = UI.Icon(b, icon, size, colorKey or "textMuted")
	b.icon:SetPoint("CENTER")
	b.colorKey = colorKey or "textMuted"
	function b:SetIconColor(key)
		self.colorKey = key
		UI.SetIconColor(self.icon, key)
	end
	b:SetScript("OnEnter", function(self)
		if self:IsEnabled() then
			self.hover:Show()
			UI.SetIconColor(self.icon, "text")
		end
		if tooltip then UI.ShowTooltip(self, tooltip) end
	end)
	b:SetScript("OnLeave", function(self)
		self.hover:Hide()
		UI.SetIconColor(self.icon, self.colorKey)
		UI.HideTooltip()
	end)
	b:SetScript("OnEnable", function(self) self.icon:SetAlpha(1) end)
	b:SetScript("OnDisable", function(self) self.icon:SetAlpha(0.3); self.hover:Hide() end)
	return b
end

-- Simple checkbox with label (used in dialogs and the profiles page, not for settings).
function UI.CreateCheckbox(parent, text)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(200, 22)
	b.box = CreateFrame("Frame", nil, b)
	b.box:SetSize(16, 16)
	b.box:SetPoint("LEFT")
	UI.Background(b.box, "input")
	b.boxBorder = UI.Border(b.box, "borderStrong")
	b.check = UI.Icon(b.box, "common-icon-checkmark", 12, "accent")
	b.check:SetPoint("CENTER")
	b.label = UI.Text(b, "body", "text")
	b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
	b.label:SetText(text or "")
	b.checked = false
	function b:SetChecked(v)
		self.checked = v and true or false
		self.check:SetShown(self.checked)
		self.boxBorder:SetColor(self.checked and "accent" or "borderStrong")
	end
	function b:GetChecked() return self.checked end
	b:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		if self.onChange then self.onChange(self.checked) end
	end)
	b:SetChecked(false)
	return b
end
