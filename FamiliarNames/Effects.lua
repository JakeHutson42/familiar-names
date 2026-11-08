local _, Names = ...

Names.effectPresets = {
    { id = "none", label = "None", description = "Use your chosen static name colour." },
    { id = "gold", label = "Gold Shimmer", color = { 1, 0.68, 0.12 }, accent = { 1, 0.97, 0.65 }, description = "Warm gold with a travelling glint." },
    { id = "void", label = "Void Pulse", color = { 0.60, 0.22, 1 }, accent = { 0.92, 0.65, 1 }, description = "A deep purple, breathing glow." },
    { id = "arcane", label = "Arcane Orbit", color = { 0.76, 0.40, 1 }, accent = { 1, 0.78, 1 }, description = "Violet sparks orbit the name." },
    { id = "frost", label = "Frost Glint", color = { 0.30, 0.78, 1 }, accent = { 0.90, 1, 1 }, description = "Ice-blue glints sweep in opposite directions." },
    { id = "ember", label = "Ember Glow", color = { 1, 0.30, 0.06 }, accent = { 1, 0.82, 0.25 }, description = "Amber lettering with rising embers." },
    { id = "emerald", label = "Emerald Wave", color = { 0.15, 0.85, 0.40 }, accent = { 0.65, 1, 0.75 }, description = "A green wave rolls beneath the name." },
}

local presets = {}
for _, preset in ipairs(Names.effectPresets) do presets[preset.id] = preset end
local active = setmetatable({}, { __mode = "k" })
local clock, accumulated, serial = 0, 0, 0
local ticker = CreateFrame("Frame", "FamiliarNamesEffectsTicker")
ticker:Hide()

function Names:GetEffectPreset(id)
    return presets[id] or presets.none
end

local function CreateVisuals(target)
    local function Texture(layer)
        local texture = target:CreateTexture(nil, layer)
        texture:SetTexture("Interface\\Cooldown\\star4")
        texture:SetBlendMode("ADD")
        return texture
    end
    serial = serial + 1
    local visuals = { glow = Texture("BACKGROUND"), sparks = {}, phase = serial * 0.73 }
    for index = 1, 3 do visuals.sparks[index] = Texture("OVERLAY") end
    target.nameVisuals = visuals
    return visuals
end

local function Render(target, state)
    local preset, visuals = state.preset, target.nameVisuals
    local time = clock + visuals.phase
    local pulse = 0.5 + 0.5 * math.sin(time * 2)
    local strength = Names.db.effectIntensity / 100
    local tint = (0.12 + pulse * 0.38) * strength
    local color, accent = preset.color, preset.accent
    target.name:SetTextColor(color[1] + (accent[1] - color[1]) * tint,
        color[2] + (accent[2] - color[2]) * tint, color[3] + (accent[3] - color[3]) * tint)
    local width, height = state.width, state.height
    local expansion = preset.id == "void" and (0.85 + pulse * 0.30) or 1
    visuals.glow:SetSize((width + 24) * expansion, height * 1.8 * expansion)
    visuals.glow:SetVertexColor(unpack(color))
    visuals.glow:SetAlpha((0.10 + pulse * 0.18) * strength)
    for index, spark in ipairs(visuals.sparks) do
        local progress = (time * 0.35 + (index - 1) / 3) % 1
        local x, y, alpha, size = 0, 0, 0, height * 0.7
        if preset.id == "gold" then
            x, y, alpha = (progress - 0.5) * width, 0, math.sin(progress * math.pi) ^ 4
        elseif preset.id == "void" then
            x, y, alpha = (index - 2) * width * 0.48, 0, pulse * 0.45
            size = height * (0.65 + pulse * 0.35)
        elseif preset.id == "arcane" then
            local angle = time * 1.8 + index * math.pi * 2 / 3
            x, y, alpha = math.cos(angle) * (width / 2 + 5), math.sin(angle) * height * 0.65, 0.85
        elseif preset.id == "frost" then
            local direction = index % 2 == 0 and -1 or 1
            x, y, alpha = (progress - 0.5) * width * direction, direction * height * 0.25, math.sin(progress * math.pi) ^ 6
        elseif preset.id == "ember" then
            x = (index - 2) * width * 0.28 + math.sin(time * 2 + index) * 4
            y, alpha, size = (progress * 1.8 - 0.4) * height, (1 - progress) ^ 2, height * 0.5
        elseif preset.id == "emerald" then
            x, y, alpha = (progress - 0.5) * width, math.sin(progress * math.pi * 2) * 4 - height * 0.35, 0.8
        end
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", target.name, "CENTER", x, y)
        spark:SetSize(size, size)
        spark:SetVertexColor(unpack(accent))
        spark:SetAlpha(alpha * strength)
    end
end

function Names:StopNameEffect(target, keepChoice)
    local state = active[target]
    if state then target.name:SetTextColor(unpack(state.baseColor)) end
    active[target] = nil
    if not keepChoice then target.nameEffect = nil end
    if target.nameVisuals then
        target.nameVisuals.glow:Hide()
        for _, spark in ipairs(target.nameVisuals.sparks) do spark:Hide() end
    end
    if not next(active) then ticker:Hide() end
end

function Names:ApplyNameEffect(target, id)
    self:StopNameEffect(target)
    local preset = self:GetEffectPreset(id)
    if not self.db.enabled or not self.db.animatedNames or preset.id == "none" or self.db.effectIntensity == 0 then return end
    local visuals = target.nameVisuals or CreateVisuals(target)
    local state = { preset = preset, baseColor = { target.name:GetTextColor() },
        width = math.max(24, target.name:GetStringWidth()), height = self.db.fontSize }
    target.nameEffect = preset.id
    active[target] = state
    visuals.glow:ClearAllPoints()
    visuals.glow:SetPoint("CENTER", target.name, "CENTER", 0, 0)
    visuals.glow:Show()
    for _, spark in ipairs(visuals.sparks) do spark:Show() end
    Render(target, state)
    ticker:Show()
end

function Names:ResumeNameEffect(target)
    if target.nameEffect and not active[target] then self:ApplyNameEffect(target, target.nameEffect) end
end

-- One 30 Hz clock for visible names; no unit queries, timers or frame allocation here.
ticker:SetScript("OnUpdate", function(_, elapsed)
    clock = clock + elapsed * Names.db.effectSpeed / 100
    accumulated = accumulated + elapsed
    if accumulated < 1 / 30 then return end
    accumulated = 0
    for target, state in pairs(active) do
        if target:IsVisible() and target.name:IsShown() then
            Render(target, state)
        else
            Names:StopNameEffect(target, true)
        end
    end
end)
