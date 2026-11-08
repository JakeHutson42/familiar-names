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
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:SetAlpha(value) AssertPlain(value); self.alpha = value end
function Widget:GetAlpha() return self.alpha end
function Widget:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
function Widget:CanChangeHitTestPoints()
    if self.hitTestAllowed ~= nil then return self.hitTestAllowed end
    return not combat
end
function Widget:ClearAllHitTestPoints()
    assert(self:CanChangeHitTestPoints(), "Protected click area was changed")
    self.clickable = false
end
function Widget:UpdateHitTestArea()
    assert(self.plate:CanChangeHitTestPoints(), "Protected click area was restored")
    self.plate.clickable = true
end
function Widget:GetRaidTargetIndex() return units[self.unit].raidMarker end
function Widget:SetText(text) AssertPlain(text); self.textValue = text end
function Widget:SetTextColor(...) self.color = { ... } end
function Widget:GetTextColor() return unpack(self.color) end
function Widget:GetStringWidth() return #(self.textValue or "") * 8 end
function Widget:SetBlendMode(value) self.blendMode = value end
function Widget:SetVertexColor(...) self.vertexColor = { ... } end
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
NamePlateSetupOptions = {}
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
function hooksecurefunc(target, name, callback)
    if type(target) == "string" then callback, name, target = name, target, _G end
    local original = target[name]
    assert(type(original) == "function", "Hooked API is unavailable")
    target[name] = function(...) original(...); callback(...) end
end

local Names = {}
for _, file in ipairs({ "Core.lua", "Effects.lua", "Nameplates.lua", "Options.lua" }) do
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
    plate.clickable = true
    plate.UnitFrame = NewWidget(plate)
    plate.UnitFrame.unit = token
    plate.UnitFrame.plate = plate
    plate.UnitFrame.name = NewWidget(plate.UnitFrame)
    plate.UnitFrame.healthBar = NewWidget(plate.UnitFrame)
    plate.UnitFrame.castBar = NewWidget(plate.UnitFrame)
    plate.UnitFrame.levelBadge = NewWidget(plate.UnitFrame)
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
        if child.point and child.point[2] == 196 and child.point[3] == -106 then show = child end
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
            assert(plate.UnitFrame.alpha == (owner.guid == "Player-self" and 1 or 0), "Owner's plate rule was not inherited")
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
    Names.db.hideStrangerPlates = false
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
Test("hidden strangers' minions lose the entire plate, including health, cast and level", function()
    Names:ResetSettings()
    Names.db.hideStrangers = true
    Names:SettingsChanged()
    local plate = AddUnit("nameplate100", { guid = "Pet-photo-regression", isPlayer = false,
        minion = true, ownerGUID = "Player-stranger", name = "Stranger's Imp" })
    Names:UpdatePlate("nameplate100")
    assert(plate.alpha == 1, "The root must stay available for addon labels and markers")
    assert(plate.UnitFrame.healthBar:GetEffectiveAlpha() == 0)
    assert(plate.UnitFrame.castBar:GetEffectiveAlpha() == 0)
    assert(plate.UnitFrame.levelBadge:GetEffectiveAlpha() == 0)
    assert(not Overlay(plate).name.shown and not plate.clickable)
    CompactUnitFrame_UpdateName(plate.UnitFrame)
    plate.UnitFrame:SetAlpha(1)
    plate.UnitFrame:UpdateHitTestArea(NamePlateSetupOptions)
    assert(plate.UnitFrame.alpha == 0 and not plate.clickable)
end)
Test("every category can hide bars independently of its coloured name", function()
    local categories = { "party", "battleNet", "friends", "guild", "enemies" }
    local properties = { { party = true }, { battleNet = true }, { friend = true }, { guild = true }, { enemy = true } }
    for index, key in ipairs(categories) do
        local token = "nameplate" .. (100 + index)
        local plate = AddUnit(token, properties[index])
        Names.db.categories[key].hidePlate = true
        Names:SettingsChanged()
        assert(plate.UnitFrame.alpha == 0 and not plate.clickable, key .. " bar survived")
        assert(Overlay(plate).name.shown and Overlay(plate).name:GetEffectiveAlpha() == 1)
        if key ~= "enemies" then assert(Overlay(plate).name.color[1] == Names.db.categories[key].color[1]) end
        Names.db.categories[key].hidePlate = false
        Names:SettingsChanged()
        assert(plate.UnitFrame.alpha == 1 and plate.clickable, key .. " bar was not restored")
        assert(Overlay(plate).name.shown)
    end
    assert(cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == "0", "Global names-only mode must not override category choices")
end)
Test("stranger plate checkbox preserves names; hide strangers always hides both", function()
    local plate = AddUnit("nameplate106", {})
    Names.db.hideStrangers = false
    Names.db.hideStrangerPlates = true
    Names:SettingsChanged()
    assert(Overlay(plate).name.shown and plate.UnitFrame.alpha == 0)
    Names.db.hideStrangerPlates = false
    Names:SettingsChanged()
    assert(Overlay(plate).name.shown and plate.UnitFrame.alpha == 1)
    Names.db.hideStrangers = true
    Names:SettingsChanged()
    assert(not Overlay(plate).name.shown and plate.UnitFrame.alpha == 0)
end)
Test("minion plate checkbox covers own and enemy pets while ordinary NPCs stay native", function()
    local own = AddUnit("nameplate107", { guid = "Pet-self-plate", isPlayer = false, minion = true, ownerGUID = "Player-self" })
    local enemy = AddUnit("nameplate108", { guid = "Pet-enemy-plate", isPlayer = false, minion = true, enemy = true, ownerGUID = "Player-enemy-offscreen" })
    local npc = AddUnit("nameplate109", { guid = "Creature-unowned-plate", isPlayer = false })
    Names.db.hideMinionPlates = true
    Names:SettingsChanged()
    assert(own.UnitFrame.alpha == 0 and Overlay(own).name.shown)
    assert(enemy.UnitFrame.alpha == 0 and Overlay(enemy).name.shown)
    assert(npc.UnitFrame.alpha == 1 and npc.clickable and not Overlay(npc))
    Names.db.hideMinionPlates = false
    Names:SettingsChanged()
    assert(own.UnitFrame.alpha == 1 and own.clickable)
    assert(enemy.UnitFrame.alpha == 1 and enemy.clickable)
end)
Test("shared markers survive hidden plates without changing shared assignments", function()
    local plate = AddUnit("nameplate110", { party = true, raidMarker = 4 })
    Names.db.categories.party.hidePlate = true
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 0)
    assert(Overlay(plate).sharedMarker.shown and Overlay(plate).sharedMarker.icon == 4)
    assert(Overlay(plate).sharedMarker:GetEffectiveAlpha() == 1)
    units.nameplate110.raidMarker = nil
    Event("RAID_TARGET_UPDATE")
    assert(not Overlay(plate).sharedMarker.shown)
