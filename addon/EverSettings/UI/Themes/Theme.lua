-- Neutral graphite theme with a muted teal accent. All colors, fonts, type sizes, icons
-- and metrics live here.
local addonName, ns = ...

local Theme = {}
ns.Theme = Theme

Theme.colors = {
	window       = { 0.071, 0.075, 0.082, 0.98 },
	header       = { 0.094, 0.098, 0.110, 1 },
	sidebar      = { 0.086, 0.090, 0.100, 1 },
	content      = { 0.106, 0.110, 0.122, 1 },
	section      = { 0.129, 0.133, 0.149, 1 },
	inspector    = { 0.094, 0.098, 0.110, 1 },
	rowHover     = { 1, 1, 1, 0.03 },
	rowSelected  = { 0.227, 0.655, 0.639, 0.10 },
	navSelected  = { 0.227, 0.655, 0.639, 0.16 },
	border       = { 1, 1, 1, 0.07 },
	borderStrong = { 1, 1, 1, 0.14 },
	accent       = { 0.227, 0.655, 0.639, 1 },
	accentHover  = { 0.290, 0.741, 0.722, 1 },
	accentDim    = { 0.227, 0.655, 0.639, 0.22 },
	onAccent     = { 0.035, 0.090, 0.090, 1 },
	text         = { 0.925, 0.933, 0.945, 1 },
	textMuted    = { 0.690, 0.710, 0.745, 1 },
	textDim      = { 0.490, 0.510, 0.550, 1 },
	textDisabled = { 0.380, 0.395, 0.425, 1 },
	warning      = { 0.878, 0.667, 0.290, 1 },
	warningDim   = { 0.878, 0.667, 0.290, 0.16 },
	error        = { 0.890, 0.380, 0.360, 1 },
	success      = { 0.400, 0.760, 0.490, 1 },
	info         = { 0.500, 0.640, 0.880, 1 },
	input        = { 0.055, 0.059, 0.067, 1 },
	control      = { 0.165, 0.169, 0.188, 1 },
	controlHover = { 0.212, 0.216, 0.239, 1 },
	controlDisabled = { 0.130, 0.133, 0.148, 1 },
	track        = { 0.235, 0.240, 0.262, 1 },
}

Theme.statusColors = {
	verified = Theme.colors.success, source = Theme.colors.accent, community = Theme.colors.info,
	experimental = Theme.colors.warning, unknown = Theme.colors.textDim, unsupported = Theme.colors.error,
}
Theme.statusLabels = {
	verified = "VERIFIED", source = "SOURCE", community = "COMMUNITY",
	experimental = "EXPERIMENTAL", unknown = "UNKNOWN", unsupported = "UNSUPPORTED",
}

Theme.metrics = {
	headerHeight = 52, footerHeight = 50, sidebarWidth = 248,
	inspectorWidth = 320, inspectorMin = 260, inspectorMax = 520,
	rowHeight = 60, sectionHeight = 34, navItemHeight = 30, padding = 18,
	minWidth = 860, minHeight = 520,
	-- Setting controls: every row uses the same widths (wide/narrow tier by list width).
	sliderWide = 200, sliderNarrow = 140, editWidth = 72, unitWidth = 30, wideListWidth = 760,
	scaleMin = 0.7, scaleMax = 1.6, scaleStep = 0.05,
}

-- Width of the control area for a given list width (identical for every row).
function Theme.ControlWidth(listWidth)
	local m = Theme.metrics
	local slider = (listWidth or 0) >= m.wideListWidth and m.sliderWide or m.sliderNarrow
	return slider + 10 + m.editWidth + 4 + m.unitWidth, slider
end

-- Typography -----------------------------------------------------------------------
-- Inter (SIL Open Font License, Media/Fonts/Inter-LICENSE.txt) is bundled because the
-- Forever client only ships display fonts (Friz Quadrata, Morpheus) and Arial Narrow.
-- Inter covers Latin, Greek and Cyrillic; CJK locales use the client's standard font.
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local FONTS = {
	regular = MEDIA .. "Fonts\\Inter-Regular.ttf",
	medium = MEDIA .. "Fonts\\Inter-Medium.ttf",
	semibold = MEDIA .. "Fonts\\Inter-SemiBold.ttf",
}
do
	local locale = GetLocale and GetLocale() or "enUS"
	if locale == "koKR" or locale == "zhCN" or locale == "zhTW" then
		local std = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		FONTS = { regular = std, medium = std, semibold = std }
	end
end
Theme.fonts = FONTS
Theme.fallbackFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Type scale: role -> { size, weight }. Use roles, not raw sizes, in new code.
Theme.type = {
	windowTitle = { 15, "semibold" },
	pageTitle = { 20, "semibold" },
	pageDesc = { 13, "regular" },
	groupHeader = { 15, "semibold" },
	sectionHeader = { 13, "semibold" },
	settingName = { 13, "medium" },
	settingDesc = { 12, "regular" },
	technical = { 11, "regular" },
	body = { 13, "regular" },
	label = { 12, "medium" },
	small = { 11, "regular" },
	meta = { 11, "regular" },
	overline = { 10, "semibold" },
	badge = { 9, "semibold" },
	input = { 13, "medium" },
	button = { 12, "semibold" },
	nav = { 13, "regular" },
	navActive = { 13, "medium" },
}

local fontCache = {}
-- Returns a shared font object. `weight` is "regular", "medium" or "semibold".
function Theme:Font(size, colorKey, weight)
	colorKey = colorKey or "text"
	weight = FONTS[weight or "regular"] and (weight or "regular") or "regular"
	local key = ("EverSettingsFont_%d_%s_%s"):format(size, colorKey, weight)
	local font = fontCache[key]
	if font then return font end
	font = CreateFont(key)
	local ok = font:SetFont(FONTS[weight], size, "")
	if ok == false then
		font:SetFont(self.fallbackFont, size, "")
	end
	local c = self.colors[colorKey] or self.colors.text
	font:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	font:SetShadowOffset(0, 0)
	fontCache[key] = font
	return font
end

-- Font for a type role.
function Theme:RoleFont(role, colorKey)
	local t = self.type[role] or self.type.body
	return self:Font(t[1], colorKey, t[2])
end

function Theme:Color(key)
	local c = self.colors[key]
	return c[1], c[2], c[3], c[4] or 1
end

function Theme.Hex(c)
	return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function Theme:Colorize(text, key)
	return ("|cff%s%s|r"):format(Theme.Hex(self.colors[key] or self.statusColors[key] or self.colors.text), text)
end

-- Icons --------------------------------------------------------------------------------
-- White 32x32 TGAs rendered from Lucide (ISC, Media/Icons/Lucide-LICENSE.txt) by
-- tools/icons; tinted at runtime. Anything not listed here is treated as an atlas name.
Theme.iconFiles = {}
for _, name in ipairs({
	"graphics", "camera", "qol", "combat", "targeting", "nameplates", "questing", "controls", "audio",
	"interface", "accessibility", "performance", "network", "advanced", "favorites", "modified", "recent",
	"all", "browser", "profiles", "diagnostics", "preferences", "search", "details", "help", "close",
	"reset", "chevron-down", "chevron-right", "lock", "logo", "star", "star-filled",
	"knob", "pill", "dot", "rounded",
}) do
	Theme.iconFiles[name] = MEDIA .. "Icons\\" .. name .. ".tga"
end
