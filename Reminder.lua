-- Reminder.lua
-- WoW Classic Era Addon
-- Author: Antigravity

local random, time = math.random, time
local tinsert, ipairs, pairs = table.insert, ipairs, pairs

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

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
local theme = {
    border = { 0.23, 0.26, 0.31 },
    gold = { 0.90, 0.73, 0.43 },
    text = { 0.91, 0.92, 0.94 },
    muted = { 0.59, 0.64, 0.71 },
    green = { 0.48, 0.78, 0.64 },
}

local function ApplyBackdrop(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
    local bg = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    }
    frame:SetBackdrop(bg)
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
end

local function Label(parent, text, font, color)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetText(text)
    label:SetTextColor(unpack(color or theme.text))
    label:SetJustifyH("LEFT")
    return label
end

local function Fill(parent, color, alpha)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    return texture
end

local function CreateButton(parent, width, height, text, style)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    local primary = style == "primary"
    local danger = style == "danger"
    local normal = primary and { 0.28, 0.22, 0.13 } or { 0.12, 0.14, 0.18 }
    local edge = primary and theme.gold or theme.border
    ApplyBackdrop(button, normal[1], normal[2], normal[3], 1, edge[1], edge[2], edge[3], 1)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    button:SetText(text)
    button:GetFontString():SetTextColor(unpack(primary and theme.gold or (danger and { 0.91, 0.56, 0.54 } or theme.text)))
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(normal[1] + 0.06, normal[2] + 0.06, normal[3] + 0.06, 1)
        self:SetBackdropBorderColor(unpack(danger and { 0.85, 0.4, 0.38 } or theme.gold))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(normal[1], normal[2], normal[3], 1)
        self:SetBackdropBorderColor(unpack(edge))
    end)
    return button
end

local function CreateCheckButton(parent, width, height, labelText)
    local check = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    check:SetSize(width, height)
    ApplyBackdrop(check, 0.045, 0.055, 0.075, 1, 0.30, 0.34, 0.40, 1)
    local tick = check:CreateTexture(nil, "ARTWORK")
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetAllPoints()
    tick:SetVertexColor(unpack(theme.gold))
    check:SetCheckedTexture(tick)
    local highlight = check:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetColorTexture(1, 0.82, 0.5, 0.12)
    highlight:SetAllPoints()
    if labelText then
        check.text = Label(check, labelText)
        check.text:SetPoint("LEFT", check, "RIGHT", 10, 0)
        -- Let clicking the label toggle the checkbox as well.
        check:SetHitRectInsets(0, -check.text:GetStringWidth() - 10, -3, -3)
    end
    return check
end

local function AddTooltip(control, title, description)
    control:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, unpack(theme.gold))
        GameTooltip:AddLine(description, 0.85, 0.88, 0.92, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function() GameTooltip:Hide() end)
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

local professionSkillIDs = {
    ["alchemy"] = 171,
    ["blacksmithing"] = 164,
    ["cooking"] = 185,
    ["enchanting"] = 333,
    ["engineering"] = 202,
    ["first aid"] = 129,
    ["fishing"] = 356,
    ["herbalism"] = 182,
    ["leatherworking"] = 165,
    ["mining"] = 186,
    ["skinning"] = 393,
    ["tailoring"] = 197,
}

