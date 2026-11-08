local _, Names = ...
local refreshers = {}
local refreshing = false

local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function Tooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Button(parent, text, x, y, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

local function Checkbox(parent, text, x, y, getValue, setValue, tip)
    local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    button:SetSize(26, 26)
    button:SetPoint("TOPLEFT", x, y)
    button.Text:SetText(text)
    button:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
        Names:SettingsChanged()
    end)
    table.insert(refreshers, function() button:SetChecked(getValue()) end)
    if tip then Tooltip(button, tip) end
    return button
end

local function SettingCheckbox(parent, text, key, x, y, tip)
    return Checkbox(parent, text, x, y, function() return Names.db[key] end,
        function(value) Names.db[key] = value end, tip)
end

local function Slider(parent, text, key, x, y, low, high)
    local slider = CreateFrame("Slider", "FamiliarNamesSlider_" .. key, parent, "UISliderTemplateWithLabels")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetSize(260, 16)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(low))
    slider.High:SetText(tostring(high))
    slider:SetScript("OnValueChanged", function(_, value)
        if refreshing then return end
        Names.db[key] = math.floor(value + 0.5)
        Names:SettingsChanged()
    end)
    table.insert(refreshers, function()
        slider:SetValue(Names.db[key])
        slider.Text:SetText(text .. ": " .. Names.db[key])
    end)
end

local function Section(parent, text, y)
    Label(parent, text, 8, y, "GameFontNormalLarge")
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.22)
    line:SetPoint("TOPLEFT", 8, y - 23)
    line:SetPoint("TOPRIGHT", -8, y - 23)
    line:SetHeight(1)
end

function Names:RefreshOptions()
    refreshing = true
    for _, refresh in ipairs(refreshers) do refresh() end
    refreshing = false
end

function Names:PickColor(category)
    if not ColorPickerFrame then C_AddOns.LoadAddOn("Blizzard_ColorPickerFrame") end
    local color = self.db.categories[category].color
    local original = { unpack(color) }
    ColorPickerFrame:SetupColorPickerAndShow({
        r = color[1], g = color[2], b = color[3], hasOpacity = false,
        swatchFunc = function()
            self.db.categories[category].color = { ColorPickerFrame:GetColorRGB() }
            self:SettingsChanged()
        end,
        cancelFunc = function()
            self.db.categories[category].color = original
            self:SettingsChanged()
        end,
    })
end

-- One small icon grid serves category settings, the target toolbar and the minimap.
function Names:PickMarker(anchor, onSelect)
    if not self.markerPicker then
        local picker = CreateFrame("Frame", "FamiliarNamesMarkerPicker", UIParent, "BackdropTemplate")
        table.insert(UISpecialFrames, "FamiliarNamesMarkerPicker")
        picker:SetSize(154, 146)
        picker:SetFrameStrata("DIALOG")
        picker:SetClampedToScreen(true)
        picker:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        for index = 0, 8 do
            local selected = index
            local button = CreateFrame("Button", nil, picker)
            button:SetSize(36, 36)
            button:SetPoint("TOPLEFT", 14 + (index % 3) * 44, -12 - math.floor(index / 3) * 42)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            if index == 0 then
                button.text = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                button.text:SetAllPoints()
                button.text:SetText("None")
            else
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                SetRaidTargetIconTexture(icon, index)
            end
            Tooltip(button, index == 0 and "No personal marker" or self.markerLabels[index])
            button:SetScript("OnClick", function()
                picker.onSelect(selected)
                picker:Hide()
            end)
        end
        self.markerPicker = picker
    end
    self.markerPicker.onSelect = onSelect
    self.markerPicker:ClearAllPoints()
    self.markerPicker:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    self.markerPicker:Show()
end

