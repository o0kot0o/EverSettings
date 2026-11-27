-- Single-line edit boxes and the header search box.
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

function UI.CreateEditBox(parent, width, height, justify)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width or 120, height or 24)
	e:SetAutoFocus(false)
	e:SetFontObject(Theme:Font(12, "text"))
	e:SetJustifyH(justify or "LEFT")
	e:SetTextInsets(6, 6, 0, 0)
	e.bg = UI.Background(e, "input")
	e.border = UI.Border(e, "borderStrong")
	e.hasError = false

	function e:UpdateBorder()
		if self.hasError then
			self.border:SetColor("error")
		elseif self:HasFocus() then
			self.border:SetColor("accent")
		else
			self.border:SetColor("borderStrong")
		end
	end
	function e:SetError(flag)
		self.hasError = flag and true or false
		self:UpdateBorder()
	end
	e:SetScript("OnEditFocusGained", function(self) self:UpdateBorder() end)
	e:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:UpdateBorder() end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	return e
end

-- Search box with magnifier icon, placeholder and clear button.
-- onChange(text) fires after a short pause in typing.
function UI.CreateSearchBox(parent, width, placeholder, onChange)
	local e = UI.CreateEditBox(parent, width, 26)
	e:SetTextInsets(24, 22, 0, 0)
	e.icon = UI.Icon(e, "common-search-magnifyingglass", 12, "textDim")
	e.icon:SetPoint("LEFT", 7, 0)
	e.placeholder = UI.Text(e, 12, "textDim")
	e.placeholder:SetPoint("LEFT", 24, 0)
	e.placeholder:SetText(placeholder or "")
	e.clear = UI.CreateIconButton(e, "uitools-icon-close", 9, nil, "textDim")
	e.clear:SetSize(18, 18)
	e.clear:SetPoint("RIGHT", -3, 0)
	e.clear:Hide()
	e.clear:SetScript("OnClick", function()
		e:SetText("")
		e:ClearFocus()
	end)

	local pendingToken = 0
	e:SetScript("OnTextChanged", function(self, userInput)
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
