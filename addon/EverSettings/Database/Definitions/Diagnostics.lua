-- Read-only information rows (Advanced > Read-only information).
local _, ns = ...
local R = ns.Registry

local function info(id, name, description, handler)
	return {
		id = "advanced." .. id, subcategory = "info", name = name, description = description,
		provider = "diagnostic", diagnostic = handler, control = "readonly", valueType = "string",
		scope = "addon", classification = "standard",
		sources = { "EverSettings runtime" },
		verification = { exists = "verified", values = "verified" },
		status = "source",
	}
end

R:DefineGroup({ category = "advanced" }, {
	info("clientBuild", "Client Build", "Version, build number and build date reported by GetBuildInfo().", "clientBuild"),
	info("interfaceVersion", "Interface Version", "TOC interface number. Forever uses the 16000-16999 range.", "interfaceVersion"),
	info("locale", "Client Locale", "Language of the game client.", "locale"),
	info("screenSize", "Physical Screen Size", "Physical screen size reported by GetPhysicalScreenSize().", "screenSize"),
	info("catalog", "Bundled CVar Catalog", "Source build of EverSettings' bundled variable catalog.", "catalogInfo"),
	info("discovery", "Runtime Discovery", "Result of the read-only enumeration with ConsoleGetAllCommands().", "discoveredCVars"),
})
