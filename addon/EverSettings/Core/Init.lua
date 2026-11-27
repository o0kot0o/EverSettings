-- EverSettings core namespace, constants and saved-variable defaults.
local addonName, ns = ...

ns.name = addonName
ns.version = "0.3.0-alpha"
ns.TARGET_INTERFACE = 16001

-- Saved variable layout version. Bump and add a migration in Boot.lua when the layout changes.
ns.DB_VERSION = 3

ns.DB_DEFAULTS = {
	dbVersion = ns.DB_VERSION,
	-- Details panel (inspector) is hidden on fresh installs; inspectorChosen records that the
	-- player toggled it, so their choice is kept.
	window = { point = "CENTER", x = 0, y = 0, width = 1100, height = 700, scale = 1,
		inspector = false, inspectorChosen = false, inspectorWidth = 320 },
	ui = { collapsed = {}, lastPage = "category:graphics", showTechnical = false, hideEmpty = false },
	favorites = {},          -- [settingId] = true
	profiles = {},           -- [name] = profile table (see Profiles.lua)
	activeProfile = nil,
	snapshots = {},          -- initial snapshot (machine/account scoped CVars)
	characterSnapshots = {}, -- [charKey] = initial snapshot of character scoped CVars
	originals = {},          -- legacy (0.1/0.2): migrated into originalsScoped by Backup:Migrate
	originalsScoped = {},    -- [scopeKey][settingId] = { value, raw, time, build, provider, scope, owner }
	originalsLegacy = {},    -- legacy character-scoped originals that cannot be attributed to a character
	backups = {},            -- list of { name, time, reason, values = { [id] = serialized } }
	history = {},            -- list of change records, newest last
	discovery = {},          -- results of the last runtime discovery, keyed by build
	debug = false,
}

ns.MAX_HISTORY = 500
ns.MAX_BACKUPS = 25

function ns:Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	print("|cff3aa7a3EverSettings|r: " .. msg)
end

function ns:Debug(fmt, ...)
	if self.db and self.db.debug then
		local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
		print("|cff7f8590EverSettings debug|r: " .. msg)
	end
end
