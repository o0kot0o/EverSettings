-- Low-level drawing helpers shared by all components.
local _, ns = ...

local Theme = ns.Theme
local UI = {}
ns.UI = UI

function UI.SetColor(texture, color)
	texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

function UI.Background(frame, colorKey, layer)
	local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetAllPoints()
	UI.SetColor(tex, Theme.colors[colorKey] or colorKey)
	return tex
end

-- 1px border made of four textures. Returns a table with :SetColor(color).
function UI.Border(frame, colorKey, layer)
	local color = Theme.colors[colorKey or "border"] or colorKey
	local edges = {}
	local function edge(p1, p2, horizontal)
		local t = frame:CreateTexture(nil, layer or "BORDER")
		t:SetPoint(p1)
		t:SetPoint(p2)
		if horizontal then t:SetHeight(1) else t:SetWidth(1) end
		UI.SetColor(t, color)
		edges[#edges + 1] = t
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT", false)
	edge("TOPRIGHT", "BOTTOMRIGHT", false)
	return {
		edges = edges,
		SetColor = function(_, c)
			c = Theme.colors[c] or c
			for _, t in ipairs(edges) do UI.SetColor(t, c) end
		end,
		SetShown = function(_, shown)
			for _, t in ipairs(edges) do t:SetShown(shown) end
		end,
	}
end

function UI.Line(parent, colorKey, horizontal, layer)
	local t = parent:CreateTexture(nil, layer or "BORDER")
	UI.SetColor(t, Theme.colors[colorKey or "border"])
	if horizontal then t:SetHeight(1) else t:SetWidth(1) end
	return t
end

function UI.Text(parent, size, colorKey, justify, flags)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(Theme:Font(size or 12, colorKey, flags))
	fs:SetJustifyH(justify or "LEFT")
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	return fs
end

function UI.SetTextColor(fs, colorKey)
	local c = Theme.colors[colorKey] or Theme.statusColors[colorKey] or colorKey
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- Atlas icon tinted with a theme color. Falls back to a plain square if the atlas is missing.
function UI.Icon(parent, atlas, size, colorKey, layer)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	tex:SetSize(size, size)
	UI.SetIcon(tex, atlas, colorKey)
	return tex
end

function UI.SetIcon(tex, atlas, colorKey)
	local ok = atlas and tex:SetAtlas(atlas)
	if ok == false then
		tex:SetColorTexture(1, 1, 1, 0.6)
	end
	local c = Theme.colors[colorKey or "textMuted"] or colorKey
	tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

-- Small uppercase tag ("EXPERIMENTAL", "RESTART").
function UI.CreateBadge(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(14)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.text = UI.Text(f, 9, "text", "CENTER")
	f.text:SetPoint("CENTER", 0, 0)
	function f:Set(label, colorKey)
		local c = Theme.colors[colorKey] or Theme.statusColors[colorKey] or Theme.colors.textMuted
		self.bg:SetColorTexture(c[1], c[2], c[3], 0.16)
		self.text:SetText(label)
		self.text:SetTextColor(c[1], c[2], c[3], 1)
		self:SetWidth(math.max(18, self.text:GetStringWidth() + 10))
		self:Show()
	end
	return f
end

function UI.ShowTooltip(owner, title, body, anchor)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if title then GameTooltip:AddLine(title, 1, 1, 1) end
	if body then GameTooltip:AddLine(body, 0.75, 0.77, 0.8, true) end
	GameTooltip:Show()
end

function UI.HideTooltip()
	if GameTooltip then GameTooltip:Hide() end
end

function UI.AttachTooltip(frame, title, body)
	frame:HookScript("OnEnter", function(self)
		local t = type(title) == "function" and title(self) or title
		local b = type(body) == "function" and body(self) or body
		if t or b then UI.ShowTooltip(self, t, b) end
	end)
	frame:HookScript("OnLeave", UI.HideTooltip)
end
