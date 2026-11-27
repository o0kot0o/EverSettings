-- Canonical value handling.
--
-- Canonical values are Lua values by valueType:
--   boolean -> true/false     number/integer -> number     enum -> option value     string -> string
-- Providers convert between canonical values and raw storage. The UI converts between
-- canonical values and what the player sees/types (display scale, offset and suffix).
local _, ns = ...

local Util = ns.Util
local Values = {}
ns.Values = Values

local FALSE_STRINGS = { ["0"] = true, [""] = true, ["false"] = true, ["off"] = true, ["disabled"] = true }

function Values.FromRaw(def, raw)
	if raw == nil then return nil end
	local vt = def.valueType
	if vt == "boolean" then
		local s = tostring(raw):lower()
		local b
		if def.onRaw and s == tostring(def.onRaw):lower() then
			b = true
		elseif def.offRaw and s == tostring(def.offRaw):lower() then
			b = false
		else
			local n = tonumber(s)
			if n then b = n ~= 0 else b = not FALSE_STRINGS[s] end
		end
		if def.invert then b = not b end
		return b
	elseif vt == "number" or vt == "integer" then
		local n = tonumber(raw)
		if not n then return nil, ("'%s' is not a number"):format(tostring(raw)) end
		return n
	elseif vt == "enum" then
		if def.enumType == "string" then return tostring(raw) end
		return tonumber(raw) or tostring(raw)
	end
	return tostring(raw)
end

function Values.ToRaw(def, value)
	local vt = def.valueType
	if vt == "boolean" then
		local b = value and true or false
		if def.invert then b = not b end
		if b then return def.onRaw or "1" end
		return def.offRaw or "0"
	elseif vt == "number" or vt == "integer" then
		if type(value) ~= "number" then return nil end
		return Util.FormatNumber(value, 6)
	elseif vt == "enum" then
		return tostring(value)
	end
	return value ~= nil and tostring(value) or nil
end

function Values.Equal(def, a, b)
	if a == nil or b == nil then return a == b end
	if type(a) == "number" and type(b) == "number" then
		return Util.NearlyEqual(a, b)
	end
	return a == b
end

-- Returns ok, errorMessage. Values outside the researched range are always rejected.
function Values.Validate(def, value)
	local vt = def.valueType
	if value == nil then return false, "no value" end
	if vt == "boolean" then
		if type(value) ~= "boolean" then return false, "expected On or Off" end
		return true
	elseif vt == "number" or vt == "integer" then
		if type(value) ~= "number" or value ~= value then return false, "expected a number" end
		if vt == "integer" and not Util.IsInteger(value) then
			return false, "whole numbers only"
		end
		local lo, hi = ns.Providers:GetRange(def)
		if def.control == "slider" and not lo then
			return false, "range unavailable on this client"
		end
		if lo then
			local ext = def.extendedRange
			local minAllowed = ext and math.min(lo, ext.min) or lo
			local maxAllowed = ext and math.max(hi, ext.max) or hi
			if value < minAllowed - 1e-9 or value > maxAllowed + 1e-9 then
				return false, ("allowed %s to %s"):format(Values.FormatNumber(def, minAllowed), Values.FormatNumber(def, maxAllowed))
			end
		end
		return true
	elseif vt == "enum" then
		for _, opt in ipairs(ns.Providers:GetOptions(def)) do
			if opt.value == value then
				if opt.disabled then return false, opt.disabled end
				if opt.notSelectable then return false, "this value cannot be selected" end
				return true
			end
		end
		return false, "not one of the documented values"
	elseif vt == "string" then
		return type(value) == "string", "expected text"
	end
	return false, "unknown value type"
end

-- Display transform: shown = value * displayScale + displayOffset.
local function scale(def) return def.displayScale or 1 end
local function offset(def) return def.displayOffset or 0 end

function Values.Decimals(def)
	if def.decimals then return def.decimals end
	if def.valueType == "integer" then return 0 end
	local step = def.step or 0.01
	return Util.DecimalsForStep(step * scale(def))
end

function Values.ToDisplayNumber(def, value)
	return value * scale(def) + offset(def)
end

function Values.FromDisplayNumber(def, shown)
	return (shown - offset(def)) / scale(def)
end

-- Number as the player sees it, without suffix (used in edit boxes).
-- Exact values are shown with up to 4 extra decimals so typed values are never misrepresented.
function Values.FormatNumber(def, value)
	local shown = Values.ToDisplayNumber(def, value)
	local decimals = Values.Decimals(def)
	local text = Util.FormatNumber(shown, decimals)
	if not Util.NearlyEqual(tonumber(text) or shown, shown, 1e-9) then
		text = Util.FormatNumber(shown, decimals + 4)
	end
	return text
end

function Values.Format(def, value)
	if value == nil then return "—" end
	local vt = def.valueType
	if vt == "boolean" then
		return value and (def.onLabel or "On") or (def.offLabel or "Off")
	elseif vt == "enum" then
		for _, opt in ipairs(def.options or ns.Providers:GetOptions(def)) do
			if opt.value == value then return opt.label end
		end
		return tostring(value) .. " (undocumented)"
	elseif vt == "number" or vt == "integer" then
		if type(value) ~= "number" then return tostring(value) end
		return Values.FormatNumber(def, value) .. (def.suffix or "")
	end
	return tostring(value)
end

-- Parse what the player typed into a numeric edit box. Returns canonical value or nil, error.
function Values.ParseInput(def, text)
	local stripped = Util.Trim(text)
	if def.suffix then
		local suffix = Util.Trim(def.suffix)
		if suffix ~= "" and stripped:sub(-#suffix):lower() == suffix:lower() then
			stripped = Util.Trim(stripped:sub(1, -#suffix - 1))
		end
	end
	local shown = Util.ParseNumber(stripped)
	if not shown then return nil, "enter a number" end
	local value = Values.FromDisplayNumber(def, shown)
	-- Remove floating point noise introduced by the display transform.
	value = Util.Round(value, 9)
	if def.valueType == "integer" then
		if not Util.IsInteger(value) then return nil, "whole numbers only" end
	end
	return value
end
