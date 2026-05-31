-- Reminder.lua
-- WoW Classic Era Addon
-- Author: Antigravity

local cos, sin, rad = math.cos, math.sin, math.rad
local deg, atan2 = math.deg, math.atan2
local random, time = math.random, time
local tinsert, ipairs, pairs = table.insert, ipairs, pairs

-- -------------------------------------------------------------
-- Data Structures & Capital Cities
-- -------------------------------------------------------------
local bigCities = {
    ["Stormwind City"] = true,
    ["Stormwind"] = true,
    ["Ironforge"] = true,
    ["Darnassus"] = true,
    ["Orgrimmar"] = true,
    ["Undercity"] = true,
    ["Thunder Bluff"] = true,
    ["Dalaran"] = true,
    ["Shattrath City"] = true,
    ["Shattrath"] = true,
    ["Silvermoon City"] = true,
    ["The Exodar"] = true,
}

local professionList = {
    { value = "Alchemy", label = "Alchemy" },
    { value = "Blacksmithing", label = "Blacksmithing" },
    { value = "Cooking", label = "Cooking" },
    { value = "Enchanting", label = "Enchanting" },
    { value = "Engineering", label = "Engineering" },
    { value = "First Aid", label = "First Aid" },
    { value = "Fishing", label = "Fishing" },
    { value = "Herbalism", label = "Herbalism" },
    { value = "Leatherworking", label = "Leatherworking" },
    { value = "Mining", label = "Mining" },
    { value = "Skinning", label = "Skinning" },
    { value = "Tailoring", label = "Tailoring" }
}

local typeList = {
    { value = "level", label = "Player Level" },
    { value = "rested", label = "Rested Place (Inn/City)" },
    { value = "profession", label = "Profession & City" },
    { value = "pet_level", label = "Hunter Pet Level" }
}

-- -------------------------------------------------------------
-- Helper Functions
-- -------------------------------------------------------------
local function ApplyBackdrop(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
    local bg = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    }
    frame:SetBackdrop(bg)
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
end

local function IsInBigCity()
    local zone = GetRealZoneText()
    if not zone or zone == "" then return false end
    zone = zone:lower()
    for city in pairs(bigCities) do
        if zone:find(city:lower(), 1, true) then
            return true
        end
    end
    
    local subzone = GetMinimapZoneText()
    if subzone and subzone ~= "" then
        subzone = subzone:lower()
        for city in pairs(bigCities) do
            if subzone:find(city:lower(), 1, true) then
                return true
            end
        end
    end
    return false
end

local function GetProfessionSkillRank(name)
    if not name or name == "" then return 0 end
    name = name:lower()
    
    -- Expand collapsed headers to scan all skills
    local collapsedHeaders = {}
    local numSkills = GetNumSkillLines()
    local i = 1
    while i <= numSkills do
        local skillName, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded then
            ExpandSkillHeader(i)
            collapsedHeaders[i] = true
            numSkills = GetNumSkillLines() -- update count
        end
        i = i + 1
    end
    
    local foundRank = 0
    for j = 1, GetNumSkillLines() do
        local skillName, isHeader, _, rank = GetSkillLineInfo(j)
        if not isHeader and skillName and skillName:lower() == name then
            foundRank = rank
            break
        end
    end
    
    -- Restore collapsed states in reverse order
    for j = GetNumSkillLines(), 1, -1 do
        local _, isHeader = GetSkillLineInfo(j)
        if isHeader and collapsedHeaders[j] then
            CollapseSkillHeader(j)
        end
    end
    
    return foundRank
end

-- -------------------------------------------------------------
-- Custom UI Control Creators
-- -------------------------------------------------------------
local function CreateEditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(width, height)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(6, 6, 0, 0)
    ApplyBackdrop(eb, 0, 0, 0, 0.6, 0.4, 0.4, 0.4, 1)
    
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetNumeric(true)
    return eb
end

local activeDropdownMenu = nil

