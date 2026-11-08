local frames, units, visiblePlates, cvarWrites, messages = {}, {}, {}, {}, {}
local combat, inInstance = false, false
local SECRET = {}
local friendGuids, battleNetGuids = {}, {}
local guildRoster = { "Player-guild-offscreen" }
function issecretvalue(value) return rawequal(value, SECRET) end
local function AssertPlain(value) assert(not issecretvalue(value), "Restricted value escaped its guard") end

local Widget = {}
Widget.__index = Widget
local function NewWidget(parent)
    local widget = setmetatable({ parent = parent, children = {}, scripts = {}, shown = true,
        alpha = 1, width = 160, height = 40, color = { 1, 1, 1, 1 } }, Widget)
    if parent then table.insert(parent.children, widget) end
    return widget
end
function Widget:IsForbidden() return self.forbidden or false end
function Widget:SetScript(event, callback) self.scripts[event] = callback end
function Widget:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function Widget:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Widget:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Widget:SetShown(value) if value then self:Show() else self:Hide() end end
function Widget:IsShown() return self.shown end
function Widget:SetAlpha(value) AssertPlain(value); self.alpha = value end
function Widget:GetAlpha() return self.alpha end
function Widget:SetText(text) AssertPlain(text); self.textValue = text end
function Widget:SetTextColor(...) self.color = { ... } end
function Widget:GetTextColor() return unpack(self.color) end
function Widget:SetFont(...) self.font = { ... } end
function Widget:SetPoint(...) self.point = { ... } end
function Widget:ClearAllPoints() self.point = nil end
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetWidth(width) self.width = width end
function Widget:SetHeight(height) self.height = height end
function Widget:GetWidth() return self.width end
function Widget:GetCenter() return 100, 100 end
function Widget:GetEffectiveScale() return 1 end
function Widget:GetFrameLevel() return 1 end
function Widget:GetUnit() return self.unitToken end
function Widget:SetChecked(value) self.checked = value end
function Widget:GetChecked() return self.checked end
function Widget:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Widget:SetTexture(value) self.texture = value end
function Widget:GetFontString() return self.Text end
function Widget:CreateFontString() return NewWidget(self) end
function Widget:CreateTexture() return NewWidget(self) end
function Widget:SetScrollChild(child) self.scrollChild = child end
function Widget:Disable() self.disabled = true end
for _, method in ipairs({ "SetAllPoints", "EnableMouse", "SetFrameStrata", "SetFrameLevel", "SetClampedToScreen",
    "SetBackdrop", "SetColorTexture", "SetJustifyH", "SetWordWrap", "RegisterForClicks", "RegisterForDrag",
    "SetHighlightTexture", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag" }) do
    Widget[method] = function() end
end
function CreateFrame(kind, name, parent, template)
    local widget = NewWidget(parent)
    widget.template, widget.frameName = template, name
    if template == "UICheckButtonTemplate" or template == "UIPanelButtonTemplate" then widget.Text = NewWidget(widget) end
    if template == "UISliderTemplateWithLabels" then
        widget.Low, widget.High, widget.Text = NewWidget(widget), NewWidget(widget), NewWidget(widget)
    end
    if name then _G[name] = widget end
    table.insert(frames, widget)
    return widget
end

UIParent = NewWidget()
Minimap = NewWidget(UIParent)
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
GameTooltip = { SetOwner = function() end, SetText = function() end, Hide = function() end }
SlashCmdList = {}
UISpecialFrames = {}
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { GetID = function() return 42 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) assert(id == 42); Settings.opened = true end,
}
ColorPickerFrame = {
    SetupColorPickerAndShow = function(self, info) self.info = info end,
    GetColorRGB = function() return 0.1, 0.2, 0.3 end,
    Hide = function() end,
}
function InCombatLockdown() return combat end
function IsInInstance() return inInstance, inInstance and "party" or "none" end
function GetCursorPosition() return 100, 180 end
math.atan2 = math.atan2 or function(y, x) return math.atan(y / x) end
function wipe(tbl) for key in pairs(tbl) do tbl[key] = nil end end
function SetRaidTarget() error("Shared raid marker API must never be called") end
function SetRaidTargetIconTexture(texture, index) texture.icon = index end
function SendAddonMessage() error("No addon messaging allowed") end
local cvars = { UnitNameFriendlyPlayerName = "1", UnitNameEnemyPlayerName = "1",
    nameplateShowFriendlyPlayers = "0", nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
    UnitNameNPC = "1", nameplateShowFriendlyNpcs = "0", UnitNameNonCombatCreatureName = "1",
    UnitNameFriendlyMinionName = "1", UnitNameFriendlyPetName = "1",
    UnitNameFriendlyGuardianName = "0", UnitNameFriendlyTotemName = "1",
    UnitNameEnemyMinionName = "1", UnitNameEnemyPetName = "1",
    UnitNameEnemyGuardianName = "0", UnitNameEnemyTotemName = "1", nameplateShowFriendlyPlayerMinions = "0" }
C_CVar = {
    GetCVar = function(key) return cvars[key] end,
    SetCVar = function(key, value)
        assert(not combat, "CVar write during combat")
        assert(not key:lower():find("npc"), "NPC settings changed")
        table.insert(cvarWrites, key)
        cvars[key] = value
    end,
}
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return visiblePlates[unit] end,
    GetNamePlates = function()
        local list = {}
        for _, plate in pairs(visiblePlates) do table.insert(list, plate) end
        return list
    end,
}
C_FriendList = { IsFriend = function(guid)
    AssertPlain(guid)
    if friendGuids[guid] then return true end
    for _, unit in pairs(units) do if unit.guid == guid then return unit.friend end end
end }
C_BattleNet = { GetAccountInfoByGUID = function(guid)
    AssertPlain(guid)
    if battleNetGuids[guid] then return { isFriend = true } end
    for _, unit in pairs(units) do
        if unit.guid == guid and unit.battleNet then return { isFriend = true } end
    end
end }
C_GuildInfo = { GuildRoster = function() end }
function GetNumGuildMembers() return #guildRoster end
function GetGuildRosterInfo(index)
    local entry = { [17] = guildRoster[index] }
    return unpack(entry, 1, 17)
