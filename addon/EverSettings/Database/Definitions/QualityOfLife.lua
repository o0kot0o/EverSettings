-- Quality of Life definitions, plus related questing/interface conveniences.
local _, ns = ...
local R = ns.Registry

local CTRL = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Frame/Controls.lua"
local IFACE_CAMELOT = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Frame/Camelot/InterfaceOverrides.lua"
local PRESET = "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Shared/Preset.lua"
local CHAT = "wow-ui-source@forever 1.60.1.71139 Blizzard_ChatFrameBase/Mainline/ChatFrameOverrides.lua"
local DUMP = "Client CVar dump 1.60.1.70938 (Ketho/BlizzardInterfaceResources@forever Resources/CVars.lua)"
local STR = "GlobalStrings enUS (Ketho/BlizzardInterfaceResources@forever)"
local FPP = "ForeverPlusPlus docs/forever-api.md (xIGBClutchIx/ForeverPlusPlus@6b98426)"

local function standard()
	return { exists = "source", values = "source", write = "source", persist = "unknown", effect = "source" }
end
-- Hidden variables documented only by the client's own help text.
local function helpOnly()
	return { exists = "source", values = "source", write = "source", persist = "unknown", effect = "unknown" }
end

R:DefineGroup({ category = "qol" }, {
	-- Looting -------------------------------------------------------------------
	{
		id = "qol.autoLoot", subcategory = "looting", name = "Auto Loot",
		description = "Makes Auto Loot the default when clicking lootable things. Hold the Loot Key to do the opposite.",
		keywords = { "auto loot", "loot" },
		provider = "cvar", cvar = "autoLootDefault", control = "toggle", valueType = "boolean",
		sources = { CTRL .. " (autoLootDefault)", STR .. " OPTION_TOOLTIP_AUTO_LOOT_DEFAULT" }, verification = standard(),
	},
	{
		id = "qol.lootUnderMouse", subcategory = "looting", name = "Open Loot Window at Mouse",
		description = "Opens the loot window at the current mouse position.",
		keywords = { "loot window", "cursor" },
		provider = "cvar", cvar = "lootUnderMouse", control = "toggle", valueType = "boolean",
		sources = { CTRL .. " (lootUnderMouse)", STR .. " OPTION_TOOLTIP_LOOT_UNDER_MOUSE" }, verification = standard(),
	},
	{
		id = "qol.lootSparkles", subcategory = "looting", name = "Loot Sparkles Without Outlines",
		description = "When Outline Mode is disabled, replaces passive outlines with loot sparkles. Community reports say it also makes quest givers sparkle and that turning it back off needs a full client restart.",
		keywords = { "sparkle", "quest items", "outline" },
		provider = "cvar", cvar = "outlineModeShowLootEffectWhenDisabled", control = "toggle", valueType = "boolean",
		classification = "experimental", apply = "restart",
		related = { "graphics.outlineMode" },
		sources = { DUMP .. " (help text)", FPP .. " (Forever Loot Sparkles / OneForAll reports, restart needed to revert)" },
		verification = { exists = "source", values = "source", write = "community", persist = "unknown", effect = "community" },
	},
	{
		id = "qol.showLootSpam", subcategory = "looting", name = "Show Full Loot Rolls in Chat",
		description = "Whether to show full loot rolls in chat (client help text). Forever-specific variable; not in Blizzard's settings window.",
		keywords = { "loot rolls", "chat spam" },
		provider = "cvar", cvar = "showLootSpam", control = "toggle", valueType = "boolean",
		sources = { DUMP .. " ('Whether to show full loot rolls in chat.')", FPP .. " (Forever-only CVar)" }, verification = helpOnly(),
	},

	-- Inventory -------------------------------------------------------------------
	{
		id = "qol.freeBagSlots", subcategory = "inventory", name = "Show Free Bag Space",
		description = "Displays remaining inventory space on the backpack icon.",
		keywords = { "bag space", "slots", "backpack" },
		provider = "cvar", cvar = "displayFreeBagSlots", control = "toggle", valueType = "boolean",
		sources = { IFACE_CAMELOT .. " (displayFreeBagSlots)", STR .. " OPTION_TOOLTIP_DISPLAY_FREE_BAG_SLOTS" }, verification = standard(),
	},
	{
		id = "qol.combinedBags", subcategory = "inventory", name = "Combined Bags",
		description = "Uses one combined bag frame for all bags.",
		keywords = { "one bag", "bags" },
		provider = "cvar", cvar = "combinedBags", control = "toggle", valueType = "boolean",
		sources = { PRESET .. " (combinedBags)", DUMP .. " ('Use combined bag frame for all bags')" }, verification = standard(),
	},

	-- Tooltips -----------------------------------------------------------------------
	{
		id = "qol.compareItems", subcategory = "tooltips", name = "Always Compare Items",
		description = "Always shows item comparison tooltips (client help text). Used by Blizzard's tooltip code but not offered in Forever's settings window.",
		keywords = { "compare", "tooltip", "shift" },
		provider = "cvar", cvar = "alwaysCompareItems", control = "toggle", valueType = "boolean",
		sources = { DUMP .. " ('Always show item comparison tooltips')", "wow-ui-source@forever Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua" },
		verification = helpOnly(),
	},
	{
		id = "qol.verboseTooltips", subcategory = "tooltips", name = "Verbose Tooltips",
		description = "Shows verbose tooltips (client help text), for example full spell descriptions on action buttons.",
		keywords = { "uber tooltips", "detailed" },
		provider = "cvar", cvar = "UberTooltips", control = "toggle", valueType = "boolean",
		sources = { DUMP .. " ('Show verbose tooltips')", "wow-ui-source@forever Blizzard_ActionBar/Shared/ActionButton.lua" },
		verification = helpOnly(),
	},

	-- Interaction -----------------------------------------------------------------------
	{
		id = "qol.interactOnLeftClick", subcategory = "interaction", name = "Interact on Left Click",
		description = "Interact with objects and friendly NPCs using left or right click.",
		keywords = { "click", "npc" },
		provider = "cvar", cvar = "interactOnLeftClick", control = "toggle", valueType = "boolean",
		sources = { CTRL .. " (interactOnLeftClick)", STR .. " OPTION_TOOLTIP_INTERACT_ON_LEFT_CLICK" }, verification = standard(),
	},
	{
		id = "qol.stickyTargeting", subcategory = "interaction", name = "Sticky Targeting",
		description = "Prevents clicking the game world from clearing your target. Targets clear only with Escape or by clicking another target. Stored inverted as deselectOnClick.",
		keywords = { "deselect", "target", "click terrain" },
		provider = "cvar", cvar = "deselectOnClick", invert = true, control = "toggle", valueType = "boolean",
		technical = "deselectOnClick (inverted)",
		sources = { CTRL .. " (deselectOnClick with NegateBoolean)", STR .. " OPTION_TOOLTIP_GAMEFIELD_DESELECT" }, verification = standard(),
	},
	{
		id = "qol.questItemLeftClick", subcategory = "interaction", name = "Use Quest Items with Left Click",
		description = "Whether you can use a quest item by left clicking on a relevant creature (client help text). Forever-specific variable.",
		keywords = { "quest item", "click" },
		provider = "cvar", cvar = "canUseQuestItemWithLeftClick", control = "toggle", valueType = "boolean",
		sources = { DUMP, FPP .. " (Forever-only CVar)" }, verification = helpOnly(),
	},

	-- Convenience -------------------------------------------------------------------------
	{
		id = "qol.autoClearAFK", subcategory = "convenience", name = "Auto Clear AFK",
		description = "Automatically leaves Away mode when you move or talk.",
		keywords = { "afk", "away" },
		provider = "cvar", cvar = "autoClearAFK", control = "toggle", valueType = "boolean",
		sources = { CTRL .. " (autoClearAFK)", STR .. " OPTION_TOOLTIP_CLEAR_AFK" }, verification = standard(),
	},
	{
		id = "qol.instantQuestText", subcategory = "convenience", name = "Instant Quest Text",
		description = "Shows quest text instantly instead of fading it in.",
		keywords = { "quest text", "fade" },
		provider = "cvar", cvar = "instantQuestText", control = "toggle", valueType = "boolean",
		sources = { IFACE_CAMELOT .. " (instantQuestText)", STR .. " OPTION_TOOLTIP_SHOW_QUEST_FADING" }, verification = standard(),
	},
	{
		id = "qol.loadingScreenTips", subcategory = "convenience", name = "Loading Screen Tips",
		description = "Shows the tip of the day on loading screens.",
		keywords = { "tips", "loading" },
		provider = "cvar", cvar = "showLoadingScreenTips", control = "toggle", valueType = "boolean",
		sources = { IFACE_CAMELOT .. " (showLoadingScreenTips)", STR .. " OPTION_TOOLTIP_SHOW_TIPOFTHEDAY" }, verification = standard(),
	},
	{
		id = "qol.autoDismount", subcategory = "convenience", name = "Auto Dismount",
		description = "Automatically dismount when needed (client help text). Not offered in Forever's settings window; exactly which actions trigger it is unverified.",
		keywords = { "mount", "dismount" },
		provider = "cvar", cvar = "autoDismount", control = "toggle", valueType = "boolean",
		sources = { DUMP .. " ('Automatically dismount when needed')", FPP .. " (defaults and scope unverified)" }, verification = helpOnly(),
	},
	{
		id = "qol.autoStand", subcategory = "convenience", name = "Auto Stand",
		description = "Automatically stand when needed (client help text). Secure variable: cannot be changed during combat.",
		keywords = { "sit", "stand" },
		provider = "cvar", cvar = "autoStand", control = "toggle", valueType = "boolean",
		sources = { DUMP .. " ('Automatically stand when needed', secure)" },
		verification = { exists = "source", values = "source", write = "unknown", persist = "unknown", effect = "unknown" },
	},
	{
		id = "qol.autoUnshift", subcategory = "convenience", name = "Auto Leave Shapeshift",
		description = "Automatically leave shapeshift form when needed (client help text). Secure variable: cannot be changed during combat.",
		keywords = { "shapeshift", "druid", "form" },
		provider = "cvar", cvar = "autoUnshift", control = "toggle", valueType = "boolean",
		sources = { DUMP .. " ('Automatically leave shapeshift form when needed', secure)" },
		verification = { exists = "source", values = "source", write = "unknown", persist = "unknown", effect = "unknown" },
	},
	{
		id = "qol.breakUpLargeNumbers", subcategory = "convenience", name = "Separate Large Numbers",
		description = "Uses separators in large numbers (client help text: 'Toggles using commas in large numbers').",
		keywords = { "commas", "numbers" },
		provider = "cvar", cvar = "breakUpLargeNumbers", control = "toggle", valueType = "boolean",
		sources = { DUMP }, verification = helpOnly(),
	},
})

