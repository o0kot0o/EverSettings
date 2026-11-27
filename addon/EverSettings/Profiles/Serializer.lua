-- Profile export format. A strict, line-free text format parsed by hand: imported text is
-- never executed (no loadstring), and every value is type-tagged and validated later
-- against the local settings database.
--
--   !ES1;n=<name>;t=<unix time>;<settingId>=<tag><value>;...;#<checksum>
--   tags: b = boolean (1/0), n = number, s = string
--   reserved characters ; = % | # and control characters are percent-encoded.
local _, ns = ...

local Serializer = { PREFIX = "!ES1;", FORMAT_VERSION = 1 }
ns.Serializer = Serializer

local function escape(s)
	-- Whitespace is encoded too, because Decode strips whitespace added by chat or e-mail wrapping.
	return (tostring(s):gsub("[%%;=|#%c%s]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function unescape(s)
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- Adler-32 style checksum over the payload, to detect truncated copy/paste.
local function checksum(s)
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + s:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return ("%04x%04x"):format(b, a)
end
Serializer.Checksum = checksum

local function encodeValue(v)
	local t = type(v)
	if t == "boolean" then return "b" .. (v and "1" or "0") end
	if t == "number" then return "n" .. ns.Util.FormatNumber(v, 6) end
	if t == "string" then return "s" .. escape(v) end
	return nil
end

function Serializer.Encode(profile)
	local parts = { "n=" .. escape(profile.name or ""), "t=" .. tostring(math.floor(profile.modified or 0)) }
	for _, id in ipairs(ns.Util.SortedKeys(profile.values)) do
		local enc = encodeValue(profile.values[id])
		if enc and id:match("^[%w_%.]+$") then
			parts[#parts + 1] = id .. "=" .. enc
		end
	end
	local payload = table.concat(parts, ";")
	return Serializer.PREFIX .. payload .. ";#" .. checksum(payload)
end

Serializer.MAX_INPUT = 100000   -- bytes, checked before any processing
Serializer.MAX_ENTRIES = 1000
Serializer.MAX_NAME = 64

-- True when every % in s starts a valid two-digit hex escape.
local function validEscapes(s)
	return not s:gsub("%%%x%x", ""):find("%%")
end

-- Returns profile table or nil, error. Does not consult the settings database and never
-- executes anything. The checksum detects corruption and truncation, not authenticity.
function Serializer.Decode(text)
	if type(text) ~= "string" then return nil, "no text" end
	if #text > Serializer.MAX_INPUT then return nil, "text is too long" end
	text = text:gsub("%s+", "")
	if text:sub(1, #Serializer.PREFIX) ~= Serializer.PREFIX then
		return nil, "not an EverSettings profile (expected it to start with " .. Serializer.PREFIX .. ")"
	end
	local body = text:sub(#Serializer.PREFIX + 1)
	local payload, sum = body:match("^(.*);#(%x+)$")
	if not payload then return nil, "missing checksum: the text may be incomplete" end
	if #sum ~= 8 then return nil, "invalid checksum length" end
	if checksum(payload) ~= sum:lower() then return nil, "checksum mismatch: the text was changed or truncated" end

	local profile = { version = Serializer.FORMAT_VERSION, values = {}, malformed = {} }
	local seen, count = {}, 0
	for field in (payload .. ";"):gmatch("([^;]*);") do
		count = count + 1
		if count > Serializer.MAX_ENTRIES + 2 then return nil, "too many entries" end
		local key, raw = field:match("^([%w_%.]+)=(.*)$")
		if key and seen[key] then
			return nil, ("duplicate entry '%s'"):format(key)
		end
		if key then seen[key] = true end
		if not key then
			if field ~= "" then profile.malformed[#profile.malformed + 1] = field end
		elseif not validEscapes(raw) then
			if key == "n" or key == "t" then return nil, "malformed profile name or time" end
			profile.malformed[#profile.malformed + 1] = key
		elseif key == "n" then
			local name = unescape(raw)
			if #name > Serializer.MAX_NAME or name:find("%c") then return nil, "invalid profile name" end
			profile.name = name
		elseif key == "t" then
			local t = tonumber(raw)
			if raw ~= "" and (not t or t ~= t or t == math.huge or t == -math.huge) then return nil, "invalid time" end
			profile.modified = t
		else
			local tag, v = raw:sub(1, 1), raw:sub(2)
			local number = tag == "n" and ns.Util.ParseNumber(v) -- rejects nan/inf and overflow
			if tag == "b" and (v == "1" or v == "0") then
				profile.values[key] = (v == "1")
			elseif tag == "n" and number then
				profile.values[key] = number
			elseif tag == "s" then
				profile.values[key] = unescape(v)
			else
				profile.malformed[#profile.malformed + 1] = key
			end
		end
	end
	return profile
end
