-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/addons/libstub/
-- Runtime Check: 2008-04-18
-- License: Public Domain
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2
local LibStub = _G[LIBSTUB_MAJOR]

if not LibStub or (LibStub.minor or 0) < LIBSTUB_MINOR then
	LibStub = LibStub or {libs = {}, minors = {}}
	_G[LIBSTUB_MAJOR] = LibStub
	LibStub.minor = LIBSTUB_MINOR

	function LibStub:NewLibrary(major, minor)
		assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
		if type(minor) == "string" then
			minor = tonumber(strmatch(minor, "%d+"))
		end
		if type(minor) ~= "number" then
			error("Bad argument #3 to `NewLibrary' (number expected)", 2)
		end

		local oldminor = self.minors[major]
		if oldminor and oldminor >= minor then return nil end
		self.minors[major] = minor
		local lib = self.libs[major] or {}
		self.libs[major] = lib
		return lib, oldminor
	end

	function LibStub:GetLibrary(major, silent)
		if not self.libs[major] and not silent then
			error(string.format("Cannot find a library instance of %q.", tostring(major)), 2)
		end
		return self.libs[major], self.minors[major]
	end

	function LibStub:IterateLibraries()
		return pairs(self.libs)
	end
	setmetatable(LibStub, { __call = LibStub.GetLibrary })
end
