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
    { value = "Alchemy",        label = "Alchemy" },
    { value = "Blacksmithing",  label = "Blacksmithing" },
    { value = "Cooking",        label = "Cooking" },
    { value = "Enchanting",     label = "Enchanting" },
    { value = "Engineering",    label = "Engineering" },
    { value = "First Aid",      label = "First Aid" },
    { value = "Fishing",        label = "Fishing" },
    { value = "Herbalism",      label = "Herbalism" },
    { value = "Leatherworking", label = "Leatherworking" },
    { value = "Mining",         label = "Mining" },
    { value = "Skinning",       label = "Skinning" },
    { value = "Tailoring",      label = "Tailoring" }
}

local typeList = {
    { value = "level",     label = "Player Level" },
    { value = "rested",    label = "Rested" },
    { value = "city",      label = "City" },
    -- { value = "profession", label = "Profession & City" },
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
local function CreateEditBox(parent, width, height, numeric)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(width, height)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(6, 6, 0, 0)
    ApplyBackdrop(eb, 0, 0, 0, 0.6, 0.4, 0.4, 0.4, 1)

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if numeric then
        eb:SetNumeric(true)
    end
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
local RefreshList

local function ShowNextAlert()
    if #alertQueue == 0 then
        if alertFrame then alertFrame:Hide() end
        return
    end

    local alertData = table.remove(alertQueue, 1)
    local msg = alertData.text
    local reminderId = alertData.id

    if not alertFrame then
        alertFrame = CreateFrame("Frame", "ReminderAlertFrame", UIParent, "BackdropTemplate")
        alertFrame:SetSize(320, 160)
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

        local message = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        message:SetPoint("TOPLEFT", 15, -55)
        message:SetPoint("BOTTOMRIGHT", -15, 45)
        message:SetJustifyH("CENTER")
        message:SetJustifyV("TOP")
        message:SetWordWrap(true)
        alertFrame.message = message

        local okBtn = CreateFrame("Button", nil, alertFrame, "UIPanelButtonTemplate")
        okBtn:SetSize(90, 22)
        okBtn:SetText("OK")
        okBtn:SetScript("OnClick", function()
            PlaySound(856)
            ShowNextAlert()
        end)
        alertFrame.okBtn = okBtn

        local removeBtn = CreateFrame("Button", nil, alertFrame, "UIPanelButtonTemplate")
        removeBtn:SetSize(110, 22)
        removeBtn:SetText("Done, remove")
        removeBtn:SetScript("OnClick", function()
            PlaySound(856)
            local currentReminderId = alertFrame.currentReminderId
            if currentReminderId and ReminderDB and ReminderDB.reminders then
                for idx, rem in ipairs(ReminderDB.reminders) do
                    if rem.id == currentReminderId then
                        table.remove(ReminderDB.reminders, idx)
                        break
                    end
                end
                print("|cfffff569[Reminder]|r Removed reminder: " .. msg)
                RefreshList()
            end
            ShowNextAlert()
        end)
        alertFrame.removeBtn = removeBtn
    end

    alertFrame.currentReminderId = reminderId

    if reminderId then
        alertFrame.okBtn:ClearAllPoints()
        alertFrame.okBtn:SetPoint("BOTTOMLEFT", alertFrame, "BOTTOMLEFT", 40, 12)
        alertFrame.removeBtn:ClearAllPoints()
        alertFrame.removeBtn:SetPoint("BOTTOMRIGHT", alertFrame, "BOTTOMRIGHT", -40, 12)
        alertFrame.removeBtn:Show()
    else
        alertFrame.okBtn:ClearAllPoints()
        alertFrame.okBtn:SetPoint("BOTTOM", alertFrame, "BOTTOM", 0, 12)
        alertFrame.removeBtn:Hide()
    end

    alertFrame.message:SetText(msg)
    alertFrame:Show()
    PlaySound(18019) -- Raid warning sound
end

local function TriggerAlert(message, reminderId)
    -- Log to chat frame as a fallback record
    local chatMsg = message:gsub("\n\n", " - ")
    DEFAULT_CHAT_FRAME:AddMessage("|cfffff569[Reminder]|r " .. chatMsg)

    tinsert(alertQueue, { text = message, id = reminderId })
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

local subtitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPLEFT", 12, -35)
subtitle:SetText("Conditions:")

local function CreateCheckButton(parent, width, height, labelText)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(width, height)
    
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", check, "RIGHT", 6, 0)
    text:SetText(labelText)
    check.text = text
    
    return check
end

local function SetControlEnabled(control, enabled)
    if enabled then
        control:Enable()
        control:SetAlpha(1)
    else
        control:Disable()
        control:SetAlpha(0.5)
        if control.ClearFocus then
            control:ClearFocus()
        end
    end
end

-- Checkbox conditions setup
local levelCheck = CreateCheckButton(rightPanel, 20, 20, "Player Level >=")
levelCheck:SetPoint("TOPLEFT", 12, -52)

local levelEditBox = CreateEditBox(rightPanel, 70, 20, true)
levelEditBox:SetPoint("TOPLEFT", 130, -52)

local restedCheck = CreateCheckButton(rightPanel, 20, 20, "Is Rested")
restedCheck:SetPoint("TOPLEFT", 12, -77)

local cityCheck = CreateCheckButton(rightPanel, 20, 20, "In Big City")
cityCheck:SetPoint("TOPLEFT", 12, -102)

local profCheck = CreateCheckButton(rightPanel, 20, 20, "Profession Skill")
profCheck:SetPoint("TOPLEFT", 12, -127)

local profDropdown = CreateDropdown(rightPanel, 110, 20, professionList)
profDropdown:SetPoint("TOPLEFT", 12, -149)

local skillEditBox = CreateEditBox(rightPanel, 80, 20, true)
skillEditBox:SetPoint("TOPLEFT", 130, -149)

local petCheck = CreateCheckButton(rightPanel, 20, 20, "Pet Level >=")
petCheck:SetPoint("TOPLEFT", 12, -177)

local petLevelEditBox = CreateEditBox(rightPanel, 80, 20, true)
petLevelEditBox:SetPoint("TOPLEFT", 130, -177)

-- Custom message fields (always visible)
local msgLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
msgLabel:SetPoint("TOPLEFT", 12, -205)
msgLabel:SetText("Custom Message (Optional):")
local msgEditBox = CreateEditBox(rightPanel, 200, 20, false)
msgEditBox:SetPoint("TOPLEFT", 12, -220)

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

local function UpdateFormStates()
    SetControlEnabled(levelEditBox, levelCheck:GetChecked())
    SetControlEnabled(profDropdown, profCheck:GetChecked())
    SetControlEnabled(skillEditBox, profCheck:GetChecked())
    SetControlEnabled(petLevelEditBox, petCheck:GetChecked())
end

levelCheck:SetScript("OnClick", function(self)
    UpdateFormStates()
    if self:GetChecked() then levelEditBox:SetFocus() end
    PlaySound(856)
end)

restedCheck:SetScript("OnClick", function(self)
    PlaySound(856)
end)

cityCheck:SetScript("OnClick", function(self)
    PlaySound(856)
end)

profCheck:SetScript("OnClick", function(self)
    UpdateFormStates()
    if self:GetChecked() then skillEditBox:SetFocus() end
    PlaySound(856)
end)

petCheck:SetScript("OnClick", function(self)
    UpdateFormStates()
    if self:GetChecked() then petLevelEditBox:SetFocus() end
    PlaySound(856)
end)

local function ClearForm()
    editingReminder = nil
    formTitle:SetText("Add Reminder")
    
    levelCheck:SetChecked(false)
    restedCheck:SetChecked(false)
    cityCheck:SetChecked(false)
    profCheck:SetChecked(false)
    petCheck:SetChecked(false)

    levelEditBox:SetText("")
    profDropdown:SetValue("Alchemy")
    skillEditBox:SetText("")
    petLevelEditBox:SetText("")
    msgEditBox:SetText("")

    UpdateFormStates()

    saveBtn:SetText("Add")
    cancelBtn:Hide()
end

-- -------------------------------------------------------------
-- Reminder List Manager
-- -------------------------------------------------------------
local listRows = {}

RefreshList = function()
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
            row:EnableMouse(true)

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

            -- Custom message text
            local msgText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            msgText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 30, 5)
            msgText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -88, 5)
            msgText:SetJustifyH("LEFT")
            msgText:SetWordWrap(false)
            row.msgText = msgText

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

        -- Tooltip showing custom message on row hover
        row:SetScript("OnEnter", function(self)
            if rem.message and rem.message ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Custom Message:", 1, 0.82, 0)
                GameTooltip:AddLine(rem.message, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Re-anchor dynamically depending on whether there is a message
        row.text:ClearAllPoints()
        if rem.message and rem.message ~= "" then
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -5)
            row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -88, -5)
            row.msgText:SetText(rem.message)
            row.msgText:Show()
        else
            row.text:SetPoint("LEFT", row.check, "RIGHT", 5, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -88, 0)
            row.msgText:Hide()
        end

        local desc = ""
        local condDescs = {}
        local conditions = rem.conditions or { { type = rem.type, value = rem.value, profession = rem.profession } }
        for _, cond in ipairs(conditions) do
            if cond.type == "level" then
                table.insert(condDescs, "Lvl >= |cfffff569" .. (cond.value or 0) .. "|r")
            elseif cond.type == "rested" then
                table.insert(condDescs, "Rested")
            elseif cond.type == "city" then
                table.insert(condDescs, "In City")
            elseif cond.type == "profession" then
                table.insert(condDescs, (cond.profession or "Unknown") .. " >= |cfffff569" .. (cond.value or 0) .. "|r")
            elseif cond.type == "pet_level" then
                table.insert(condDescs, "Pet >= |cfffff569" .. (cond.value or 0) .. "|r")
            end
        end
        desc = table.concat(condDescs, ", ")
        row.text:SetText(desc)

        -- Hooks
        row.editBtn:SetScript("OnClick", function()
            PlaySound(856)
            editingReminder = rem
            formTitle:SetText("Edit Reminder")

            -- Reset all checkboxes first
            levelCheck:SetChecked(false)
            restedCheck:SetChecked(false)
            cityCheck:SetChecked(false)
            profCheck:SetChecked(false)
            petCheck:SetChecked(false)

            levelEditBox:SetText("")
            skillEditBox:SetText("")
            petLevelEditBox:SetText("")
            msgEditBox:SetText(rem.message or "")

            local conditions = rem.conditions or { { type = rem.type, value = rem.value, profession = rem.profession } }
            for _, cond in ipairs(conditions) do
                if cond.type == "level" then
                    levelCheck:SetChecked(true)
                    levelEditBox:SetText(tostring(cond.value or ""))
                elseif cond.type == "rested" then
                    restedCheck:SetChecked(true)
                elseif cond.type == "city" then
                    cityCheck:SetChecked(true)
                elseif cond.type == "profession" then
                    profCheck:SetChecked(true)
                    profDropdown:SetValue(cond.profession or "Alchemy")
                    skillEditBox:SetText(tostring(cond.value or ""))
                elseif cond.type == "pet_level" then
                    petCheck:SetChecked(true)
                    petLevelEditBox:SetText(tostring(cond.value or ""))
                end
            end

            UpdateFormStates()

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
    local conditions = {}

    if levelCheck:GetChecked() then
        local text = levelEditBox:GetText()
        local value = tonumber(text)
        if not value or value <= 0 then
            print("|cffff3333[Reminder] Please enter a valid level!|r")
            return
        end
        table.insert(conditions, { type = "level", value = value })
    end

    if restedCheck:GetChecked() then
        table.insert(conditions, { type = "rested" })
    end

    if cityCheck:GetChecked() then
        table.insert(conditions, { type = "city" })
    end

    if profCheck:GetChecked() then
        local profession = profDropdown:GetValue()
        local text = skillEditBox:GetText()
        local value = tonumber(text)
        if not value or value <= 0 then
            print("|cffff3333[Reminder] Please enter a valid skill value!|r")
            return
        end
        table.insert(conditions, { type = "profession", profession = profession, value = value })
    end

    if petCheck:GetChecked() then
        local text = petLevelEditBox:GetText()
        local value = tonumber(text)
        if not value or value <= 0 then
            print("|cffff3333[Reminder] Please enter a valid pet level!|r")
            return
        end
        table.insert(conditions, { type = "pet_level", value = value })
    end

    if #conditions == 0 then
        print("|cffff3333[Reminder] Please select at least one condition!|r")
        return
    end

    local customMsg = msgEditBox:GetText()

    if editingReminder then
        editingReminder.conditions = conditions
        editingReminder.message = (customMsg ~= "") and customMsg or nil
        editingReminder.triggered = false
    else
        local newRem = {
            id = tostring(time()) .. "_" .. tostring(random(1000, 9999)),
            conditions = conditions,
            message = (customMsg ~= "") and customMsg or nil,
            enabled = true,
            triggered = false,
        }
        table.insert(ReminderDB.reminders, newRem)
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
            local allMet = true
            local msgs = {}

            local conditions = rem.conditions
            if not conditions then
                conditions = {
                    { type = rem.type, value = rem.value, profession = rem.profession }
                }
            end

            for _, cond in ipairs(conditions) do
                local condMet = false
                local condMsg = ""

                if cond.type == "level" then
                    condMet = UnitLevel("player") >= (cond.value or 0)
                    condMsg = "Lvl >= " .. (cond.value or 0)
                elseif cond.type == "rested" then
                    condMet = IsResting()
                    condMsg = "Rested"
                elseif cond.type == "city" then
                    condMet = IsInBigCity()
                    condMsg = "In City"
                elseif cond.type == "profession" then
                    local rank = GetProfessionSkillRank(cond.profession)
                    condMet = (rank >= (cond.value or 0)) and IsInBigCity()
                    condMsg = (cond.profession or "Profession") .. " >= " .. (cond.value or 0) .. " (in City)"
                elseif cond.type == "pet_level" then
                    condMet = UnitExists("pet") and (UnitLevel("pet") >= (cond.value or 0))
                    condMsg = "Pet Lvl >= " .. (cond.value or 0)
                else
                    condMet = true
                end

                if not condMet then
                    allMet = false
                end
                if condMsg ~= "" then
                    table.insert(msgs, condMsg)
                end
            end

            if allMet and #conditions > 0 then
                if not rem.triggered then
                    rem.triggered = true
                    local alertMsg = "Reminder Met: " .. table.concat(msgs, ", ")
                    if rem.message and rem.message ~= "" then
                        alertMsg = alertMsg .. "\n\n|cff82c5ff" .. rem.message .. "|r"
                    end
                    TriggerAlert(alertMsg, rem.id)
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

        -- Database Migration to Multi-condition structure
        for _, rem in ipairs(ReminderDB.reminders) do
            if not rem.conditions then
                rem.conditions = {}
                if rem.type then
                    table.insert(rem.conditions, {
                        type = rem.type,
                        value = rem.value,
                        profession = rem.profession
                    })
                end
                rem.type = nil
                rem.value = nil
                rem.profession = nil
            end
        end

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
