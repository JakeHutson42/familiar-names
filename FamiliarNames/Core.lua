local _, Names = ...

Names.categoryLabels = {
    party = "Party members", battleNet = "Battle.net friends",
    friends = "Character friends", guild = "Guildmates", enemies = "Enemy players",
}
Names.markerLabels = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
Names.manualMarkers = {} -- Unit GUIDs, kept for this login only.
Names.guildMembers = {}

Names.defaults = {
    enabled = true, hideStrangers = false, showMinimap = true, minimapAngle = 220,
    fontSize = 16, outline = true, nameOffset = 0, showGuild = false, showTitles = false,
    markersEnabled = true, markersWhenHidden = true, markerSize = 24, markerOffset = 16,
    priority = { "party", "battleNet", "friends", "guild" },
    categories = {
        party = { show = true, color = { 0.35, 0.70, 1 }, marker = 0 },
        battleNet = { show = true, color = { 0.75, 0.50, 1 }, marker = 0 },
        friends = { show = true, color = { 1, 0.85, 0.25 }, marker = 0 },
        guild = { show = true, color = { 0.30, 1, 0.45 }, marker = 0 },
        enemies = { show = true, highlight = false, color = { 1, 0.25, 0.25 }, marker = 0 },
    },
}

local function AddDefaults(settings, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(settings[key]) ~= "table" then settings[key] = {} end
            AddDefaults(settings[key], value)
        elseif settings[key] == nil then
            settings[key] = value
        end
    end
    return settings
end

-- Never compare, index by, or concatenate restricted unit values.
function Names.Plain(value)
    if not issecretvalue or not issecretvalue(value) then return value end
end

function Names:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff79c9ffFamiliar Names:|r " .. message)
end

function Names:GetMembership(unit, guid)
    local account = C_BattleNet.GetAccountInfoByGUID(guid)
    return {
        party = unit and self.Plain(UnitInParty(unit)),
        battleNet = account and self.Plain(account.isFriend),
        friends = self.Plain(C_FriendList.IsFriend(guid)),
        guild = (unit and self.Plain(UnitIsInMyGuild(unit))) or self.guildMembers[guid],
    }
end

function Names:UpdateGuildMembers()
    wipe(self.guildMembers)
    for index = 1, GetNumGuildMembers() do
        local guid = self.Plain(select(17, GetGuildRosterInfo(index)))
        if guid then self.guildMembers[guid] = true end
    end
end

function Names:GetPlayerOwner(unit)
    local visited = {}
    local guid = self.Plain(UnitOwnerGUID(unit))
    while guid and guid ~= "" and not visited[guid] do
        if guid:match("^Player%-") then return guid, self.Plain(UnitTokenFromGUID(guid)) end
        visited[guid] = true
        local owner = self.Plain(UnitTokenFromGUID(guid))
        if not owner then return end
        guid = self.Plain(UnitOwnerGUID(owner))
    end
end

-- Pets, guardians, totems and companions follow their player's visibility rule.
-- Unknown player-owned units are hidden when strangers are hidden; ordinary NPCs
-- and their summons are never classified using their names or creature GUID type.
function Names:GetMinionRule(unit)
    if self.namesRestricted then return end
    local ownerGUID, owner = self:GetPlayerOwner(unit)
    local isMinion = ownerGUID or self.Plain(UnitIsMinion(unit)) or self.Plain(UnitIsBattlePetCompanion(unit))
    if not isMinion then return end
    local enemy = self.Plain(UnitCanAttack("player", owner or unit))
    local show, category
    if ownerGUID and ownerGUID == self.Plain(UnitGUID("player")) then
        show = true
    elseif ownerGUID then
        show, category = self:GetNameRule(self:GetMembership(owner, ownerGUID), enemy)
    else
        show = enemy and self.db.categories.enemies.show or (not enemy and not self.db.hideStrangers)
    end
    local filtered = enemy and self.enemyMinionsFiltered or (not enemy and self.friendlyMinionsFiltered)
    if show and not filtered then return end -- Preserve native pet visibility when no replacement is needed.
    if self.Plain(UnitIsBattlePetCompanion(unit)) then
        show = show and C_CVar.GetCVar("UnitNameNonCombatCreatureName") == "1"
    else
        local key = enemy and "UnitNameEnemyMinionName" or "UnitNameFriendlyMinionName"
        local original = self.db.originalCVars and self.db.originalCVars[key]
        show = show and (original or C_CVar.GetCVar(key)) ~= "0"
    end
    return show, category
end

-- A visible matching category wins; hiding one category must not hide another.
function Names:GetNameRule(membership, isEnemy)
    local firstMatch
    for _, key in ipairs(self.db.priority) do
        if membership[key] then
            firstMatch = firstMatch or key
            if self.db.categories[key].show then return true, key end
        end
    end
    if firstMatch then return false, firstMatch end
    if isEnemy then return self.db.categories.enemies.show, "enemies" end
    return not self.db.hideStrangers, nil
end

function Names:GetMarker(guid, category)
    local manual = self.manualMarkers[guid]
    if manual ~= nil then return manual end -- Zero explicitly clears an automatic marker.
    return category and self.db.categories[category].marker or 0
end

function Names:MarkTarget(index)
    local guid = self.Plain(UnitGUID("target"))
    if not guid then
        self:Print("Select a target whose identity is available first.")
        return
    end
    self.manualMarkers[guid] = index
    self:RefreshPlates()
    self:Print(index == 0 and "Personal marker cleared." or (self.markerLabels[index] .. " placed on your target, for you only."))
end

-- Only player and player-minion CVars are managed. Ordinary NPC settings stay native.
local playerCVars = {
    UnitNameFriendlyPlayerName = "0",
    UnitNameEnemyPlayerName = "0",
    nameplateShowFriendlyPlayers = "1",
    nameplateShowOnlyNameForFriendlyPlayerUnits = "1",
}

function Names:ApplyPlayerCVars(restore)
    if InCombatLockdown() then
        self.pendingCVars = true
        return
    end
    self.pendingCVars = nil
    local active = self.db.enabled and not self.namesRestricted and not restore
    self.active = self.db.enabled and not restore
    if active then
        local desired = {}
        for key, value in pairs(playerCVars) do desired[key] = value end
        self.friendlyMinionsFiltered = self.db.hideStrangers
        for _, key in ipairs(self.db.priority) do
            if not self.db.categories[key].show then self.friendlyMinionsFiltered = true end
        end
        self.enemyMinionsFiltered = not self.db.categories.enemies.show
        for _, side in ipairs({ "Friendly", "Enemy" }) do
            local filtered = side == "Friendly" and self.friendlyMinionsFiltered or (side == "Enemy" and self.enemyMinionsFiltered)
            if filtered then
                for _, kind in ipairs({ "Minion", "Pet", "Guardian", "Totem" }) do
                    desired["UnitName" .. side .. kind .. "Name"] = "0"
                end
            end
        end
        if self.friendlyMinionsFiltered then desired.nameplateShowFriendlyPlayerMinions = "1" end
        self.db.originalCVars = self.db.originalCVars or {}
        for key, value in pairs(self.db.originalCVars) do
            if desired[key] == nil then
                C_CVar.SetCVar(key, value)
                self.db.originalCVars[key] = nil
            end
        end
        -- Snapshot every related setting before writing: grouped minion settings
        -- can update their individual pet/guardian/totem values together.
        for key in pairs(desired) do
            local current = C_CVar.GetCVar(key)
            if current ~= nil and self.db.originalCVars[key] == nil then self.db.originalCVars[key] = current end
        end
        for key, value in pairs(desired) do
            if key == "UnitNameEnemyPlayerName" then
                local enemy = self.db.categories.enemies
                value = enemy.show and not enemy.highlight and "1" or "0"
            end
            local current = C_CVar.GetCVar(key)
            if current ~= nil then
                if current ~= value then C_CVar.SetCVar(key, value) end
            end
        end
    elseif self.db.originalCVars then
        for key, value in pairs(self.db.originalCVars) do C_CVar.SetCVar(key, value) end
        self.db.originalCVars = nil
    end
    if not active then self.friendlyMinionsFiltered, self.enemyMinionsFiltered = false, false end
end

function Names:UpdateContext()
    -- Instances may protect friendly plates or player identities. Keep native names
    -- there rather than disabling native text that the addon cannot replace.
    self.namesRestricted = IsInInstance()
    self:ApplyPlayerCVars()
    self:RefreshPlates()
    if self.RefreshOptions then self:RefreshOptions() end
end

function Names:SettingsChanged()
    self:ApplyPlayerCVars()
    self:RefreshPlates()
    self:UpdateMinimap()
    if self.RefreshOptions then self:RefreshOptions() end
end

function Names:ResetSettings()
    self:ApplyPlayerCVars(true)
    local originalCVars = self.db.originalCVars -- Retain the backup if combat delayed restoration.
    FamiliarNamesDB = AddDefaults({}, self.defaults)
    self.db = FamiliarNamesDB
    self.db.originalCVars = originalCVars
    self:SettingsChanged()
end

function Names:HandleCommand(message)
    local command, argument = message:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "mark" then
        local index = tonumber(argument)
        for number, label in ipairs(self.markerLabels) do
            if label:lower() == argument then index = number end
        end
        if index and index >= 0 and index <= 8 and index == math.floor(index) then
            self:MarkTarget(index)
        else
            self:Print("Use /names mark star (or circle, diamond, triangle, moon, square, cross, skull).")
        end
    elseif command == "clear" then
        self:MarkTarget(0)
    elseif command == "clearall" then
        wipe(self.manualMarkers)
        self:RefreshPlates()
        self:Print("All manual markers cleared; category markers apply again.")
    elseif command == "on" or command == "off" then
        self.db.enabled = command == "on"
        self:SettingsChanged()
        self:Print(self.db.enabled and "Enabled." or "Disabled; Blizzard player-name settings restored after combat.")
    elseif command == "minimap" then
        self.db.showMinimap = not self.db.showMinimap
        self:SettingsChanged()
    elseif command == "" then
        self:OpenOptions()
    else
        self:Print("/names | on | off | minimap | mark <icon or 0-8> | clear | clearall")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, argument)
    if event == "ADDON_LOADED" then
        if argument ~= "FamiliarNames" then return end
        FamiliarNamesDB = AddDefaults(FamiliarNamesDB or {}, Names.defaults)
        Names.db = FamiliarNamesDB
        SLASH_FAMILIARNAMES1 = "/names"
        SLASH_FAMILIARNAMES2 = "/familiarnames"
        SlashCmdList.FAMILIARNAMES = function(message) Names:HandleCommand(message) end
        for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT",
            "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
            "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE",
            "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
            "BN_CONNECTED", "BN_DISCONNECTED", "UNIT_NAME_UPDATE", "UNIT_FACTION", "RAID_TARGET_UPDATE",
            "UNIT_PET", "UNIT_FLAGS", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_GUILD_UPDATE" }) do
            events:RegisterEvent(name)
        end
    elseif event == "PLAYER_LOGIN" then
        Names:UpdateGuildMembers()
        C_GuildInfo.GuildRoster()
        Names:InstallNameHook()
        Names:CreateOptions()
        Names:CreateMinimap()
        Names:UpdateContext()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Names:UpdateContext()
    elseif event == "PLAYER_LOGOUT" then
        Names:ApplyPlayerCVars(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Names:SettingsChanged()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Names:RemovePlate(argument)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Names:RefreshPlates() -- A newly available owner can also change their pet's rule.
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        Names:UpdateGuildMembers()
        Names:RefreshPlates()
    else
        Names:RefreshPlates()
    end
end)
