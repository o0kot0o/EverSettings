-- On/Off switch.
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

function UI.CreateToggle(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(36, 18)
	b.track = b:CreateTexture(nil, "BACKGROUND")
	b.track:SetAllPoints()
	b.knob = b:CreateTexture(nil, "ARTWORK")
	b.knob:SetSize(14, 14)
	UI.SetColor(b.knob, Theme.colors.text)
	b.label = UI.Text(b, 11, "textMuted", "RIGHT")
	b.label:SetPoint("RIGHT", b, "LEFT", -8, 0)
	b.checked = false

	function b:SetChecked(v)
		self.checked = v and true or false
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint("RIGHT", -2, 0)
			UI.SetColor(self.track, Theme.colors.accent)
			self.label:SetText("On")
		else
			self.knob:SetPoint("LEFT", 2, 0)
			UI.SetColor(self.track, Theme.colors.track)
			self.label:SetText("Off")
		end
	end
	function b:GetChecked() return self.checked end
	function b:SetToggleEnabled(enabled)
		self:SetEnabled(enabled)
		self:SetAlpha(enabled and 1 or 0.4)
	end
	b:SetScript("OnClick", function(self)
		if self.onToggle then self.onToggle(not self.checked) end
	end)
	b:SetChecked(false)
	return b
end
