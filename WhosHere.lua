local STRINGS = {
    enUS = { one = "%d guild member", many = "%d guild members" },
    deDE = { one = "%d Gildenmitglied", many = "%d Gildenmitglieder" },
    frFR = { one = "%d membre de la guilde", many = "%d membres de la guilde" },
    esES = { one = "%d miembro de la hermandad", many = "%d miembros de la hermandad" },
    esMX = { one = "%d miembro de la hermandad", many = "%d miembros de la hermandad" },
    itIT = { one = "%d membro della gilda", many = "%d membri della gilda" },
    ptBR = { one = "%d membro da guilda", many = "%d membros da guilda" },
    ruRU = { one = "%d член гильдии", many = "%d членов гильдии" },
    koKR = { one = "길드원 %d명", many = "길드원 %d명" },
    zhCN = { one = "%d 名公会成员", many = "%d 名公会成员" },
    zhTW = { one = "%d 名公會成員", many = "%d 名公會成員" },
}
local L = STRINGS[GetLocale()] or STRINGS.enUS
local f = CreateFrame("Frame", "WhosHereFrame", UIParent)
f:SetSize(400, 30)
f:SetFrameStrata("HIGH")
f:EnableMouse(true)
f:Hide()

local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetAllPoints()
text:SetTextColor(0.3, 1, 0.3)
text:SetShadowOffset(1, -1)

local HOLD, FADE = 3.0, 1.5
local pending, elapsed = false, 0

local function RequestRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local members = {}

local function CollectMembers(zone)
    wipe(members)
    local myName = strlower((strsplit("-", (UnitName("player")))))
    local myGUID = UnitGUID("player")
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, class, memberZone, _, _, online, _, classFile, _, _, _, _, guid = GetGuildRosterInfo(i)
        if online and memberZone == zone and name then
            local short = strsplit("-", name)
            local isMe = (guid and guid == myGUID) or strlower(short) == myName
            if not isMe then
                members[#members + 1] = { name = short, level = level, class = class, classFile = classFile }
            end
        end
    end
    table.sort(members, function(a, b) return a.name < b.name end)
end

local function Anchor()
    local anchor = SubZoneTextString or ZoneTextString
    f:ClearAllPoints()
    f:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
end

local function Show()
    pending = false
    local zone = GetRealZoneText()
    if not zone or zone == "" then return end
    CollectMembers(zone)
    local count = #members
    if count < 1 then
        f:Hide()
        return
    end
    Anchor()
    text:SetText(string.format(count == 1 and L.one or L.many, count))
    elapsed = 0
    f:SetAlpha(1)
    f:Show()
end

local hovering = false

f:SetScript("OnEnter", function(self)
    hovering = true
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(GetRealZoneText(), 1, 1, 1)
    for _, m in ipairs(members) do
        local color = m.classFile and RAID_CLASS_COLORS[m.classFile]
        local r, g, b = 1, 1, 1
        if color then r, g, b = color.r, color.g, color.b end
        GameTooltip:AddDoubleLine(m.name, (m.level or "") .. " " .. (m.class or ""), r, g, b, 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end)

f:SetScript("OnLeave", function(self)
    hovering = false
    elapsed = HOLD
    GameTooltip:Hide()
end)

f:SetScript("OnUpdate", function(self, dt)
    if hovering then return end
    elapsed = elapsed + dt
    if elapsed > HOLD then
        local a = 1 - (elapsed - HOLD) / FADE
        if a <= 0 then self:Hide() else self:SetAlpha(a) end
    end
end)

-- Persistent, draggable counter
local counter = CreateFrame("Frame", "WhosHereCounter", UIParent)
counter:SetSize(40, 24)
counter:SetFrameStrata("MEDIUM")
counter:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
counter:SetMovable(true)
counter:EnableMouse(true)
counter:SetClampedToScreen(true)
counter:RegisterForDrag("LeftButton")

local bg = counter:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.4)

local counterText = counter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
counterText:SetPoint("CENTER")
counterText:SetTextColor(0.3, 1, 0.3)
counterText:SetText("0")

local function SavePosition()
    local point, _, relPoint, x, y = counter:GetPoint()
    WhosHereDB = WhosHereDB or {}
    WhosHereDB.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition()
    local p = WhosHereDB and WhosHereDB.pos
    if p then
        counter:ClearAllPoints()
        counter:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    end
end

counter:SetScript("OnDragStart", function(self) self:StartMoving() end)
counter:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

local function UpdateCounter()
    if not IsInGuild() or (WhosHereDB and WhosHereDB.hidden) then
        counter:Hide()
        return
    end
    counter:Show()
    local zone = GetRealZoneText()
    if not zone or zone == "" then return end
    CollectMembers(zone)
    local n = #members
    counterText:SetText(n)
    counter:SetWidth(math.max(40, counterText:GetStringWidth() + 16))
end

counter:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(GetRealZoneText(), 1, 1, 1)
    for _, m in ipairs(members) do
        local color = m.classFile and RAID_CLASS_COLORS[m.classFile]
        local r, g, b = 1, 1, 1
        if color then r, g, b = color.r, color.g, color.b end
        GameTooltip:AddDoubleLine(m.name, (m.level or "") .. " " .. (m.class or ""), r, g, b, 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end)
counter:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Minimap button
local mini = CreateFrame("Button", "WhosHereMinimapButton", Minimap)
mini:SetSize(31, 31)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)
mini:RegisterForClicks("LeftButtonUp")
mini:RegisterForDrag("RightButton")
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = mini:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture("Interface\\AddOns\\WhosHere\\icon")
local border = mini:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function PlaceMinimapButton()
    local angle = math.rad((WhosHereDB and WhosHereDB.minimapAngle) or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    mini:ClearAllPoints()
    mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

mini:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        WhosHereDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        PlaceMinimapButton()
    end)
end)
mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

mini:SetScript("OnClick", function()
    WhosHereDB.hidden = not WhosHereDB.hidden
    UpdateCounter()
end)
mini:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Who's here?", 1, 1, 1)
    GameTooltip:AddLine("Click: show/hide counter", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-drag: move button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
PlaceMinimapButton()

C_Timer.NewTicker(30, function()
    if IsInGuild() then RequestRoster() end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "WhosHere" then
            WhosHereDB = WhosHereDB or {}
            RestorePosition()
            PlaceMinimapButton()
            UpdateCounter()
        end
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        if pending then Show() end
        UpdateCounter()
        return
    end
    if event == "PLAYER_GUILD_UPDATE" then
        if arg1 == nil or arg1 == "player" then
            if IsInGuild() then RequestRoster() end
            UpdateCounter()
        end
        return
    end
    if event == "ZONE_CHANGED" then
        UpdateCounter()
        return
    end
    f:Hide()
    UpdateCounter()
    if not IsInGuild() then return end
    pending = true
    RequestRoster()
    -- Fallback if the roster is already current and no update fires
    C_Timer.After(1.5, function() if pending then Show() end end)
end)

