local _, ns = ...

describe("runtime discovery", function()
	it("separates variables from console commands", function()
		local r = ns.Discovery:Run()
		truthy(r.available)
		eq(r.numCVars, ns.CVarCatalog.meta.numCVars)
		eq(r.numCommands, ns.CVarCatalog.meta.numCommands)
		eq(#r.new, 0)
		eq(#r.missing, 0)
	end)

	it("detects new, missing and changed variables without writing", function()
		MOCK.cvars.brandnewcvar = "1"; MOCK.names.brandnewcvar = "brandNewCVar"; MOCK.defaults.brandnewcvar = "1"
		MOCK.hiddenFromConsole = { farclip = true }
		local oldDefault = MOCK.defaults.maxfps
		MOCK.defaults.maxfps = "144"
		local r = ns.Discovery:Run()
		MOCK.cvars.brandnewcvar, MOCK.names.brandnewcvar, MOCK.defaults.brandnewcvar = nil, nil, nil
		MOCK.hiddenFromConsole = nil
		MOCK.defaults.maxfps = oldDefault
		contains(r.new, "brandNewCVar")
		contains(r.missing, "farclip")
		eq(#r.changedDefaults, 1)
		eq(r.changedDefaults[1].name, "maxFPS")
		eq(writes(), 0)
		truthy(ns.db.discovery.byBuild[ns.Compat.buildString])
	end)

	it("counts unclassified variables", function()
		ns.Discovery:Run()
		local n = ns.Discovery:GetUnclassifiedCount()
		truthy(n > 1500 and n < ns.CVarCatalog.meta.numCVars, "unclassified " .. n)
	end)

	it("diagnostics report builds and finds no consistency issues", function()
		local text = ns.Diagnostics:BuildReport()
		truthy(text:find("API capabilities"))
		eq(#ns.Diagnostics:CheckDefinitions(), 0, table.concat(ns.Diagnostics:CheckDefinitions(), "; "))
	end)
end)
