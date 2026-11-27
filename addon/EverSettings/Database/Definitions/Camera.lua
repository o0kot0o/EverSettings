-- Camera definitions.
local _, ns = ...
local R = ns.Registry

local CTRL = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Frame/Controls.lua"
local CTRL_CAMELOT = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Frame/Camelot/ControlsOverrides.lua"
local GFX = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Shared/Graphics.lua"
local ACC = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Frame/Accessibility.lua"
local DUMP = "Client CVar dump 1.60.1.70938 (Ketho/BlizzardInterfaceResources@forever Resources/CVars.lua)"
local STR = "GlobalStrings enUS (Ketho/BlizzardInterfaceResources@forever)"
local FPP = "ForeverPlusPlus docs/forever-api.md (xIGBClutchIx/ForeverPlusPlus@6b98426)"

local function standard()
	return { exists = "source", values = "source", write = "source", persist = "unknown", effect = "source" }
end

local FOLLOW_OPTIONS = {
	{ value = 1, label = "Only horizontal when moving", description = "The camera stays where placed, except when your character is moving (horizontal position only)." },
	{ value = 4, label = "Only when moving", description = "The camera stays where placed, except when your character is moving." },
	{ value = 2, label = "Always adjust camera", description = "The camera always prefers being behind your character." },
	{ value = 0, label = "Never adjust camera", description = "The camera stays where set and never auto adjusts." },
}

