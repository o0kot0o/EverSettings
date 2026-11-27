-- Graphics & Visuals definitions.
-- Every range, option list and label below comes from Blizzard's Forever settings code
-- (Gethe/wow-ui-source@forever, build 1.60.1.71139) or the client's own CVar help text.
local _, ns = ...
local R = ns.Registry

local GFX = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Shared/Graphics.lua"
local GFXO = "wow-ui-source@forever 1.60.1.71139 Blizzard_Settings_Shared/Mainline/GraphicsOverrides.lua"
local DUMP = "Client CVar dump 1.60.1.70938 (Ketho/BlizzardInterfaceResources@forever Resources/CVars.lua)"
local STR = "GlobalStrings enUS (Ketho/BlizzardInterfaceResources@forever)"

-- Evidence for settings that Blizzard's own Forever settings window exposes.
local function standard()
	return { exists = "source", values = "source", write = "source", persist = "unknown", effect = "source" }
end

local function videoOption(fnName, negate)
	return function()
		local fn = C_VideoOptions and C_VideoOptions[fnName]
		if not fn then return false, "C_VideoOptions." .. fnName .. " is unavailable" end
		local supported = fn() and true or false
		if negate then supported = not supported end
		if not supported then return false, "Not supported on this system" end
		return true
	end
end

local function notMac()
	if IsMacClient and IsMacClient() then return false, "Not available on macOS" end
	return true
end

local COMBAT_CUES = "Disabling this may cause you to miss important visual cues during combat."

local QUALITY_CHILDREN = {
	"graphicsQuality", "graphicsShadowQuality", "graphicsLiquidDetail", "graphicsPBRLiquidDetail",
	"graphicsParticleDensity", "graphicsSSAO", "graphicsDepthEffects", "graphicsComputeEffects",
	"graphicsOutlineMode", "graphicsTextureResolution", "graphicsSpellDensity", "graphicsProjectedTextures",
	"graphicsLightMode", "graphicsViewDistance", "graphicsEnvironmentDetail", "graphicsGroundClutter",
}

-- Options for advanced quality dropdowns are validated per system with
-- IsGraphicsSettingValueSupported(cvar, value, raid), as Blizzard's AddValidatedSettingOption does.
local function quality(t)
	t.provider = "cvar"
	t.control = "dropdown"
	t.valueType = "enum"
	t.optionSupport = "graphicsQuality"
	t.verification = standard()
	t.sources = t.sources or { GFX, STR }
	return t
end

-- Particle density options depend on secondary lighting support (Graphics.lua GetParticleDensityOptions).
ns.Providers.optionFuncs.particleDensity = function()
	local secondary = C_VideoOptions and C_VideoOptions.IsSecondaryLightingSupported and C_VideoOptions.IsSecondaryLightingSupported()
	if not secondary then
		return {
			{ value = 0, label = "Disabled", warning = COMBAT_CUES },
			{ value = 1, label = "Low" }, { value = 2, label = "Fair" }, { value = 3, label = "Medium" },
			{ value = 4, label = "High" }, { value = 5, label = "Ultra" },
		}
	end
	return {
		{ value = 0, label = "Low" }, { value = 1, label = "Fair" }, { value = 2, label = "Medium" },
		{ value = 3, label = "High" }, { value = 4, label = "Ultra" },
	}
end

