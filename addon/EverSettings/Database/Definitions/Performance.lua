-- Performance definitions (frame rate limits and latency).
local _, ns = ...
local R = ns.Registry

local GFX = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Shared/Graphics.lua"
local DUMP = "Client CVar dump 1.60.1.70938 (Ketho/BlizzardInterfaceResources@forever Resources/CVars.lua)"

local function standard()
	return { exists = "source", values = "source", write = "source", persist = "unknown", effect = "source" }
end

local FPS_RANGE = "Graphics.lua CreateSliderOptions(8, 200, 1); client help 'Min 8'. Whether the client accepts values above 200 is not researched."

R:DefineGroup({ category = "performance", subcategory = "frameRate" }, {
	{
		id = "performance.useMaxFPS", name = "Limit Foreground FPS",
		description = "Enables the foreground frame rate limit.",
		keywords = { "fps cap", "frame limit" },
		provider = "cvar", cvar = "useMaxFPS", control = "toggle", valueType = "boolean",
		related = { "performance.maxFPS" },
		sources = { GFX .. " (PROXY_FOREGROUND_FPS_ENABLED)", DUMP }, verification = standard(),
	},
	{
		id = "performance.maxFPS", name = "Foreground FPS Limit",
		description = "Maximum frame rate while the game window is in the foreground. Used only while Limit Foreground FPS is on.",
		keywords = { "fps cap", "frame limit", "maxfps" },
		provider = "cvar", cvar = "maxFPS", control = "slider", valueType = "integer",
		min = 8, max = 200, step = 1, suffix = " fps", rangeSource = FPS_RANGE,
		dependencies = { { id = "performance.useMaxFPS", value = true, reason = "Only used while Limit Foreground FPS is on." } },
		related = { "performance.useMaxFPS" },
		sources = { GFX .. " (PROXY_FOREGROUND_FPS)", DUMP .. " ('Set FPS limit. Min 8')" }, verification = standard(),
	},
	{
		id = "performance.useTargetFPS", name = "Target FPS",
		description = "When enabled, the client takes dynamic actions if the frame rate falls below the target.",
		keywords = { "dynamic", "target fps" },
		provider = "cvar", cvar = "useTargetFPS", control = "toggle", valueType = "boolean",
		related = { "performance.targetFPS" },
		sources = { GFX .. " (PROXY_TARGET_FPS_ENABLED)", DUMP }, verification = standard(),
	},
	{
		id = "performance.targetFPS", name = "Target FPS Value",
		description = "Frame rate the client tries to maintain. Used only while Target FPS is on.",
		keywords = { "target fps" },
		provider = "cvar", cvar = "targetFPS", control = "slider", valueType = "integer",
		min = 8, max = 200, step = 1, suffix = " fps", rangeSource = FPS_RANGE,
		dependencies = { { id = "performance.useTargetFPS", value = true, reason = "Only used while Target FPS is on." } },
		related = { "performance.useTargetFPS" },
		sources = { GFX .. " (PROXY_TARGET_FPS)", DUMP .. " ('Dynamic actions will be taken if you fall below the FPS target')" },
		verification = standard(),
	},
	{
		id = "performance.lowLatencyMode", subcategory = "rendering", name = "Low Latency Mode",
		description = "Lets the game use techniques such as NVIDIA Reflex or Intel XeLL to reduce input latency. Unsupported choices are disabled for your system.",
		keywords = { "reflex", "xell", "input lag", "latency" },
		provider = "cvar", cvar = "LowLatencyMode", control = "dropdown", valueType = "enum", optionSupport = "graphicsCVar",
		isAvailable = function()
			if IsMacClient and IsMacClient() then return false, "Not available on macOS" end
			return true
		end,
		options = {
			{ value = 0, label = "Auto Detect" }, { value = 1, label = "Disabled" }, { value = 2, label = "Built-in" },
			{ value = 3, label = "NVIDIA Reflex" }, { value = 4, label = "NVIDIA Reflex + Boost" }, { value = 5, label = "Intel XeLL" },
		},
		sources = { GFX .. " (LowLatencyMode)", DUMP .. " ('0=AutoDetect, 1=None, 2=BuiltIn, 3=Reflex, 4=Reflex+Boost, 5=XeLL')" },
		verification = standard(),
	},
})

R:DefineGroup({ category = "performance", subcategory = "background" }, {
	{
		id = "performance.useMaxFPSBk", name = "Limit Background FPS",
		description = "Enables the frame rate limit used while the game window is in the background.",
		keywords = { "background", "alt tab", "fps cap" },
		provider = "cvar", cvar = "useMaxFPSBk", control = "toggle", valueType = "boolean",
		related = { "performance.maxFPSBk" },
		sources = { GFX .. " (PROXY_BACKGROUND_FPS_ENABLED)", DUMP }, verification = standard(),
	},
	{
		id = "performance.maxFPSBk", name = "Background FPS Limit",
		description = "Maximum frame rate while the game window is in the background. Used only while Limit Background FPS is on.",
		keywords = { "background", "alt tab", "maxfpsbk" },
		provider = "cvar", cvar = "maxFPSBk", control = "slider", valueType = "integer",
		min = 8, max = 200, step = 1, suffix = " fps", rangeSource = FPS_RANGE,
		dependencies = { { id = "performance.useMaxFPSBk", value = true, reason = "Only used while Limit Background FPS is on." } },
		related = { "performance.useMaxFPSBk" },
		sources = { GFX .. " (PROXY_BACKGROUND_FPS)", DUMP .. " ('Set background FPS limit. Min 8')" }, verification = standard(),
	},
})
