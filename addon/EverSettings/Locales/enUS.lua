-- English (default) strings for interface chrome.
-- Setting names and descriptions live in the definition files, which are data.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L.ADDON_TITLE = "EverSettings"
L.SEARCH_PLACEHOLDER = "Search settings"
L.PENDING_NONE = "No pending changes"
L.PENDING_FMT = "%d pending change(s)"
L.APPLY = "Apply"
L.DISCARD = "Discard"
L.RESET_CATEGORY = "Reset category"
L.UNDO = "Undo"
L.REDO = "Redo"
L.RESET = "Reset to default"
L.INSPECTOR = "Inspector"
L.HELP = "Help"
L.CLOSE = "Close"
L.PROFILES = "Profiles"
L.NO_PROFILE = "No profile"
L.FAVORITES = "Favorites"
L.MODIFIED = "Modified"
L.RECENT = "Recently Changed"
L.ALL_SETTINGS = "All Settings"
L.DIAGNOSTICS = "Diagnostics"
L.CVAR_BROWSER = "CVar Browser"
L.SEARCH_RESULTS = "Search results"
L.EMPTY_CATEGORY = "No researched settings in this category yet."
L.EMPTY_CATEGORY_HINT = "Variables that belong here are listed read-only in Advanced > CVar Browser until their behaviour and safe values are researched."
L.EMPTY_FAVORITES = "No favorites yet. Use the star on any setting to pin it here."
L.EMPTY_MODIFIED = "Every managed setting is at its factory default."
L.EMPTY_RECENT = "No changes recorded yet."
L.EMPTY_SEARCH = "No settings match your search."
L.IN_COMBAT = "Unavailable in combat"
L.HELP_TEXT = [[EverSettings shows researched game settings with clear controls.

Changes are staged first. Nothing reaches the game until you press Apply, and the footer shows how many changes are waiting.

Slash commands
  /es or /eversettings    open or close the window
  /es diag                print a diagnostics summary
  /es discover            re-run CVar discovery (read-only)
  /es resetwindow         reset window position and size
  /es debug               toggle debug messages

Verification badges
  VERIFIED     observed working in game
  SOURCE       documented in Blizzard's Forever UI source
  COMMUNITY    reported by other players or addons
  EXPERIMENTAL known to be risky or incomplete
  UNKNOWN      not researched yet; shown read-only]]
