-- Setting definition schema. See docs/SETTINGS_SCHEMA.md for the full description.
-- The validator runs at login (results visible in Diagnostics) and offline in tests.
local _, ns = ...

local Schema = {}
ns.Schema = Schema

Schema.Provider = {
	CVar = "cvar",             -- one console variable
	Composite = "composite",   -- one control driving several variables
	API = "api",               -- dedicated getter/setter functions
	Blizzard = "blizzard",     -- Blizzard Settings API (reserved; not used in Milestone A)
	Diagnostic = "diagnostic", -- read-only information
}

Schema.Control = {
	Slider = "slider",     -- numeric with researched range: slider + edit box
	Toggle = "toggle",
	Dropdown = "dropdown",
	Number = "number",     -- numeric without a researched range: edit box only (advanced)
	Text = "text",
	ReadOnly = "readonly",
}

Schema.ValueType = {
	Number = "number", Integer = "integer", Boolean = "boolean", Enum = "enum", String = "string",
}

-- Verification states, strongest first.
Schema.Verification = {
	Verified = "verified",         -- observed in game on Forever
	Source = "source",             -- documented in Blizzard's Forever UI source or client dump
	Community = "community",       -- reported by addons/players, not checked by us
	Experimental = "experimental", -- known risky, incomplete or behaviour unclear
	Unknown = "unknown",
	Unsupported = "unsupported",   -- restricted or not functional on Forever
}
Schema.VerificationOrder = { "verified", "source", "community", "experimental", "unknown", "unsupported" }

-- Separate evidence aspects, see docs/SETTINGS_RESEARCH.md.
Schema.EvidenceAspects = { "exists", "values", "write", "persist", "effect" }
Schema.EvidenceLabels = {
	exists = "Variable exists", values = "Accepted values", write = "Write permission",
	persist = "Persistence", effect = "Observed effect",
}

Schema.Scope = {
	Account = "account",       -- stored server-side per account
	Character = "character",   -- stored server-side per character
	Machine = "machine",       -- stored locally (Config.wtf)
	Addon = "addon",           -- EverSettings' own saved variables
	Unknown = "unknown",
}

Schema.Apply = {
	Immediate = "immediate",
	GxRestart = "gxrestart",   -- graphics device restart (brief screen flicker)
	Reload = "reload",         -- requires /reload
	Restart = "restart",       -- requires a full client restart
}

Schema.Classification = {
	Standard = "standard",         -- exposed in Blizzard's Forever settings window
	Hidden = "hidden",             -- console only
	Experimental = "experimental",
}

local VALID = {}
for key, enum in pairs({ provider = Schema.Provider, control = Schema.Control, valueType = Schema.ValueType,
		apply = Schema.Apply, classification = Schema.Classification, scope = Schema.Scope }) do
	VALID[key] = {}
	for _, v in pairs(enum) do VALID[key][v] = true end
end
local VALID_VERIFICATION = {}
for _, v in pairs(Schema.Verification) do VALID_VERIFICATION[v] = true end