-- Image-based anti-aliasing options; CMAA entries depend on AntiAliasingSupported().
ns.Providers.optionFuncs.imageAA = function()
	local options = {
		{ value = 0, label = "None" }, { value = 1, label = "FXAA Low" }, { value = 2, label = "FXAA High" },
	}
	local cmaa, cmaa2
	if AntiAliasingSupported then
		local _
		_, cmaa, cmaa2 = AntiAliasingSupported()
	end
	if cmaa then options[#options + 1] = { value = 3, label = "CMAA" } end
	if cmaa2 then options[#options + 1] = { value = 4, label = "CMAA 2" } end
	return options
end

R:DefineGroup({ category = "graphics" }, {
	-- Display ---------------------------------------------------------------
	{
		id = "graphics.vsync", subcategory = "display", name = "Vertical Sync",
		description = "Synchronizes your framerate to some fraction of your monitor's refresh rate. Enable this if you see excessive screen tearing.",
		keywords = { "vsync", "tearing", "refresh" },
		provider = "cvar", cvar = "vsync", control = "toggle", valueType = "boolean",
		performance = "Can cap frame rate to the monitor refresh rate and may add input latency.",
		sources = { GFX .. " (PROXY_VERTICAL_SYNC)", STR .. " OPTION_TOOLTIP_VERTICAL_SYNC" },
		verification = standard(),
	},
	{
		id = "graphics.gamma", subcategory = "display", name = "Gamma",
		description = "Controls the gamma of the game.",
		keywords = { "brightness", "dark" },
		provider = "cvar", cvar = "Gamma", control = "slider", valueType = "number",
		min = 0.3, max = 2.8, step = 0.1,
		rangeSource = "Graphics.lua CreateSliderOptions(.3, 2.8, .1); client help text 'Range: [0.3 - 2.8]'",
		sources = { GFX .. " (Gamma)", DUMP }, verification = standard(),
	},
	{
		id = "graphics.brightness", subcategory = "display", name = "Brightness",
		description = "Controls the brightness of the game.",
		provider = "cvar", cvar = "Brightness", control = "slider", valueType = "number",
		min = 0, max = 100, step = 1, suffix = "%",
		rangeSource = "Graphics.lua CreateSliderOptions(0, 100, 1); client help text 'Range: [0 - 100]'",
		sources = { GFX .. " (Brightness)", DUMP }, verification = standard(),
	},
	{
		id = "graphics.contrast", subcategory = "display", name = "Contrast",
		description = "Controls the contrast of the game.",
		provider = "cvar", cvar = "Contrast", control = "slider", valueType = "number",
		min = 0, max = 100, step = 1, suffix = "%",
		rangeSource = "Graphics.lua CreateSliderOptions(0, 100, 1); client help text 'Range: [0 - 100]'",
		sources = { GFX .. " (Contrast)", DUMP }, verification = standard(),
	},
	{
		id = "graphics.bloom", subcategory = "lighting", name = "Bloom Intensity",
		description = "Controls the intensity of the bloom effect. Only offered by Blizzard when linear lighting was enabled at startup.",
		keywords = { "glow", "bloom" },
		provider = "cvar", cvar = "bloomUserMult", control = "slider", valueType = "number",
		min = 0, max = 1, step = 0.2,
		rangeSource = "Graphics.lua CreateSliderOptions(0, 1, 0.2)",
		isAvailable = videoOption("IsLinearEnabledOnStart"),
		sources = { GFX .. " (bloomUserMult, shown when C_VideoOptions.IsLinearEnabledOnStart())" },
		verification = standard(),
	},

	-- Resolution and scaling -------------------------------------------------
	{
		id = "graphics.useUiScale", subcategory = "scaling", name = "Use UI Scale",
		description = "Use the UI Scale slider. When off, the system default scale is used.",
		keywords = { "ui scale", "interface size" },
		provider = "cvar", cvar = "useUiScale", control = "toggle", valueType = "boolean",
		related = { "graphics.uiScale" },
		sources = { GFX .. " (PROXY_USE_UI_SCALE)", STR .. " OPTION_TOOLTIP_USE_UISCALE" },
		verification = { exists = "source", values = "source", write = "unknown", persist = "unknown", effect = "source" },
	},
	{
		id = "graphics.uiScale", subcategory = "scaling", name = "UI Scale",
		description = "Changes the size of the game's user interface. Takes effect only while Use UI Scale is on.",
		keywords = { "ui scale", "interface size", "uiscale" },
		provider = "cvar", cvar = "uiScale", control = "slider", valueType = "number",
		min = 0.65, max = 1.15, step = 0.01, displayScale = 100, suffix = "%", decimals = 0,
		rangeSource = "Graphics.lua CreateSliderOptions(.65, 1.15, .01), displayed as a percentage",
		dependencies = { { id = "graphics.useUiScale", value = true, reason = "UI Scale only applies while Use UI Scale is on." } },
		related = { "graphics.useUiScale" },
		sources = { GFX .. " (PROXY_UI_SCALE)", DUMP .. " (secure)" },
		verification = { exists = "source", values = "source", write = "unknown", persist = "unknown", effect = "source" },
	},
	{
		id = "graphics.renderScale", subcategory = "scaling", name = "Render Scale",
		description = "Changes the resolution used to render the 3D world. Below 100% reduces GPU load; above 100% is supersampling and very expensive.",
		keywords = { "resolution", "supersampling", "ssaa", "upscale" },
		provider = "cvar", cvar = "RenderScale", control = "slider", valueType = "number",
		rangeFunc = "renderScale", step = 0.01, displayScale = 100, suffix = "%", decimals = 0,
		rangeSource = "Graphics.lua: GetMinRenderScale()..GetMaxRenderScale() queried from the client at runtime. Step 0.01 is EverSettings' slider granularity only; the edit box accepts exact values.",
		performance = "Strong GPU impact: values above 100% multiply rendering cost.",
		related = { "graphics.resampleQuality", "graphics.resampleSharpness" },
		sources = { GFX .. " (PROXY_RESOLUTION_RENDER_SCALE)", STR .. " OPTION_TOOLTIP_RENDER_SCALE" },
		verification = standard(),
	},
	{
		id = "graphics.resampleQuality", subcategory = "scaling", name = "Resample Quality",
		description = "When Render Scale is not 100%, adjusts the quality of the upscale or downscale. Point and FSR are only used for upscaling.",
		keywords = { "fsr", "upscaling", "fidelityfx" },
		provider = "cvar", cvar = "ResampleQuality", control = "dropdown", valueType = "enum",
		options = {
			{ value = 0, label = "Point" }, { value = 1, label = "Bilinear" }, { value = 2, label = "Bicubic" },
			{ value = 3, label = "FidelityFX Super Resolution 1.0" },
		},
		related = { "graphics.renderScale", "graphics.resampleSharpness" },
		sources = { GFX .. " (ResampleQuality)", STR .. " RESAMPLE_QUALITY_*" }, verification = standard(),
	},
	{
		id = "graphics.resampleSharpness", subcategory = "scaling", name = "FSR Sharpness",
		description = "Strength of the FidelityFX Super Resolution sharpening. Lower values are sharper: 0 is full strength. Blizzard's slider shows this reversed.",
		keywords = { "fsr", "sharpen" },
		provider = "cvar", cvar = "ResampleSharpness", control = "slider", valueType = "number",
		min = 0, max = 2, step = 0.1,
		rangeSource = "Graphics.lua CreateSliderOptions(0.0, 2.0, .1); client help '[0.0-2.0]. 0 is full strength. -1 to disable.' The -1 disable value is not offered here until verified.",
		related = { "graphics.resampleQuality" },
		sources = { GFX .. " (PROXY_RESAMPLE_SHARPNESS)", DUMP }, verification = standard(),
	},

	-- Anti-aliasing -----------------------------------------------------------
	{
		id = "graphics.imageAA", subcategory = "antialiasing", name = "Image-Based Anti-Aliasing",
		description = "Post-process anti-aliasing technique. Blizzard only enables this choice when the main Anti-Aliasing mode is Image-Based or Advanced.",
		keywords = { "fxaa", "cmaa", "aliasing", "jaggies" },
		provider = "cvar", cvar = "ffxAntiAliasingMode", control = "dropdown", valueType = "enum",
		optionsFunc = "imageAA",
		sources = { GFX .. " (PROXY_FXAA; CMAA options depend on AntiAliasingSupported())" },
		verification = standard(),
	},

	-- Textures ------------------------------------------------------------------
	quality({
		id = "graphics.textureResolution", subcategory = "textures", name = "Texture Resolution",
		description = "Controls the level of all texture detail. Decreasing this may slightly improve performance.",
		keywords = { "texture detail", "vram" }, cvar = "graphicsTextureResolution",
		options = { { value = 0, label = "Low" }, { value = 1, label = "Fair" }, { value = 2, label = "High" } },
		sources = { GFXO .. " (GetTextureResolutionOptions)", STR },
	}),
	{
		id = "graphics.textureFiltering", subcategory = "textures", name = "Texture Filtering",
		description = "Increases texture sharpness, particularly for textures viewed at an angle.",
		keywords = { "anisotropic", "trilinear", "bilinear", "af" },
		provider = "cvar", cvar = "textureFilteringMode", control = "dropdown", valueType = "enum",
		optionSupport = "graphicsCVar",
		options = {
			{ value = 0, label = "Bilinear" }, { value = 1, label = "Trilinear" }, { value = 2, label = "2x Anisotropic" },
			{ value = 3, label = "4x Anisotropic" }, { value = 4, label = "8x Anisotropic" }, { value = 5, label = "16x Anisotropic" },
		},
		sources = { GFX .. " (textureFilteringMode)", STR .. " OPTION_TOOLTIP_ANISOTROPIC" }, verification = standard(),
	},
	quality({
		id = "graphics.projectedTextures", subcategory = "textures", name = "Projected Textures",
		description = "Projects textures onto the environment, such as spell area markers. Disabling may improve performance but hides combat cues.",
		keywords = { "decals", "ground effects" }, cvar = "graphicsProjectedTextures",
		options = { { value = 0, label = "Disabled", warning = COMBAT_CUES }, { value = 1, label = "Enabled" } },
	}),

	-- Environment / vegetation / view distance --------------------------------
	{
		id = "graphics.environmentDetail", subcategory = "environment", name = "Environment Detail",
		description = "Controls how far you can see objects. Decrease to improve performance.",
		keywords = { "objects", "doodads" },
		provider = "cvar", cvar = "graphicsEnvironmentDetail", control = "slider", valueType = "integer",
		min = 0, max = 9, step = 1, displayOffset = 1,
		rangeSource = "Graphics.lua advanced quality slider CreateSliderOptions(0, 9, 1), labels shown as 1-10",
		sources = { GFX .. " (EnvironmentDetail)", STR .. " OPTION_TOOLTIP_ENVIRONMENT_DETAIL" }, verification = standard(),
	},
	{
		id = "graphics.groundClutter", subcategory = "vegetation", name = "Ground Clutter",
		description = "Controls the density and distance of ground clutter such as grass and foliage. Decrease to improve performance.",
		keywords = { "grass", "foliage", "vegetation density" },
		provider = "cvar", cvar = "graphicsGroundClutter", control = "slider", valueType = "integer",
		min = 0, max = 9, step = 1, displayOffset = 1,
		rangeSource = "Graphics.lua advanced quality slider CreateSliderOptions(0, 9, 1), labels shown as 1-10",
		sources = { GFX .. " (GroundClutter)", STR .. " OPTION_TOOLTIP_GROUND_CLUTTER" }, verification = standard(),
	},
	{
		id = "graphics.viewDistance", subcategory = "viewDistance", name = "View Distance",
		description = "Controls how far you can see. Larger view distances require more memory and a faster processor.",
		keywords = { "draw distance", "farclip", "fog" },
		provider = "cvar", cvar = "graphicsViewDistance", control = "slider", valueType = "integer",
		min = 0, max = 9, step = 1, displayOffset = 1,
		rangeSource = "Graphics.lua advanced quality slider CreateSliderOptions(0, 9, 1), labels shown as 1-10",
		related = { "graphics.farclip" },
		sources = { GFX .. " (ViewDistance)", STR .. " OPTION_TOOLTIP_FARCLIP" }, verification = standard(),
	},
	{
		id = "graphics.farclip", subcategory = "viewDistance", name = "Far Clip Distance",
		description = "Far clip plane distance (client help text). View Distance normally manages this. Shown read-only because its valid range on Forever has not been researched.",
		keywords = { "farclip", "draw distance" },
		provider = "cvar", cvar = "farclip", control = "readonly", valueType = "number",
		readOnlyReason = "Read-only: no documented range for Forever. Use View Distance instead.",
		related = { "graphics.viewDistance" },
		sources = { DUMP .. " (default 1000, help 'Far clip plane distance')" },
		verification = { exists = "source", values = "unknown", write = "unknown", persist = "unknown", effect = "unknown" },
	},

	-- Lighting / shadows -------------------------------------------------------
	quality({
		id = "graphics.lightMode", subcategory = "lighting", name = "Lighting Quality",
		description = "Controls the detail level of secondary lighting effects.",
		keywords = { "lights" }, cvar = "graphicsLightMode",
		isAvailable = videoOption("IsSecondaryLightingSupported"),
		options = { { value = 0, label = "Fair" }, { value = 1, label = "Medium" }, { value = 2, label = "High" }, { value = 3, label = "Ultra" } },
	}),
	quality({
		id = "graphics.ssao", subcategory = "lighting", name = "SSAO",
		description = "Rendering quality of the ambient occlusion lighting effects. Decreasing this may greatly improve performance.",
		keywords = { "ambient occlusion", "ao" }, cvar = "graphicsSSAO",
		options = { { value = 0, label = "Disabled" }, { value = 1, label = "Low" }, { value = 2, label = "Medium" }, { value = 3, label = "High" }, { value = 4, label = "Ultra" } },
		performance = "Can greatly affect GPU performance.",
	}),
	quality({
		id = "graphics.shadowQuality", subcategory = "shadows", name = "Shadow Quality",
		description = "Controls both the method and quality of shadows. Decreasing this may greatly improve performance.",
		keywords = { "shadows" }, cvar = "graphicsShadowQuality",
		options = {
			{ value = 0, label = "Low" }, { value = 1, label = "Fair" }, { value = 2, label = "Medium" },
			{ value = 3, label = "High" }, { value = 4, label = "Ultra" }, { value = 5, label = "Ultra High" },
		},
		performance = "One of the most expensive graphics settings.",
	}),
	{
		id = "graphics.rtShadows", subcategory = "shadows", name = "Ray Traced Shadows",
		description = "Improves shadow quality with ray tracing. Requires a hardware ray tracing capable graphics card.",
		keywords = { "raytracing", "rtx", "dxr" },
		provider = "cvar", cvar = "shadowRt", control = "dropdown", valueType = "enum", optionSupport = "graphicsCVar",
		isAvailable = function()
			if IsMacClient and IsMacClient() then return false, "Not available on macOS" end
			if C_VideoOptions and C_VideoOptions.IsSecondaryLightingSupported and C_VideoOptions.IsSecondaryLightingSupported() then
				return false, "Blizzard hides this when secondary lighting is supported"
			end
			return true
		end,
		options = { { value = 0, label = "Disabled" }, { value = 1, label = "Fair" }, { value = 2, label = "Medium" }, { value = 3, label = "High" } },
		performance = "Very expensive on the GPU.",
		sources = { GFX .. " (shadowrt)", DUMP .. " ('Raytraced shadows (0-3)')" }, verification = standard(),
	},

	-- Water ------------------------------------------------------------------------
	quality({
		id = "graphics.liquidDetail", subcategory = "water", name = "Liquid Detail",
		description = "Controls the rendering quality of liquid. Decreasing this may improve performance.",
		keywords = { "water" }, cvar = "graphicsLiquidDetail",
		options = { { value = 0, label = "Low" }, { value = 1, label = "Fair" }, { value = 2, label = "Medium" }, { value = 3, label = "High" } },
	}),
	quality({
		id = "graphics.pbrLiquidDetail", subcategory = "water", name = "PBR Liquid Detail",
		description = "Rendering quality of the newer physically based liquids.",
		keywords = { "water", "pbr" }, cvar = "graphicsPBRLiquidDetail",
		isAvailable = videoOption("IsPBRWaterSupported"),
		options = { { value = 0, label = "Low" }, { value = 1, label = "High" }, { value = 2, label = "Ultra" } },
		sources = { GFXO .. " (shown when C_VideoOptions.IsPBRWaterSupported())", GFX },
	}),

	-- Visual effects ------------------------------------------------------------------
	quality({
		id = "graphics.particleDensity", subcategory = "effects", name = "Particle Density",
		description = "Number of particles used in effects from spells, fires and so on. Decrease to improve performance.",
		keywords = { "particles", "spell effects" }, cvar = "graphicsParticleDensity",
		optionsFunc = "particleDensity", options = nil,
	}),
	quality({
		id = "graphics.spellDensity", subcategory = "effects", name = "Spell Density",
		description = "Controls the visibility of non-essential spells. Your own spells are always shown.",
		keywords = { "spell visuals", "clutter" }, cvar = "graphicsSpellDensity",
		isAvailable = videoOption("IsSpellVisualDensitySystemSupported"),
		options = {
			{ value = 0, label = "Essential", description = "Only show essential spells. Your own spells are always shown." },
			{ value = 1, label = "Reduced", description = "Reduces the non-essential spells shown." },
			{ value = 2, label = "Everything", description = "Always show all spells." },
		},
	}),
	quality({
		id = "graphics.depthEffects", subcategory = "effects", name = "Depth Effects",
		description = "Controls the rendering of depth-based particle effects. Decreasing this may improve performance.",
		cvar = "graphicsDepthEffects",
		options = { { value = 0, label = "Disabled" }, { value = 1, label = "Low" }, { value = 2, label = "Medium" }, { value = 3, label = "High" } },
	}),
	quality({
		id = "graphics.computeEffects", subcategory = "effects", name = "Compute Effects",
		description = "Quality of compute-based effects such as volumetric fog and some particles. May be expensive on older graphics cards.",
		keywords = { "volumetric fog" }, cvar = "graphicsComputeEffects",
		options = { { value = 0, label = "Low" }, { value = 1, label = "Fair" }, { value = 2, label = "Medium" }, { value = 3, label = "High" }, { value = 4, label = "Ultra" } },
	}),
	quality({
		id = "graphics.outlineMode", subcategory = "effects", name = "Outline Mode",
		description = "Controls whether the selection outline effect is allowed.",
		keywords = { "outline", "highlight", "selection" }, cvar = "graphicsOutlineMode",
		isAvailable = videoOption("IsOutlineModeSupported"),
		options = { { value = 0, label = "Disabled" }, { value = 1, label = "Medium" }, { value = 2, label = "High" } },
		related = { "qol.lootSparkles" },
	}),

	-- Advanced rendering -------------------------------------------------------------
	{
		id = "graphics.qualityPreset", subcategory = "advanced", name = "Graphics Quality Preset",
		description = "Sets every advanced quality setting to Blizzard's preset for the chosen level, exactly as the standard Graphics Quality slider does. Changes staged on individual quality settings are applied after the preset.",
		keywords = { "preset", "overall quality", "graphics quality" },
		provider = "composite", composite = "graphicsPreset", cvars = QUALITY_CHILDREN,
		technical = "graphicsQuality (+ advanced quality CVars)",
		childMinimum = { graphicsParticleDensity = 1 },
		childCondition = {
			graphicsPBRLiquidDetail = "IsPBRWaterSupported", graphicsOutlineMode = "IsOutlineModeSupported",
			graphicsSpellDensity = "IsSpellVisualDensitySystemSupported", graphicsLightMode = "IsSecondaryLightingSupported",
		},
		control = "slider", valueType = "integer", min = 0, max = 9, step = 1, displayOffset = 1,
		rangeSource = "Graphics.lua CreateSliderOptions(0, 9, 1) with labels 1-10; cascade from OnGCChanged",
		applyOrder = -10,
		sources = { GFX .. " (PROXY_GRAPHICS_QUALITY, OnGCChanged)", GFXO .. " (CreateAdvancedSettingsTable)" },
		verification = standard(),
	},
	{
		id = "graphics.tripleBuffering", subcategory = "advanced", name = "Triple Buffering",
		description = "Evens out frame rate spikes but may slightly increase input latency on slower GPUs. Applying restarts the graphics device.",
		keywords = { "buffering", "frame latency", "input lag" },
		provider = "composite", composite = "boolMap", cvars = { "GxMaxFrameLatency" },
		technical = "gxMaxFrameLatency (3 = on, 2 = off)", onValue = 3, offValue = 2, defaultValue = true,
		control = "toggle", valueType = "boolean", apply = "gxrestart",
		sources = { GFX .. " (PROXY_TRIPLE_BUFFERING, CommitFlag.GxRestart)", STR .. " OPTION_TOOLTIP_TRIPLE_BUFFER" },
		verification = standard(),
	},
	{
		id = "graphics.vrs", subcategory = "advanced", name = "Variable Rate Shading",
		description = "Reduces GPU workload with little visible quality loss on supported hardware (requires VRS Tier 2).",
		keywords = { "vrs", "shading rate" },
		provider = "cvar", cvar = "vrsValar", control = "dropdown", valueType = "enum", optionSupport = "graphicsCVar",
		isAvailable = notMac,
		options = { { value = 0, label = "Disabled" }, { value = 1, label = "Standard" }, { value = 2, label = "Aggressive" } },
		sources = { GFX .. " (vrsValar)", STR .. " OPTION_TOOLTIP_VRS_MODE", DUMP }, verification = standard(),
	},
	{
		id = "graphics.physicsLevel", subcategory = "advanced", name = "Physics Interactions",
		description = "Physics interactions with the environment. Requires a full client restart to take effect.",
		keywords = { "physics", "cloth" },
		provider = "cvar", cvar = "physicsLevel", control = "dropdown", valueType = "enum", apply = "restart",
		options = { { value = 0, label = "None" }, { value = 1, label = "Player Only" }, { value = 2, label = "Player and NPC" } },
		sources = { GFX .. " (PROXY_PHYSICS_LEVEL, CommitFlag.ClientRestart)" }, verification = standard(),
	},
})