local function CreateDropdown(parent, width, height, options, callback)
    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, height)
    ApplyBackdrop(dropdown, 0.1, 0.1, 0.1, 0.8, 0.4, 0.4, 0.4, 1)
    
    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    dropdown.text = text
    
    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -4, 0)
    dropdown.arrow = arrow
    
    local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    ApplyBackdrop(menu, 0.05, 0.05, 0.05, 0.95, 0.4, 0.4, 0.4, 1)
    menu:SetFrameStrata("DIALOG")
    menu:Hide()
    dropdown.menu = menu
    
    local buttons = {}
    
    local function UpdateOptions(newOptions)
        options = newOptions
        for _, btn in ipairs(buttons) do
            btn:Hide()
        end
        
        local menuHeight = 6
        for i, opt in ipairs(options) do
            local btn = buttons[i]
            if not btn then
                btn = CreateFrame("Button", nil, menu)
                btn:SetHeight(18)
                btn:SetNormalFontObject("GameFontHighlightSmall")
                btn:SetHighlightFontObject("GameFontNormalSmall")
                
                local btnHighlight = btn:CreateTexture(nil, "BACKGROUND")
                btnHighlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                btnHighlight:SetBlendMode("ADD")
                btnHighlight:SetAllPoints()
                btn:SetHighlightTexture(btnHighlight)
                
                local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                btnText:SetPoint("LEFT", 6, 0)
                btnText:SetPoint("RIGHT", -6, 0)
                btnText:SetJustifyH("LEFT")
                btn.text = btnText
                
                buttons[i] = btn
            end
            
            btn.text:SetText(opt.label or opt.value)
            btn:SetWidth(width - 8)
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 18)
            btn:SetScript("OnClick", function()
                dropdown.selectedValue = opt.value
                dropdown.text:SetText(opt.label or opt.value)
                menu:Hide()
                activeDropdownMenu = nil
                if callback then callback(opt.value) end
            end)
            btn:Show()
            menuHeight = menuHeight + 18
        end
        menu:SetSize(width, menuHeight)
    end
    
    dropdown:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
            activeDropdownMenu = nil
        else
            if activeDropdownMenu and activeDropdownMenu ~= menu then
                activeDropdownMenu:Hide()
            end
            menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
            menu:SetFrameLevel(dropdown:GetFrameLevel() + 20)
            menu:Show()
            activeDropdownMenu = menu
        end
        PlaySound(856)
    end)
    
    dropdown.UpdateOptions = UpdateOptions
    dropdown.SetValue = function(self, val)
        self.selectedValue = val
        for _, opt in ipairs(options) do
            if opt.value == val then
                self.text:SetText(opt.label or opt.value)
                return
            end
        end
        self.text:SetText(val)
    end
    dropdown.GetValue = function(self)
        return self.selectedValue
    end
    
    UpdateOptions(options)
    return dropdown
end

-- Global click hook for custom dropdowns closing
local dropdownCloseHook = CreateFrame("Frame")
dropdownCloseHook:SetScript("OnUpdate", function()
    if activeDropdownMenu and activeDropdownMenu:IsShown() then
        if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
            local parentBtn = activeDropdownMenu:GetParent()
            if not activeDropdownMenu:IsMouseOver() and not parentBtn:IsMouseOver() then
                activeDropdownMenu:Hide()
                activeDropdownMenu = nil
            end
        end
    end
end)

-- -------------------------------------------------------------
-- Alert Popup Frame (Queue-Managed)
-- -------------------------------------------------------------
local alertQueue = {}
local alertFrame = nil

