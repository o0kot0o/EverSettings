-- Minimal World of Warcraft API mock for offline tests (Lua 5.1, run through lupa).
--
-- Widget objects are strict: calling a method that does not exist on that widget type in
-- the Forever client's WidgetAPI dump (tests/data/WidgetAPI.lua, build 1.60.1.70938) raises
-- an error, as does SetScript with a handler the widget type does not support.
-- Game state (CVars, combat, timers) is controllable through the global MOCK table.

MOCK = {
	cvars = {}, defaults = {}, flags = {}, help = {}, readOnly = {}, locked = {},
	setLog = {}, printed = {}, timers = {}, combat = false,
	clamp = {}, reject = {}, extraCVars = {}, commands = {},
	frames = {}, eventFrames = {}, minimapFiltered = { [1024] = true },
	unknownMethodCalls = {},
}

-- Widget API ------------------------------------------------------------------
local widgetAPI = dofile(MOCK_DATA_DIR .. "/WidgetAPI.lua")
-- Dump quirk: Region is listed as inheriting itself; in the client it inherits ScriptRegion
-- (warcraft.wiki.gg Widget API hierarchy), which provides SetPoint/SetAllPoints/Show etc.
if widgetAPI.Region and widgetAPI.Region.inherits[1] == "Region" then
	widgetAPI.Region.inherits = { "ScriptRegion" }
end
local methodCache, handlerCache = {}, {}

local function collect(typeName, field, out, visited)
	visited = visited or {}
	if visited[typeName] then return out end -- the dump lists Region as inheriting itself
	visited[typeName] = true
	local t = widgetAPI[typeName]
	if not t then return out end
	for _, parent in ipairs(t.inherits or {}) do collect(parent, field, out, visited) end
	for _, m in ipairs(t[field] or {}) do out[m] = true end
	return out
end

local function methodsFor(typeName)
	if not methodCache[typeName] then methodCache[typeName] = collect(typeName, "methods", {}) end
	return methodCache[typeName]
end
local function handlersFor(typeName)
	if not handlerCache[typeName] then handlerCache[typeName] = collect(typeName, "handlers", {}) end
	return handlerCache[typeName]
end

local Impl = {} -- implemented behaviour; anything else valid is a no-op

local function noop() end

local function makeObject(objType, parent, name)
	local obj = {
		__type = objType, __parent = parent, __name = name, __shown = objType ~= "Frame" and true or true,
		__points = {}, __scripts = {}, __children = {}, __events = {},
		__width = 0, __height = 0, __text = "", __value = 0, __min = 0, __max = 1, __enabled = true,
		__level = parent and ((parent.__level or 0) + 1) or 1, __alpha = 1,
	}
	local methods = methodsFor(objType)
	setmetatable(obj, {
		__index = function(t, k)
			if methods[k] then
				return Impl[k] or noop
			end
			return nil
		end,
	})
	if parent and parent.__children then table.insert(parent.__children, obj) end
	return obj
end
MOCK.makeObject = makeObject

-- Size and anchors
function Impl.SetSize(self, w, h) self.__width, self.__height = w or 0, h or 0 end
function Impl.SetWidth(self, w) self.__width = w or 0 end
function Impl.SetHeight(self, h) self.__height = h or 0 end
function Impl.GetWidth(self) return (self.__width ~= 0 and self.__width) or 600 end
function Impl.GetHeight(self) return (self.__height ~= 0 and self.__height) or 400 end
function Impl.GetSize(self) return Impl.GetWidth(self), Impl.GetHeight(self) end
function Impl.SetPoint(self, point, ...) table.insert(self.__points, { point, ... }) end
function Impl.ClearAllPoints(self) self.__points = {} end
function Impl.GetPoint(self, i)
	local p = self.__points[i or 1]
	if not p then return nil end
	return p[1], nil, p[1], 0, 0