end)
Test("native alpha changes are respected on restoration", function()
    local plate = visiblePlates.nameplate110
    plate.UnitFrame:SetAlpha(0.6)
    assert(plate.UnitFrame.alpha == 0)
    Names.db.categories.party.hidePlate = false
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 0.6)
    Names.db.categories.party.hidePlate = true
    Names:SettingsChanged()
    plate.UnitFrame:SetAlpha(0)
    Names.db.categories.party.hidePlate = false
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 0)
end)
Test("combat-protected click areas are restored when Blizzard permits it", function()
    local plate = AddUnit("nameplate111", { party = true })
    Names.db.categories.party.hidePlate = true
    combat = true
    Names:UpdatePlate("nameplate111")
    assert(plate.UnitFrame.alpha == 0 and plate.clickable)
    combat = false
    Event("PLAYER_REGEN_ENABLED")
    assert(not plate.clickable)
    combat = true
    Names.db.categories.party.hidePlate = false
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 1 and not plate.clickable)
    combat = false
    Event("PLAYER_REGEN_ENABLED")
    assert(plate.UnitFrame.alpha == 1 and plate.clickable)
end)
Test("hidden plate removal and NPC reuse restore all native visuals and click areas", function()
    local plate = visiblePlates.nameplate111
    Names.db.categories.party.hidePlate = true
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 0)
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate111")
    assert(plate.UnitFrame.alpha == 1 and plate.clickable)
    units.nameplate111 = { guid = "Creature-reused-plate", name = "Ordinary NPC", isPlayer = false }
    Names:UpdatePlate("nameplate111")
    assert(plate.UnitFrame.alpha == 1 and plate.UnitFrame.levelBadge:GetEffectiveAlpha() == 1)
    assert(not Overlay(plate).shown and plate.clickable)
    Names:HandleCommand("off")
    assert(visiblePlates.nameplate100.UnitFrame.alpha == 1 and visiblePlates.nameplate100.clickable)
    Names:HandleCommand("on")
