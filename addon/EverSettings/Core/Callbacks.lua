-- Minimal publish/subscribe used to decouple services from the UI.
local _, ns = ...

local Callbacks = { handlers = {} }
ns.Callbacks = Callbacks

-- Events fired:
--   "ValueChanged"   (settingId, source)   game value changed (apply, external, discovery)
--   "PendingChanged" ()                     staged changes added/removed
--   "ApplyFinished"  (report)               an apply run completed
--   "FavoritesChanged" ()
--   "ProfilesChanged" ()
--   "HistoryChanged" ()
--   "DiscoveryFinished" (result)
function Callbacks:Register(event, owner, fn)
	local list = self.handlers[event]
	if not list then
		list = {}
		self.handlers[event] = list
	end
	list[#list + 1] = { owner = owner, fn = fn }
end

function Callbacks:Unregister(event, owner)
	local list = self.handlers[event]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i].owner == owner then
			table.remove(list, i)
		end
	end
end

function Callbacks:Fire(event, ...)
	local list = self.handlers[event]
	if not list then return end
	for i = 1, #list do
		local entry = list[i]
		if entry then
			local ok, err = pcall(entry.fn, entry.owner, ...)
			if not ok then
				ns:Print("callback error in %s: %s", event, tostring(err))
			end
		end
	end
end
