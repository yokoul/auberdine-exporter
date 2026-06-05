-- AuberdineExporter - Guild Tracker
-- Suivi des activités de guilde façon GRM (Guild Roster Manager) :
--   * Roster (membres, classes, niveaux, rangs, notes publiques)
--   * Entrées / sorties (join / leave / kick)
--   * Changements de rang (promotion / rétrogradation) avec acteur
--   * Modifications de notes publiques
--
-- Approche : combinaison d'un snapshot du roster (diff d'état via
-- GUILD_ROSTER_UPDATE + GetGuildRosterInfo) et du parsing des messages
-- système (CHAT_MSG_SYSTEM) pour récupérer l'acteur exact d'un kick ou
-- d'une promotion.
--
-- Stockage MULTI-GUILDES : AuberdineExporterDB.guilds[guildKey], avec un
-- drapeau `share` par guilde (choix des guildes exportées).
--
-- Export ÉCONOME : par défaut, seulement le DELTA depuis le dernier export
-- (plafonné à 30 jours) ; un roster complet n'est envoyé qu'en mode "full"
-- (premier export d'une guilde ou resync manuel). Cf. docs/GUILD-TRACKING.md.

AuberdineExporter = AuberdineExporter or {}
local GT = {}
AuberdineExporter.GuildTracker = GT

-- ===================== Configuration =====================

local MAX_LOG = 1000                       -- taille max par défaut du journal (configurable dans l'UI)
local HARD_MAX_LOG = 50000                 -- garde-fou absolu (protège la SavedVariable)
local SCAN_THROTTLE = 2                     -- secondes min entre deux diffs
local PERIODIC_SCAN = 60                    -- re-scan périodique
local HINT_TTL = 60                         -- durée de vie d'un indice d'acteur
local EXPORT_MAX_AGE = 30 * 24 * 60 * 60    -- plafond export : 30 jours
local FULL_REFRESH_INTERVAL = 7 * 24 * 60 * 60  -- full auto si le dernier date de +7 jours (re-sync rangs/roster)

-- ===================== Réglages =====================

local function GuildSettings()
    if type(AuberdineExporterDB) ~= "table" then
        return { enabled = true, exportPublicNotes = true, trackNoteChanges = true, forceFullExport = false }
    end
    AuberdineExporterDB.settings = AuberdineExporterDB.settings or {}
    local s = AuberdineExporterDB.settings.guild
    if type(s) ~= "table" then
        s = {}
        AuberdineExporterDB.settings.guild = s
    end
    if s.enabled == nil then s.enabled = true end
    if s.exportPublicNotes == nil then s.exportPublicNotes = true end
    if s.trackNoteChanges == nil then s.trackNoteChanges = true end
    if s.forceFullExport == nil then s.forceFullExport = false end
    if s.maxLog == nil then s.maxLog = MAX_LOG end
    return s
end
function GT:GetSettings() return GuildSettings() end

-- ===================== Helpers internes =====================

local function IsValidRealm()
    return AuberdineExporter.IsOnAuberdine and AuberdineExporter:IsOnAuberdine()
end

local function GuildPrint(msg)
    print("|cff00ff00AuberdineExporter|r |cffffd200[Guilde]|r " .. msg)
end

local function StripRealm(name)
    if not name then return name end
    return name:match("^([^%-]+)") or name
end

-- Clé de la guilde du personnage courant ("NomGuilde-Royaume"), ou nil
local function CurrentGuildKey()
    if not IsInGuild() then return nil end
    local gname = GetGuildInfo("player")
    if not gname or gname == "" then return nil end
    return gname .. "-" .. GetRealmName()
end

-- Initialise la table multi-guildes + migration de l'ancien format mono-guilde
local function EnsureGuildsDB()
    if type(AuberdineExporterDB) ~= "table" then return nil end
    -- Migration : ancien AuberdineExporterDB.guild (mono) -> guilds[clé]
    if type(AuberdineExporterDB.guild) == "table" and AuberdineExporterDB.guild.name then
        AuberdineExporterDB.guilds = AuberdineExporterDB.guilds or {}
        local old = AuberdineExporterDB.guild
        local key = old.name .. "-" .. (old.realm or GetRealmName())
        if not AuberdineExporterDB.guilds[key] then
            old.share = (old.share ~= false)
            old.lastExportTs = old.lastExportTs or 0
            AuberdineExporterDB.guilds[key] = old
        end
        AuberdineExporterDB.guild = nil
    end
    AuberdineExporterDB.guilds = AuberdineExporterDB.guilds or {}
    return AuberdineExporterDB.guilds
end

local function EnsureGuild(key)
    local guilds = EnsureGuildsDB()
    if not guilds or not key then return nil end
    if type(guilds[key]) ~= "table" then
        guilds[key] = {
            realm = GetRealmName(),
            ranks = {}, roster = {}, log = {},
            lastScan = 0, lastExportTs = 0,
            share = true, initialized = false,
        }
    end
    local g = guilds[key]
    g.ranks = g.ranks or {}
    g.roster = g.roster or {}
    g.log = g.log or {}
    g.lastExportTs = g.lastExportTs or 0
    if g.share == nil then g.share = true end
    return g
end

local function CurrentGuild()
    local key = CurrentGuildKey()
    if not key then return nil, nil end
    return EnsureGuild(key), key
end

-- Demande au serveur une mise à jour du roster (rate-limité à 10s côté Blizzard)
function GT:RequestRoster()
    if not IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Construit le roster courant depuis l'API, indexé par GUID (clé stable)
local function BuildCurrentRoster()
    local result = {}
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, rankName, rankIndex, level, _, zone, publicNote,
              _, online, _, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if name then
            local key = (guid and guid ~= "") and guid or name
            result[key] = {
                name = StripRealm(name),
                class = classFile,
                level = level,
                rankIndex = rankIndex,
                rankName = rankName,
                publicNote = publicNote or "",
                online = online and true or false,
                zone = zone,
                guid = guid,
            }
        end
    end
    return result
end

-- Reconstruit la table des rangs (rankIndex -> rankName) à partir du roster
local function BuildRanksFromRoster(g)
    for _, m in pairs(g.roster) do
        if m.rankIndex ~= nil and m.rankName then
            g.ranks[m.rankIndex] = m.rankName
        end
    end
end

-- ===================== Journal =====================

local function AddLog(g, entry)
    entry.ts = entry.ts or time()
    g.log[#g.log + 1] = entry
    -- Plafond configurable (0 / négatif = illimité, borné par le garde-fou)
    local cap = GuildSettings().maxLog or MAX_LOG
    if not cap or cap <= 0 or cap > HARD_MAX_LOG then cap = HARD_MAX_LOG end
    local excess = #g.log - cap
    while excess > 0 do
        table.remove(g.log, 1)
        excess = excess - 1
    end
end

-- ===================== Indices d'acteur (messages système) =====================

local pendingActors = {}

local function PushHint(data)
    data.ts = time()
    pendingActors[#pendingActors + 1] = data
    for i = #pendingActors, 1, -1 do
        if (time() - pendingActors[i].ts) > HINT_TTL then
            table.remove(pendingActors, i)
        end
    end
end

local function ConsumeHint(kind, target)
    for i = #pendingActors, 1, -1 do
        local h = pendingActors[i]
        if (time() - h.ts) <= HINT_TTL and h.target == target
            and (h.kind == kind or (kind == "LEAVE" and h.kind == "KICK")) then
            table.remove(pendingActors, i)
            return h
        end
    end
    return nil
end

-- Conversion d'une global string Blizzard en pattern Lua avec captures
local function ToPattern(fmt)
    if not fmt then return nil end
    fmt = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = fmt:gsub("%%%%%d%%%$s", "(.-)")   -- positionnel %1$s
    fmt = fmt:gsub("%%%%s", "(.-)")          -- simple %s
    return "^" .. fmt .. "$"
end

local SYS_PATTERNS = {}
local function RegisterPattern(globalName, kind, order)
    local s = _G[globalName]
    local pat = ToPattern(s)
    if pat then
        SYS_PATTERNS[#SYS_PATTERNS + 1] = { pat = pat, kind = kind, order = order }
    end
end

RegisterPattern("ERR_GUILD_JOIN_S",      "JOIN",    { "target" })
RegisterPattern("ERR_GUILD_LEAVE_S",     "LEAVE",   { "target" })
RegisterPattern("ERR_GUILD_REMOVE_SS",   "KICK",    { "target", "actor" })
RegisterPattern("ERR_GUILD_PROMOTE_SSS", "PROMOTE", { "actor", "target", "detail" })
RegisterPattern("ERR_GUILD_DEMOTE_SSS",  "DEMOTE",  { "actor", "target", "detail" })

local function OnSystemMessage(msg)
    if not msg or not IsInGuild() then return end
    if not GuildSettings().enabled then return end
    for _, sp in ipairs(SYS_PATTERNS) do
        local caps = { string.match(msg, sp.pat) }
        if caps[1] ~= nil then
            local data = { kind = sp.kind }
            for i, field in ipairs(sp.order) do
                data[field] = StripRealm(caps[i])
            end
            if data.kind == "KICK" or data.kind == "PROMOTE" or data.kind == "DEMOTE" then
                PushHint(data)
            end
            GT:RequestRoster()
            return
        end
    end
end

-- ===================== Diff du roster =====================

function GT:Diff(g, newRoster, isFirstScan, s)
    local old = g.roster or {}
    s = s or GuildSettings()

    for key, m in pairs(newRoster) do
        local prev = old[key]
        if not prev then
            m.firstSeen = time()
            if not isFirstScan then
                m.joinDate = time()
                AddLog(g, { type = "JOIN", target = m.name })
            end
        else
            m.firstSeen = prev.firstSeen or time()
            m.joinDate = prev.joinDate

            if prev.rankIndex ~= nil and m.rankIndex ~= nil and prev.rankIndex ~= m.rankIndex then
                local kind = (m.rankIndex < prev.rankIndex) and "PROMOTE" or "DEMOTE"
                local hint = ConsumeHint(kind, m.name)
                AddLog(g, {
                    type = kind,
                    target = m.name,
                    detail = m.rankName,
                    fromRank = prev.rankName,
                    actor = hint and hint.actor or nil,
                })
            end

            if s.trackNoteChanges and (prev.publicNote or "") ~= (m.publicNote or "") then
                AddLog(g, {
                    type = "NOTE",
                    target = m.name,
                    detail = m.publicNote,
                    fromNote = prev.publicNote or "",
                })
            end
        end
    end

    for key, prev in pairs(old) do
        if not newRoster[key] then
            if not isFirstScan then
                local hint = ConsumeHint("LEAVE", prev.name)
                if hint and hint.kind == "KICK" then
                    AddLog(g, { type = "KICK", target = prev.name, actor = hint.actor })
                else
                    AddLog(g, { type = "LEAVE", target = prev.name })
                end
            end
        end
    end

    g.roster = newRoster
    g.lastScan = time()
end

-- ===================== Scan principal =====================

local lastDiffTime = 0

function GT:OnRosterUpdate(forced)
    if not IsValidRealm() or not IsInGuild() then return end
    local s = GuildSettings()
    if not s.enabled then return end
    local g = CurrentGuild()
    if not g then return end

    local now = GetTime()
    if not forced and (now - lastDiffTime) < SCAN_THROTTLE then return end

    local newRoster = BuildCurrentRoster()
    if next(newRoster) == nil then return end
    lastDiffTime = now

    local gname = GetGuildInfo("player")
    if gname then g.name = gname end
    if UnitFactionGroup then
        g.faction = UnitFactionGroup("player") or g.faction
    end

    local isFirstScan = (g.initialized ~= true) and (next(g.roster) == nil)
    GT:Diff(g, newRoster, isFirstScan, s)
    g.initialized = true
    BuildRanksFromRoster(g)
end

function GT:ForceScan()
    GT:RequestRoster()
    GT:OnRosterUpdate(true)
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function() GT:OnRosterUpdate(true) end)
    end
end

-- ===================== Export (delta par défaut, full sur demande) =====================

local function LeanMember(m, includeNotes)
    local e = { name = m.name, class = m.class, level = m.level, rankIndex = m.rankIndex }
    if m.joinDate then e.joinDate = m.joinDate end
    if includeNotes and m.publicNote and m.publicNote ~= "" then
        e.publicNote = m.publicNote
    end
    return e
end

local function LeanLog(e)
    local o = { ts = e.ts, type = e.type, target = e.target }
    if e.actor then o.actor = e.actor end
    if e.detail then o.detail = e.detail end
    return o
end

local function CountLogSince(g, since)
    local n = 0
    for _, e in ipairs(g.log or {}) do
        if (e.ts or 0) > since then n = n + 1 end
    end
    return n
end

-- Décide si l'export doit être complet (full) : 1er export, resync manuel,
-- ou refresh périodique automatique (rangs/roster) au-delà de FULL_REFRESH_INTERVAL
local function ShouldFullExport(g, s, now)
    if s.forceFullExport then return true end
    if not g.lastExportTs or g.lastExportTs == 0 then return true end
    return (now - (g.lastFullExportTs or 0)) >= FULL_REFRESH_INTERVAL
end

-- Estimation (octets) de la taille du PROCHAIN export pour une guilde
local function EstimateExportBytes(g, s)
    local now = time()
    local full = ShouldFullExport(g, s, now)
    local floor = now - EXPORT_MAX_AGE
    local since = full and floor or math.max(g.lastExportTs, floor)
    local bytes = 80 + CountLogSince(g, since) * 90
    if full then
        local m = 0
        for _ in pairs(g.roster or {}) do m = m + 1 end
        bytes = bytes + m * (s.exportPublicNotes and 150 or 110)
    end
    return bytes
end

-- Construit le payload d'export. Met à jour lastExportTs (best-effort).
function GT:GetExportData()
    local s = GuildSettings()
    if not s.enabled then return nil end
    local guilds = EnsureGuildsDB()
    if not guilds then return nil end

    local now = time()
    local out = {}
    for _, g in pairs(guilds) do
        if g.share ~= false and g.name then
            local full = ShouldFullExport(g, s, now)
            local floor = now - EXPORT_MAX_AGE
            local since = full and floor or math.max(g.lastExportTs, floor)

            local logOut = {}
            for _, e in ipairs(g.log or {}) do
                if (e.ts or 0) > since then
                    logOut[#logOut + 1] = LeanLog(e)
                end
            end

            local entry = {
                name = g.name,
                realm = g.realm,
                faction = g.faction,
                mode = full and "full" or "delta",
                since = since,
                exportedAt = now,
                log = logOut,
            }

            if full then
                entry.ranks = g.ranks
                local members = {}
                for _, m in pairs(g.roster or {}) do
                    members[#members + 1] = LeanMember(m, s.exportPublicNotes)
                end
                entry.members = members
                entry.memberCount = #members
                g.lastFullExportTs = now
            end

            out[#out + 1] = entry
            g.lastExportTs = now
        end
    end

    s.forceFullExport = false
    if #out == 0 then return nil end
    return { guilds = out }
end

-- ===================== API pour l'UI =====================

function GT:GetTrackedGuilds()
    local guilds = EnsureGuildsDB()
    local list = {}
    if not guilds then return list end
    local s = GuildSettings()
    for key, g in pairs(guilds) do
        if g.name then
            local memberCount = 0
            for _ in pairs(g.roster or {}) do memberCount = memberCount + 1 end
            list[#list + 1] = {
                key = key,
                name = g.name,
                share = (g.share ~= false),
                memberCount = memberCount,
                logCount = #(g.log or {}),
                estBytes = EstimateExportBytes(g, s),
                lastExportTs = g.lastExportTs or 0,
            }
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

function GT:SetShare(key, val)
    local guilds = EnsureGuildsDB()
    if guilds and guilds[key] then
        guilds[key].share = val and true or false
    end
end

-- Force un export complet (roster + journal) au prochain export
function GT:RequestFullResync()
    GuildSettings().forceFullExport = true
end

-- ===================== Affichage (commandes slash) =====================

local TYPE_LABELS = {
    JOIN    = "|cff00ff00Entrée|r",
    LEAVE   = "|cffff8000Départ|r",
    KICK    = "|cffff0000Expulsion|r",
    PROMOTE = "|cff00ccffPromotion|r",
    DEMOTE  = "|cffcc66ffRétrogradation|r",
    NOTE    = "|cffaaaaaaNote|r",
}

local function FmtKB(bytes)
    return string.format("%.1f KB", (bytes or 0) / 1024)
end

function GT:PrintSummary()
    if not IsInGuild() then
        GuildPrint("Vous n'êtes pas dans une guilde.")
        return
    end
    local g = CurrentGuild()
    if not g or not g.name then
        GuildPrint("Pas encore de données. Lancez |cffffffff/auberdine guild scan|r.")
        return
    end
    local s = GuildSettings()
    local total, online = 0, 0
    for _, m in pairs(g.roster or {}) do
        total = total + 1
        if m.online then online = online + 1 end
    end
    GuildPrint("|cffffffff" .. g.name .. "|r (" .. (g.faction or "?") .. ")")
    print(string.format("  • Membres : |cffffffff%d|r (%d en ligne)", total, online))
    print(string.format("  • Journal : |cffffffff%d|r événement(s)", #(g.log or {})))
    print(string.format("  • Partage : %s", (g.share ~= false) and "|cff00ff00activé|r" or "|cffff0000désactivé|r"))
    print(string.format("  • Export estimé : |cffffffff%s|r (%s)",
        FmtKB(EstimateExportBytes(g, s)),
        (not g.lastExportTs or g.lastExportTs == 0 or s.forceFullExport) and "complet" or "delta"))
    print(string.format("  • Dernier scan : %s",
        (g.lastScan and g.lastScan > 0) and date("%Y-%m-%d %H:%M:%S", g.lastScan) or "jamais"))
    print("  |cff888888/auberdine guild log|r · |cff888888members|r · |cff888888list|r · |cff888888share on|off|r · |cff888888resync|r")
end

function GT:PrintList()
    local list = GT:GetTrackedGuilds()
    if #list == 0 then
        GuildPrint("Aucune guilde suivie.")
        return
    end
    GuildPrint(string.format("%d guilde(s) suivie(s) :", #list))
    for _, gi in ipairs(list) do
        print(string.format("  %s |cffffffff%s|r — %d membres, %d évts, ~%s",
            gi.share and "|cff00ff00[partagée]|r" or "|cff888888[ignorée] |r",
            gi.name, gi.memberCount, gi.logCount, FmtKB(gi.estBytes)))
    end
    print("  |cff888888/auberdine guild share on|off|r pour (dé)activer le partage de la guilde courante.")
end

function GT:PrintLog(n)
    local g = CurrentGuild()
    if not g or not g.log or #g.log == 0 then
        GuildPrint("Journal vide.")
        return
    end
    n = tonumber(n) or 20
    local logCount = #g.log
    local startIdx = math.max(1, logCount - n + 1)
    GuildPrint(string.format("Journal (%d derniers / %d) :", math.min(n, logCount), logCount))
    for i = startIdx, logCount do
        local e = g.log[i]
        local when = date("%m-%d %H:%M", e.ts or 0)
        local label = TYPE_LABELS[e.type] or e.type
        local line = string.format("  |cff888888%s|r %s |cffffffff%s|r", when, label, e.target or "?")
        if e.actor then line = line .. " |cff888888(par " .. e.actor .. ")|r" end
        if e.type == "PROMOTE" or e.type == "DEMOTE" then
            line = line .. " → |cffffd200" .. (e.detail or "?") .. "|r"
        elseif e.type == "NOTE" then
            line = line .. " : |cffaaaaaa\"" .. (e.detail or "") .. "\"|r"
        end
        print(line)
    end
end

function GT:PrintMembers()
    local g = CurrentGuild()
    if not g or not g.roster or next(g.roster) == nil then
        GuildPrint("Aucun membre en mémoire. Lancez |cffffffff/auberdine guild scan|r.")
        return
    end
    local list = {}
    for _, m in pairs(g.roster) do list[#list + 1] = m end
    table.sort(list, function(a, b)
        if (a.rankIndex or 99) ~= (b.rankIndex or 99) then
            return (a.rankIndex or 99) < (b.rankIndex or 99)
        end
        return (a.name or "") < (b.name or "")
    end)
    GuildPrint(string.format("%d membre(s) :", #list))
    for _, m in ipairs(list) do
        local status = m.online and "|cff00ff00●|r" or "|cff666666○|r"
        print(string.format("  %s |cffffffff%s|r (niv %s) - %s",
            status, m.name or "?", tostring(m.level or "?"), m.rankName or "?"))
    end
end

function GT:SetCurrentShare(val)
    local _, key = CurrentGuild()
    if not key then
        GuildPrint("Vous n'êtes pas dans une guilde.")
        return
    end
    GT:SetShare(key, val)
    GuildPrint("Partage de la guilde courante " .. (val and "|cff00ff00activé|r" or "|cffff0000désactivé|r") .. ".")
end

function GT:ResyncCurrent()
    GT:RequestFullResync()
    GuildPrint("Prochain export forcé en mode |cffffd200complet|r (roster + journal).")
end

-- Efface le JOURNAL d'une guilde (garde le roster et le drapeau share, pour
-- éviter de re-générer des JOIN au prochain scan).
function GT:ClearLogByKey(key)
    local guilds = EnsureGuildsDB()
    if guilds and guilds[key] then
        guilds[key].log = {}
        return true
    end
    return false
end

-- Efface le journal de la guilde courante
function GT:ClearCurrentLog()
    local _, key = CurrentGuild()
    if not key then
        GuildPrint("Vous n'êtes pas dans une guilde.")
        return
    end
    GT:ClearLogByKey(key)
    GuildPrint("Journal de la guilde courante effacé.")
end

-- ===================== Événements =====================

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

local started = false
local function StartTracking()
    if started then return end
    if not IsValidRealm() then return end
    started = true
    EnsureGuildsDB()
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function() GT:RequestRoster() end)
        C_Timer.After(8, function() GT:OnRosterUpdate(true) end)
    end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(PERIODIC_SCAN, function()
            if IsInGuild() and GuildSettings().enabled then GT:RequestRoster() end
        end)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        StartTracking()
    elseif event == "PLAYER_GUILD_UPDATE" then
        if IsValidRealm() and IsInGuild() then
            GT:RequestRoster()
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        GT:OnRosterUpdate(false)
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if IsValidRealm() then
            OnSystemMessage(msg)
        end
    end
end)