R:DefineGroup({ category = "questing" }, {
	{
		id = "questing.showQuestLevel", subcategory = "indicators", name = "Show Quest Levels",
		description = "Shows quest levels in the quest list and quest text (client help text). Forever-specific variable.",
		keywords = { "quest level" },
		provider = "cvar", cvar = "showQuestLevel", control = "toggle", valueType = "boolean",
		sources = { DUMP, "wow-ui-source@forever Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua", FPP }, verification = helpOnly(),
	},
	{
		id = "questing.trivialQuests", subcategory = "indicators", name = "Show Low-Level Quests",
		description = "Tracks trivial (low-level) quests on the minimap, using the minimap tracking API exactly as Forever's settings window does.",
		keywords = { "trivial", "grey quests", "low level" },
		provider = "api", api = "trivialQuestTracking", control = "toggle", valueType = "boolean",
		scope = "character", classification = "standard", technical = "C_Minimap tracking filter TrivialQuests",
		sources = { IFACE_CAMELOT .. " (PROXY_TRIVIAL_QUEST_FILTERING)" },
		verification = { exists = "source", values = "source", write = "unknown", persist = "unknown", effect = "source" },
	},
	{
		id = "questing.flightmasterIcon", subcategory = "flightPaths", name = "Learned Flight Path Icon",
		description = "Shows an icon over flight masters whose flight path you have learned (client help text). Forever-specific variable.",
		keywords = { "taxi", "flight master" },
		provider = "cvar", cvar = "showTaxiNodeLearnedIcon", control = "toggle", valueType = "boolean",
		sources = { DUMP, FPP .. " (Forever-only CVar)" }, verification = helpOnly(),
	},
	{
		id = "questing.dungeonEntrances", subcategory = "worldMap", name = "Dungeon Entrances on Map",
		description = "Shows dungeon entrances on the world map. Forever's map menu does not offer this.",
		keywords = { "dungeon", "entrance", "map" },
		provider = "cvar", cvar = "showDungeonEntrancesOnMap", control = "toggle", valueType = "boolean",
		sources = { DUMP, "wow-ui-source@forever Blizzard_SharedMapDataProviders/DungeonEntranceDataProvider.lua", FPP },
		verification = { exists = "source", values = "source", write = "source", persist = "unknown", effect = "source" },
	},
	{
		id = "questing.mapPlayerCoords", subcategory = "worldMap", name = "World Map Player Coordinates",
		description = "Shows your coordinates on the world map.",
		keywords = { "coordinates", "coords" },
		provider = "cvar", cvar = "worldMapShowPlayerCoords", control = "toggle", valueType = "boolean",
		sources = { DUMP, FPP .. " (WorldMapCoordsPanelTemplate follows these CVars)" }, verification = standard(),
	},
	{
		id = "questing.mapCursorCoords", subcategory = "worldMap", name = "World Map Cursor Coordinates",
		description = "Shows the cursor's coordinates on the world map.",
		keywords = { "coordinates", "coords", "cursor" },
		provider = "cvar", cvar = "worldMapShowCursorCoords", control = "toggle", valueType = "boolean",
		sources = { DUMP, FPP }, verification = standard(),
	},
	{
		id = "questing.minimapCoords", subcategory = "minimap", name = "Minimap Coordinates",
		description = "Shows your coordinates on the minimap.",
		keywords = { "coordinates", "coords", "minimap" },
		provider = "cvar", cvar = "minimapShowPlayerCoords", control = "toggle", valueType = "boolean",
		sources = { DUMP }, verification = standard(),
	},
})

R:DefineGroup({ category = "interface" }, {
	{
		id = "interface.whisperMode", subcategory = "chat", name = "New Whispers",
		description = "Where new whisper conversations appear.",
		keywords = { "whisper", "tab", "chat" },
		provider = "cvar", cvar = "whisperMode", control = "dropdown", valueType = "enum", enumType = "string",
		options = {
			{ value = "inline", label = "In-line" }, { value = "popout", label = "New Tab" },
			{ value = "popout_and_inline", label = "Both" },
		},
		sources = { DUMP .. " (\"popout\", \"inline\", \"popout_and_inline\")", CHAT, STR .. " CONVERSATION_MODE_*" }, verification = standard(),
	},
	{
		id = "interface.localTime", subcategory = "behavior", name = "Use Local Time",
		description = "Shows your computer's time instead of realm time on the minimap clock.",
		keywords = { "clock", "time", "realm time" },
		provider = "cvar", cvar = "timeMgrUseLocalTime", control = "toggle", valueType = "boolean",
		sources = { DUMP, "wow-ui-source@forever Blizzard_FrameXMLUtil/GameTimeUtil.lua", FPP }, verification = standard(),
	},
})