local function ShowNextAlert()
    if #alertQueue == 0 then
        if alertFrame then alertFrame:Hide() end
        return
    end
    
    local msg = table.remove(alertQueue, 1)
    
    if not alertFrame then
        alertFrame = CreateFrame("Frame", "ReminderAlertFrame", UIParent, "BackdropTemplate")
        alertFrame:SetSize(320, 130)
        alertFrame:SetPoint("CENTER", 0, 150)
        alertFrame:SetFrameStrata("DIALOG")
        alertFrame:EnableMouse(true)
        alertFrame:SetMovable(true)
        alertFrame:RegisterForDrag("LeftButton")
        alertFrame:SetScript("OnDragStart", alertFrame.StartMoving)
        alertFrame:SetScript("OnDragStop", alertFrame.StopMovingOrSizing)
        
        ApplyBackdrop(alertFrame, 0.08, 0.08, 0.08, 0.95, 0.85, 0.7, 0.2, 1) -- Gold border
        
        local icon = alertFrame:CreateTexture(nil, "OVERLAY")
        icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
        icon:SetSize(24, 24)
        icon:SetPoint("TOP", 0, -12)
        alertFrame.icon = icon
        
        local title = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", icon, "BOTTOM", 0, -6)
        title:SetText("Reminder Alert!")
        title:SetTextColor(0.85, 0.7, 0.2)
        alertFrame.title = title
        
        local message = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        message:SetPoint("TOPLEFT", 15, -60)
        message:SetPoint("BOTTOMRIGHT", -15, 40)
        message:SetJustifyH("CENTER")
        message:SetJustifyV("TOP")
        message:SetWordWrap(true)
        alertFrame.message = message
        
        local okBtn = CreateFrame("Button", nil, alertFrame, "UIPanelButtonTemplate")
        okBtn:SetSize(90, 22)
        okBtn:SetPoint("BOTTOM", 0, 12)
        okBtn:SetText("OK")
        okBtn:SetScript("OnClick", function()
            PlaySound(856)
            ShowNextAlert()
        end)
        alertFrame.okBtn = okBtn
    end
    
    alertFrame.message:SetText(msg)
    alertFrame:Show()
    PlaySound(18019) -- Raid warning sound
end

local function TriggerAlert(message)
    tinsert(alertQueue, message)
    if not alertFrame or not alertFrame:IsShown() then
        ShowNextAlert()
    end
end