end
units.player = { guid = "Player-self", isPlayer = true, name = "You" }
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitOwnerGUID(unit) return units[unit] and units[unit].ownerGUID end
function UnitTokenFromGUID(guid)
    AssertPlain(guid)
    for token, unit in pairs(units) do if unit.guid == guid then return token end end
end
function UnitIsMinion(unit) return units[unit] and units[unit].minion or false end
function UnitIsBattlePetCompanion(unit) return units[unit] and units[unit].companion or false end
function UnitIsPlayer(unit) return units[unit].isPlayer end
function UnitIsUnit(first, second) return units[first] and units[second] and units[first].guid == units[second].guid or false end
function UnitInParty(unit) return units[unit].party end
function UnitIsInMyGuild(unit) return units[unit].guild end
function UnitCanAttack(_, unit) return units[unit].enemy end
function UnitName(unit) return units[unit].name end
function UnitPVPName(unit) return "Champion " .. units[unit].name end
function GetGuildInfo(unit) return units[unit].guild and "Test Guild" or nil end
function CompactUnitFrame_UpdateName(frame)
    frame.name:SetText(units[frame.unit].name)
    frame.name:SetTextColor(0.8, 0.2, 0.1)
    frame.name:Show()
end
function hooksecurefunc(name, callback)
    local original = _G[name]
    _G[name] = function(...) original(...); callback(...) end
end

local Names = {}
for _, file in ipairs({ "Core.lua", "Nameplates.lua", "Options.lua" }) do
    assert(loadfile("FamiliarNames/" .. file))("FamiliarNames", Names)
end
local events = frames[1]
local function Event(name, ...) events.scripts.OnEvent(events, name, ...) end
local passed = 0
local function Test(name, action)
    action()
    passed = passed + 1
    print("PASS " .. name)
end
local function AddUnit(token, properties, plate)
    properties.guid = properties.guid or ("Player-" .. token)
    properties.name = properties.name or "Testplayer"
    if properties.isPlayer == nil then properties.isPlayer = true end
    units[token] = properties
    plate = plate or NewWidget(UIParent)
    plate.unitToken = token
    plate.UnitFrame = NewWidget(plate)
    plate.UnitFrame.unit = token
    plate.UnitFrame.name = NewWidget(plate.UnitFrame)
    plate.UnitFrame.name.color = { 0.8, 0.2, 0.1 }
    visiblePlates[token] = plate
    return plate
end
local function Overlay(plate)
    for _, child in ipairs(plate.children) do if child.marker then return child end end
end

