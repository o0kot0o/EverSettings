-- Modal-style dialogs built from EverSettings' own frames (StaticPopup is avoided to keep
-- Blizzard's popup system untainted).
local _, ns = ...

local Theme, UI, L = ns.Theme, ns.UI, ns.L

local dialog

local function EnsureDialog()
	if dialog then return dialog end
	local d = CreateFrame("Frame", "EverSettingsDialog", UIParent)
	d:SetFrameStrata("DIALOG")
	d:SetToplevel(true)
	d:SetSize(440, 200)
	d:SetPoint("CENTER", 0, 80)
	d:EnableMouse(true)
	d:SetClampedToScreen(true)
	UI.Background(d, "section")
	UI.Border(d, "borderStrong")
	d.title = UI.Text(d, "groupHeader", "text")
	d.title:SetPoint("TOPLEFT", 16, -14)
	d.title:SetPoint("TOPRIGHT", -16, -14)
	d.body = UI.Text(d, "body", "textMuted")
	d.body:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -10)
	d.body:SetPoint("TOPRIGHT", d.title, "BOTTOMRIGHT", 0, -10)
	d.body:SetWordWrap(true)
	d.body:SetJustifyV("TOP")

	d.input = UI.CreateEditBox(d, 408, 24)
	d.input:SetPoint("TOPLEFT", d.body, "BOTTOMLEFT", 0, -10)

	-- Multi-line text area (export/import).
	d.area = CreateFrame("ScrollFrame", nil, d)
	d.area:SetPoint("TOPLEFT", d.body, "BOTTOMLEFT", 0, -10)
	d.area:SetPoint("BOTTOMRIGHT", -16, 50)
	UI.Background(d.area, "input")
	UI.Border(d.area, "borderStrong")
	d.areaEdit = CreateFrame("EditBox", nil, d.area)
	d.areaEdit:SetMultiLine(true)
	d.areaEdit:SetAutoFocus(false)
	d.areaEdit:SetFontObject(Theme:Font(11, "text"))
	d.areaEdit:SetTextInsets(6, 6, 6, 6)
	d.areaEdit:SetWidth(400)
	d.areaEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	d.area:SetScrollChild(d.areaEdit)
	d.area:EnableMouseWheel(true)
	d.area:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, d.areaEdit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 30)))
	end)
	d.area:SetScript("OnMouseDown", function() d.areaEdit:SetFocus() end)

	d.accept = UI.CreateButton(d, "OK", "primary", 100, 26)
	d.accept:SetPoint("BOTTOMRIGHT", -16, 14)
	d.cancel = UI.CreateButton(d, "Cancel", "secondary", 100, 26)
	d.cancel:SetPoint("RIGHT", d.accept, "LEFT", -8, 0)
	d.extra = UI.CreateButton(d, "", "ghost", 110, 26)
	d.extra:SetPoint("BOTTOMLEFT", 16, 14)

	d.cancel:SetScript("OnClick", function() d:Hide() end)
	d.accept:SetScript("OnClick", function()
		local text = d.mode == "prompt" and d.input:GetText() or (d.mode == "text" and d.areaEdit:GetText()) or nil
		local cb = d.onAccept
		if cb then
			local keepOpen = cb(text)
			if keepOpen then return end
		end
		d:Hide()
	end)
	d.input:SetScript("OnEnterPressed", function() d.accept:Click() end)
	d.input:SetScript("OnEscapePressed", function() d:Hide() end)
	d:Hide()
	tinsert(UISpecialFrames, "EverSettingsDialog")
	dialog = d
	return d
end

local function Open(mode, title, body, acceptText, onAccept, opts)
	local d = EnsureDialog()
	opts = opts or {}
	d:SetScale(ns.db and ns.db.window.scale or 1)
	d.mode, d.onAccept = mode, onAccept
	d.title:SetText(title or "")
	d.body:SetText(body or "")
	d.accept:SetText(acceptText or "OK")
	d.cancel:SetShown(not opts.noCancel)
	d.cancel:SetText(opts.cancelText or "Cancel")
	d.input:SetShown(mode == "prompt")
	d.area:SetShown(mode == "text")
	d.extra:SetShown(opts.extraText ~= nil)
	if opts.extraText then
		d.extra:SetText(opts.extraText)
		d.extra:SetScript("OnClick", opts.onExtra)
	end
	local bodyHeight = (body and body ~= "") and math.min(d.body:GetStringHeight(), 260) or 0
	if mode == "text" then
		d:SetSize(520, 380)
		d.areaEdit:SetWidth(484)
		d.areaEdit:SetText(opts.text or "")
		d.area:SetVerticalScroll(0)
	else
		d:SetSize(440, 100 + bodyHeight + (mode == "prompt" and 34 or 0))
	end
	if mode == "prompt" then
		d.input:SetText(opts.text or "")
		d.input:SetFocus()
		d.input:HighlightText()
	end
	d:Show()
	if mode == "text" and opts.selectAll then
		d.areaEdit:SetFocus()
		d.areaEdit:HighlightText()
	end
	return d
end

function UI.Confirm(title, body, acceptText, onAccept, opts)
	return Open("confirm", title, body, acceptText, onAccept, opts)
end

function UI.Alert(title, body)
	return Open("confirm", title, body, "OK", nil, { noCancel = true })
end

function UI.Prompt(title, body, defaultText, acceptText, onAccept)
	return Open("prompt", title, body, acceptText, onAccept, { text = defaultText })
end

function UI.TextDialog(title, body, text, acceptText, onAccept, opts)
	opts = opts or {}
	opts.text = text
	return Open("text", title, body, acceptText, onAccept, opts)
end

function UI.HideDialog()
	if dialog then dialog:Hide() end
end
