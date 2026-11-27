-- Virtualized scroll list. Only rows intersecting the viewport exist as frames, so a list
-- with thousands of entries (the CVar browser) stays responsive.
--
--   list:RegisterType(type, height, create(parent) -> frame, update(frame, item, list))
--   list:SetItems({ { type = "row", ... }, ... })
local _, ns = ...

local Theme, UI = ns.Theme, ns.UI

local SCROLLBAR_WIDTH, WHEEL_STEP = 6, 60

function UI.CreateScrollList(parent)
	local list = CreateFrame("Frame", nil, parent)
	list:SetClipsChildren(true)
	list.types, list.items, list.offsets, list.total = {}, {}, {}, 0
	list.scroll = 0
	list.active = {}  -- visible frames: [index] = frame
	list.pools = {}   -- [type] = { frames }

	local bar = CreateFrame("Frame", nil, list)
	bar:SetWidth(SCROLLBAR_WIDTH)
	bar:SetPoint("TOPRIGHT", -2, -2)
	bar:SetPoint("BOTTOMRIGHT", -2, 2)
	local thumb = CreateFrame("Button", nil, bar)
	thumb:SetWidth(SCROLLBAR_WIDTH)
	thumb.tex = thumb:CreateTexture(nil, "ARTWORK")
	thumb.tex:SetAllPoints()
	UI.SetColor(thumb.tex, Theme.colors.borderStrong)
	thumb:SetScript("OnEnter", function(self) UI.SetColor(self.tex, Theme.colors.textDim) end)
	thumb:SetScript("OnLeave", function(self) if not self.dragging then UI.SetColor(self.tex, Theme.colors.borderStrong) end end)
	list.bar, list.thumb = bar, thumb

	function list:RegisterType(typeName, height, create, update)
		self.types[typeName] = { height = height, create = create, update = update }
		self.pools[typeName] = {}
	end

	function list:ViewHeight() return math.max(1, self:GetHeight()) end
	function list:MaxScroll() return math.max(0, self.total - self:ViewHeight()) end

	function list:SetItems(items, keepScroll)
		self.items = items or {}
		local y = 0
		for i, item in ipairs(self.items) do
			self.offsets[i] = y
			y = y + (item.height or self.types[item.type].height)
		end
		for i = #self.items + 1, #self.offsets do self.offsets[i] = nil end
		self.total = y
		if not keepScroll then self.scroll = 0 end
		self.scroll = math.min(self.scroll, self:MaxScroll())
		self:Render(true)
	end

	local function release(self, index)
		local frame = self.active[index]
		if frame then
			frame:Hide()
			frame:ClearAllPoints()
			local pool = self.pools[frame.listType]
			pool[#pool + 1] = frame
			self.active[index] = nil
		end
	end

	local function acquire(self, typeName)
		local pool = self.pools[typeName]
		local frame = table.remove(pool)
		if not frame then
			frame = self.types[typeName].create(self)
			frame.listType = typeName
		end
		return frame
	end

	-- Binary search for the first item whose bottom is below `y`.
	local function firstVisible(self, y)
		local lo, hi = 1, #self.items
		while lo < hi do
			local mid = math.floor((lo + hi) / 2)
			local item = self.items[mid]
			local bottom = self.offsets[mid] + (item.height or self.types[item.type].height)
			if bottom <= y then lo = mid + 1 else hi = mid end
		end
		return lo
	end

	function list:Render(force)
		local view = self:ViewHeight()
		local first = #self.items > 0 and firstVisible(self, self.scroll) or 1
		local wanted = {}
		local i = first
		while i <= #self.items and self.offsets[i] < self.scroll + view do
			wanted[i] = true
			i = i + 1
		end
		for index, frame in pairs(self.active) do
			if not wanted[index] or force or frame.listType ~= self.items[index].type then
				release(self, index)
			end
		end
		local width = self:GetWidth() - (self.total > view and (SCROLLBAR_WIDTH + 6) or 0)
		for index in pairs(wanted) do
			local item = self.items[index]
			local frame = self.active[index]
			if not frame then
				frame = acquire(self, item.type)
				self.active[index] = frame
				self.types[item.type].update(frame, item, self)
			end
			frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(self.offsets[index] - self.scroll))
			frame:SetSize(width, item.height or self.types[item.type].height)
			frame:Show()
		end
		self:UpdateScrollbar()
	end

	-- Re-run update functions on visible rows without rebuilding the list.
	function list:RefreshVisible()
		for index, frame in pairs(self.active) do
			self.types[frame.listType].update(frame, self.items[index], self)
		end
	end

	function list:ForEachVisible(fn)
		for index, frame in pairs(self.active) do fn(frame, self.items[index], index) end
	end

	function list:UpdateScrollbar()
		local view = self:ViewHeight()
		if self.total <= view then
			self.bar:Hide()
			return
		end
		self.bar:Show()
		local barHeight = self.bar:GetHeight()
		local thumbHeight = math.max(24, barHeight * view / self.total)
		local maxScroll = self:MaxScroll()
		local pos = maxScroll > 0 and (self.scroll / maxScroll) * (barHeight - thumbHeight) or 0
		self.thumb:SetHeight(thumbHeight)
		self.thumb:ClearAllPoints()
		self.thumb:SetPoint("TOP", self.bar, "TOP", 0, -pos)
	end

	function list:SetScroll(value)
		local clamped = math.max(0, math.min(self:MaxScroll(), value))
		if clamped ~= self.scroll then
			self.scroll = clamped
			self:Render()
		end
	end

	function list:ScrollToIndex(index)
		local top = self.offsets[index]
		if not top then return end
		local item = self.items[index]
		local bottom = top + (item.height or self.types[item.type].height)
		if top < self.scroll then
			self:SetScroll(top)
		elseif bottom > self.scroll + self:ViewHeight() then
			self:SetScroll(bottom - self:ViewHeight())
		end
	end

	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta)
		self:SetScroll(self.scroll - delta * WHEEL_STEP)
	end)
	list:SetScript("OnSizeChanged", function(self) self:Render(true) end)

	thumb:RegisterForDrag("LeftButton")
	thumb:SetScript("OnDragStart", function(self)
		self.dragging = true
		local _, cursorY = GetCursorPosition()
		self.startY = cursorY / self:GetEffectiveScale()
		self.startScroll = list.scroll
		self:SetScript("OnUpdate", function(t)
			local _, y = GetCursorPosition()
			y = y / t:GetEffectiveScale()
			local barHeight = list.bar:GetHeight() - t:GetHeight()
			if barHeight <= 0 then return end
			local delta = (t.startY - y) / barHeight * list:MaxScroll()
			list:SetScroll(t.startScroll + delta)
		end)
	end)
	thumb:SetScript("OnDragStop", function(self)
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		UI.SetColor(self.tex, Theme.colors.borderStrong)
	end)
	return list
end