local function GetProfessionSkillRank(name)
    if not name or name == "" then return 0 end
    name = name:lower()

    -- Forever exposes skill data through C_SkillInfo instead of the old globals.
    -- Looking up the ID also works when the Skills panel headers are collapsed.
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        local skillID = professionSkillIDs[name]
        if not skillID then return 0 end
        local info = C_SkillInfo.GetSkillLineInfoByID(skillID)
        return info and info.rank or 0
    end

    -- Keep the skill-window scan for Classic Era clients with the legacy API.
    if not (GetNumSkillLines and GetSkillLineInfo and ExpandSkillHeader and CollapseSkillHeader) then
        return 0
    end

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
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(9, 9, 0, 0)
    ApplyBackdrop(eb, 0.045, 0.055, 0.075, 1, 0.23, 0.26, 0.31, 1)
    eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(theme.gold)) end)
    eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(theme.border)) end)

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
    ApplyBackdrop(dropdown, 0.045, 0.055, 0.075, 1, 0.23, 0.26, 0.31, 1)
    dropdown:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(theme.gold)) end)
    dropdown:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(theme.border)) end)

    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(theme.text))
    dropdown.text = text

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -4, 0)
    dropdown.arrow = arrow

    local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    ApplyBackdrop(menu, 0.08, 0.095, 0.12, 1, 0.40, 0.34, 0.23, 1)
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
                btn:SetHeight(24)
                btn:SetNormalFontObject("GameFontHighlightSmall")
                btn:SetHighlightFontObject("GameFontNormalSmall")

                local btnHighlight = btn:CreateTexture(nil, "BACKGROUND")
                btnHighlight:SetColorTexture(0.90, 0.73, 0.43, 0.15)
                btnHighlight:SetAllPoints()
                btn:SetHighlightTexture(btnHighlight)

                local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                btnText:SetPoint("LEFT", 6, 0)
                btnText:SetPoint("RIGHT", -6, 0)
                btnText:SetJustifyH("LEFT")
                btnText:SetTextColor(unpack(theme.text))
                btn.text = btnText

                buttons[i] = btn
            end

            btn.text:SetText(opt.label or opt.value)
            btn:SetWidth(width - 8)
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 24)
            btn:SetScript("OnClick", function()
                dropdown.selectedValue = opt.value
                dropdown.text:SetText(opt.label or opt.value)
                menu:Hide()
                activeDropdownMenu = nil
                if callback then callback(opt.value) end
            end)
            btn:Show()
            menuHeight = menuHeight + 24
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
        alertFrame:SetSize(420, 210)
        alertFrame:SetPoint("CENTER", 0, 150)
        alertFrame:SetFrameStrata("DIALOG")
        alertFrame:EnableMouse(true)
        alertFrame:SetMovable(true)
        alertFrame:SetClampedToScreen(true)
        alertFrame:RegisterForDrag("LeftButton")
        alertFrame:SetScript("OnDragStart", alertFrame.StartMoving)
        alertFrame:SetScript("OnDragStop", alertFrame.StopMovingOrSizing)

        ApplyBackdrop(alertFrame, 0.055, 0.065, 0.085, 0.98, 0.56, 0.45, 0.27, 1)
        local accent = Fill(alertFrame, theme.gold)
        accent:SetPoint("TOPLEFT", 1, -1)
        accent:SetPoint("TOPRIGHT", -1, -1)
        accent:SetHeight(3)

        local icon = alertFrame:CreateTexture(nil, "OVERLAY")
        icon:SetTexture("Interface\\Icons\\inv_misc_clock_01")
        icon:SetSize(34, 34)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("TOPLEFT", 22, -22)
        alertFrame.icon = icon

        local title = Label(alertFrame, "Reminder", "GameFontNormalLarge", theme.gold)
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -1)
        alertFrame.title = title
        local hint = Label(alertFrame, "Your conditions have been met.", nil, theme.muted)
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

        local message = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        message:SetPoint("TOPLEFT", 22, -78)
        message:SetWidth(376)
        message:SetTextColor(unpack(theme.text))
        message:SetJustifyH("LEFT")
        message:SetJustifyV("TOP")
        message:SetWordWrap(true)
        alertFrame.message = message

        local okBtn = CreateButton(alertFrame, 112, 30, "Dismiss")
        okBtn:SetScript("OnClick", function()
            PlaySound(856)
            ShowNextAlert()
        end)
        alertFrame.okBtn = okBtn

        local removeBtn = CreateButton(alertFrame, 150, 30, "Complete & remove", "primary")
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
                print("|cfffff569[Reminder]|r Removed reminder: " .. alertFrame.message:GetText())
                RefreshList()
            end
            ShowNextAlert()
        end)
        alertFrame.removeBtn = removeBtn
    end

    alertFrame.currentReminderId = reminderId

    if reminderId then
        alertFrame.okBtn:ClearAllPoints()
        alertFrame.okBtn:SetPoint("BOTTOMLEFT", alertFrame, "BOTTOMLEFT", 22, 20)
        alertFrame.removeBtn:ClearAllPoints()
        alertFrame.removeBtn:SetPoint("BOTTOMRIGHT", alertFrame, "BOTTOMRIGHT", -22, 20)
        alertFrame.removeBtn:Show()
    else
        alertFrame.okBtn:ClearAllPoints()
        alertFrame.okBtn:SetPoint("BOTTOMRIGHT", alertFrame, "BOTTOMRIGHT", -22, 20)
        alertFrame.removeBtn:Hide()
    end

    alertFrame.message:SetText(msg)
    alertFrame:SetHeight(math.max(190, 78 + alertFrame.message:GetStringHeight() + 76))
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
frame:SetSize(820, 620)
frame:SetPoint("CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
ApplyBackdrop(frame, 0.055, 0.065, 0.085, 0.98, 0.30, 0.32, 0.37, 1)
frame:Hide()

local topAccent = Fill(frame, theme.gold)
topAccent:SetPoint("TOPLEFT", 1, -1)
topAccent:SetPoint("TOPRIGHT", -1, -1)
topAccent:SetHeight(2)

local closeBtn = CreateButton(frame, 28, 26, "x")
closeBtn:SetPoint("TOPRIGHT", -18, -20)
closeBtn:SetScript("OnClick", function() frame:Hide(); PlaySound(856) end)
AddTooltip(closeBtn, "Close", "You can also press Escape to close this window.")

-- Add to special frames to close on ESC
tinsert(UISpecialFrames, "ReminderFrame")

-- Title Text
local headerIcon = frame:CreateTexture(nil, "ARTWORK")
headerIcon:SetTexture("Interface\\Icons\\inv_misc_clock_01")
headerIcon:SetSize(38, 38)
headerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
headerIcon:SetPoint("TOPLEFT", 22, -23)
local titleText = Label(frame, "Reminder", "GameFontNormalHuge", theme.gold)
titleText:SetPoint("TOPLEFT", headerIcon, "TOPRIGHT", 12, 1)
local tagline = Label(frame, "A little nudge, at the right moment.", nil, theme.muted)
tagline:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)

