local _, Names = ...
local plates = {}
local overlays = setmetatable({}, { __mode = "k" })
local hiddenFrames = setmetatable({}, { __mode = "k" })
local hookedFrames = setmetatable({}, { __mode = "k" })

local function ClearHitTest(overlay)
    local plate = overlay.plate
    if not plate:IsForbidden() and plate:CanChangeHitTestPoints() then
        plate:ClearAllHitTestPoints()
        overlay.hitTestCleared = true
    end
end

local function RestorePlate(overlay)
    local frame = overlay.hiddenFrame
    if frame then
        hiddenFrames[frame] = nil
        overlay.hiddenFrame = nil
        if not frame:IsForbidden() then frame:SetAlpha(overlay.frameAlpha) end
    end
    local plate = overlay.plate
    if overlay.hitTestCleared and not plate:IsForbidden() and plate:CanChangeHitTestPoints() then
        local currentFrame = plate.UnitFrame
        if currentFrame and not currentFrame:IsForbidden() then
            currentFrame:UpdateHitTestArea(NamePlateSetupOptions)
            overlay.hitTestCleared = nil
        end
    end
end

local function HidePlate(overlay, frame)
    if not hookedFrames[frame] then
        hooksecurefunc(frame, "SetAlpha", function(_, alpha)
            local current = hiddenFrames[frame]
            if current and not current.settingAlpha then
                current.frameAlpha = Names.Plain(alpha) or current.frameAlpha
                current.settingAlpha = true
                frame:SetAlpha(0)
                current.settingAlpha = nil
            end
        end)
        hooksecurefunc(frame, "UpdateHitTestArea", function()
            local current = hiddenFrames[frame]
            if current then ClearHitTest(current) end
        end)
        hookedFrames[frame] = true
    end
    overlay.hiddenFrame, overlay.frameAlpha = frame, Names.Plain(frame:GetAlpha()) or 1
    hiddenFrames[frame] = overlay
    overlay.settingAlpha = true
    frame:SetAlpha(0) -- Hide the entire native plate, including bars, auras and level badges.
    overlay.settingAlpha = nil
    ClearHitTest(overlay)
end

local function RestoreName(overlay)
    if overlay.nativeName then
        if not overlay.nativeName:IsForbidden() then overlay.nativeName:SetAlpha(overlay.nativeAlpha) end
        overlay.nativeName = nil
    end
end

local function CreateOverlay(plate)
    local overlay = CreateFrame("Frame", nil, plate)
    overlay.plate = plate
    overlay:SetAllPoints(plate)
    overlay:EnableMouse(false)
    overlay.name = overlay:CreateFontString(nil, "OVERLAY")
    overlay.guild = overlay:CreateFontString(nil, "OVERLAY")
    overlay.marker = overlay:CreateTexture(nil, "OVERLAY")
    overlay.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    overlay.sharedMarker = overlay:CreateTexture(nil, "OVERLAY")
    overlay.sharedMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    overlay:Hide()
    overlays[plate] = overlay
    return overlay
end

function Names:RemovePlate(unit)
    local overlay = plates[unit]
    if overlay then
        RestoreName(overlay)
        RestorePlate(overlay)
        overlay:Hide()
        plates[unit] = nil
    end
end