local function CategoryRow(parent, row, y)
    local function Key() return row == 5 and "enemies" or Names.db.priority[row] end
    local label = Label(parent, "", 12, y - 7)
    Checkbox(parent, "", 210, y, function() return Names.db.categories[Key()].show end,
        function(value) Names.db.categories[Key()].show = value end, "Show names for this category.")
    local color = Button(parent, "", 272, y - 1, 112, function() Names:PickColor(Key()) end)
    local marker = Button(parent, "", 404, y - 1, 100, function(self)
        local category = Key()
        Names:PickMarker(self, function(index)
            Names.db.categories[category].marker = index
            Names:SettingsChanged()
        end)
    end)
    Tooltip(marker, "Choose an automatic personal marker for this category.")
    if row < 5 then
        local up = Button(parent, "^", 526, y - 1, 26, function()
            local priority = Names.db.priority
            if row > 1 then priority[row], priority[row - 1] = priority[row - 1], priority[row] end
            Names:SettingsChanged()
        end)
        local down = Button(parent, "v", 556, y - 1, 26, function()
            local priority = Names.db.priority
            if row < 4 then priority[row], priority[row + 1] = priority[row + 1], priority[row] end
            Names:SettingsChanged()
        end)
        Tooltip(up, "Move this category higher in the priority order.")
        Tooltip(down, "Move this category lower in the priority order.")
        if row == 1 then up:Disable() end
        if row == 4 then down:Disable() end
    end
    table.insert(refreshers, function()
        local key = Key()
        local rule = Names.db.categories[key]
        label:SetText(Names.categoryLabels[key])
        color:SetText("Preview name")
        color:GetFontString():SetTextColor(unpack(rule.color))
        marker:SetText(rule.marker == 0 and "None" or Names.markerLabels[rule.marker])
    end)
end

