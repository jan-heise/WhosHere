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
    local me = UnitName("player")
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, class, memberZone, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if online and memberZone == zone and name and Ambiguate(name, "short") ~= me then
            members[#members + 1] = { name = Ambiguate(name, "short"), level = level, class = class, classFile = classFile }
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
    if count < 1 then return end
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

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(self, event)
    if event == "GUILD_ROSTER_UPDATE" then
        if pending then Show() end
        return
    end
    if not IsInGuild() then return end
    pending = true
    RequestRoster()
    -- Fallback if the roster is already current and no update fires
    C_Timer.After(1.5, function() if pending then Show() end end)
end)