-- Panels
local leftPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
leftPanel:SetPoint("TOPLEFT", 18, -86)
leftPanel:SetPoint("BOTTOMLEFT", 18, 48)
leftPanel:SetWidth(410)
ApplyBackdrop(leftPanel, 0.08, 0.095, 0.12, 1, 0.23, 0.26, 0.31, 1)
local listTitle = Label(leftPanel, "Your reminders", "GameFontNormalLarge", theme.text)
listTitle:SetPoint("TOPLEFT", 16, -16)
local listCount = Label(leftPanel, "0 active / 0 total", nil, theme.muted)
listCount:SetPoint("TOPRIGHT", -16, -20)
local listHint = Label(leftPanel, "Check a reminder to enable it.", nil, theme.muted)
listHint:SetPoint("TOPLEFT", 16, -39)

local rightPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
rightPanel:SetPoint("TOPLEFT", 440, -86)
rightPanel:SetPoint("BOTTOMRIGHT", -18, 48)
ApplyBackdrop(rightPanel, 0.08, 0.095, 0.12, 1, 0.23, 0.26, 0.31, 1)

-- Scroll Frame for Reminder List
local scrollFrame = CreateFrame("ScrollFrame", "ReminderListScrollFrame", leftPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 12, -64)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(368, 1)
scrollFrame:SetScrollChild(scrollChild)

