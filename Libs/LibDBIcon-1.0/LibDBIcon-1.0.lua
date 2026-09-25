-- LibDBIcon-1.0
local MAJOR, MINOR = "LibDBIcon-1.0", 45
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}
lib.radius = lib.radius or 80

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local math_rad, math_cos, math_sin, math_deg = math.rad, math.cos, math.sin, math.deg
local math_atan2 = math.atan2 or math.atan

local function getPosition(deg, radius)
	local angle = math_rad(deg or 220)
	local rad = radius or 80
	if Minimap and Minimap.GetWidth then
		local w = Minimap:GetWidth()
		if w and w > 0 then
			rad = (w / 2) + 10
		end
	end
	return math_cos(angle) * rad, math_sin(angle) * rad
end

local function onDragStart(self)
	self:SetScript("OnUpdate", function(s)
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		if mx and my and scale and scale > 0 then
			px, py = px / scale, py / scale
			local dx = px - mx
			local dy = py - my
			local angle = math_deg(math_atan2(dy, dx))
			if angle < 0 then angle = angle + 360 end
			self.db.minimapPos = angle
			local x, y = getPosition(angle, self.radius)
			self:ClearAllPoints()
			self:SetPoint("CENTER", Minimap, "CENTER", x, y)
		end
	end)
end

local function onDragStop(self)
	self:SetScript("OnUpdate", nil)
end

local function onClick(self, b)
	if self.dataObject and self.dataObject.OnClick then
		self.dataObject.OnClick(self, b)
	end
end

local function onEnter(self)
	if self.dataObject and self.dataObject.OnTooltipShow then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		self.dataObject.OnTooltipShow(GameTooltip)
		GameTooltip:Show()
	elseif self.dataObject and self.dataObject.OnEnter then
		self.dataObject.OnEnter(self)
	end
end

local function onLeave(self)
	if self.dataObject and self.dataObject.OnLeave then
		self.dataObject.OnLeave(self)
	else
		GameTooltip:Hide()
	end
end

local function createButton(name, object, db)
	local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
	button.dataObject = object
	button.db = db
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 5) + 8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 0)
	icon:SetTexture(object.icon or "Interface\\Icons\\inv_misc_clock_01")
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button.border = border

	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)

	lib.objects[name] = button

	local x, y = getPosition(db.minimapPos or 220, lib.radius)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)

	if db.hide then
		button:Hide()
	else
		button:Show()
	end

	return button
end

function lib:Register(name, object, db)
	if not object then
		error("Usage: LibDBIcon:Register(name, object, db): object is required.", 2)
	end
	db = db or {}
	if lib.objects[name] then
		return
	end
	createButton(name, object, db)
end

function lib:Refresh(name, db)
	local button = lib.objects[name]
	if button then
		if db then button.db = db end
		local x, y = getPosition(button.db.minimapPos or 220, lib.radius)
		button:ClearAllPoints()
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
		if button.db.hide then
			button:Hide()
		else
			button:Show()
		end
		if button.dataObject and button.dataObject.icon then
			button.icon:SetTexture(button.dataObject.icon)
		end
	end
end

function lib:Show(name)
	local button = lib.objects[name]
	if button then
		button.db.hide = false
		button:Show()
	end
end

function lib:Hide(name)
	local button = lib.objects[name]
	if button then
		button.db.hide = true
		button:Hide()
	end
end

function lib:IsButtonShown(name)
	local button = lib.objects[name]
	return button and button:IsShown()
end

function lib:GetMinimapButton(name)
	return lib.objects[name]
end