-- -------------------------------------------------------------
-- Main Settings Window Creation
-- -------------------------------------------------------------
local frame = CreateFrame("Frame", "ReminderFrame", UIParent, "BackdropTemplate")
frame:SetSize(550, 360)
frame:SetPoint("CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
ApplyBackdrop(frame, 0.05, 0.05, 0.05, 0.95, 0.3, 0.3, 0.3, 1)
frame:Hide()

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Add to special frames to close on ESC
tinsert(UISpecialFrames, "ReminderFrame")

-- Title Text
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPLEFT", 15, -15)
titleText:SetText("Reminder Settings")

-- Panels
local leftPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
leftPanel:SetPoint("TOPLEFT", 15, -45)
leftPanel:SetPoint("BOTTOMLEFT", 15, 15)
leftPanel:SetWidth(270)
ApplyBackdrop(leftPanel, 0.02, 0.02, 0.02, 0.6, 0.2, 0.2, 0.2, 0.8)

local rightPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
rightPanel:SetPoint("TOPLEFT", 300, -45)
rightPanel:SetPoint("BOTTOMRIGHT", -15, 15)
ApplyBackdrop(rightPanel, 0.02, 0.02, 0.02, 0.6, 0.2, 0.2, 0.2, 0.8)

-- Scroll Frame for Reminder List
local scrollFrame = CreateFrame("ScrollFrame", "ReminderListScrollFrame", leftPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 6, -6)
scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(238, 1)
scrollFrame:SetScrollChild(scrollChild)

-- Form Fields Setup
local formTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
formTitle:SetPoint("TOPLEFT", 12, -12)
formTitle:SetText("Add Reminder")

local typeLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
typeLabel:SetPoint("TOPLEFT", 12, -35)
typeLabel:SetText("Reminder Type:")

-- Dynamic field widgets
local levelLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
levelLabel:SetPoint("TOPLEFT", 12, -85)
levelLabel:SetText("Target Level:")
local levelEditBox = CreateEditBox(rightPanel, 200, 24)
levelEditBox:SetPoint("TOPLEFT", 12, -100)

local profLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profLabel:SetPoint("TOPLEFT", 12, -85)
profLabel:SetText("Profession:")
local profDropdown = CreateDropdown(rightPanel, 200, 24, professionList)
profDropdown:SetPoint("TOPLEFT", 12, -100)

local skillLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
skillLabel:SetPoint("TOPLEFT", 12, -135)
skillLabel:SetText("Skill Level:")
local skillEditBox = CreateEditBox(rightPanel, 200, 24)
skillEditBox:SetPoint("TOPLEFT", 12, -150)

local petLevelLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
petLevelLabel:SetPoint("TOPLEFT", 12, -85)
petLevelLabel:SetText("Pet Level:")
local petLevelEditBox = CreateEditBox(rightPanel, 200, 24)
petLevelEditBox:SetPoint("TOPLEFT", 12, -100)

local saveBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
saveBtn:SetSize(90, 24)
saveBtn:SetPoint("BOTTOMLEFT", 12, 12)
saveBtn:SetText("Add")

local cancelBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
cancelBtn:SetSize(90, 24)
cancelBtn:SetPoint("BOTTOMLEFT", 110, 12)
cancelBtn:SetText("Cancel")
cancelBtn:Hide()

local editingReminder = nil

local function UpdateFormFields(selectedType)
    levelLabel:Hide()
    levelEditBox:Hide()
    profLabel:Hide()
    profDropdown:Hide()
    skillLabel:Hide()
    skillEditBox:Hide()
    petLevelLabel:Hide()
    petLevelEditBox:Hide()
    
    if selectedType == "level" then
        levelLabel:Show()
        levelEditBox:Show()
    elseif selectedType == "profession" then
        profLabel:Show()
        profDropdown:Show()
        skillLabel:Show()
        skillEditBox:Show()
    elseif selectedType == "pet_level" then
        petLevelLabel:Show()
        petLevelEditBox:Show()
    elseif selectedType == "rested" then
        -- Rested place has no extra config fields
    end
end

local typeDropdown = CreateDropdown(rightPanel, 200, 24, typeList, function(val)
    UpdateFormFields(val)
end)
typeDropdown:SetPoint("TOPLEFT", 12, -50)

local function ClearForm()
    editingReminder = nil
    formTitle:SetText("Add Reminder")
    typeDropdown:SetValue("level")
    UpdateFormFields("level")
    levelEditBox:SetText("")
    profDropdown:SetValue("Alchemy")
    skillEditBox:SetText("")
    petLevelEditBox:SetText("")
    saveBtn:SetText("Add")
    cancelBtn:Hide()
end

-- -------------------------------------------------------------
-- Reminder List Manager
-- -------------------------------------------------------------
local listRows = {}

local function RefreshList()
    -- Hide all rows first
    for _, row in ipairs(listRows) do
        row:Hide()
    end
    
    if not ReminderDB or not ReminderDB.reminders then return end
    
    local yOffset = 0
    for i, rem in ipairs(ReminderDB.reminders) do
        local row = listRows[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetSize(238, 40)
            ApplyBackdrop(row, 0.12, 0.12, 0.12, 0.7, 0.25, 0.25, 0.25, 1)
            
            -- Checkbox for enabled/disabled
            local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            check:SetSize(20, 20)
            check:SetPoint("LEFT", 5, 0)
            row.check = check
            
            -- Description text
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", check, "RIGHT", 5, 0)
            text:SetPoint("RIGHT", -88, 0)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(true)
            row.text = text
            
            -- Edit button
            local editBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            editBtn:SetSize(38, 18)
            editBtn:SetPoint("RIGHT", -44, 0)
            editBtn:SetText("Edit")
            row.editBtn = editBtn
            
            -- Delete button
            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(36, 18)
            delBtn:SetPoint("RIGHT", -5, 0)
            delBtn:SetText("Del")
            row.delBtn = delBtn
            
            listRows[i] = row
        end
        
        -- Populate row content
        row.check:SetChecked(rem.enabled)
        row.check:SetScript("OnClick", function(self)
            rem.enabled = self:GetChecked()
            if rem.enabled then
                rem.triggered = false -- reset trigger state so it can re-evaluate
            end
            PlaySound(856)
        end)
        
        local desc = ""
        if rem.type == "level" then
            desc = "Level |cfffff569" .. rem.value .. "|r"
        elseif rem.type == "rested" then
            desc = "Rested Place"
        elseif rem.type == "profession" then
            desc = rem.profession .. " >= |cfffff569" .. rem.value .. "|r"
        elseif rem.type == "pet_level" then
            desc = "Pet lvl >= |cfffff569" .. rem.value .. "|r"
        end
        row.text:SetText(desc)
        
        -- Hooks
        row.editBtn:SetScript("OnClick", function()
            PlaySound(856)
            editingReminder = rem
            formTitle:SetText("Edit Reminder")
            typeDropdown:SetValue(rem.type)
            UpdateFormFields(rem.type)
            
            if rem.type == "level" then
                levelEditBox:SetText(tostring(rem.value))
            elseif rem.type == "profession" then
                profDropdown:SetValue(rem.profession)
                skillEditBox:SetText(tostring(rem.value))
            elseif rem.type == "pet_level" then
                petLevelEditBox:SetText(tostring(rem.value))
            end
            
            saveBtn:SetText("Save")
            cancelBtn:Show()
        end)
        
        row.delBtn:SetScript("OnClick", function()
            PlaySound(856)
            for j, r in ipairs(ReminderDB.reminders) do
                if r.id == rem.id then
                    table.remove(ReminderDB.reminders, j)
                    break
                end
            end
            if editingReminder and editingReminder.id == rem.id then
                ClearForm()
            end
            RefreshList()
        end)
        
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:Show()
        yOffset = yOffset + 44
    end
    
    scrollChild:SetHeight(yOffset > 0 and yOffset or 1)
end

-- Save / Add Button Action
saveBtn:SetScript("OnClick", function()
    local selectedType = typeDropdown:GetValue()
    local value = 0
    local profession = ""
    
    if selectedType == "level" then
        local text = levelEditBox:GetText()
        value = tonumber(text)
        if not value or value <= 0 then
            print("|cffff3333[Reminder] Please enter a valid level!|r")
            return
        end
    elseif selectedType == "profession" then
        profession = profDropdown:GetValue()
        local text = skillEditBox:GetText()
        value = tonumber(text)
        if not value or value <= 0 then
            print("|cffff3333[Reminder] Please enter a valid skill value!|r")
            return
        end
    elseif selectedType == "pet_level" then
        local text = petLevelEditBox:GetText()
        value = tonumber(text)
        if not value or value <= 0 then
            print("|cffff3333[Reminder] Please enter a valid pet level!|r")
            return
        end
    end
    
    if editingReminder then
        editingReminder.type = selectedType
        editingReminder.value = value
        editingReminder.profession = profession
        editingReminder.triggered = false
    else
        local newRem = {
            id = tostring(time()) .. "_" .. tostring(random(1000, 9999)),
            type = selectedType,
            value = value,
            profession = profession,
            enabled = true,
            triggered = false,
        }
        tinsert(ReminderDB.reminders, newRem)
    end
    
    RefreshList()
    ClearForm()
    PlaySound(856)
end)

cancelBtn:SetScript("OnClick", function()
    ClearForm()
    PlaySound(856)
end)

-- -------------------------------------------------------------
-- Minimap Button Creation
-- -------------------------------------------------------------
local MinimapButton = CreateFrame("Button", "ReminderMinimapButton", Minimap)
MinimapButton:SetSize(31, 31)
MinimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
MinimapButton:SetToplevel(true)
MinimapButton:RegisterForClicks("LeftButtonUp")
MinimapButton:RegisterForDrag("LeftButton")

local icon = MinimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 0)
MinimapButton.icon = icon

local border = MinimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", 0, 0)

local function UpdateMinimapPosition()
    if not ReminderDB then return end
    local angle = ReminderDB.minimapPos or 45
    local radius = 80
    local x = radius * cos(rad(angle))
    local y = radius * sin(rad(angle))
    MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    if ReminderDB.minimapHide then
        MinimapButton:Hide()
    else
        MinimapButton:Show()
    end
end

MinimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(s)
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local mx, my = Minimap:GetCenter()
        local angle = deg(atan2((cy / scale) - my, (cx / scale) - mx))
        ReminderDB.minimapPos = angle
        UpdateMinimapPosition()
    end)
