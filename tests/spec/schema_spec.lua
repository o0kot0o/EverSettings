local _, ns = ...
local Schema, Registry = ns.Schema, ns.Registry

describe("definitions", function()
	it("all pass schema validation", function()
		eq(#Registry.errors, 0, "validation errors: " .. table.concat(Registry.errors, "; "))
		eq(#Registry.warnings, 0, "validation warnings: " .. table.concat(Registry.warnings, "; "))
	end)

	it("cover Graphics, Camera and Quality of Life", function()
		truthy(Registry:CountCategory("graphics") >= 25, "graphics count")
		truthy(Registry:CountCategory("camera") >= 10, "camera count")
		truthy(Registry:CountCategory("qol") >= 15, "qol count")
	end)

	it("reference CVars that exist in the catalog with their canonical casing", function()
		for _, d in ipairs(Registry.ordered) do
			if d.provider == "cvar" then
				local entry, canonical = Registry.FindCatalogEntry(d.cvar)
				truthy(entry, d.id .. " cvar " .. d.cvar)
				eq(d.cvar, canonical, d.id)
			end
			for _, name in ipairs(d.cvars or {}) do
				truthy(Registry.FindCatalogEntry(name), d.id .. " composite cvar " .. name)
			end
		end
	end)

	it("every slider has a researched range and cites it", function()
		for _, d in ipairs(Registry.ordered) do
			if d.control == "slider" then
				truthy(d.rangeSource, d.id .. " rangeSource")
				local lo, hi, step = ns.Providers:GetRange(d)
				truthy(lo and hi and lo < hi, d.id .. " range")
				truthy(step and step > 0, d.id .. " step")
			end
		end
	end)

	it("defaults of curated settings lie inside their documented values", function()
		for _, d in ipairs(Registry.ordered) do
			if d.control ~= "readonly" and d.provider ~= "diagnostic" and ns.Providers:IsAvailable(d) then
				local default = ns.Providers:GetDefault(d)
				truthy(default ~= nil, d.id .. " default")
				local ok, err = ns.Values.Validate(d, default)
				truthy(ok, d.id .. " default " .. tostring(default) .. " invalid: " .. tostring(err))
			end
		end
	end)

	it("derive scope, classification and secure restrictions from the catalog", function()
		eq(def("qol.autoLoot").scope, "account")
		eq(def("questing.showQuestLevel").scope, "character")
		eq(def("graphics.gamma").scope, "machine")
		eq(def("graphics.gamma").classification, "standard")
		eq(def("qol.showLootSpam").classification, "hidden")
		truthy(def("qol.autoStand").restrictions.secure)
		truthy(def("qol.autoStand").restrictions.combat)
		truthy(def("graphics.uiScale").restrictions.secure)
	end)

	it("only mark settings verified when an in-game source is cited", function()
		for _, d in ipairs(Registry.ordered) do
			if d.provider ~= "diagnostic" then
				local cited = false
				for _, src in ipairs(d.sources) do
					if src:find("In game") then cited = true end
				end
				for aspect, state in pairs(d.verification) do
					if state == "verified" then
						truthy(cited, d.id .. " has '" .. aspect .. "' verified without an in-game source")
					end
				end
			end
		end
	end)

	it("records the in-game verified settings", function()
		eq(def("camera.maxZoom").statusSummary, "verified")
		eq(def("camera.maxZoom").verification.effect, "verified")
		eq(def("graphics.gamma").verification.write, "verified")
		eq(def("graphics.gamma").statusSummary, "source", "effect not yet observed, so not shown as VERIFIED")
	end)

	it("have unique ids and valid categories", function()
		local seen = {}
		for _, d in ipairs(Registry.ordered) do
			falsy(seen[d.id], "duplicate " .. d.id)
			seen[d.id] = true
			truthy(ns.Categories.byId[d.category].subById[d.subcategory], d.id .. " subcategory")
		end
	end)
end)

describe("schema validator", function()
	local function base(extra)
		local d = {
			id = "test.x", name = "X", description = "d", category = "graphics", subcategory = "display",
			provider = "cvar", cvar = "Gamma", control = "toggle", valueType = "boolean",
			sources = { "s" }, verification = { exists = "source" },
		}
		for k, v in pairs(extra or {}) do d[k] = v end
		return d
	end
	local function errorsOf(d) return (Schema.Validate(d, ns.Categories, ns.CVarCatalog)) end

	it("accepts a minimal valid definition", function()
		eq(#errorsOf(base()), 0)
	end)
	it("rejects a slider without a range", function()
		truthy(#errorsOf(base({ control = "slider", valueType = "number" })) > 0)
	end)
	it("rejects a slider without a cited range source", function()
		truthy(#errorsOf(base({ control = "slider", valueType = "number", min = 0, max = 1, step = 0.1 })) > 0)
	end)
	it("rejects a dropdown with a single option", function()
		truthy(#errorsOf(base({ control = "dropdown", valueType = "enum", options = { { value = 1, label = "a" } } })) > 0)
	end)
	it("rejects unknown providers, categories and verification states", function()
		truthy(#errorsOf(base({ provider = "magic" })) > 0)
		truthy(#errorsOf(base({ category = "nope" })) > 0)
		truthy(#errorsOf(base({ verification = { exists = "probably" } })) > 0)
	end)
	it("rejects 'verified' status without verified effect evidence", function()
		truthy(#errorsOf(base({ status = "verified", verification = { effect = "source" } })) > 0)
	end)
	it("requires research sources", function()
		truthy(#errorsOf(base({ sources = {} })) > 0)
	end)
end)
