-- Mandatory numeric control: a slider plus an editable numeric box, kept in sync.
--
--  * The slider spans exactly the researched range; it never implies an unsupported range.
--  * Typing an exact value keeps that exact value (it is not rounded to a slider step).
--  * Enter confirms, Escape cancels, invalid input is flagged and never applied.
local _, ns = ...

local Theme, UI, Values, Util = ns.Theme, ns.UI, ns.Values, ns.Util

local SLIDER_WIDTH, BOX_WIDTH = 168, 64

function UI.CreateNumericControl(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(SLIDER_WIDTH + BOX_WIDTH + 10, 24)

	-- Slider ---------------------------------------------------------------
	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(SLIDER_WIDTH, 18)
	s:SetPoint("LEFT")
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(false) -- avoid accidental changes while scrolling the list
	s.track = s:CreateTexture(nil, "BACKGROUND")
	s.track:SetPoint("LEFT")
	s.track:SetPoint("RIGHT")
	s.track:SetHeight(4)
	UI.SetColor(s.track, Theme.colors.track)
	s.fill = s:CreateTexture(nil, "BORDER")
	s.fill:SetPoint("LEFT", s.track, "LEFT")
	s.fill:SetHeight(4)
	UI.SetColor(s.fill, Theme.colors.accent)
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(10, 16)
	UI.SetColor(thumb, Theme.colors.text)
	s:SetThumbTexture(thumb)
	s.thumb = thumb
	f.slider = s

	-- Edit box ---------------------------------------------------------------
	local e = UI.CreateEditBox(f, BOX_WIDTH, 22, "RIGHT")
	e:SetPoint("LEFT", s, "RIGHT", 10, 0)
	f.edit = e

	f.updating = false

	local function updateFill()
		local lo, hi = s:GetMinMaxValues()
		local v = s:GetValue()
		local pct = (hi > lo) and (v - lo) / (hi - lo) or 0
		s.fill:SetWidth(math.max(1, SLIDER_WIDTH * Util.Clamp(pct, 0, 1)))
	end

	function f:Setup(def, lo, hi, step, onCommit, onError)
		self.def, self.lo, self.hi, self.step = def, lo, hi, step
		self.onCommit, self.onError = onCommit, onError
		-- Re-applying the range or step cancels an in-progress drag in the client, so only
		-- touch the slider when something actually changed and the player is not dragging.
		if s.dragging then return end
		local curLo, curHi = s:GetMinMaxValues()
		local newStep = step or (hi - lo) / 100
		if curLo ~= lo or curHi ~= hi or self.appliedStep ~= newStep then
			self.updating = true
			s:SetMinMaxValues(lo, hi)
			s:SetValueStep(newStep)
			self.appliedStep = newStep
			self.updating = false
		end
	end

	-- Display a canonical value without firing callbacks.
	function f:SetValue(value)
		-- Refreshes during a drag must not move the thumb under the player's cursor.
		if s.dragging then return end
		self.value = value
		self.updating = true
		if type(value) == "number" then
			s:SetValue(Util.Clamp(value, self.lo or value, self.hi or value))
			if not e:HasFocus() then
				e:SetText(Values.FormatNumber(self.def, value))
			end
		else
			e:SetText("")
		end
		e:SetError(false)
		updateFill()
		self.updating = false
	end

	function f:SetEnabled(enabled)
		s:SetEnabled(enabled)
		e:SetEnabled(enabled)
		local a = enabled and 1 or 0.4
		s:SetAlpha(a)
		e:SetAlpha(a)
		if not enabled then e:ClearFocus() end
	end

	s:SetScript("OnValueChanged", function(self, value, userInput)
		updateFill()
		if f.updating then return end
		if userInput == false then return end
		-- Snap to the step grid relative to the minimum (slider positions are always on-step).
		local step = f.step
		if step and step > 0 then
			value = f.lo + Util.Round((value - f.lo) / step) * step
			value = Util.Round(value, Util.DecimalsForStep(step) + 2)
		end
		f.value = value
		e:SetText(Values.FormatNumber(f.def, value))
		e:SetError(false)
		if s.dragging then
			-- Stage once on release; staging mid-drag refreshes the row and ends the drag.
			f.dragValue = value
		elseif f.onCommit then
			f.onCommit(value)
		end
	end)

	s:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and self:IsEnabled() then
			self.dragging = true
			f.dragValue = nil
		end
	end)
	s:SetScript("OnMouseUp", function(self)
		if not self.dragging then return end
		self.dragging = false
		local value = f.dragValue
		f.dragValue = nil
		if value ~= nil and f.onCommit then f.onCommit(value) end
	end)
	s:SetScript("OnHide", function(self)
		-- A row recycled mid-drag must not leave the control stuck in drag mode.
		if self.dragging then
			self.dragging = false
			f.dragValue = nil
		end
	end)

	e:SetScript("OnEnterPressed", function(self)
		local value, err = Values.ParseInput(f.def, self:GetText())
		if value ~= nil then
			local ok, verr = Values.Validate(f.def, value)
			if not ok then value, err = nil, verr end
		end
		if value == nil then
			self:SetError(true)
			if f.onError then f.onError(err) end
			return -- keep focus so the player can correct it
		end
		self:SetError(false)
		self:ClearFocus()
		f:SetValue(value)
		if f.onCommit then f.onCommit(value) end
	end)
	e:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		self:SetError(false)
		if f.onError then f.onError(nil) end
		f:SetValue(f.value)
	end)
	e:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		-- Leaving the box without Enter cancels the edit (and clears any error).
		if self.hasError and f.onError then f.onError(nil) end
		f:SetValue(f.value)
		self:UpdateBorder()
	end)
	e:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
		self:UpdateBorder()
	end)
	e:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self.hasError then self:SetError(false) end
	end)
	return f
end
