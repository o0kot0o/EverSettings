-- Startup and event wiring. Startup is strictly read-only: EverSettings never changes a
-- game setting unless the player applies a change.
local addonName, ns = ...

local Util, Compat = ns.Util, ns.Compat
local frame = CreateFrame("Frame")
ns.eventFrame = frame

local function Migrate(db)
	db.dbVersion = db.dbVersion or 1
	if db.dbVersion < 2 then
		-- 0.1.0 opened the Details panel by default without it being a player choice; from
		-- 0.2 it is hidden unless the player turns it on.
		if not db.window.inspectorChosen then db.window.inspector = false end
	end
	db.dbVersion = ns.DB_VERSION
end

local function OnAddonLoaded()
	EverSettingsDB = EverSettingsDB or {}
	ns.db = Util.ApplyDefaults(EverSettingsDB, ns.DB_DEFAULTS)
	Migrate(ns.db)
	Compat:Detect()
	ns.Registry:Finalize()
	ns.Backup:Migrate() -- scoped originals (v3); needs finalized definitions
	if #ns.Registry.errors > 0 then
		ns:Print("%d setting definition(s) failed validation and were disabled. See /es diag.", #ns.Registry.errors)
	end
end

local function OnPlayerLogin()
	-- Read-only startup work, spread out slightly to stay off the login hitch.
	ns.Sync:Prime()
	Compat.After(1, function()
		local ok, err = pcall(ns.Backup.EnsureInitialSnapshot, ns.Backup)
		if not ok then ns:Print("initial snapshot failed: %s", tostring(err)) end
	end)
	Compat.After(3, function()
		local ok, err = pcall(ns.Discovery.Run, ns.Discovery)
		if not ok then ns:Print("discovery failed: %s", tostring(err)) end
	end)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			OnAddonLoaded()
			frame:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		OnPlayerLogin()
	elseif event == "CVAR_UPDATE" then
		if ns.db then ns.Sync:OnCVarUpdate(...) end
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		if ns.Window then ns.Window:OnCombatChanged() end
	end
end)

-- Slash commands ------------------------------------------------------------------
local function HandleSlash(msg)
	local cmd = Util.Trim(msg or ""):lower()
	if not ns.db then
		ns:Print("not initialised yet.")
		return
	end
	if cmd == "" or cmd == "show" or cmd == "toggle" then
		ns.Window:Toggle()
	elseif cmd == "diag" or cmd == "diagnostics" then
		ns.Diagnostics:PrintSummary()
	elseif cmd == "discover" then
		ns.Discovery:Run()
		ns.Diagnostics:PrintSummary()
	elseif cmd == "resetwindow" then
		ns.Window:ResetPosition()
		ns:Print("window position and size reset.")
	elseif cmd == "debug" then
		ns.db.debug = not ns.db.debug
		ns:Print("debug messages %s.", ns.db.debug and "on" or "off")
	elseif cmd == "help" then
		ns:Print("/es - open or close | /es diag | /es discover | /es resetwindow | /es debug")
	else
		ns:Print("unknown command '%s'. Try /es help.", cmd)
	end
end

SLASH_EVERSETTINGS1 = "/eversettings"
SLASH_EVERSETTINGS2 = "/es"
SlashCmdList.EVERSETTINGS = HandleSlash
ns.HandleSlash = HandleSlash
