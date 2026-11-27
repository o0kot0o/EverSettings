-- Collapsible right-hand inspector with full detail on the selected setting or variable.
local _, ns = ...

local Theme, UI, L, Util = ns.Theme, ns.UI, ns.L, ns.Util
local Values, Providers, Changes, Registry = ns.Values, ns.Providers, ns.Changes, ns.Registry

local SCOPE_LABELS = {
	account = "Account (stored on Blizzard's servers)", character = "Character (stored on Blizzard's servers)",
	machine = "This computer (Config.wtf)", addon = "EverSettings", unknown = "Unknown",
}
local APPLY_LABELS = {
	immediate = "Immediately", gxrestart = "Restarts the graphics device", reload = "Requires /reload", restart = "Requires a full game restart",
}

function UI.CreateInspector(parent, window)
	local f = CreateFrame("Frame", nil, parent)
	UI.Background(f, "inspector")
	local edge = UI.Line(f, "border", false)
	edge:SetPoint("TOPLEFT")
	edge:SetPoint("BOTTOMLEFT")

	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", 1, -1)
	scroll:SetPoint("BOTTOMRIGHT", -1, 1)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(Theme.metrics.inspectorWidth - 2, 10)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 40)))
	end)
	f.scroll, f.content = scroll, content

	-- Simple flowing layout: a pool of font strings and buttons stacked top to bottom.
	f.texts, f.buttons, f.badges = {}, {}, {}
	local y, textIndex, buttonIndex, badgeIndex
	local WIDTH = Theme.metrics.inspectorWidth - 32

	local function Begin()
		y, textIndex, buttonIndex, badgeIndex = -16, 0, 0, 0
		for _, t in ipairs(f.texts) do t:Hide() end
		for _, b in ipairs(f.buttons) do b:Hide() end
		for _, b in ipairs(f.badges) do b:Hide() end
	end

	local function Text(str, size, color, gap)
		textIndex = textIndex + 1
		local t = f.texts[textIndex]
		if not t then
			t = UI.Text(content, 12, "text")
			t:SetWordWrap(true)
			t:SetJustifyV("TOP")
			t:SetWidth(WIDTH)
			f.texts[textIndex] = t
		end
		t:SetFontObject(Theme:Font(size or 12, color or "text"))
		t:SetText(str)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", 16, y)
		t:Show()
		y = y - t:GetStringHeight() - (gap or 6)
		return t
	end

	local function Heading(str)
		y = y - 8
		Text(str, 10, "textDim", 4)
	end

	local function KV(key, value, color)
		Text(Theme:Colorize(key, "textMuted") .. "   " .. Theme:Colorize(tostring(value), color or "text"), 12, "text", 4)
	end

	local function Badges(list)
		local x = 16
		for _, entry in ipairs(list) do
			badgeIndex = badgeIndex + 1
			local b = f.badges[badgeIndex]
			if not b then
				b = UI.CreateBadge(content)
				f.badges[badgeIndex] = b
			end
			b:Set(entry[1], entry[2])
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", x, y)
			x = x + b:GetWidth() + 4
		end
		if #list > 0 then y = y - 20 end
	end

	local function LinkButton(label, onClick)
		buttonIndex = buttonIndex + 1
		local b = f.buttons[buttonIndex]
		if not b then
			b = UI.CreateButton(content, "", "ghost", WIDTH, 22)
			b.label:SetJustifyH("LEFT")
			f.buttons[buttonIndex] = b
		end
		b:SetText(label)
		b:SetScript("OnClick", onClick)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 10, y)
		b:Show()
		y = y - 24
	end

	local function Finish()
		content:SetHeight(-y + 16)
		scroll:SetVerticalScroll(0)
	end

	function f:ShowEmpty()
		Begin()
		Text(L.INSPECTOR, 15, "text", 8)
		Text("Select a setting to see its full description, values, restrictions, research sources and verification status.", 12, "textMuted")
		Finish()
	end

	function f:ShowSetting(def)
		if not def then return self:ShowEmpty() end
		self.current = { kind = "setting", id = def.id }
		Begin()
		Text(def.name, 15, "text", 4)
		Text(def.technical, 11, "textDim", 8)
		local badges = { { Theme.statusLabels[def.statusSummary] or def.statusSummary, def.statusSummary } }
		badges[#badges + 1] = { def.classification:upper(), def.classification == "standard" and "textMuted" or "warning" }
		if def.apply ~= "immediate" then badges[#badges + 1] = { (def.apply == "gxrestart" and "GX RESTART" or def.apply:upper()), "info" } end
		Badges(badges)
		Text(def.description, 12, "textMuted", 8)

		local available, reason = Providers:IsAvailable(def)
		local current = available and Providers:Get(def) or nil
		local pending, hasPending = Changes:GetPending(def.id)
		local default = Providers:GetDefault(def)
		local original = ns.Backup:GetOriginal(def)
		Heading("VALUES")
		KV("Current", available and Values.Format(def, current) or "unavailable", available and "text" or "textDim")
		if hasPending then KV("Pending", Values.Format(def, pending), "warning") end
		KV("Factory default", default ~= nil and Values.Format(def, default) or "unknown")
		if original ~= nil then KV("Before EverSettings", Values.Format(def, original)) end
		if def.provider ~= "diagnostic" and available then
			local raw = Providers:GetRaw(def)
			if raw and raw ~= "" then Text(raw, 10, "textDim", 4) end
		end

		if def.control ~= "readonly" and def.provider ~= "diagnostic" then
			Heading("VALID VALUES")
			if def.valueType == "boolean" then
				Text("On or Off", 12, "text")
			elseif def.control == "dropdown" then
				for _, opt in ipairs(Providers:GetOptions(def)) do
					if not opt.notSelectable then
						local line = ("%s  %s"):format(Theme:Colorize(tostring(opt.value), "textDim"), opt.label)
						if opt.disabled then line = line .. Theme:Colorize("  (" .. opt.disabled .. ")", "textDim") end
						Text(line, 12, "text", 3)
					end
				end
			elseif def.control == "slider" then
				local lo, hi, step = Providers:GetRange(def)
				if lo then
					local shownStep = Util.FormatNumber((step or 0) * (def.displayScale or 1), 6)
					Text(("%s to %s, step %s"):format(Values.Format(def, lo), Values.Format(def, hi), shownStep), 12, "text", 3)
					Text("Typed values are kept exactly; they are not rounded to the slider step.", 10, "textDim", 3)
				else
					Text("Range unavailable on this client.", 12, "textDim", 3)
				end
				if def.extendedRange then
					Text(("Extended range %s to %s (%s)"):format(Values.Format(def, def.extendedRange.min), Values.Format(def, def.extendedRange.max), def.extendedRange.source), 11, "warning", 3)
				end
				if def.rangeSource then Text(def.rangeSource, 10, "textDim", 3) end
			end
		end

		Heading("BEHAVIOUR")
		KV("Storage", SCOPE_LABELS[def.scope] or def.scope)
		KV("Takes effect", APPLY_LABELS[def.apply] or def.apply)
		KV("Provider", def.provider)
		local restriction = Providers:GetRestriction(def)
		if not available then
			KV("Availability", reason or "unavailable", "error")
		elseif restriction then
			KV("Restriction", restriction, "warning")
		end
		if def.restrictions.secure then Text("Secure variable: addons cannot change it during combat.", 11, "warning") end
		if def.performance then KV("Performance", def.performance) end
		for _, dep in ipairs(def.dependencies or {}) do
			local other = Registry:Get(dep.id)
			Text(Theme:Colorize("Depends on ", "textMuted") .. (other and other.name or dep.id) .. Theme:Colorize(" — " .. (dep.reason or ""), "textMuted"), 12, "text", 4)
		end

		Heading("VERIFICATION")
		for _, aspect in ipairs(ns.Schema.EvidenceAspects) do
			local state = def.verification[aspect] or "unknown"
			KV(ns.Schema.EvidenceLabels[aspect], Theme.statusLabels[state] or state, state)
		end
		Text("A setting existing, or a successful write, does not prove it has a visible effect. Only VERIFIED effect evidence was observed in game.", 10, "textDim", 4)

		Heading("SOURCES")
		for _, s in ipairs(def.sources or {}) do Text("• " .. s, 11, "textMuted", 3) end

		if #def.related > 0 then
			Heading("RELATED SETTINGS")
			for _, id in ipairs(def.related) do
				local other = Registry:Get(id)
				if other then LinkButton(other.name, function() window:RevealSetting(id) end) end
			end
		end
		Finish()
	end

	function f:ShowCVar(name)
		self.current = { kind = "cvar", name = name }
		local entry, canonical = Registry.FindCatalogEntry(name)
		canonical = canonical or name
		Begin()
		Text(canonical, 15, "text", 4)
		Text("Console variable (read-only in EverSettings)", 11, "textDim", 8)
		local help = entry and entry[5]
		local d = ns.Discovery.last
		if not entry and d and d.clientCVars[name] then help = d.clientCVars[name].help end
		Text((help and help ~= "") and help or "No description provided by the client.", 12, "textMuted", 8)
		Heading("VALUES")
		local value = ns.Compat.GetCVar(canonical)
		KV("Current", value ~= nil and value or "not present in client", value ~= nil and "text" or "textDim")
		KV("Default (client)", tostring(ns.Compat.GetCVarDefault(canonical)))
		if entry then KV("Default (catalog)", entry[1]) end
		local initial = ns.Backup:GetInitialRaw(canonical)
		if initial ~= nil then KV("Initial snapshot", initial) end
		Heading("FLAGS")
		local info = ns.Compat.GetCVarInfo(canonical)
		if info then
			KV("Account stored", tostring(info.account)); KV("Character stored", tostring(info.character))
			KV("Secure", tostring(info.secure)); KV("Read-only", tostring(info.readOnly)); KV("Locked", tostring(info.locked))
		elseif entry then
			KV("Account stored", tostring(Registry.HasFlag(entry[3], Registry.FLAG_ACCOUNT)))
			KV("Character stored", tostring(Registry.HasFlag(entry[3], Registry.FLAG_CHARACTER)))
			KV("Secure", tostring(Registry.HasFlag(entry[3], Registry.FLAG_SECURE)))
		end
		if entry then
			KV("Console category", ns.CONSOLE_CATEGORY[entry[2]] or tostring(entry[2]))
			KV("Blizzard UI", ({ [0] = "hidden (console only)", "used by Blizzard UI code", "in the settings window" })[entry[4]] or "?")
		end
		local defs = Registry:GetByCVar(canonical)
		if defs then
			Heading("MANAGED BY")
			for _, def in ipairs(defs) do LinkButton(def.name, function() window:RevealSetting(def.id) end) end
		end
		Heading("SOURCES")
		Text("• Client CVar dump " .. tostring(ns.CVarCatalog.meta.cvarsBuild), 11, "textMuted", 3)
		Finish()
	end

	function f:Refresh()
		local c = self.current
		if not c then return self:ShowEmpty() end
		if c.kind == "setting" then
			local def = Registry:Get(c.id)
			local keep = scroll:GetVerticalScroll()
			self:ShowSetting(def)
			scroll:SetVerticalScroll(math.min(keep, math.max(0, content:GetHeight() - scroll:GetHeight())))
		end
	end

	f:ShowEmpty()
	return f
end