function Names:UpdatePlate(unit)
    if not self.db or not self.Plain(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    self:RemovePlate(unit)
    if not self.active then return end

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    local unitFrame = plate.UnitFrame
    if not unitFrame or unitFrame:IsForbidden() then return end
    local guid = self.Plain(UnitGUID(unit))
    if not guid or self.Plain(UnitIsUnit("player", unit)) then return end

    local isPlayer = self.Plain(UnitIsPlayer(unit))
    if isPlayer == nil then return end
    if isPlayer and self.namesRestricted then return end
    local showName, category, hidePlate = false, nil, false
    local manageName = isPlayer
    if isPlayer and not self.namesRestricted then
        local name = self.Plain(UnitName(unit))
        if not name then return end
        showName, category = self:GetNameRule(self:GetMembership(unit, guid), self.Plain(UnitCanAttack("player", unit)))
        hidePlate = self:ShouldHidePlate(showName, category)
    elseif not isPlayer then
        showName, category, hidePlate = self:GetMinionRule(unit)
        manageName = showName ~= nil
    end

    local marker = self:GetMarker(guid, isPlayer and category or nil)
    local showMarker = self.db.markersEnabled and marker > 0
        and (not manageName or showName or self.db.markersWhenHidden)
    if not manageName and not showMarker then return end

    local overlay = overlays[plate] or CreateOverlay(plate)
    -- A recycled plate may now have a different Blizzard unit frame.
    RestoreName(overlay)
    RestorePlate(overlay)
    overlay.name:Hide()
    overlay.guild:Hide()
    overlay.marker:Hide()
    overlay.sharedMarker:Hide()
    plates[unit] = overlay

    local nativeName = unitFrame.name
    if not nativeName or nativeName:IsForbidden() then return end
    if hidePlate then
        HidePlate(overlay, unitFrame)
        -- Keep shared raid markers visible without changing the group's assignment.
        local shared = self.Plain(unitFrame:GetRaidTargetIndex())
        if shared and shared > 0 then
            SetRaidTargetIconTexture(overlay.sharedMarker, shared)
            overlay.sharedMarker:SetSize(24, 24)
            overlay.sharedMarker:ClearAllPoints()
            overlay.sharedMarker:SetPoint("BOTTOM", nativeName, "TOP", 0, 10 + self.db.nameOffset)
            overlay.sharedMarker:Show()
        end
    end
    if manageName then
        overlay.nativeName, overlay.nativeAlpha = nativeName, self.Plain(nativeName:GetAlpha()) or 1
        nativeName:SetAlpha(0)
        if showName then
            local text = self.Plain(UnitName(unit))
            if isPlayer and self.db.showTitles then text = self.Plain(UnitPVPName(unit)) or text end
            if not text then RestoreName(overlay); RestorePlate(overlay); overlay:Hide(); return end
            local font = STANDARD_TEXT_FONT
            local flags = self.db.outline and "OUTLINE" or ""
            overlay.name:SetFont(font, self.db.fontSize, flags)
            overlay.name:SetText(text)
            overlay.name:ClearAllPoints()
            overlay.name:SetPoint("BOTTOM", nativeName, "BOTTOM", 0, self.db.nameOffset)
            local rule = category and self.db.categories[category]
            if rule and (category ~= "enemies" or rule.highlight) then
                overlay.name:SetTextColor(unpack(rule.color))
            else
                -- Native nameplate colour preserves Blizzard/class colours.
                local r, g, b = nativeName:GetTextColor()
                overlay.name:SetTextColor(self.Plain(r) or 1, self.Plain(g) or 1, self.Plain(b) or 1)
            end
            overlay.name:Show()
            local guild = isPlayer and self.db.showGuild and self.Plain(GetGuildInfo(unit))
            if guild then
                overlay.guild:SetFont(font, math.max(10, self.db.fontSize - 3), flags)
                overlay.guild:SetText("<" .. guild .. ">")
                overlay.guild:SetTextColor(0.75, 0.75, 0.75)
                overlay.guild:ClearAllPoints()
                overlay.guild:SetPoint("TOP", overlay.name, "BOTTOM", 0, -2)
                overlay.guild:Show()
            end
        end
    end

    if showMarker then
        SetRaidTargetIconTexture(overlay.marker, marker)
        overlay.marker:SetSize(self.db.markerSize, self.db.markerSize)
        overlay.marker:ClearAllPoints()
        -- A side offset keeps personal icons separate from shared raid icons.
        overlay.marker:SetPoint("BOTTOM", nativeName, "TOP", self.db.markerSize, self.db.markerOffset + self.db.nameOffset)
        overlay.marker:Show()
    end
    overlay:Show()
end

function Names:RefreshPlates()
    if not self.db then return end
    for unit in pairs(plates) do self:RemovePlate(unit) end
    -- Click-area changes can be protected during combat. Restore them as soon as
    -- Blizzard permits it, using the current unit frame rather than stale anchors.
    for _, overlay in pairs(overlays) do
        if overlay.hitTestCleared and not overlay.hiddenFrame then RestorePlate(overlay) end
    end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if not plate:IsForbidden() then self:UpdatePlate(self.Plain(plate:GetUnit())) end
    end
end

function Names:InstallNameHook()
    -- Observe Blizzard's updates without replacing its functions.
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if frame:IsForbidden() then return end
        local unit = Names.Plain(frame.unit)
        if unit and type(unit) == "string" and unit:match("^nameplate%d+$") then Names:UpdatePlate(unit) end
    end)
end