end
function Impl.SetAllPoints(self) self.__points = { { "ALL" } } end
function Impl.GetEffectiveScale() return 1 end
function Impl.GetScale() return 1 end

-- Visibility
function Impl.Show(self)
	local was = self.__shown
	self.__shown = true
	if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Impl.Hide(self)
	local was = self.__shown
	self.__shown = false
	if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Impl.SetShown(self, v) if v then Impl.Show(self) else Impl.Hide(self) end end
function Impl.IsShown(self) return self.__shown end
function Impl.IsVisible(self)
	local o = self
	while o do
		if not o.__shown then return false end
		o = o.__parent
	end
	return true
end
function Impl.SetAlpha(self, a) self.__alpha = a end
function Impl.GetAlpha(self) return self.__alpha end

-- Scripts
function Impl.SetScript(self, handler, fn)
	if not handlersFor(self.__type)[handler] then
		error(("%s has no script handler '%s'"):format(self.__type, tostring(handler)), 2)
	end
	self.__scripts[handler] = fn
end
function Impl.GetScript(self, handler) return self.__scripts[handler] end
function Impl.HookScript(self, handler, fn)
	if not handlersFor(self.__type)[handler] then
		error(("%s has no script handler '%s'"):format(self.__type, tostring(handler)), 2)
	end
	local old = self.__scripts[handler]
	self.__scripts[handler] = function(...)
		if old then old(...) end
		fn(...)
	end
end
function Impl.HasScript(self, handler) return handlersFor(self.__type)[handler] == true end

-- Hierarchy
function Impl.GetParent(self) return self.__parent end
function Impl.GetName(self) return self.__name end
function Impl.GetObjectType(self) return self.__type end
function Impl.CreateTexture(self, name) return makeObject("Texture", self, name) end
function Impl.CreateFontString(self, name) return makeObject("FontString", self, name) end
function Impl.CreateMaskTexture(self, name) return makeObject("MaskTexture", self, name) end
function Impl.GetFrameLevel(self) return self.__level end
function Impl.SetFrameLevel(self, l) self.__level = l end
function Impl.GetChildren(self) return unpack(self.__children) end

-- Events
function Impl.RegisterEvent(self, event) self.__events[event] = true; MOCK.eventFrames[self] = true end
function Impl.UnregisterEvent(self, event) self.__events[event] = nil end
function Impl.IsEventRegistered(self, event) return self.__events[event] == true end

-- Enable state
function Impl.SetEnabled(self, v)
	local was = self.__enabled
	self.__enabled = v and true or false
	if was ~= self.__enabled then
		local h = self.__enabled and self.__scripts.OnEnable or self.__scripts.OnDisable
		if h then h(self) end
	end
end
function Impl.Enable(self) Impl.SetEnabled(self, true) end
function Impl.Disable(self) Impl.SetEnabled(self, false) end
function Impl.IsEnabled(self) return self.__enabled end

-- Text
function Impl.SetText(self, t)
	self.__text = t == nil and "" or tostring(t)
	if self.__type == "EditBox" and self.__scripts.OnTextChanged then self.__scripts.OnTextChanged(self, false) end
end
function Impl.GetText(self) return self.__text end
function Impl.SetFormattedText(self, fmt, ...) Impl.SetText(self, fmt:format(...)) end
function Impl.GetStringWidth(self) return #(self.__text or "") * 6 end
function Impl.GetStringHeight(self) return 14 end
function Impl.SetFontObject(self, f) self.__font = f end
function Impl.GetFontObject(self) return self.__font end
function Impl.SetFont() return true end

-- EditBox focus
function Impl.SetFocus(self)
	if MOCK.focus and MOCK.focus ~= self then Impl.ClearFocus(MOCK.focus) end
	MOCK.focus = self
	if self.__scripts.OnEditFocusGained then self.__scripts.OnEditFocusGained(self) end