end)
Test("nameplate checkbox controls follow the displayed category after reordering", function()
    local control
    for _, frame in ipairs(frames) do
        if frame.template == "UICheckButtonTemplate" and frame.point
            and frame.point[2] == 258 and frame.point[3] == -106 then control = frame end
    end
    assert(control)
    local category = Names.db.priority[1]
    control.checked = false
    control.scripts.OnClick(control)
    assert(not Names.db.categories[category].hidePlate)
    control.checked = true
    control.scripts.OnClick(control)
    assert(Names.db.categories[category].hidePlate)
end)
Test("enemy minions with unavailable owners still follow enemy plate settings", function()
    Names:ResetSettings()
    Names.db.hideStrangers = true
    Names:SettingsChanged()
    local plate = AddUnit("nameplate112", { guid = "Pet-enemy-secret-owner", isPlayer = false,
        minion = true, enemy = true, ownerGUID = SECRET })
    Names:UpdatePlate("nameplate112")
    assert(plate.UnitFrame.alpha == 1 and not Overlay(plate))
    Names.db.categories.enemies.hidePlate = true
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 0 and Overlay(plate).name.shown)
    Names.db.categories.enemies.show = false
    Names:SettingsChanged()
    assert(plate.UnitFrame.alpha == 0 and not Overlay(plate).name.shown)
