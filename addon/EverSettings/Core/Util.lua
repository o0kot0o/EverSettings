-- Pure helpers with no game-state side effects. Safe to unit test offline.
local _, ns = ...

local Util = {}
ns.Util = Util

local floor, abs, tonumber, tostring, type = math.floor, math.abs, tonumber, tostring, type

function Util.Trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.CopyTable(src, seen)
	if type(src) ~= "table" then return src end
	seen = seen or {}
	if seen[src] then return seen[src] end
	local out = {}
	seen[src] = out
	for k, v in pairs(src) do
		out[Util.CopyTable(k, seen)] = Util.CopyTable(v, seen)
	end
	return out
end

-- Fill missing keys of `dst` from `defaults` (recursively), without overwriting existing values.
function Util.ApplyDefaults(dst, defaults)
	for k, v in pairs(defaults) do
		if dst[k] == nil then
			dst[k] = Util.CopyTable(v)
		elseif type(v) == "table" and type(dst[k]) == "table" then
			Util.ApplyDefaults(dst[k], v)
		end
	end
	return dst
end

function Util.Round(value, decimals)
	local m = 10 ^ (decimals or 0)
	if value >= 0 then
		return floor(value * m + 0.5) / m
	end
	return -floor(-value * m + 0.5) / m
end

-- Number of decimals implied by a step, e.g. 0.05 -> 2, 1 -> 0.
function Util.DecimalsForStep(step)
	if not step or step <= 0 then return 2 end
	local decimals = 0
	local s = step
	while decimals < 6 and abs(s - Util.Round(s)) > 1e-9 do
		s = s * 10
		decimals = decimals + 1
	end
	return decimals
end

-- Format a number without trailing zeros ("1.50" -> "1.5", "2.000" -> "2").
function Util.FormatNumber(value, decimals)
	if type(value) ~= "number" then return tostring(value) end
	local text = ("%." .. (decimals or 6) .. "f"):format(value)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	if text == "-0" then text = "0" end
	return text
end

-- Strict numeric parse: accepts "12", "-3.5", ".5", "1e3"; rejects "12abc", "", "nan", "inf".
function Util.ParseNumber(text)
	if type(text) == "number" then
		if text ~= text or text == math.huge or text == -math.huge then return nil end
		return text
	end
	text = Util.Trim(text):gsub(",", ".")
	if text == "" then return nil end
	if not text:match("^[-+]?%d*%.?%d+$") and not text:match("^[-+]?%d+%.?%d*[eE][-+]?%d+$") and not text:match("^[-+]?%d+%.$") then
		return nil
	end
	local n = tonumber(text)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	return n
end

function Util.NearlyEqual(a, b, epsilon)
	epsilon = epsilon or 1e-4
	return abs(a - b) <= epsilon * math.max(1, abs(a), abs(b))
end

function Util.IsInteger(n)
	return type(n) == "number" and n == floor(n)
end

function Util.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Case-insensitive plain-text search across several fields.
function Util.MatchesQuery(query, ...)
	if not query or query == "" then return true end
	for i = 1, select("#", ...) do
		local field = select(i, ...)
		if type(field) == "string" and field:lower():find(query, 1, true) then
			return true
		elseif type(field) == "table" then
			for _, s in ipairs(field) do
				if type(s) == "string" and s:lower():find(query, 1, true) then
					return true
				end
			end
		end
	end
	return false
end

function Util.SortedKeys(t, cmp)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, cmp)
	return keys
end

function Util.Count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

function Util.FormatTime(t)
	if not t then return "-" end
	if date then
		return date("%Y-%m-%d %H:%M", t)
	end
	return tostring(t)
end

function Util.Now()
	return time and time() or 0
end