local emptyState = CreateFrame("Frame", nil, leftPanel)
emptyState:SetPoint("TOPLEFT", 30, -130)
emptyState:SetPoint("BOTTOMRIGHT", -30, 70)
local emptyIcon = emptyState:CreateTexture(nil, "ARTWORK")
emptyIcon:SetTexture("Interface\\Icons\\inv_misc_clock_01")
emptyIcon:SetSize(48, 48)
emptyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
emptyIcon:SetAlpha(0.45)
emptyIcon:SetPoint("TOP", 0, -30)
local emptyTitle = Label(emptyState, "Make room for a reminder", "GameFontNormal", theme.gold)
emptyTitle:SetPoint("TOP", emptyIcon, "BOTTOM", 0, -18)
local emptyHint = Label(emptyState, "Choose your conditions on the right,\nthen add your first reminder.", nil, theme.muted)
emptyHint:SetPoint("TOP", emptyTitle, "BOTTOM", 0, -10)
emptyHint:SetJustifyH("CENTER")

-- Form Fields Setup
local formTitle = Label(rightPanel, "New reminder", "GameFontNormalLarge", theme.gold)
formTitle:SetPoint("TOPLEFT", 18, -16)

local subtitle = Label(rightPanel, "Notify me when all selected conditions match.", nil, theme.muted)
subtitle:SetPoint("TOPLEFT", 18, -40)

local function SetControlEnabled(control, enabled)
    if enabled then
        control:Enable()
        control:SetAlpha(1)
    else
        control:Disable()
        control:SetAlpha(0.35)
        if control.ClearFocus then
            control:ClearFocus()
        end
    end
end

-- Checkbox conditions setup
local levelCheck = CreateCheckButton(rightPanel, 18, 18, "Player level at least")
levelCheck:SetPoint("TOPLEFT", 18, -72)

local levelEditBox = CreateEditBox(rightPanel, 74, 26, true)
levelEditBox:SetPoint("TOPRIGHT", -18, -68)

local restedCheck = CreateCheckButton(rightPanel, 18, 18, "Resting in an inn or city")
restedCheck:SetPoint("TOPLEFT", 18, -106)

local cityCheck = CreateCheckButton(rightPanel, 18, 18, "In a capital city")
cityCheck:SetPoint("TOPLEFT", 18, -140)

local profCheck = CreateCheckButton(rightPanel, 18, 18, "Profession skill (in a city)")
profCheck:SetPoint("TOPLEFT", 18, -174)
AddTooltip(profCheck, "Profession skill", "Triggers when your skill is at least the chosen rank and you are in a capital city.")

local profDropdown = CreateDropdown(rightPanel, 180, 26, professionList)
profDropdown:SetPoint("TOPLEFT", 46, -201)

local skillEditBox = CreateEditBox(rightPanel, 74, 26, true)
skillEditBox:SetPoint("TOPRIGHT", -18, -201)
AddTooltip(skillEditBox, "Minimum skill rank", "Enter the profession skill rank to reach, such as 150.")

local petCheck = CreateCheckButton(rightPanel, 18, 18, "Hunter pet level at least")
petCheck:SetPoint("TOPLEFT", 18, -245)

local petLevelEditBox = CreateEditBox(rightPanel, 74, 26, true)
petLevelEditBox:SetPoint("TOPRIGHT", -18, -241)

local areaCheck = CreateCheckButton(rightPanel, 18, 18, "In a specific area")
areaCheck:SetPoint("TOPLEFT", 18, -279)

local areaLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
areaLabel:SetPoint("TOPLEFT", 46, -310)
areaLabel:SetText("Area:")

local areaEditBox = CreateEditBox(rightPanel, 204, 26, false)
areaEditBox:SetPoint("TOPRIGHT", -18, -302)

local subAreaLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subAreaLabel:SetPoint("TOPLEFT", 46, -342)
subAreaLabel:SetText("Sub-area:")

local subAreaEditBox = CreateEditBox(rightPanel, 204, 26, false)
subAreaEditBox:SetPoint("TOPRIGHT", -18, -334)
AddTooltip(subAreaEditBox, "Sub-area (optional)", "Leave blank to match anywhere in the area above.")

-- Custom message fields (always visible)
local msgLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
msgLabel:SetPoint("TOPLEFT", 18, -378)
msgLabel:SetText("Your message |cff969fae(optional)|r")
msgLabel:SetTextColor(unpack(theme.text))
local msgEditBox = CreateEditBox(rightPanel, 306, 28, false)
msgEditBox:SetPoint("TOPLEFT", 18, -397)