end)
Test("effects default to none and all six presets animate without fading the name", function()
    Names:ResetSettings()
    assert(not FamiliarNamesEffectsTicker.shown)
    assert(Names.db.categories.party.effect == "none" and #Names.effectPresets == 7)
    local plate = AddUnit("nameplate120", { party = true })
    for index = 2, #Names.effectPresets do
        local preset = Names.effectPresets[index]
        Names.db.categories.party.effect = preset.id
        Names:SettingsChanged()
        local overlay = Overlay(plate)
        assert(overlay.nameEffect == preset.id and overlay.nameVisuals.glow.shown)
        local spark = overlay.nameVisuals.sparks[1]
        local before = { overlay.name.color[2], spark.point[4], spark.point[5], spark.width, spark.alpha }
        FamiliarNamesEffectsTicker.scripts.OnUpdate(FamiliarNamesEffectsTicker, 0.27)
        local changed = before[1] ~= overlay.name.color[2] or before[2] ~= spark.point[4]
            or before[3] ~= spark.point[5] or before[4] ~= spark.width or before[5] ~= spark.alpha
        assert(changed, preset.id .. " did not animate")
        assert(overlay.name.alpha == 1 and overlay.name.shown, "Readable name was faded")
        assert(plate.UnitFrame.alpha == 0, "Effect changed native plate visibility")
        for _, particle in ipairs(overlay.nameVisuals.sparks) do
            assert(particle.alpha >= 0 and particle.alpha <= 1)
        end
    end
end)
Test("effect visuals are pooled and animation ticks do not query unit data", function()
    local overlay = Overlay(visiblePlates.nameplate120)
    local visuals, childCount, frameCount = overlay.nameVisuals, #overlay.children, #frames
    local guidAPI, plateAPI, cvarAPI = UnitGUID, C_NamePlate.GetNamePlates, C_CVar.GetCVar
    local function Disallowed() error("Animation tick queried game data") end
    UnitGUID, C_NamePlate.GetNamePlates, C_CVar.GetCVar = Disallowed, Disallowed, Disallowed
    local success, problem = pcall(function()
        for index = 1, 60 do FamiliarNamesEffectsTicker.scripts.OnUpdate(FamiliarNamesEffectsTicker, 1 / 60) end
    end)
    UnitGUID, C_NamePlate.GetNamePlates, C_CVar.GetCVar = guidAPI, plateAPI, cvarAPI
    assert(success, problem)
    assert(#frames == frameCount and #overlay.children == childCount)
    Names:RefreshPlates()
    assert(overlay.nameVisuals == visuals and #overlay.children == childCount)
end)
Test("none, master disable and zero intensity restore the chosen static colour", function()
    local overlay = Overlay(visiblePlates.nameplate120)
    Names.db.categories.party.color = { 0.17, 0.45, 0.81 }
    Names.db.categories.party.effect = "gold"
    Names:SettingsChanged()
    assert(overlay.name.color[1] == 1)
    Names.db.animatedNames = false
    Names:SettingsChanged()
    assert(overlay.name.color[1] == 0.17 and not overlay.nameVisuals.glow.shown)
    assert(not FamiliarNamesEffectsTicker.shown)
    Names.db.animatedNames = true
    Names.db.effectIntensity = 0
    Names:SettingsChanged()
    assert(overlay.name.color[1] == 0.17 and not overlay.nameEffect)
    Names.db.effectIntensity = 60
    Names.db.categories.party.effect = "none"
    Names:SettingsChanged()
    assert(overlay.name.color[1] == 0.17 and not FamiliarNamesEffectsTicker.shown)
end)
Test("effects pause on hidden overlays and resume without allocating new textures", function()
    Names.db.categories.party.effect = "void"
    Names:SettingsChanged()
    local overlay = Overlay(visiblePlates.nameplate120)
    local visuals = overlay.nameVisuals
    overlay:Hide()
    assert(not visuals.glow.shown)
    overlay:Show()
    assert(FamiliarNamesEffectsTicker.shown and overlay.nameVisuals == visuals and visuals.glow.shown)
end)
Test("hidden names never animate and recycled NPC plates have no leftover effects", function()
    Names.db.categories.party.show = false
    Names:SettingsChanged()
    local overlay = Overlay(visiblePlates.nameplate120)
    assert(not overlay.name.shown and not overlay.nameEffect and not overlay.nameVisuals.glow.shown)
    Names.db.categories.party.show = true
    Names:SettingsChanged()
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate120")
    units.nameplate120 = { guid = "Creature-effect-reuse", isPlayer = false, name = "Ordinary NPC" }
    Names:UpdatePlate("nameplate120")
    assert(not overlay.nameEffect and not overlay.nameVisuals.glow.shown and not overlay.shown)
    Names.db.categories.party.effect = "none"
    Names:SettingsChanged()
    assert(not FamiliarNamesEffectsTicker.shown)
end)
Test("enemy effects require enemy highlighting and respect name visibility", function()
    local plate = AddUnit("nameplate121", { enemy = true })
    Names.db.categories.enemies.effect = "arcane"
    Names:SettingsChanged()
    assert(not Overlay(plate).nameEffect)
    Names.db.categories.enemies.highlight = true
    Names:SettingsChanged()
    assert(Overlay(plate).nameEffect == "arcane")
    Names.db.categories.enemies.show = false
    Names:SettingsChanged()
    assert(not Overlay(plate).nameEffect and not Overlay(plate).name.shown)
end)
Test("the effect picker saves a category and animates the live preview", function()
    Names:ResetSettings()
    Names.options:Show()
    local selector
    for _, frame in ipairs(frames) do
        if frame.template == "UIPanelButtonTemplate" and frame.point
            and frame.point[2] == 157 and frame.point[3] == -810 then selector = frame end
    end
    assert(selector)
    selector.scripts.OnClick(selector)
    assert(Names.effectPicker.shown)
    Names.effectPicker.children[2].scripts.OnClick()
    assert(Names.db.categories.party.effect == "gold" and not Names.effectPicker.shown)
    assert(Names.effectPreview.nameEffect == "gold" and FamiliarNamesEffectsTicker.shown)
    Names.db.categories.battleNet.color = { 0.12, 0.34, 0.56 }
    Names.db.categories.battleNet.effect = "frost"
    Names.previewCategory = "battleNet"
    Names:SettingsChanged()
    assert(Names.effectPreview.nameEffect == "frost")
    Names.db.animatedNames = false
    Names:SettingsChanged()
    assert(Names.effectPreview.name.color[1] == 0.12, "Preview restored a previous category's colour")
    Names.options:Hide()
    assert(not Names.effectPreview.nameEffect and not FamiliarNamesEffectsTicker.shown)
end)
Test("speed and intensity controls change the actual animation", function()
    Names:ResetSettings()
    local plate = AddUnit("nameplate122", { party = true })
    Names.db.categories.party.effect = "gold"
    Names.db.effectIntensity = 30
    Names.db.effectSpeed = 25
    Names:SettingsChanged()
    local overlay = Overlay(plate)
    local lowGlow = overlay.nameVisuals.glow.alpha
    Names.db.effectIntensity = 90
    Names:SettingsChanged()
    assert(math.abs(overlay.nameVisuals.glow.alpha / lowGlow - 3) < 0.001)
    local spark, width = overlay.nameVisuals.sparks[1], overlay.name:GetStringWidth()
    local before = spark.point[4]
    FamiliarNamesEffectsTicker.scripts.OnUpdate(FamiliarNamesEffectsTicker, 0.1)
    local slowDistance = (spark.point[4] - before) % width
    Names.db.effectSpeed = 200
    before = spark.point[4]
    FamiliarNamesEffectsTicker.scripts.OnUpdate(FamiliarNamesEffectsTicker, 0.1)
    local fastDistance = (spark.point[4] - before) % width
    assert(math.abs(fastDistance / slowDistance - 8) < 0.001)
    Names.db.categories.party.effect = "none"
    Names:SettingsChanged()
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
