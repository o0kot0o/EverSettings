-- Neutral graphite theme with a muted teal accent. All colors and metrics live here.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

Theme.colors = {
	window      = { 0.071, 0.075, 0.082, 0.98 },
	header      = { 0.094, 0.098, 0.110, 1 },
	sidebar     = { 0.086, 0.090, 0.100, 1 },
	content     = { 0.106, 0.110, 0.122, 1 },
	section     = { 0.129, 0.133, 0.149, 1 },
	inspector   = { 0.094, 0.098, 0.110, 1 },
	rowHover    = { 1, 1, 1, 0.035 },
	rowSelected = { 0.227, 0.655, 0.639, 0.12 },
	border      = { 1, 1, 1, 0.07 },
	borderStrong = { 1, 1, 1, 0.14 },
	accent      = { 0.227, 0.655, 0.639, 1 },
	accentHover = { 0.290, 0.741, 0.722, 1 },
	accentDim   = { 0.227, 0.655, 0.639, 0.35 },
	text        = { 0.910, 0.918, 0.929, 1 },
	textMuted   = { 0.600, 0.620, 0.660, 1 },
	textDim     = { 0.420, 0.440, 0.480, 1 },
	warning     = { 0.851, 0.643, 0.255, 1 },
	error       = { 0.851, 0.333, 0.310, 1 },
	success     = { 0.361, 0.722, 0.451, 1 },
	info        = { 0.455, 0.604, 0.851, 1 },
	input       = { 0.059, 0.063, 0.071, 1 },
	control     = { 0.165, 0.169, 0.188, 1 },
	controlHover = { 0.208, 0.212, 0.235, 1 },
	track       = { 0.200, 0.204, 0.224, 1 },
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
	headerHeight = 46, footerHeight = 46, sidebarWidth = 208, inspectorWidth = 300,
	rowHeight = 52, sectionHeight = 30, categoryHeaderHeight = 34, controlWidth = 300,
	padding = 16, minWidth = 900, minHeight = 540,
}

-- Arial Narrow reads well at small sizes; CJK locales need the client's standard font.
local FONT_PATH = "Fonts\\ARIALN.TTF"
do
	local locale = GetLocale and GetLocale() or "enUS"
	if locale == "koKR" or locale == "zhCN" or locale == "zhTW" or locale == "ruRU" then
		FONT_PATH = STANDARD_TEXT_FONT or FONT_PATH
	end
end
Theme.fontPath = FONT_PATH

local fontCache = {}
-- Returns a shared font object for (size, colorKey, flags).
function Theme:Font(size, colorKey, flags)
	colorKey = colorKey or "text"
	local key = ("EverSettingsFont_%d_%s_%s"):format(size, colorKey, flags or "")
	local font = fontCache[key]
	if font then return font end
	font = CreateFont(key)
	local ok = font:SetFont(FONT_PATH, size, flags or "")
	if ok == false and STANDARD_TEXT_FONT then
		font:SetFont(STANDARD_TEXT_FONT, size, flags or "")
	end
	local c = self.colors[colorKey] or self.colors.text
	font:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	font:SetShadowOffset(0, 0)
	fontCache[key] = font
	return font
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
