-- CallbackHandler-1.0
local MAJOR, MINOR = "CallbackHandler-1.0", 8
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end

local meta = {__index = function(tbl, key) key = tostring(key); tbl[key] = {}; return tbl[key] end}

local function Dispatch(handlers, ...)
	for i = 1, #handlers do
		local func = handlers[i]
		if type(func) == "function" then
			func(...)
		elseif type(func) == "string" and ... and type((...)[func]) == "function" then
			(...)[func](...)
		end
	end
end

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	UnregisterAllName = UnregisterAllName or "UnregisterAllCallbacks"

	local events = setmetatable({}, meta)
	local registry = {
		events = events,
		insertQueue = {},
		recurse = 0,
	}

	function target:Fire(eventname, ...)
		local handlers = events[eventname]
		if handlers and #handlers > 0 then
			Dispatch(handlers, eventname, ...)
		end
	end

	target[RegisterName] = function(self, eventname, method, arg)
		if type(eventname) ~= "string" then
			error("Usage: " .. RegisterName .. "(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end
		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: " .. RegisterName .. "(eventname, method[, arg]): 'method' - string or function expected.", 2)
		end

		local handlers = events[eventname]
		table.insert(handlers, method)
	end

	target[UnregisterName] = function(self, eventname, method)
		local handlers = events[eventname]
		if not handlers then return end
		for i = #handlers, 1, -1 do
			if handlers[i] == method then
				table.remove(handlers, i)
			end
		end
	end

	target[UnregisterAllName] = function(self)
		for k in pairs(events) do
			events[k] = nil
		end
	end

	return registry
end
