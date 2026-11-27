-- Category tree. A setting has exactly one primary category/subcategory but may carry
-- any number of search keywords and related-setting links.
local _, ns = ...

local Categories = { list = {}, byId = {} }
ns.Categories = Categories

local function C(id, name, description, subs)
	local cat = { id = id, name = name, description = description, subcategories = {}, subById = {} }
	for _, s in ipairs(subs) do
		local sub = { id = s[1], name = s[2] }
		cat.subcategories[#cat.subcategories + 1] = sub
		cat.subById[sub.id] = sub
	end
	Categories.list[#Categories.list + 1] = cat
	Categories.byId[id] = cat
	return cat
end

C("graphics", "Graphics & Visuals", "Display, quality levels and rendering features.", {
	{ "display", "Display" }, { "scaling", "Resolution and scaling" }, { "antialiasing", "Anti-aliasing" },
	{ "textures", "Textures" }, { "environment", "Environment" }, { "vegetation", "Vegetation" },
	{ "terrain", "Terrain" }, { "viewDistance", "View distance" }, { "lighting", "Lighting" },
	{ "shadows", "Shadows" }, { "water", "Water" }, { "weather", "Weather" },
	{ "effects", "Visual effects" }, { "advanced", "Advanced rendering" },
})
C("camera", "Camera", "Zoom, field of view and how the camera follows your character.", {
	{ "zoom", "Zoom" }, { "fov", "Field of view" }, { "movement", "Movement" }, { "rotation", "Rotation" },
	{ "following", "Following behavior" }, { "shake", "Camera shake" },
})
C("qol", "Quality of Life", "Conveniences for inventory, looting and interaction.", {
	{ "inventory", "Inventory" }, { "equipment", "Equipment" }, { "tooltips", "Tooltips" },
	{ "looting", "Looting" }, { "interaction", "Interaction" }, { "convenience", "Convenience" },
})
C("combat", "Combat", "Casting, spell queueing and combat feedback.", {
	{ "casting", "Casting" }, { "spellQueue", "Spell queue" }, { "combatText", "Combat text" },
	{ "autoAttack", "Auto-attacking" }, { "feedback", "Combat feedback" },
})
C("targeting", "Targeting & Interaction", "How targets are selected and how soft targeting behaves.", {
	{ "selection", "Target selection" }, { "mouseover", "Mouseover" }, { "softTarget", "Soft targeting" },
	{ "interaction", "Interaction behavior" },
})
C("nameplates", "Nameplates & Unit Frames", "Nameplate visibility, scale and unit frame display.", {
	{ "visibility", "Visibility" }, { "scaling", "Scaling" }, { "positioning", "Positioning" },
	{ "opacity", "Opacity" }, { "health", "Health" }, { "auras", "Auras" },
})
C("questing", "Questing & Navigation", "Quest display, maps, minimap and travel.", {
	{ "indicators", "Quest indicators" }, { "tracking", "Quest tracking" }, { "worldMap", "World map" },
	{ "minimap", "Minimap" }, { "navigation", "Navigation" }, { "flightPaths", "Flight paths" },
})
C("controls", "Controls & Input", "Keyboard, mouse, movement and controller input.", {
	{ "keyboard", "Keyboard" }, { "mouse", "Mouse" }, { "movement", "Movement" }, { "controller", "Controller" },
})
C("audio", "Audio", "Volume levels and sound behavior.", {
	{ "master", "Master volume" }, { "music", "Music" }, { "ambient", "Ambient sound" },
	{ "effects", "Effects" }, { "dialogue", "Dialogue" }, { "behavior", "Audio behavior" },
})
C("interface", "Interface", "Action bars, chat, menus and notifications.", {
	{ "actionBars", "Action bars" }, { "chat", "Chat" }, { "menus", "Menus" },
	{ "notifications", "Notifications" }, { "behavior", "Interface behavior" },
})
C("accessibility", "Accessibility", "Readability, motion reduction and color options.", {
	{ "text", "Text readability" }, { "motion", "Motion reduction" }, { "visual", "Visual assistance" },
	{ "color", "Color options" },
})
C("performance", "Performance", "Frame rate limits and resource usage.", {
	{ "frameRate", "Frame rate" }, { "rendering", "Rendering optimizations" },
	{ "background", "Background performance" }, { "resources", "Resource management" },
})
C("network", "Network", "Latency and network behavior supported by the client.", {
	{ "latency", "Latency" }, { "behavior", "Network behavior" },
})
C("advanced", "Advanced & Experimental", "Experimental settings, client information and the technical CVar browser.", {
	{ "experimental", "Experimental settings" }, { "unclassified", "Unclassified variables" },
	{ "info", "Read-only information" }, { "browser", "Technical CVar browser" },
})
