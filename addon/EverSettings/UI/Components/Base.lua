-- Low-level drawing helpers shared by all components.
local _, ns = ...

local Theme = ns.Theme
local UI = {}
ns.UI = UI

local function color(key)
	return Theme.colors[key] or Theme.statusColors[key] or key
end
UI.ResolveColor = color

function UI.SetColor(texture, c)
	c = color(c)
	texture:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

function UI.Background(frame, colorKey, layer)
	local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetAllPoints()
	UI.SetColor(tex, colorKey)
	return tex
end

-- Border made of four textures (default 1px). Returns an object with
-- :SetColor(color), :SetShown(bool) and :SetThickness(px).
function UI.Border(frame, colorKey, layer, thickness)
	local edges = {}
	local function edge(p1, p2, horizontal)
		local t = frame:CreateTexture(nil, layer or "BORDER")
		t:SetPoint(p1)
		t:SetPoint(p2)
		t.horizontal = horizontal
		edges[#edges + 1] = t
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT", false)
	edge("TOPRIGHT", "BOTTOMRIGHT", false)
	local border = { edges = edges }
	function border:SetColor(c)
		for _, t in ipairs(edges) do UI.SetColor(t, c) end
	end
	function border:SetThickness(px)
		for _, t in ipairs(edges) do
			if t.horizontal then t:SetHeight(px) else t:SetWidth(px) end
		end
	end
	function border:SetShown(shown)
		for _, t in ipairs(edges) do t:SetShown(shown) end
	end
	border:SetColor(colorKey or "border")
	border:SetThickness(thickness or 1)
	return border
end

function UI.Line(parent, colorKey, horizontal, layer)
	local t = parent:CreateTexture(nil, layer or "BORDER")
	UI.SetColor(t, colorKey or "border")
	if horizontal then t:SetHeight(1) else t:SetWidth(1) end
	return t
end

-- Font string. `size` may be a type role name ("settingName") or a pixel size.
function UI.Text(parent, size, colorKey, justify, weight)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	if type(size) == "string" then
		fs:SetFontObject(Theme:RoleFont(size, colorKey))
	else
		fs:SetFontObject(Theme:Font(size or 12, colorKey, weight))
	end
	fs:SetJustifyH(justify or "LEFT")
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	return fs
end

function UI.SetFont(fs, role, colorKey)
	fs:SetFontObject(Theme:RoleFont(role, colorKey))
end

function UI.SetTextColor(fs, colorKey)
	local c = color(colorKey)
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- Icon: an EverSettings icon name (Theme.iconFiles) or a Blizzard atlas, tinted.
function UI.Icon(parent, icon, size, colorKey, layer)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	tex:SetSize(size, size)
	UI.SetIcon(tex, icon, colorKey)
	return tex
end

function UI.SetIcon(tex, icon, colorKey)
	local file = Theme.iconFiles[icon]
	local ok
	if file then
		ok = tex:SetTexture(file)
	elseif icon then
		ok = tex:SetAtlas(icon)
	end
	if ok == false then
		tex:SetColorTexture(1, 1, 1, 0.6)
	end
	tex.iconName = icon
	UI.SetIconColor(tex, colorKey or "textMuted")
end

function UI.SetIconColor(tex, colorKey)
	local c = color(colorKey)
	tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

-- Small uppercase tag ("PENDING", "RESTART").
function UI.CreateBadge(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(15)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.text = UI.Text(f, "badge", "text", "CENTER")
	f.text:SetPoint("CENTER", 0, 0)
	function f:Set(label, colorKey)
		local c = color(colorKey) or Theme.colors.textMuted
		self.bg:SetColorTexture(c[1], c[2], c[3], 0.15)
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
	if body then GameTooltip:AddLine(body, 0.78, 0.80, 0.83, true) end
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