Test("addon startup, native settings panel and minimap", function()
    Event("ADDON_LOADED", "SomethingElse")
    assert(not Names.db)
    Event("ADDON_LOADED", "FamiliarNames")
    Event("PLAYER_LOGIN")
    assert(Names.db.enabled and Names.minimap.shown and Names.settingsCategory)
    assert(cvars.UnitNameFriendlyPlayerName == "0" and cvars.UnitNameEnemyPlayerName == "1")
    assert(cvars.nameplateShowFriendlyPlayers == "1")
    SlashCmdList.FAMILIARNAMES("")
    assert(Settings.opened)
end)
Test("all social categories have separate rules", function()
    for _, key in ipairs(Names.db.priority) do
        local show, category = Names:GetNameRule({ [key] = true }, false)
        assert(show and category == key)
    end
end)
Test("overlap chooses highest visible category", function()
    local show, category = Names:GetNameRule({ party = true, guild = true }, false)
    assert(show and category == "party")
    Names.db.categories.party.show = false
    show, category = Names:GetNameRule({ party = true, guild = true }, false)
    assert(show and category == "guild")
    assert(not Names:GetNameRule({ party = true }, false))
    Names.db.categories.party.show = true
end)
Test("hiding strangers leaves enemies visible by default", function()
    Names.db.hideStrangers = true
    assert(not Names:GetNameRule({}, false))
    local show, category = Names:GetNameRule({}, true)
    assert(show and category == "enemies")
    Names.db.categories.enemies.show = false
    assert(not Names:GetNameRule({}, true))
    Names.db.categories.enemies.show = true
end)
local friendPlate = AddUnit("nameplate1", { battleNet = true, guild = true })
Test("Battle.net detection and custom player name", function()
    Names:RefreshPlates()
    local overlay = Overlay(friendPlate)
    assert(overlay.name.shown and friendPlate.UnitFrame.name.alpha == 0)
    assert(overlay.name.color[1] == Names.db.categories.battleNet.color[1])
    Names.db.showTitles, Names.db.showGuild = true, true
    Names:RefreshPlates()
    assert(overlay.name.textValue == "Champion Testplayer" and overlay.guild.textValue == "<Test Guild>")
end)
local strangerPlate = AddUnit("nameplate2", {})
Test("hidden strangers stay hidden after native name refresh", function()
    Names:UpdatePlate("nameplate2")
    assert(not Overlay(strangerPlate).name.shown)
    CompactUnitFrame_UpdateName(strangerPlate.UnitFrame)
    assert(strangerPlate.UnitFrame.name.alpha == 0 and not Overlay(strangerPlate).name.shown)
end)
local enemyPlate = AddUnit("nameplate3", { enemy = true })
Test("enemy colour defaults to Blizzard and can be highlighted or hidden", function()
    Names:UpdatePlate("nameplate3")
    assert(Overlay(enemyPlate).name.color[1] == 0.8)
    Names.db.categories.enemies.highlight = true
    Names:SettingsChanged()
    assert(Overlay(enemyPlate).name.color[1] == 1 and cvars.UnitNameEnemyPlayerName == "0")
    Names.db.categories.enemies.show = false
    Names:SettingsChanged()
    assert(not Overlay(enemyPlate).name.shown)
    Names.db.categories.enemies.show, Names.db.categories.enemies.highlight = true, false
end)
local npcPlate = AddUnit("nameplate4", { isPlayer = false, guid = "Creature-123" })
Test("personal NPC marker leaves its native name untouched", function()
    units.target = units.nameplate4
    Names:HandleCommand("mark skull")
    assert(Overlay(npcPlate).marker.icon == 8 and Overlay(npcPlate).marker.shown)
    assert(npcPlate.UnitFrame.name.alpha == 1 and npcPlate.UnitFrame.name.shown)
    Names:HandleCommand("clear")
    assert(not Overlay(npcPlate).shown)
end)
Test("manual marker overrides automatic marker and clearall restores automatic", function()
    Names.db.categories.battleNet.marker = 2
    units.target = units.nameplate1
    Names:MarkTarget(8)
    assert(Overlay(friendPlate).marker.icon == 8)
    Names:MarkTarget(0)
    assert(not Overlay(friendPlate).marker.shown)
    Names:HandleCommand("clearall")
    assert(Overlay(friendPlate).marker.icon == 2 and Overlay(friendPlate).marker.shown)
end)
Test("markers can remain visible independently of hidden names", function()
    units.target = units.nameplate2
    Names:MarkTarget(1)
    assert(Overlay(strangerPlate).marker.shown and not Overlay(strangerPlate).name.shown)
    Names.db.markersWhenHidden = false
    Names:RefreshPlates()
    assert(not Overlay(strangerPlate).marker.shown)
    Names.db.markersWhenHidden = true
end)
Test("restricted values and forbidden frames are skipped", function()
    local secretPlate = AddUnit("nameplate5", { guid = SECRET })
    Names:UpdatePlate("nameplate5")
    assert(not Overlay(secretPlate) and secretPlate.UnitFrame.name.alpha == 1)
    local forbidden = AddUnit("nameplate6", {})
    forbidden.forbidden = true
    Names:RefreshPlates()
    assert(not Overlay(forbidden))
    Names:UpdatePlate(SECRET)
end)
Test("removal and player-to-NPC plate reuse restore native names", function()
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(friendPlate.UnitFrame.name.alpha == 1 and not Overlay(friendPlate).shown)
    visiblePlates.nameplate1 = nil
    local reused = AddUnit("nameplate7", { isPlayer = false, guid = "Creature-789" }, friendPlate)
    Names:RefreshPlates()
    assert(reused.UnitFrame.name.alpha == 1 and not Overlay(reused).shown)
end)
Test("instance fallback restores native player settings without losing NPC markers", function()
    units.target = units.nameplate4
    Names:MarkTarget(1)
    inInstance = true
    Event("PLAYER_ENTERING_WORLD")
    assert(Names.namesRestricted and cvars.UnitNameFriendlyPlayerName == "1")
    assert(strangerPlate.UnitFrame.name.alpha == 1 and not Overlay(strangerPlate).shown)
    assert(Overlay(npcPlate).marker.shown)
    inInstance = false
    Event("PLAYER_ENTERING_WORLD")
    assert(cvars.UnitNameFriendlyPlayerName == "0")
end)
Test("disable waits for combat before restoring managed CVars", function()
    combat = true
    local before = #cvarWrites
    Names:HandleCommand("off")
    assert(#cvarWrites == before and Names.pendingCVars and Names.active)
    combat = false
    Event("PLAYER_REGEN_ENABLED")
    assert(not Names.active and not Names.pendingCVars)
    assert(cvars.UnitNameFriendlyPlayerName == "1" and cvars.nameplateShowFriendlyPlayers == "0")
    assert(cvars.UnitNameNPC == "1" and cvars.nameplateShowFriendlyNpcs == "0")
    assert(not Overlay(strangerPlate).shown and strangerPlate.UnitFrame.name.alpha == 1)
end)
Test("colour picker cancel, category controls, sliders and marker picker", function()
    Names:HandleCommand("on")
    Names:PickColor("friends")
    local original = Names.db.categories.friends.color[1]
    ColorPickerFrame.info.swatchFunc()
    assert(Names.db.categories.friends.color[1] == 0.1)
    ColorPickerFrame.info.cancelFunc()
    assert(Names.db.categories.friends.color[1] == original)
    FamiliarNamesSlider_fontSize:SetValue(21)
    assert(Names.db.fontSize == 21)
    Names:PickMarker(Names.minimap, function(index) Names:MarkTarget(index) end)
    assert(Names.markerPicker.shown)
    Names.markerPicker.children[9].scripts.OnClick()
    assert(Names.manualMarkers[units.target.guid] == 8 and not Names.markerPicker.shown)
    Names:HandleCommand("minimap")
    assert(not Names.minimap.shown)
end)
Test("priority arrows and visibility controls stay bound to their displayed category", function()
    local content
    -- Locate controls by their anchored position, not creation order.
    for _, frame in ipairs(frames) do
        if frame.template == "UIPanelScrollFrameTemplate" then content = frame.scrollChild end
    end
    assert(content)
    local up, show
    for _, child in ipairs(content.children) do
        if child.point and child.point[2] == 526 and child.point[3] == -145 then up = child end
        if child.point and child.point[2] == 210 and child.point[3] == -106 then show = child end
    end
    local before = Names.db.priority[2]
    up.scripts.OnClick(up)
    assert(Names.db.priority[1] == before)
    show.checked = false
    show.scripts.OnClick(show)
    assert(not Names.db.categories[before].show)
end)
Test("reset during combat retains the original CVar backup", function()
    combat = true
    local original = Names.db.originalCVars
    Names:ResetSettings()
    assert(Names.db.originalCVars == original)
    combat = false
    Event("PLAYER_REGEN_ENABLED")
    Names:HandleCommand("off")
    assert(cvars.UnitNameFriendlyPlayerName == "1" and cvars.nameplateShowFriendlyPlayers == "0")
    Names:HandleCommand("on")
end)
Test("pets, guardians, totems, summons and companions follow their owner's visibility", function()
    Names:ResetSettings()
    Names.db.hideStrangers = true
    Names:SettingsChanged()
    units.party1 = { guid = "Player-party", party = true, isPlayer = true }
    friendGuids["Player-friend-offscreen"] = true
    battleNetGuids["Player-bnet-offscreen"] = true
    local owners = {
        { guid = "Player-stranger", show = false },
        { guid = "Player-self", show = true },
        { guid = "Player-party", show = true },
        { guid = "Player-friend-offscreen", show = true },
        { guid = "Player-bnet-offscreen", show = true },
        { guid = "Player-guild-offscreen", show = true },
    }
    local number = 20
    for _, kind in ipairs({ "pet", "guardian", "totem", "summon", "companion", "controlled" }) do
        for _, owner in ipairs(owners) do
            local token = "nameplate" .. number
            number = number + 1
            local plate = AddUnit(token, { guid = "Creature-" .. number, isPlayer = false,
                minion = kind ~= "companion" and kind ~= "controlled", companion = kind == "companion",
                ownerGUID = owner.guid, name = "Test " .. kind })
            Names:UpdatePlate(token)
            assert(plate.UnitFrame.name.alpha == 0, "Native name was not managed: " .. kind)
            assert(Overlay(plate).name.shown == owner.show, "Wrong visibility for " .. kind .. "/" .. owner.guid)
            assert(not Overlay(plate).guild.shown, "Pet acquired its owner's guild subtitle")
        end
    end
    assert(cvars.UnitNameFriendlyMinionName == "0" and cvars.UnitNameFriendlyPetName == "0")
    assert(cvars.UnitNameFriendlyGuardianName == "0" and cvars.UnitNameFriendlyTotemName == "0")
    assert(cvars.nameplateShowFriendlyPlayerMinions == "1")
    assert(cvars.UnitNameNPC == "1" and cvars.UnitNameNonCombatCreatureName == "1")
end)
Test("enemy pets remain visible by default, then follow the enemy visibility switch", function()
    local plate = AddUnit("nameplate80", { guid = "Pet-enemy", isPlayer = false, minion = true,
        ownerGUID = "Player-enemy-offscreen", enemy = true })
    Names:UpdatePlate("nameplate80")
    assert(plate.UnitFrame.name.alpha == 1 and not Overlay(plate))
    Names.db.categories.enemies.show = false
    Names:SettingsChanged()
    assert(plate.UnitFrame.name.alpha == 0 and not Overlay(plate).name.shown)
    assert(cvars.UnitNameEnemyMinionName == "0" and cvars.UnitNameEnemyPetName == "0")
    assert(cvars.UnitNameEnemyTotemName == "0")
    Names.db.categories.enemies.show = true
    Names:SettingsChanged()
    assert(plate.UnitFrame.name.alpha == 1 and not Overlay(plate).shown)
    assert(cvars.UnitNameEnemyMinionName == "1" and cvars.UnitNameEnemyGuardianName == "0")
end)
Test("nested summons and ownership cycles terminate and hide strangers", function()
    units.guardian = { guid = "Creature-parent", ownerGUID = "Player-stranger", isPlayer = false }
    local nested = AddUnit("nameplate81", { guid = "Creature-child", isPlayer = false, ownerGUID = "Creature-parent" })
    Names:UpdatePlate("nameplate81")
    assert(not Overlay(nested).name.shown)
    units.cycleA = { guid = "Creature-cycle-a", ownerGUID = "Creature-cycle-b", isPlayer = false }
    units.cycleB = { guid = "Creature-cycle-b", ownerGUID = "Creature-cycle-a", isPlayer = false }
    local cyclic = AddUnit("nameplate82", { guid = "Creature-cycle-start", isPlayer = false, minion = true, ownerGUID = "Creature-cycle-a" })
    Names:UpdatePlate("nameplate82")
    assert(not Overlay(cyclic).name.shown)
end)
Test("unknown or secret pet ownership does not reveal strangers", function()
    for index, owner in ipairs({ false, SECRET }) do
        local token = "nameplate" .. (82 + index)
        local plate = AddUnit(token, { guid = "Pet-unknown-" .. index, isPlayer = false, minion = true, ownerGUID = owner or nil })
        Names:UpdatePlate(token)
        assert(plate.UnitFrame.name.alpha == 0 and not Overlay(plate).name.shown)
        CompactUnitFrame_UpdateName(plate.UnitFrame)
        assert(plate.UnitFrame.name.alpha == 0 and not Overlay(plate).name.shown)
    end
end)
Test("NPC-owned summons and wild critters remain completely native", function()
    units.npcOwner = { guid = "Creature-npc-owner", isPlayer = false }
    for index, owner in ipairs({ "Creature-npc-owner", "" }) do
        local token = "nameplate" .. (84 + index)
        local plate = AddUnit(token, { guid = "Creature-native-" .. index, isPlayer = false, ownerGUID = owner })
        Names:UpdatePlate(token)
        assert(plate.UnitFrame.name.alpha == 1 and not Overlay(plate))
    end
end)
Test("a newly identifiable owner and guild changes refresh existing pets", function()
    local plate = AddUnit("nameplate87", { guid = "Pet-late-owner", isPlayer = false, minion = true, ownerGUID = "Player-late-owner" })
    Names:UpdatePlate("nameplate87")
    assert(not Overlay(plate).name.shown)
    AddUnit("nameplate88", { guid = "Player-late-owner", guild = true })
    Event("NAME_PLATE_UNIT_ADDED", "nameplate88")
    assert(Overlay(plate).name.shown)
    units.nameplate88.guild = false
    table.insert(guildRoster, "Player-late-owner")
    Event("GUILD_ROSTER_UPDATE")
    assert(Overlay(plate).name.shown)
    table.remove(guildRoster)
    Event("GUILD_ROSTER_UPDATE")
    assert(not Overlay(plate).name.shown)
end)
Test("hidden owner categories and native companion visibility are respected", function()
    local pet = AddUnit("nameplate89", { guid = "Pet-guild", isPlayer = false, minion = true, ownerGUID = "Player-guild-offscreen" })
    Names.db.categories.guild.show = false
    Names:SettingsChanged()
    assert(not Overlay(pet).name.shown)
    Names.db.categories.guild.show = true
    cvars.UnitNameNonCombatCreatureName = "0"
    local companion = AddUnit("nameplate90", { guid = "Creature-companion", isPlayer = false, companion = true, ownerGUID = "Player-guild-offscreen" })
    Names:SettingsChanged()
    assert(not Overlay(companion).name.shown)
    cvars.UnitNameNonCombatCreatureName = "1"
end)
Test("turning filtering off restores all pet settings and native names", function()
    Names.db.hideStrangers = false
    Names:SettingsChanged()
    assert(cvars.UnitNameFriendlyMinionName == "1" and cvars.UnitNameFriendlyPetName == "1")
    assert(cvars.UnitNameFriendlyGuardianName == "0" and cvars.UnitNameFriendlyTotemName == "1")
    assert(cvars.nameplateShowFriendlyPlayerMinions == "0")
    assert(visiblePlates.nameplate83.UnitFrame.name.alpha == 1)
    assert(not Overlay(visiblePlates.nameplate83).shown)
end)
Test("hidden minion markers obey the same visibility option as player markers", function()
    Names.db.hideStrangers = true
    Names.db.markersWhenHidden = false
    Names:SettingsChanged()
    units.target = units.nameplate83
    Names:MarkTarget(8)
    assert(not Overlay(visiblePlates.nameplate83).marker.shown)
    Names.db.markersWhenHidden = true
    Names:RefreshPlates()
    assert(Overlay(visiblePlates.nameplate83).marker.shown)
end)
Test("reset and logout restore the original native settings", function()
    Names:ResetSettings()
    assert(not Names.db.hideStrangers and Names.db.fontSize == 16 and Names.db.showMinimap)
    assert(Names.db.categories.enemies.show and not Names.db.categories.enemies.highlight)
    Event("PLAYER_LOGOUT")
    assert(cvars.UnitNameFriendlyPlayerName == "1" and cvars.nameplateShowFriendlyPlayers == "0")
    assert(not Names.db.originalCVars)
end)
print(string.format("%d tests passed (%s)", passed, _VERSION))
