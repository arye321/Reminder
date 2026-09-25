-- LibDataBroker-1.1
local MAJOR, MINOR = "LibDataBroker-1.1", 4
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.attributestorage = lib.attributestorage or {}
lib.proxystorage = lib.proxystorage or {}
lib.dataobjstorage = lib.dataobjstorage or {}

local domt = {
	__index = function(self, key) return lib.attributestorage[self][key] end,
	__newindex = function(self, key, value)
		if lib.attributestorage[self][key] == value then return end
		lib.attributestorage[self][key] = value
		local name = lib.proxystorage[self]
		if not name then return end
		lib.callbacks:Fire("LibDataBroker_AttributeChanged", name, key, value, self)
		lib.callbacks:Fire("LibDataBroker_AttributeChanged_" .. name, name, key, value, self)
		lib.callbacks:Fire("LibDataBroker_AttributeChanged_" .. name .. "_" .. key, name, key, value, self)
		lib.callbacks:Fire("LibDataBroker_AttributeChanged__" .. key, name, key, value, self)
	end,
}

function lib:NewDataObject(name, dataobj)
	if self.dataobjstorage[name] then return end
	if not dataobj then
		dataobj = setmetatable({}, domt)
	else
		for k, v in pairs(dataobj) do
			if type(v) == "function" then
				dataobj[k] = v
			end
		end
		dataobj = setmetatable(dataobj, domt)
	end
	self.attributestorage[dataobj] = {}
	self.proxystorage[dataobj] = name
	self.dataobjstorage[name] = dataobj
	self.callbacks:Fire("LibDataBroker_DataObjectCreated", name, dataobj)
	return dataobj
end

function lib:DataObjectIterator()
	return pairs(self.dataobjstorage)
end

function lib:GetDataObjectByName(name)
	return self.dataobjstorage[name]
end

function lib:GetNameByDataObject(dataobj)
	return self.proxystorage[dataobj]
end