local saveBtn = CreateButton(rightPanel, 178, 30, "Add reminder", "primary")
saveBtn:SetPoint("BOTTOMLEFT", 18, 16)

local cancelBtn = CreateButton(rightPanel, 116, 30, "Cancel")
cancelBtn:SetPoint("BOTTOMRIGHT", -18, 16)
cancelBtn:Hide()

local previewBtn = CreateButton(frame, 112, 26, "Preview alert")
previewBtn:SetPoint("BOTTOMRIGHT", -18, 12)
previewBtn:SetScript("OnClick", function()
    TriggerAlert("You're all set.\n\n|cff82c5ffYour reminders will appear here when their conditions match.|r")
end)
local footer = Label(frame, "Drag the header to move  |  /reminder to open", nil, theme.muted)
footer:SetPoint("BOTTOMLEFT", 22, 20)

frame:SetScript("OnShow", function(self)
    self:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 820, (UIParent:GetHeight() - 32) / 620))
    if RefreshList then RefreshList() end
end)
frame:SetScript("OnHide", function()
    if activeDropdownMenu then activeDropdownMenu:Hide(); activeDropdownMenu = nil end
    for _, editBox in ipairs({ levelEditBox, skillEditBox, petLevelEditBox, areaEditBox, subAreaEditBox, msgEditBox }) do
        editBox:ClearFocus()
    end
end)

local editingReminder = nil

local function UpdateFormStates()
    SetControlEnabled(levelEditBox, levelCheck:GetChecked())
    SetControlEnabled(profDropdown, profCheck:GetChecked())
    SetControlEnabled(skillEditBox, profCheck:GetChecked())
    SetControlEnabled(petLevelEditBox, petCheck:GetChecked())
    SetControlEnabled(areaEditBox, areaCheck:GetChecked())
    SetControlEnabled(subAreaEditBox, areaCheck:GetChecked())
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

areaCheck:SetScript("OnClick", function(self)
    UpdateFormStates()
    if self:GetChecked() then areaEditBox:SetFocus() end
    PlaySound(856)
end)

local function ClearForm()
    editingReminder = nil
    formTitle:SetText("New reminder")

    levelCheck:SetChecked(false)
    restedCheck:SetChecked(false)
    cityCheck:SetChecked(false)
    profCheck:SetChecked(false)
    petCheck:SetChecked(false)
    areaCheck:SetChecked(false)

    levelEditBox:SetText("")
    profDropdown:SetValue("Alchemy")
    skillEditBox:SetText("")
    petLevelEditBox:SetText("")
    areaEditBox:SetText("")
    subAreaEditBox:SetText("")
    msgEditBox:SetText("")

    UpdateFormStates()

    saveBtn:SetText("Add reminder")
    cancelBtn:Hide()
    if RefreshList then RefreshList() end
end

-- -------------------------------------------------------------
-- Reminder List Manager
-- -------------------------------------------------------------
local listRows = {}

local function StyleRow(row, rem, hovered)
    local selected = editingReminder == rem
    local color = selected and theme.gold or theme.border
    row:SetBackdropColor(hovered and 0.13 or 0.10, hovered and 0.15 or 0.12, hovered and 0.19 or 0.15, 1)
    row:SetBackdropBorderColor(unpack(color))
    local statusColor = rem.enabled and theme.green or theme.muted
    row.accent:SetColorTexture(statusColor[1], statusColor[2], statusColor[3], rem.enabled and 0.9 or 0.4)
    row.status:SetText(selected and "Editing" or (rem.enabled and "Watching" or "Paused"))
    row.status:SetTextColor(unpack(selected and theme.gold or statusColor))
    row.text:SetAlpha(rem.enabled and 1 or 0.5)
    row.msgText:SetAlpha(rem.enabled and 1 or 0.5)
end

