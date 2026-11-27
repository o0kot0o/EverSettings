-- Mandatory numeric control: a slider plus an editable numeric box, kept in sync.
--
--  * The slider spans exactly the researched range; it never implies an unsupported range.
--  * Typing an exact value keeps that exact value (it is not rounded to a slider step).
--  * Enter confirms, Escape cancels, invalid input is flagged and never applied.
local _, ns = ...

local Theme, UI, Values, Util = ns.Theme, ns.UI, ns.Values, ns.Util

local M = Theme.metrics
local TRACK_HEIGHT, THUMB_SIZE = 6, 24 -- thumb texture is 24px; the visible knob is ~15px

-- Layout (left to right): [ slider ] 10px [ edit box ] 4px [ unit ]. The control is
-- right-aligned by its parent, so every row's edit box and unit line up.
function UI.CreateNumericControl(parent)
	local f = CreateFrame("Frame", nil, parent)
	f.sliderWidth = M.sliderWide
	f:SetSize(f.sliderWidth + 10 + M.editWidth + 4 + M.unitWidth, 28)

	-- Slider ---------------------------------------------------------------
	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(f.sliderWidth, THUMB_SIZE)
	s:SetPoint("LEFT")
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(false) -- avoid accidental changes while scrolling the list
	s.track = s:CreateTexture(nil, "BACKGROUND")
	s.track:SetPoint("LEFT")
	s.track:SetPoint("RIGHT")
	s.track:SetHeight(TRACK_HEIGHT)
	UI.SetColor(s.track, "track")
	s.fill = s:CreateTexture(nil, "BORDER")
	s.fill:SetPoint("LEFT", s.track, "LEFT")
	s.fill:SetHeight(TRACK_HEIGHT)
	UI.SetColor(s.fill, "accent")
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(THUMB_SIZE, THUMB_SIZE)
	UI.SetIcon(thumb, "knob", "text")
	s:SetThumbTexture(thumb)
	s.thumb = thumb
	f.slider = s
	s:SetScript("OnEnter", function(self) if self:IsEnabled() then UI.SetIconColor(self.thumb, "accentHover") end end)
	s:SetScript("OnLeave", function(self) UI.SetIconColor(self.thumb, "text") end)

	-- Edit box and unit ---------------------------------------------------------
	local e = UI.CreateEditBox(f, M.editWidth, 26, "RIGHT")
	e:SetPoint("LEFT", s, "RIGHT", 10, 0)
	f.edit = e
	f.unit = UI.Text(f, "small", "textMuted", "LEFT")
	f.unit:SetPoint("LEFT", e, "RIGHT", 6, 0)
	f.unit:SetWidth(M.unitWidth)

	f.updating = false

	local function updateFill()
		local lo, hi = s:GetMinMaxValues()
		local v = s:GetValue()
		local pct = (hi > lo) and (v - lo) / (hi - lo) or 0
		s.fill:SetWidth(math.max(1, f.sliderWidth * Util.Clamp(pct, 0, 1)))
	end

	-- Responsive width. Never resizes while the player is dragging.
	function f:SetSliderWidth(width)
		if width == self.sliderWidth or self:IsDragging() then return end
		self.sliderWidth = width
		s:SetWidth(width)
		self:SetWidth(width + 10 + M.editWidth + 4 + M.unitWidth)
		updateFill()
	end

	function f:SetUnit(text)
		self.unit:SetText(text or "")
	end

	function f:Setup(def, lo, hi, step, onCommit, onError)
		self.def, self.lo, self.hi, self.step = def, lo, hi, step
		self.onCommit, self.onError = onCommit, onError
		-- Re-applying the range or step cancels an in-progress drag in the client, so only
		-- touch the slider when something actually changed and the player is not dragging.
		if f:IsDragging() then return end
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
		if f:IsDragging() then return end
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
		UI.SetColor(s.fill, enabled and "accent" or "textDisabled")
		UI.SetIconColor(s.thumb, enabled and "text" or "textDisabled")
		e:SetAlpha(enabled and 1 or 0.5)
		self.unit:SetAlpha(enabled and 1 or 0.5)
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
		-- Stage once when the drag ends: staging mid-drag refreshes the row, which would
		-- interrupt the drag. A plain click (no drag in progress) stages immediately.
		f.dragValue = value
		if f:IsDragging() then
			f:SetScript("OnUpdate", f.WatchDragEnd)
		else
			f:FinishDrag()
		end
	end)

	-- Drag state: Slider:IsDraggingThumb() (in Forever's widget API) is authoritative;
	-- OnMouseDown/OnMouseUp are a fallback for clicks on the track.
	function f:IsDragging()
		if s.dragging then return true end
		return s.IsDraggingThumb and s:IsDraggingThumb() and true or false
	end

	function f:FinishDrag()
		f:SetScript("OnUpdate", nil)
		local value = f.dragValue
		f.dragValue = nil
		if value ~= nil and f.onCommit then f.onCommit(value) end
	end

	function f.WatchDragEnd()
		if not f:IsDragging() then f:FinishDrag() end
	end

	s:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and self:IsEnabled() then
			self.dragging = true
		end
	end)
	s:SetScript("OnMouseUp", function(self)
		self.dragging = false
		if f.dragValue ~= nil then f:SetScript("OnUpdate", f.WatchDragEnd) end
	end)
	s:SetScript("OnHide", function(self)
		-- A row recycled mid-drag must not leave the control stuck in drag mode.
		self.dragging = false
		f.dragValue = nil
		f:SetScript("OnUpdate", nil)
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
