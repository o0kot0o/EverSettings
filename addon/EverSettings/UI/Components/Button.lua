-- Flat buttons: primary (accent), secondary (neutral), ghost (text only) and icon buttons.
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

local STYLES = {
	primary   = { bg = "accent", hover = "accentHover", text = "window", border = nil },
	secondary = { bg = "control", hover = "controlHover", text = "text", border = "border" },
	ghost     = { bg = nil, hover = "control", text = "textMuted", border = nil },
	danger    = { bg = "control", hover = "controlHover", text = "error", border = "border" },
}

function UI.CreateButton(parent, text, style, width, height)
	style = STYLES[style or "secondary"]
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 90, height or 26)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	if style.border then b.border = UI.Border(b, style.border) end
	b.label = UI.Text(b, 12, style.text == "window" and "window" or style.text, "CENTER")
	b.label:SetPoint("LEFT", 8, 0)
	b.label:SetPoint("RIGHT", -8, 0)
	b.label:SetText(text or "")
	b.style = style

	function b:Refresh()
		local enabled = self:IsEnabled()
		local key = (self.hovered and enabled) and style.hover or style.bg
		if key then
			UI.SetColor(self.bg, Theme.colors[key])
			self.bg:Show()
		else
			self.bg:Hide()
		end
		self.label:SetAlpha(enabled and 1 or 0.4)
		self.bg:SetAlpha(enabled and 1 or 0.5)
	end
	function b:SetText(t) self.label:SetText(t) end
	function b:GetText() return self.label:GetText() end

	b:SetScript("OnEnter", function(self) self.hovered = true; self:Refresh() end)
	b:SetScript("OnLeave", function(self) self.hovered = false; self:Refresh() end)
	b:SetScript("OnEnable", b.Refresh)
	b:SetScript("OnDisable", b.Refresh)
	b:Refresh()
	return b
end

function UI.CreateIconButton(parent, atlas, size, tooltip, colorKey)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size + 10, size + 10)
	b.hover = b:CreateTexture(nil, "BACKGROUND")
	b.hover:SetAllPoints()
	UI.SetColor(b.hover, Theme.colors.control)
	b.hover:Hide()
	b.icon = UI.Icon(b, atlas, size, colorKey or "textMuted")
	b.icon:SetPoint("CENTER")
	b.colorKey = colorKey or "textMuted"
	function b:SetIconColor(key)
		self.colorKey = key
		local c = Theme.colors[key] or key
		self.icon:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	end
	b:SetScript("OnEnter", function(self)
		if self:IsEnabled() then self.hover:Show() end
		if tooltip then UI.ShowTooltip(self, tooltip) end
	end)
	b:SetScript("OnLeave", function(self) self.hover:Hide(); UI.HideTooltip() end)
	b:SetScript("OnEnable", function(self) self.icon:SetAlpha(1) end)
	b:SetScript("OnDisable", function(self) self.icon:SetAlpha(0.3); self.hover:Hide() end)
	return b
end

-- Simple checkbox with label (used in dialogs and the profiles page, not for settings).
function UI.CreateCheckbox(parent, text)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(200, 20)
	b.box = CreateFrame("Frame", nil, b)
	b.box:SetSize(14, 14)
	b.box:SetPoint("LEFT")
	UI.Background(b.box, "input")
	b.boxBorder = UI.Border(b.box, "borderStrong")
	b.check = UI.Icon(b.box, "common-icon-checkmark", 12, "accent")
	b.check:SetPoint("CENTER")
	b.label = UI.Text(b, 12, "text")
	b.label:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
	b.label:SetText(text or "")
	b.checked = false
	function b:SetChecked(v)
		self.checked = v and true or false
		self.check:SetShown(self.checked)
	end
	function b:GetChecked() return self.checked end
	b:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		if self.onChange then self.onChange(self.checked) end
	end)
	b:SetChecked(false)
	return b
end
