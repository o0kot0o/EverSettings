-- On/Off switch: rounded track, round knob, and an explicit "On"/"Off" label.
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

function UI.CreateToggle(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(40, 22)
	b.track = UI.Icon(b, "pill", 40, "track", "BACKGROUND")
	b.track:SetSize(40, 20)
	b.track:SetPoint("CENTER")
	b.knob = UI.Icon(b, "knob", 26, "text", "ARTWORK")
	b.label = UI.Text(b, "label", "textMuted", "RIGHT")
	b.label:SetPoint("RIGHT", b, "LEFT", -10, 0)
	b.checked = false

	function b:UpdateVisual()
		local enabled = self:IsEnabled()
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint("CENTER", self, "RIGHT", -11, 0)
			UI.SetIconColor(self.track, enabled and (self.hovered and "accentHover" or "accent") or "textDisabled")
			self.label:SetText("On")
			UI.SetTextColor(self.label, enabled and "accent" or "textDisabled")
		else
			self.knob:SetPoint("CENTER", self, "LEFT", 11, 0)
			UI.SetIconColor(self.track, enabled and (self.hovered and "textDim" or "track") or "controlDisabled")
			self.label:SetText("Off")
			UI.SetTextColor(self.label, enabled and "textMuted" or "textDisabled")
		end
		UI.SetIconColor(self.knob, enabled and "text" or "textDim")
	end
	function b:SetChecked(v)
		self.checked = v and true or false
		self:UpdateVisual()
	end
	function b:GetChecked() return self.checked end
	function b:SetToggleEnabled(enabled)
		self:SetEnabled(enabled)
		self:UpdateVisual()
	end
	b:SetScript("OnEnter", function(self) self.hovered = true; self:UpdateVisual() end)
	b:SetScript("OnLeave", function(self) self.hovered = false; self:UpdateVisual() end)
	b:SetScript("OnClick", function(self)
		if self.onToggle then self.onToggle(not self.checked) end
	end)
	b:SetChecked(false)
	return b
end