R:DefineGroup({ category = "camera" }, {
	{
		id = "camera.maxZoom", subcategory = "zoom", name = "Max Camera Distance",
		description = "Adjusts the maximum distance the camera will follow behind you.",
		keywords = { "zoom", "distance", "max zoom", "cameraDistanceMaxZoomFactor" },
		provider = "cvar", cvar = "cameraDistanceMaxZoomFactor", control = "slider", valueType = "number",
		min = 1.0, max = 2.0, step = 0.1, suffix = "×",
		rangeSource = "Camelot/ControlsOverrides.lua CreateSliderOptions(1.0, 2.0, .1) is the normal range.",
		extendedRange = {
			min = 1.0, max = 2.6,
			source = "observed in game on Forever 1.60.1.71139 (2026-11-27): the client stored and reported 2.6, set by another addon. 2.6 is also Retail's engine limit. Higher values are untested; whether 2.6 visibly zooms farther than 2.0 is not yet confirmed.",
		},
		sources = { CTRL_CAMELOT .. " (Max Camera Distance)", FPP .. " ('How far past 2.0 the console takes it ... Unverified')", STR .. " OPTION_TOOLTIP_MAX_FOLLOW_DIST", "In game, owner report 2026-11-27: value 2.6 accepted and stored by the client (see issue #3)" },
		verification = standard(),
	},
	{
		id = "camera.fov", subcategory = "fov", name = "Field of View",
		description = "Adjusts the camera field of view. The range is reported by the client (GetCameraFOVDefaults).",
		keywords = { "fov", "field of view", "wide" },
		provider = "cvar", cvar = "cameraFov", control = "slider", valueType = "number",
		rangeFunc = "cameraFov", step = 5, suffix = "°",
		rangeSource = "Graphics.lua: GetCameraFOVDefaults() player min/max at runtime, slider step 5",
		sources = { GFX .. " (PROXY_CAMERA_FOV, shown only when the cameraFov CVar exists)", STR .. " OPTION_TOOLTIP_CAMERA_FOV" },
		verification = standard(),
	},
	{
		id = "camera.mouseLookSpeed", subcategory = "rotation", name = "Mouse Look Speed",
		description = "Speed at which you turn the camera with mouse look. Vertical speed is set to half the horizontal speed, as Blizzard's slider does.",
		keywords = { "sensitivity", "turn speed", "yaw", "pitch" },
		provider = "composite", composite = "ratio", cvars = { "cameraYawMoveSpeed", "cameraPitchMoveSpeed" }, ratio = 2,
		technical = "cameraYawMoveSpeed (cameraPitchMoveSpeed = yaw / 2)",
		control = "slider", valueType = "number", min = 90, max = 270, step = 10, defaultValue = 180,
		rangeSource = "Controls.lua PROXY_MOUSE_LOOK_SPEED CreateSliderOptions(90, 270, 10), default 180",
		sources = { CTRL .. " (PROXY_MOUSE_LOOK_SPEED)", STR .. " OPTION_TOOLTIP_MOUSE_LOOK_SPEED" }, verification = standard(),
	},
	{
		id = "camera.terrainTilt", subcategory = "movement", name = "Follow Terrain",
		description = "Automatically tilts the camera with the terrain: up when climbing a slope, down when descending.",
		keywords = { "terrain", "tilt", "slope" },
		provider = "cvar", cvar = "cameraTerrainTilt", control = "toggle", valueType = "boolean",
		sources = { CTRL_CAMELOT .. " (Follow Terrain)", STR .. " OPTION_TOOLTIP_FOLLOW_TERRAIN" }, verification = standard(),
	},
	{
		id = "camera.headBob", subcategory = "movement", name = "Head Bob",
		description = "Simulates head bobbing in first-person perspective.",
		keywords = { "bob", "first person" },
		provider = "cvar", cvar = "cameraBobbing", control = "toggle", valueType = "boolean",
		sources = { CTRL_CAMELOT .. " (Head Bob)", STR .. " OPTION_TOOLTIP_HEAD_BOB" }, verification = standard(),
	},
	{
		id = "camera.smartPivot", subcategory = "movement", name = "Smart Pivot",
		description = "Blizzard's Smart Pivot camera option. Blizzard provides no tooltip for it on Forever.",
		keywords = { "pivot", "ground" },
		provider = "cvar", cvar = "cameraPivot", control = "toggle", valueType = "boolean",
		sources = { CTRL_CAMELOT .. " (Smart Pivot, no tooltip)" },
		verification = { exists = "source", values = "source", write = "source", persist = "unknown", effect = "unknown" },
	},
	{
		id = "camera.waterCollision", subcategory = "movement", name = "Water Collision",
		description = "Keeps the camera above water when your character is above water, and below when below.",
		keywords = { "water", "underwater", "swim" },
		provider = "cvar", cvar = "cameraWaterCollision", control = "toggle", valueType = "boolean",
		sources = { CTRL .. " (Water Collision)", STR .. " OPTION_TOOLTIP_WATER_COLLISION" }, verification = standard(),
	},
	{
		id = "camera.followStyle", subcategory = "following", name = "Camera Following Style",
		description = "How the camera follows your character while moving.",
		keywords = { "follow", "smart camera", "auto adjust" },
		provider = "cvar", cvar = "cameraSmoothStyle", control = "dropdown", valueType = "enum",
		options = FOLLOW_OPTIONS,
		related = { "camera.autoFollowSpeed" },
		sources = { CTRL .. " (cameraSmoothStyle dropdown)", STR .. " CAMERA_SMART / CAMERA_SMARTER / CAMERA_ALWAYS / CAMERA_NEVER", FPP .. " (cameraSmoothStyle takes 0, 1, 2 or 4)" },
		verification = standard(),
	},
	{
		id = "camera.autoFollowSpeed", subcategory = "following", name = "Auto Follow Speed",
		description = "Camera movement speed in the Always and Smart following styles. Vertical speed is set to a quarter of horizontal, as Blizzard's slider does.",
		keywords = { "follow speed", "smooth" },
		provider = "composite", composite = "ratio", cvars = { "cameraYawSmoothSpeed", "cameraPitchSmoothSpeed" }, ratio = 4,
		technical = "cameraYawSmoothSpeed (cameraPitchSmoothSpeed = yaw / 4)",
		control = "slider", valueType = "number", min = 90, max = 270, step = 10, defaultValue = 180,
		rangeSource = "Controls.lua PROXY_CAMERA_SPEED CreateSliderOptions(90, 270, 10), default 180",
		related = { "camera.followStyle" },
		sources = { CTRL .. " (PROXY_CAMERA_SPEED)", STR .. " OPTION_TOOLTIP_AUTO_FOLLOW_SPEED" }, verification = standard(),
	},
	{
		id = "camera.clickToMoveFollowStyle", subcategory = "following", name = "Click-to-Move Following Style",
		description = "How the camera follows your character while using Click-to-Move.",
		keywords = { "click to move", "ctm" },
		provider = "cvar", cvar = "cameraSmoothTrackingStyle", control = "dropdown", valueType = "enum",
		options = FOLLOW_OPTIONS,
		sources = { CTRL .. " (Click to Move: cameraSmoothTrackingStyle)" }, verification = standard(),
	},
	{
		id = "camera.shake", subcategory = "shake", name = "Camera Shake",
		description = "How much spell and environment effects can shake the camera and the 2D interface. Sets both ShakeStrengthCamera and ShakeStrengthUI.",
		keywords = { "shake", "motion sickness", "screen shake" },
		provider = "composite", composite = "shakeLevel", cvars = { "ShakeStrengthCamera", "ShakeStrengthUI" },
		control = "dropdown", valueType = "enum",
		options = {
			{ value = 0, label = "None" }, { value = 0.25, label = "Reduced" }, { value = 1, label = "Full" },
			{ value = "custom", label = "Custom (set elsewhere)", notSelectable = true },
		},
		related = { "accessibility.motionSickness" },
		sources = { ACC .. " (Camera Shake: INTENSITY_NONE 0, INTENSITY_REDUCED .25, INTENSITY_FULL 1)", DUMP }, verification = standard(),
	},
	{
		id = "camera.zoomSpeed", subcategory = "zoom", name = "Zoom Speed",
		description = "Camera zoom speed. Shown read-only: no documented range for Forever.",
		keywords = { "zoom speed", "scroll" },
		provider = "cvar", cvar = "cameraZoomSpeed", control = "readonly", valueType = "number",
		readOnlyReason = "Read-only: the valid range on Forever has not been researched.",
		sources = { DUMP .. " (default 20, no help text)" },
		verification = { exists = "source", values = "unknown", write = "unknown", persist = "unknown", effect = "unknown" },
	},
})

R:DefineGroup({ category = "accessibility", subcategory = "motion" }, {
	{
		id = "accessibility.motionSickness", name = "Motion Sickness",
		description = "Reduces camera movement and keeps your character centered (CameraKeepCharacterCentered off, CameraReduceUnexpectedMovement on), as Blizzard's checkbox does.",
		keywords = { "motion sickness", "nausea", "center" },
		provider = "composite", composite = "motionSickness", cvars = { "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" },
		control = "toggle", valueType = "boolean", defaultValue = false,
		related = { "camera.shake" },
		sources = { ACC .. " (PROXY_SICKNESS)", STR .. " OPTION_TOOLTIP_MOTION_SICKNESS_CHECKBOX" }, verification = standard(),
	},
})