end
function Impl.ClearFocus(self)
	if MOCK.focus == self then
		MOCK.focus = nil
		if self.__scripts.OnEditFocusLost then self.__scripts.OnEditFocusLost(self) end
	end
end
function Impl.HasFocus(self) return MOCK.focus == self end

-- Slider
function Impl.SetMinMaxValues(self, lo, hi) self.__min, self.__max = lo, hi end
function Impl.GetMinMaxValues(self) return self.__min, self.__max end
function Impl.SetValue(self, v)
	v = math.max(self.__min, math.min(self.__max, v))
	local changed = v ~= self.__value
	self.__value = v
	if changed and self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, v, false) end
end
function Impl.GetValue(self) return self.__value end

-- Textures
function Impl.SetAtlas(self, atlas) self.__atlas = atlas; return true end
function Impl.SetColorTexture(self, r, g, b, a) self.__color = { r, g, b, a } end

-- Scroll frames
function Impl.GetVerticalScroll(self) return self.__vscroll or 0 end
function Impl.SetVerticalScroll(self, v) self.__vscroll = v end

-- Tooltip
function Impl.NumLines() return 0 end

-- Frames ------------------------------------------------------------------------
function CreateFrame(frameType, name, parent, template)
	local obj = makeObject(frameType, parent, name)
	if frameType == "Frame" or frameType == "Button" then obj.__shown = true end
	if name then _G[name] = obj end
	table.insert(MOCK.frames, obj)
	return obj
end

function CreateFont(name)
	local f = makeObject("Font", nil, name)
	_G[name] = f
	return f
end

UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
UISpecialFrames = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

function MOCK.FireEvent(event, ...)
	for frame in pairs(MOCK.eventFrames) do
		if frame.__events[event] and frame.__scripts.OnEvent then
			frame.__scripts.OnEvent(frame, event, ...)
		end
	end
end

function MOCK.Click(button, mouse)
	local h = button.__scripts.OnClick
	if h and button.__enabled then h(button, mouse or "LeftButton") end
end

function MOCK.Script(obj, handler, ...)
	local h = obj.__scripts[handler]
	if h then return h(obj, ...) end
end

-- Count frames created (for responsiveness checks).
function MOCK.FrameCount() return #MOCK.frames end

-- Lua helpers WoW provides --------------------------------------------------------
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
strsplit = function(sep, s)
	local out = {}
	for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
	return unpack(out)
end
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	table.insert(MOCK.printed, table.concat(parts, " "))
end
time = os.time
date = os.date
GetTime = os.clock
hooksecurefunc = function() end
GetCursorPosition = function() return 0, 0 end

-- Game info ---------------------------------------------------------------------------
GetBuildInfo = function() return "1.60.1", "71139", "Nov 25 2026", 16001 end
GetLocale = function() return "enUS" end
UnitName = function() return "Tester" end
GetRealmName = function() return "TestRealm" end
InCombatLockdown = function() return MOCK.combat end
IsMacClient = function() return false end
GetPhysicalScreenSize = function() return 2560, 1440 end
GetCameraFOVDefaults = function() return 90, 50, 90 end
GetMinRenderScale = function() return 0.33 end
GetMaxRenderScale = function() return 2.0 end
AntiAliasingSupported = function() return true, true, true end
IsGraphicsSettingValueSupported = function() return 0 end
IsGraphicsCVarValueSupported = function(cvar, value)
	if cvar == "LowLatencyMode" and (value == 3 or value == 4) then return 2 end -- pretend no Reflex
	return 0