RefreshList = function()
    -- Hide all rows first
    for _, row in ipairs(listRows) do
        row:Hide()
    end

    if not ReminderDB or not ReminderDB.reminders then return end

    local enabledCount = 0
    for _, rem in ipairs(ReminderDB.reminders) do
        if rem.enabled then enabledCount = enabledCount + 1 end
    end
    listCount:SetText(enabledCount .. " active / " .. #ReminderDB.reminders .. " total")
    emptyState:SetShown(#ReminderDB.reminders == 0)

    local yOffset = 0
    for i, rem in ipairs(ReminderDB.reminders) do
        local row = listRows[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetSize(368, 78)
            ApplyBackdrop(row, 0.10, 0.12, 0.15, 1, 0.23, 0.26, 0.31, 1)
            row:EnableMouse(true)
            local accent = Fill(row, theme.green)
            accent:SetPoint("TOPLEFT", 1, -1)
            accent:SetPoint("BOTTOMLEFT", 1, 1)
            accent:SetWidth(2)
            row.accent = accent

            -- Checkbox for enabled/disabled
            local check = CreateCheckButton(row, 18, 18)
            check:SetPoint("TOPLEFT", 12, -12)
            AddTooltip(check, "Enable reminder", "Uncheck to pause this reminder. Check it again to watch its conditions.")
            row.check = check

            -- Description text
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("TOPLEFT", 40, -14)
            text:SetPoint("TOPRIGHT", -12, -14)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(true)
            text:SetTextColor(unpack(theme.text))
            row.text = text

            -- Custom message text
            local msgText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            msgText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -8)
            msgText:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 0, -8)
            msgText:SetHeight(14)
            msgText:SetJustifyH("LEFT")
            msgText:SetWordWrap(false)
            msgText:SetTextColor(unpack(theme.muted))
            row.msgText = msgText
            local status = Label(row, "Watching", nil, theme.green)
            status:SetPoint("BOTTOMLEFT", 12, 16)
            row.status = status

            -- Edit button
            local editBtn = CreateButton(row, 50, 24, "Edit")
            editBtn:SetPoint("BOTTOMRIGHT", -82, 10)
            row.editBtn = editBtn

            -- Delete button
            local delBtn = CreateButton(row, 62, 24, "Remove", "danger")
            delBtn:SetPoint("BOTTOMRIGHT", -12, 10)
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
            RefreshList()
        end)

        -- Keep the full conditions and message available even when the preview is truncated.
        row:SetScript("OnEnter", function(self)
            StyleRow(self, rem, true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reminder conditions", unpack(theme.gold))
            GameTooltip:AddLine(self.text:GetText(), 0.91, 0.92, 0.94, true)
            if rem.message and rem.message ~= "" then GameTooltip:AddLine("\n" .. rem.message, 0.65, 0.78, 0.91, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            StyleRow(self, rem, false)
            GameTooltip:Hide()
        end)

        if rem.message and rem.message ~= "" then
            row.msgText:SetText(rem.message:gsub("[\r\n]+", " "))
            row.msgText:Show()
        else
            row.msgText:Hide()
        end

        local desc = ""
        local condDescs = {}
        local conditions = rem.conditions or { { type = rem.type, value = rem.value, profession = rem.profession } }
        for _, cond in ipairs(conditions) do
            if cond.type == "level" then
                table.insert(condDescs, "Level |cffe6ba6e" .. (cond.value or 0) .. "+|r")
            elseif cond.type == "rested" then
                table.insert(condDescs, "Rested")
            elseif cond.type == "city" then
                table.insert(condDescs, "In a capital city")
            elseif cond.type == "profession" then
                table.insert(condDescs, (cond.profession or "Unknown") .. " |cffe6ba6e" .. (cond.value or 0) .. "+|r in a city")
            elseif cond.type == "pet_level" then
                table.insert(condDescs, "Pet level |cffe6ba6e" .. (cond.value or 0) .. "+|r")
            elseif cond.type == "area" then
                if cond.subArea and trim(cond.subArea) ~= "" then
                    table.insert(condDescs, "|cffe6ba6e" .. cond.area .. "|r (|cffe6ba6e" .. cond.subArea .. "|r)")
                else
                    table.insert(condDescs, "|cffe6ba6e" .. cond.area .. "|r")
                end
            end
        end
        desc = table.concat(condDescs, "  |cff7d8796&|r  ")
        row.text:SetText(desc)
        row:SetHeight(math.max(74, row.text:GetStringHeight() + 56 + (row.msgText:IsShown() and 22 or 0)))
        StyleRow(row, rem, false)

        -- Hooks
        row.editBtn:SetScript("OnClick", function()
            PlaySound(856)
            editingReminder = rem
            formTitle:SetText("Edit reminder")

            -- Reset all checkboxes first
            levelCheck:SetChecked(false)
            restedCheck:SetChecked(false)
            cityCheck:SetChecked(false)
            profCheck:SetChecked(false)
            petCheck:SetChecked(false)
            areaCheck:SetChecked(false)

            levelEditBox:SetText("")
            skillEditBox:SetText("")
            petLevelEditBox:SetText("")
            areaEditBox:SetText("")
            subAreaEditBox:SetText("")
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
                elseif cond.type == "area" then
                    areaCheck:SetChecked(true)
                    areaEditBox:SetText(cond.area or "")
                    subAreaEditBox:SetText(cond.subArea or "")
                end
            end

            UpdateFormStates()

            saveBtn:SetText("Save changes")
            cancelBtn:Show()
            RefreshList()
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

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:Show()
        yOffset = yOffset + row:GetHeight() + 8
    end

    scrollChild:SetHeight(math.max(1, yOffset - 8))
    scrollFrame:SetVerticalScroll(math.min(scrollFrame:GetVerticalScroll(), math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())))
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

    if areaCheck:GetChecked() then
        local areaText = areaEditBox:GetText()
        local subAreaText = subAreaEditBox:GetText()
        if not areaText or trim(areaText) == "" then
            print("|cffff3333[Reminder] Please enter a valid Area!|r")
            return
        end
        table.insert(conditions, {
            type = "area",
            area = trim(areaText),
            subArea = (subAreaText and trim(subAreaText) ~= "") and trim(subAreaText) or nil
        })
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
-- LibDataBroker & Minimap Icon Creation
-- -------------------------------------------------------------
local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

local reminderLDB = nil
if LDB then
    reminderLDB = LDB:NewDataObject("Reminder", {
        type = "launcher",
        text = "Reminder",
        icon = 134376,
        OnClick = function(self, button)
            if button == "LeftButton" then
                if ReminderFrame:IsShown() then
                    ReminderFrame:Hide()
                else
                    ReminderFrame:Show()
                end
                PlaySound(856)
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("Reminder", 1, 1, 1)
            tt:AddLine("Left-Click: Open settings.", 0.2, 1, 0.2)
            tt:AddLine("Drag: Move minimap button.", 0.8, 0.8, 0.8)
        end,
    })
end

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
                elseif cond.type == "area" then
                    local currentArea = GetRealZoneText() or ""
                    local currentSubArea = GetMinimapZoneText() or ""

                    local targetArea = cond.area and trim(cond.area):lower() or ""
                    local targetSubArea = cond.subArea and trim(cond.subArea):lower() or ""

                    if targetArea ~= "" then
                        local areaMatch = (currentArea:lower() == targetArea)
                        local subAreaMatch = true
                        if targetSubArea ~= "" then
                            subAreaMatch = (currentSubArea:lower() == targetSubArea)
                        end
                        condMet = areaMatch and subAreaMatch
                    else
                        condMet = false
                    end

                    if cond.subArea and trim(cond.subArea) ~= "" then
                        condMsg = cond.area .. " (" .. cond.subArea .. ")"
                    else
                        condMsg = cond.area
                    end
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
        ReminderDB.minimap = ReminderDB.minimap or {}
        if ReminderDB.minimap.minimapPos == nil then
            ReminderDB.minimap.minimapPos = ReminderDB.minimapPos or 220
        end
        if ReminderDB.minimap.hide == nil then
            ReminderDB.minimap.hide = ReminderDB.minimapHide or false
        end

        -- Register with LibDBIcon
        if LDBIcon and reminderLDB then
            LDBIcon:Register("Reminder", reminderLDB, ReminderDB.minimap)
        end

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