function Names:CreateOptions()
    local panel = CreateFrame("Frame")
    panel:Hide()
    self.options = panel
    Label(panel, "Familiar Names", 16, -16, "GameFontNormalLarge")
    Label(panel, "Your colours. Your names. Your personal markers.", 16, -42)
    local status = Label(panel, "", 16, -62, "GameFontDisableSmall")
    table.insert(refreshers, function()
        status:SetText(self.pendingCVars and "Player-name setting changes are queued until combat ends."
            or self.namesRestricted and "Instance: Blizzard player names are in use. Custom player names resume outside."
            or "Only you see these changes. NPC names continue to follow Blizzard settings.")
    end)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -90)
    scroll:SetPoint("BOTTOMRIGHT", -32, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(620, 1230)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, width) content:SetWidth(math.max(600, width)) end)

    SettingCheckbox(content, "Enable Familiar Names", "enabled", 4, 0,
        "Uses name-only friendly player plates. Switching off restores your previous player-name settings after combat.")
    SettingCheckbox(content, "Show minimap button", "showMinimap", 330, 0)
    Section(content, "Player names", -48)
    Label(content, "Category", 12, -84, "GameFontNormalSmall")
    Label(content, "Show", 210, -84, "GameFontNormalSmall")
    Label(content, "Colour", 272, -84, "GameFontNormalSmall")
    Label(content, "Personal marker", 404, -84, "GameFontNormalSmall")
    Label(content, "Priority", 526, -84, "GameFontNormalSmall")
    for row = 1, 5 do CategoryRow(content, row, -106 - (row - 1) * 38) end
    -- Enemy highlighting is independent of showing enemy names.
    Checkbox(content, "Highlight enemy names", 4, -300,
        function() return self.db.categories.enemies.highlight end,
        function(value) self.db.categories.enemies.highlight = value end,
        "Off keeps Blizzard's normal enemy name colour. Custom enemy names require visible enemy nameplates.")
    SettingCheckbox(content, "Hide strangers", "hideStrangers", 300, -300,
        "Hide unknown friendly players and their pets, summons, guardians and totems. Enemy players and their minions follow the enemy setting. Ordinary NPC names are unaffected.")
    Label(content, "The highest visible matching category supplies the colour and marker.", 12, -340, "GameFontDisableSmall")
    Label(content, "Enemy nameplates must be enabled in Blizzard settings for custom enemy names.", 12, -360, "GameFontDisableSmall")

    Section(content, "Appearance", -406)
    Slider(content, "Name size", "fontSize", 14, -466, 10, 32)
    Slider(content, "Name vertical offset", "nameOffset", 330, -466, -30, 60)
    SettingCheckbox(content, "Outline names", "outline", 4, -514)
    SettingCheckbox(content, "Show player titles", "showTitles", 204, -514)
    SettingCheckbox(content, "Show guild names", "showGuild", 404, -514)
    local preview = Label(content, "", 16, -558)
    table.insert(refreshers, function()
        preview:SetFont(STANDARD_TEXT_FONT, self.db.fontSize, self.db.outline and "OUTLINE" or "")
        preview:SetText(self.db.showTitles and "Champion Exampleplayer" or "Exampleplayer")
        preview:SetTextColor(unpack(self.db.categories[self.db.priority[1]].color))
    end)

    Section(content, "Personal markers", -622)
    SettingCheckbox(content, "Enable personal markers", "markersEnabled", 4, -658)
    SettingCheckbox(content, "Show markers when names are hidden", "markersWhenHidden", 300, -658)
    Slider(content, "Marker size", "markerSize", 14, -722, 12, 48)
    Slider(content, "Marker vertical offset", "markerOffset", 330, -722, 0, 60)
    Label(content, "Mark your current target (player or NPC)", 12, -776, "GameFontNormal")
    for index = 1, 8 do
        local selected = index
        local button = Button(content, "", 12 + (index - 1) * 44, -802, 36, function() self:MarkTarget(selected) end)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(icon, index)
        Tooltip(button, self.markerLabels[index] .. ": visible only to you")
    end
    Button(content, "Clear target", 376, -802, 112, function() self:MarkTarget(0) end)
    local clearManual = Button(content, "Clear manual", 498, -802, 94, function()
        self:HandleCommand("clearall")
    end)
    Tooltip(clearManual, "Remove all manual overrides. Automatic category markers apply again.")
    Label(content, "Manual markers override category markers and last until logout or /reload.", 12, -846, "GameFontDisableSmall")
    Label(content, "Shared raid markers remain separate. NPC name visibility is never changed.", 12, -866, "GameFontDisableSmall")

    Section(content, "Access and display limits", -924)
    Label(content, "/names opens this menu. /names mark skull marks your target locally.", 12, -962)
    Label(content, "Minimap: left-click for settings, right-click for markers, drag to reposition.", 12, -984)
    local note = Label(content, "Custom names use accessible nameplates and their normal range. Player names fall back to Blizzard in instances. Personal NPC markers require an accessible NPC nameplate; this addon does not enable NPC nameplates.", 12, -1020, "GameFontDisableSmall")
    note:SetWidth(580)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    Button(content, "Restore addon defaults", 12, -1100, 190, function()
        if ColorPickerFrame then ColorPickerFrame:Hide() end
        self:ResetSettings()
    end)
    Label(content, "To uninstall, switch the addon off here before removing its folder.", 12, -1142, "GameFontDisableSmall")

    panel:SetScript("OnShow", function() self:RefreshOptions() end)
    panel:SetScript("OnHide", function() if self.markerPicker then self.markerPicker:Hide() end end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Familiar Names")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
    self:RefreshOptions()
end

function Names:OpenOptions()
    Settings.OpenToCategory(self.settingsCategory:GetID())
end

function Names:UpdateMinimap()
    if not self.minimap then return end
    local angle = math.rad(self.db.minimapAngle)
    local radius = Minimap:GetWidth() / 2 + 8
    self.minimap:ClearAllPoints()
    self.minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    self.minimap:SetShown(self.db.showMinimap)
end

function Names:CreateMinimap()
    local button = CreateFrame("Button", "FamiliarNamesMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", -1, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            Names:PickMarker(self, function(index) Names:MarkTarget(index) end)
        else
            Names:OpenOptions()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local cursorX, cursorY = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            Names.db.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
            Names:UpdateMinimap()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    Tooltip(button, "Familiar Names\nLeft-click: settings\nRight-click: personal target marker\nDrag: reposition")
    self.minimap = button
    self:UpdateMinimap()
end