end
-- Mock preset table: child level = min(level, 4) (only the mechanism is under test).
GetGraphicsCVarValueForQualityLevel = function(cvar, level, raid) return math.min(level, 4) end
C_VideoOptions = {
	IsLinearEnabledOnStart = function() return true end,
	IsOutlineModeSupported = function() return true end,
	IsPBRWaterSupported = function() return false end,
	IsSecondaryLightingSupported = function() return false end,
	IsSpellVisualDensitySystemSupported = function() return true end,
}
Enum = {
	ConsoleCommandType = { Cvar = 0, Command = 1, Macro = 2, Script = 3 },
	MinimapTrackingFilter = { TrivialQuests = 1024 },
}
MinimapUtil = { GetFilterIndexForFilterID = function(id) return id == 1024 and 7 or nil end }
C_Minimap = {
	IsFilteredOut = function(filter) return MOCK.minimapFiltered[filter] == true end,
	SetTracking = function(index, value) if index == 7 then MOCK.minimapFiltered[1024] = not value end end,
}
C_Timer = {
	After = function(seconds, fn) table.insert(MOCK.timers, fn) end,
	NewTicker = function(seconds, fn)
		local t = { cancelled = false }
		function t:Cancel() self.cancelled = true end
		return t
	end,
}
function MOCK.RunTimers()
	local guard = 0
	while #MOCK.timers > 0 and guard < 1000 do
		guard = guard + 1
		local fn = table.remove(MOCK.timers, 1)
		fn()
	end
end

-- CVars ---------------------------------------------------------------------------------
local function key(name) return name and name:lower() end

function MOCK.SeedCVars(catalog)
	for name, e in pairs(catalog.cvars) do
		local k = key(name)
		MOCK.cvars[k], MOCK.defaults[k], MOCK.flags[k], MOCK.help[k] = e[1], e[1], e[3], e[5]
		MOCK.names = MOCK.names or {}
		MOCK.names[k] = name
	end
	for name, c in pairs(catalog.commands) do MOCK.commands[name] = c end
end

local function hasFlag(flags, f) return flags and (flags % (f * 2)) >= f end

local function getCVar(name) return MOCK.cvars[key(name)] end
local function setCVar(name, value)
	local k = key(name)
	table.insert(MOCK.setLog, { name = name, value = value })
	if MOCK.cvars[k] == nil then return nil end
	if MOCK.readOnly[k] or MOCK.locked[k] then return nil end
	if hasFlag(MOCK.flags[k], 4) and MOCK.combat then return nil end
	if MOCK.reject[k] then return nil end
	value = value == nil and "" or tostring(value)
	if type(value) == "boolean" then value = value and "1" or "0" end
	if MOCK.clamp[k] then value = MOCK.clamp[k](value) end
	MOCK.cvars[k] = value
	MOCK.FireEvent("CVAR_UPDATE", name, value)
	return true
end
MOCK.setCVarRaw = setCVar

C_CVar = {
	GetCVar = getCVar,
	GetCVarDefault = function(name) return MOCK.defaults[key(name)] end,
	GetCVarBool = function(name) local v = getCVar(name); return v ~= nil and v ~= "0" end,
	SetCVar = setCVar,
	GetCVarInfo = function(name)
		local k = key(name)
		if MOCK.cvars[k] == nil then return nil end
		local f = MOCK.flags[k] or 0
		return MOCK.cvars[k], MOCK.defaults[k], hasFlag(f, 1), hasFlag(f, 2), MOCK.locked[k] or false, hasFlag(f, 4), MOCK.readOnly[k] or false
	end,
}
GetCVar, SetCVar, GetCVarDefault = getCVar, function(n, v) return setCVar(n, type(v) == "boolean" and (v and "1" or "0") or v) end, C_CVar.GetCVarDefault

function ConsoleGetAllCommands()
	local out = {}
	for k, value in pairs(MOCK.cvars) do
		if not MOCK.hiddenFromConsole or not MOCK.hiddenFromConsole[k] then
			out[#out + 1] = { command = MOCK.names[k] or k, help = MOCK.help[k] or "", category = 4, commandType = 0, scriptContents = "", scriptParameters = "" }
		end
	end
	for name, c in pairs(MOCK.commands) do
		out[#out + 1] = { command = name, help = c[2], category = c[1], commandType = 1, scriptContents = "", scriptParameters = "" }
	end
	return out
end