end)

MinimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

MinimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if ReminderFrame:IsShown() then
            ReminderFrame:Hide()
        else
            ReminderFrame:Show()
        end
        PlaySound(856)
    end
end)

MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Reminder", 1, 1, 1)
    GameTooltip:AddLine("Left-Click: Open settings.", 0.2, 1, 0.2)
    GameTooltip:AddLine("Drag: Move minimap button.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

MinimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- -------------------------------------------------------------
-- Condition Evaluation & Triggers
-- -------------------------------------------------------------
local function CheckReminders()
    if not ReminderDB or not ReminderDB.reminders then return end
    
    for _, rem in ipairs(ReminderDB.reminders) do
        if rem.enabled then
            local isMet = false
            local msg = ""
            
            if rem.type == "level" then
                isMet = UnitLevel("player") >= (rem.value or 0)
                msg = "Player Level Reached: |cfffff569" .. rem.value .. "|r!"
            elseif rem.type == "rested" then
                isMet = IsResting()
                msg = "You are now in a Rested place (City/Inn)!"
            elseif rem.type == "profession" then
                local rank = GetProfessionSkillRank(rem.profession)
                isMet = (rank >= (rem.value or 0)) and IsInBigCity()
                msg = "City Profession Skill: |cfffff569" .. rem.profession .. "|r is " .. rank .. " (Target >= " .. rem.value .. ")!"
            elseif rem.type == "pet_level" then
                isMet = UnitExists("pet") and (UnitLevel("pet") >= (rem.value or 0))
                msg = "Hunter Pet Level Reached: |cfffff569" .. rem.value .. "|r!"
            end
            
            if isMet then
                if not rem.triggered then
                    rem.triggered = true
                    TriggerAlert(msg)
                end
            else
                rem.triggered = false
            end
        end
    end
end

-- -------------------------------------------------------------
-- Event Listeners & Lifecycles
-- -------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("UNIT_LEVEL")
eventFrame:RegisterEvent("UNIT_PET")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == "Reminder" then
        -- Load Database Variables
        ReminderDB = ReminderDB or {}
        ReminderDB.reminders = ReminderDB.reminders or {}
        if ReminderDB.minimapPos == nil then ReminderDB.minimapPos = 45 end
        if ReminderDB.minimapHide == nil then ReminderDB.minimapHide = false end
        
        -- Register slash commands
        SLASH_REMINDER1 = "/reminder"
        SlashCmdList["REMINDER"] = function()
            if ReminderFrame:IsShown() then
                ReminderFrame:Hide()
            else
                ReminderFrame:Show()
            end
            PlaySound(856)
        end
        
        -- Init Position
        UpdateMinimapPosition()
        
        -- Prepare initial view
        ClearForm()
        RefreshList()
        
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Wait 2 seconds to make sure zone name, coordinates, and skills are loaded
        C_Timer.After(2, function()
            CheckReminders()
        end)
    elseif event == "UNIT_LEVEL" then
        -- Only check if it's the player or the player's pet
        if arg1 == "player" or arg1 == "pet" then
            CheckReminders()
        end
    else
        CheckReminders()
    end
end)

-- Polling Check Frame (fallback to catch dynamic changes)
local checkTimer = 0
local checkFrame = CreateFrame("Frame")
checkFrame:SetScript("OnUpdate", function(self, elapsed)
    checkTimer = checkTimer + elapsed
    if checkTimer >= 1.5 then
        checkTimer = 0
        CheckReminders()
    end
end)
