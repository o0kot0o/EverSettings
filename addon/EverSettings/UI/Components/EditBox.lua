-- Single-line edit boxes and the header search box.
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

-- Focus shows a 2px accent ring; errors a 2px red ring.
function UI.CreateEditBox(parent, width, height, justify)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width or 120, height or 26)
	e:SetAutoFocus(false)
	e:SetFontObject(Theme:RoleFont("input", "text"))
	e:SetJustifyH(justify or "LEFT")
	e:SetTextInsets(8, 8, 0, 0)
	e.bg = UI.Background(e, "input")
	e.border = UI.Border(e, "borderStrong")
	e.hasError = false

	function e:UpdateBorder()
		if self.hasError then
			self.border:SetColor("error")
			self.border:SetThickness(2)
		elseif self:HasFocus() then
			self.border:SetColor("accent")
			self.border:SetThickness(2)
		elseif self.hovered and self:IsEnabled() then
			self.border:SetColor("textDim")
			self.border:SetThickness(1)
		else
			self.border:SetColor("borderStrong")
			self.border:SetThickness(1)
		end
	end
	function e:SetError(flag)
		self.hasError = flag and true or false
		self:UpdateBorder()
	end
	e:SetScript("OnEnter", function(self) self.hovered = true; self:UpdateBorder() end)
	e:SetScript("OnLeave", function(self) self.hovered = false; self:UpdateBorder() end)
	e:SetScript("OnEditFocusGained", function(self) self:UpdateBorder() end)
	e:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:UpdateBorder() end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	return e
end

-- Search box with magnifier icon, placeholder and clear button.
-- onChange(text) fires after a short pause in typing.
function UI.CreateSearchBox(parent, width, placeholder, onChange)
	local e = UI.CreateEditBox(parent, width, 30)
	e:SetTextInsets(30, 26, 0, 0)
	e.icon = UI.Icon(e, "search", 14, "textDim")
	e.icon:SetPoint("LEFT", 9, 0)
	e.placeholder = UI.Text(e, "body", "textDim")
	e.placeholder:SetPoint("LEFT", 30, 0)
	e.placeholder:SetText(placeholder or "")
	e.clear = UI.CreateIconButton(e, "close", 10, nil, "textDim")
	e.clear:SetSize(20, 20)
	e.clear:SetPoint("RIGHT", -4, 0)
	e.clear:Hide()
	e.clear:SetScript("OnClick", function()
		e:SetText("")
		e:ClearFocus()
	end)
	e:HookScript("OnEditFocusGained", function(self) UI.SetIconColor(self.icon, "accent") end)
	e:HookScript("OnEditFocusLost", function(self) UI.SetIconColor(self.icon, "textDim") end)

	local pendingToken = 0
	e:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		self.placeholder:SetShown(text == "")
		self.clear:SetShown(text ~= "")
		pendingToken = pendingToken + 1
		local token = pendingToken
		ns.Compat.After(0.15, function()
			if token == pendingToken and onChange then onChange(self:GetText()) end
		end)
	end)
	e:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then self:SetText("") end
		self:ClearFocus()
	end)
	return e
end
