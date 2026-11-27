-- Static check: every game API the addon references exists in the Forever client's
-- global API dump (tests/data/GlobalAPI.lua, build 1.60.1.70938).
local _, ns = ...

local dump = dofile(MOCK_DATA_DIR .. "/GlobalAPI.lua")
local known = {}
for _, name in ipairs(dump[1]) do known[name] = true end
for _, name in ipairs(dump[2] or {}) do known[name] = true end

-- Functions provided by Blizzard's Lua UI code (not the C API), or by Lua itself.
local FRAMEXML = {
	CreateFrame = true, CreateFont = true, wipe = true, tinsert = true, hooksecurefunc = true,
	GetCursorPosition = true, InCombatLockdown = true,
	-- Lua wrappers around C_CVar in Blizzard_SharedXMLBase/CvarUtil.lua (forever branch).
	GetCVar = true, SetCVar = true, GetCVarDefault = true,
}

local API_NAMES = {
	"C_CVar.GetCVar", "C_CVar.GetCVarDefault", "C_CVar.GetCVarInfo", "C_CVar.SetCVar",
	"C_Minimap.IsFilteredOut", "C_Minimap.SetTracking", "C_Timer.After", "C_Timer.NewTicker",
	"C_VideoOptions.IsLinearEnabledOnStart", "C_VideoOptions.IsOutlineModeSupported",
	"C_VideoOptions.IsPBRWaterSupported", "C_VideoOptions.IsSecondaryLightingSupported",
	"C_VideoOptions.IsSpellVisualDensitySystemSupported",
	"ConsoleGetAllCommands", "GetBuildInfo", "GetLocale", "UnitName", "GetRealmName", "InCombatLockdown",
	"IsMacClient", "GetPhysicalScreenSize", "GetCameraFOVDefaults", "GetMinRenderScale", "GetMaxRenderScale",
	"AntiAliasingSupported", "IsGraphicsSettingValueSupported", "IsGraphicsCVarValueSupported",
	"GetGraphicsCVarValueForQualityLevel", "GetCVar", "SetCVar", "GetCVarDefault", "GetCursorPosition",
}

describe("Forever API surface", function()
	it("every listed global API the addon calls exists in the Forever dump", function()
		for _, name in ipairs(API_NAMES) do
			truthy(known[name] or FRAMEXML[name], name .. " missing from Forever GlobalAPI dump")
		end
	end)

	it("every C_ namespace function referenced in the source exists in the Forever dump", function()
		local checked = 0
		for _, path in ipairs(ES_FILES) do
			local fh = assert(io.open(path, "r"))
			local text = fh:read("*a")
			fh:close()
			for name in text:gmatch("(C_%a+%.%a+)") do
				checked = checked + 1
				truthy(known[name], name .. " (" .. path:match("[^/]+$") .. ") missing from Forever GlobalAPI dump")
			end
		end
		truthy(checked > 10)
	end)
end)