local function err(list, def, fmt, ...)
	list[#list + 1] = ("%s: " .. fmt):format(tostring(def and def.id or "?"), ...)
end

-- Validate one definition. `categories` is ns.Categories (for category/subcategory checks)
-- and `catalog` is ns.CVarCatalog (optional cross-check). Returns errors, warnings.
function Schema.Validate(def, categories, catalog)
	local errors, warnings = {}, {}
	if type(def) ~= "table" then
		errors[1] = "definition is not a table"
		return errors, warnings
	end
	if type(def.id) ~= "string" or not def.id:match("^[%w_]+%.[%w_%.]+$") then
		err(errors, def, "id must look like 'category.name'")
	end
	for _, field in ipairs({ "name", "description", "category", "subcategory", "provider", "control", "valueType" }) do
		if type(def[field]) ~= "string" or def[field] == "" then
			err(errors, def, "missing required string field '%s'", field)
		end
	end
	if def.provider and not VALID.provider[def.provider] then err(errors, def, "unknown provider '%s'", tostring(def.provider)) end
	if def.control and not VALID.control[def.control] then err(errors, def, "unknown control '%s'", tostring(def.control)) end
	if def.valueType and not VALID.valueType[def.valueType] then err(errors, def, "unknown valueType '%s'", tostring(def.valueType)) end
	if def.apply and not VALID.apply[def.apply] then err(errors, def, "unknown apply '%s'", tostring(def.apply)) end
	if def.classification and not VALID.classification[def.classification] then err(errors, def, "unknown classification '%s'", tostring(def.classification)) end
	if def.scope and not VALID.scope[def.scope] then err(errors, def, "unknown scope '%s'", tostring(def.scope)) end

	if categories and def.category then
		local cat = categories.byId[def.category]
		if not cat then
			err(errors, def, "unknown category '%s'", def.category)
		elseif def.subcategory and not cat.subById[def.subcategory] then
			err(errors, def, "unknown subcategory '%s' in '%s'", def.subcategory, def.category)
		end
	end

	-- Provider-specific requirements.
	if def.provider == "cvar" then
		if type(def.cvar) ~= "string" then
			err(errors, def, "cvar provider requires 'cvar'")
		elseif catalog and catalog.cvars and not ns.Registry.FindCatalogEntry(def.cvar) then
			err(warnings, def, "cvar '%s' is not in the bundled catalog", def.cvar)
		end
	elseif def.provider == "composite" then
		if type(def.composite) ~= "string" then
			err(errors, def, "composite provider requires 'composite' (handler name)")
		end
		if type(def.cvars) ~= "table" or #def.cvars == 0 then
			err(errors, def, "composite provider requires a non-empty 'cvars' list")
		end
	elseif def.provider == "api" then
		if type(def.api) ~= "string" then err(errors, def, "api provider requires 'api' (handler name)") end
	elseif def.provider == "diagnostic" then
		if def.control ~= "readonly" then err(errors, def, "diagnostic settings must use the readonly control") end
	end

	-- Control/value-type coherence. Mandatory UI rule: numeric controls need a researched range.
	if def.control == "slider" then
		if def.valueType ~= "number" and def.valueType ~= "integer" then
			err(errors, def, "slider requires a numeric valueType")
		end
		if not def.rangeFunc then
			if type(def.min) ~= "number" or type(def.max) ~= "number" or def.min >= def.max then
				err(errors, def, "slider requires numeric min < max (or rangeFunc)")
			end
			if type(def.step) ~= "number" or def.step <= 0 then
				err(errors, def, "slider requires a positive step")
			end
		end
		if not def.rangeSource then
			err(errors, def, "slider requires 'rangeSource' citing where the range comes from")
		end
		if def.extendedRange then
			local e = def.extendedRange
			if type(e.min) ~= "number" or type(e.max) ~= "number" or type(e.source) ~= "string" then
				err(errors, def, "extendedRange needs min, max and a source")
			end
		end
	elseif def.control == "toggle" then
		if def.valueType ~= "boolean" then err(errors, def, "toggle requires valueType 'boolean'") end
	elseif def.control == "dropdown" then
		if def.optionsFunc and (type(def.options) ~= "table") then
			if type(def.optionsFunc) ~= "string" then err(errors, def, "optionsFunc must be a handler name") end
		elseif type(def.options) ~= "table" or #def.options < 2 then
			err(errors, def, "dropdown requires at least two options")
		else
			local seen = {}
			for i, opt in ipairs(def.options) do
				if opt.value == nil or type(opt.label) ~= "string" then
					err(errors, def, "option %d needs value and label", i)
				elseif seen[tostring(opt.value)] then
					err(errors, def, "duplicate option value '%s'", tostring(opt.value))
				end
				seen[tostring(opt.value or "")] = true
			end
		end
	end

	-- Research metadata.
	if type(def.sources) ~= "table" or #def.sources == 0 then
		err(errors, def, "at least one research source is required")
	end
	if type(def.verification) ~= "table" then
		err(errors, def, "verification evidence table is required")
	else
		for aspect, state in pairs(def.verification) do
			if not Schema.EvidenceLabels[aspect] then
				err(errors, def, "unknown evidence aspect '%s'", tostring(aspect))
			elseif not VALID_VERIFICATION[state] then
				err(errors, def, "unknown verification state '%s' for %s", tostring(state), aspect)
			end
		end
	end
	if def.status and not VALID_VERIFICATION[def.status] then
		err(errors, def, "unknown status '%s'", tostring(def.status))
	end
	if def.status == "verified" and def.verification and def.verification.effect ~= "verified" then
		err(errors, def, "status 'verified' requires in-game verified effect evidence")
	end
	return errors, warnings
end
