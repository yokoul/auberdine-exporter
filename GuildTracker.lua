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
-- d'une promotion. Les données sont persistées dans AuberdineExporterDB.guild
-- et injectées dans l'export auberdine.eu.

AuberdineExporter = AuberdineExporter or {}
local GT = {}
AuberdineExporter.GuildTracker = GT

-- ===================== Configuration =====================

local MAX_LOG = 1000          -- taille max du journal (les plus anciens sont purgés)
local SCAN_THROTTLE = 2       -- secondes minimales entre deux diffs complets
local PERIODIC_SCAN = 60      -- re-scan périodique (capte les changements faits par d'autres)
local HINT_TTL = 60           -- durée de vie d'un indice d'acteur (secondes)

-- ===================== Helpers internes =====================

local function IsValidRealm()
    return AuberdineExporter.IsOnAuberdine and AuberdineExporter:IsOnAuberdine()
end

local function GuildLog(msg)
    print("|cff00ff00AuberdineExporter|r |cffffd200[Guilde]|r " .. msg)
end

-- Initialise / récupère la sous-table guilde de la base de données
local function EnsureGuildDB()
    if type(AuberdineExporterDB) ~= "table" then return nil end
    if type(AuberdineExporterDB.guild) ~= "table" then
        AuberdineExporterDB.guild = {}
    end
    local g = AuberdineExporterDB.guild
    g.realm = g.realm or GetRealmName()
    g.ranks = g.ranks or {}
    g.roster = g.roster or {}
    g.log = g.log or {}
    g.lastScan = g.lastScan or 0
    return g
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
        -- Classic Era : name, rankName, rankIndex, level, classDisplay, zone,
        -- publicNote, officerNote, online, status, classFile, ..., guid
        local name, rankName, rankIndex, level, _, zone, publicNote,
              _, online, _, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if name then
            -- Normaliser le nom (retirer le royaume si présent)
            local shortName = name:match("^([^%-]+)") or name
            local key = (guid and guid ~= "") and guid or name
            result[key] = {
                name = shortName,
                fullName = name,
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

-- Reconstruit la table des rangs (rankIndex -> rankName) à partir du roster.
-- Plus robuste que GuildControlGetRankName qui nécessite des permissions.
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
    local excess = #g.log - MAX_LOG
    while excess > 0 do
        table.remove(g.log, 1)
        excess = excess - 1
    end
end

-- ===================== Indices d'acteur (messages système) =====================
-- Les messages système contiennent QUI a kické / promu. On les met en tampon
-- pour enrichir l'événement détecté ensuite par le diff du roster.

local pendingActors = {}

local function PushHint(data)
    data.ts = time()
    pendingActors[#pendingActors + 1] = data
    -- Purge des indices périmés
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

-- Conversion d'une global string Blizzard ("%s a rejoint la guilde.") en
-- pattern Lua avec captures. Gère le positionnel (%1$s) et le simple (%s).
local function ToPattern(fmt)
    if not fmt then return nil end
    -- Échapper les caractères magiques de Lua
    fmt = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    -- %1$s (positionnel) -> capture
    fmt = fmt:gsub("%%%%%d%%%$s", "(.-)")
    -- %s simple -> capture
    fmt = fmt:gsub("%%%%s", "(.-)")
    return "^" .. fmt .. "$"
end

-- Table des patterns système (construite au chargement)
local SYS_PATTERNS = {}
local function RegisterPattern(globalName, kind, order)
    local s = _G[globalName]
    local pat = ToPattern(s)
    if pat then
        SYS_PATTERNS[#SYS_PATTERNS + 1] = { pat = pat, kind = kind, order = order }
    end
end

RegisterPattern("ERR_GUILD_JOIN_S",    "JOIN",    { "target" })
RegisterPattern("ERR_GUILD_LEAVE_S",   "LEAVE",   { "target" })
RegisterPattern("ERR_GUILD_REMOVE_SS", "KICK",    { "target", "actor" })
RegisterPattern("ERR_GUILD_PROMOTE_SSS", "PROMOTE", { "actor", "target", "detail" })
RegisterPattern("ERR_GUILD_DEMOTE_SSS",  "DEMOTE",  { "actor", "target", "detail" })

local function StripRealm(name)
    if not name then return name end
    return name:match("^([^%-]+)") or name
end

local function OnSystemMessage(msg)
    if not msg or not IsInGuild() then return end
    for _, sp in ipairs(SYS_PATTERNS) do
        local caps = { string.match(msg, sp.pat) }
        if caps[1] ~= nil then
            local data = { kind = sp.kind }
            for i, field in ipairs(sp.order) do
                data[field] = StripRealm(caps[i])
            end
            -- On ne garde comme indice que les événements porteurs d'acteur
            if data.kind == "KICK" or data.kind == "PROMOTE" or data.kind == "DEMOTE" then
                PushHint(data)
            end
            -- Forcer un rafraîchissement du roster pour capter le nouvel état
            GT:RequestRoster()
            return
        end
    end
end

-- ===================== Diff du roster =====================

function GT:Diff(g, newRoster, isFirstScan)
    local old = g.roster or {}

    -- Nouveaux membres + changements sur les membres existants
    for key, m in pairs(newRoster) do
        local prev = old[key]
        if not prev then
            m.firstSeen = time()
            if not isFirstScan then
                m.joinDate = time()
                AddLog(g, { type = "JOIN", target = m.name })
            end
        else
            -- Conserver les métadonnées historiques
            m.firstSeen = prev.firstSeen or time()
            m.joinDate = prev.joinDate

            -- Changement de rang (rankIndex bas = rang élevé)
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

            -- Changement de note publique
            if (prev.publicNote or "") ~= (m.publicNote or "") then
                AddLog(g, {
                    type = "NOTE",
                    target = m.name,
                    detail = m.publicNote,
                    fromNote = prev.publicNote or "",
                })
            end
        end
    end

    -- Départs (présents avant, absents maintenant)
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
    local g = EnsureGuildDB()
    if not g then return end

    local now = GetTime()
    if not forced and (now - lastDiffTime) < SCAN_THROTTLE then return end

    local newRoster = BuildCurrentRoster()
    -- Le serveur n'a pas encore renvoyé les données : on ne fait rien
    if next(newRoster) == nil then return end
    lastDiffTime = now

    -- Métadonnées de guilde
    local gname = GetGuildInfo("player")
    if gname then g.name = gname end
    if UnitFactionGroup then
        g.faction = UnitFactionGroup("player") or g.faction
    end

    -- Premier scan : on amorce silencieusement la photo (pas de flood JOIN)
    local isFirstScan = (g.initialized ~= true) and (next(g.roster) == nil)
    GT:Diff(g, newRoster, isFirstScan)
    g.initialized = true
    BuildRanksFromRoster(g)
end

-- Scan manuel forcé (commande slash)
function GT:ForceScan()
    GT:RequestRoster()
    -- Tentative immédiate sur les données déjà en cache
    GT:OnRosterUpdate(true)
    -- Nouvelle tentative après réponse serveur
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function() GT:OnRosterUpdate(true) end)
    end
end

-- ===================== Export =====================

-- Retourne une copie propre et sérialisable pour l'export auberdine.eu.
-- Les notes officier ne sont JAMAIS collectées ni exportées.
function GT:GetExportData()
    local g = AuberdineExporterDB and AuberdineExporterDB.guild
    if not g or not g.name then return nil end

    local members = {}
    local count = 0
    for _, m in pairs(g.roster or {}) do
        count = count + 1
        members[count] = {
            name = m.name,
            class = m.class,
            level = m.level,
            rankIndex = m.rankIndex,
            rankName = m.rankName,
            publicNote = m.publicNote or "",
            joinDate = m.joinDate,
            firstSeen = m.firstSeen,
        }
    end

    local log = {}
    for i, e in ipairs(g.log or {}) do
        log[i] = {
            ts = e.ts,
            type = e.type,
            target = e.target,
            actor = e.actor,
            detail = e.detail,
            fromRank = e.fromRank,
            fromNote = e.fromNote,
        }
    end

    return {
        name = g.name,
        realm = g.realm,
        faction = g.faction,
        lastScan = g.lastScan,
        memberCount = count,
        ranks = g.ranks,
        members = members,
        log = log,
    }
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

function GT:PrintSummary()
    local g = AuberdineExporterDB and AuberdineExporterDB.guild
    if not IsInGuild() then
        GuildLog("Vous n'êtes pas dans une guilde.")
        return
    end
    if not g or not g.name then
        GuildLog("Pas encore de données de guilde. Lancez |cffffffff/auberdine guild scan|r.")
        return
    end

    local total, online = 0, 0
    for _, m in pairs(g.roster or {}) do
        total = total + 1
        if m.online then online = online + 1 end
    end

    GuildLog("|cffffffff" .. g.name .. "|r (" .. (g.faction or "?") .. ")")
    print(string.format("  • Membres : |cffffffff%d|r (%d en ligne)", total, online))
    print(string.format("  • Rangs   : |cffffffff%d|r", (function()
        local c = 0; for _ in pairs(g.ranks or {}) do c = c + 1 end; return c
    end)()))
    print(string.format("  • Journal : |cffffffff%d|r événement(s)", #(g.log or {})))
    print(string.format("  • Dernier scan : %s",
        (g.lastScan and g.lastScan > 0) and date("%Y-%m-%d %H:%M:%S", g.lastScan) or "jamais"))
    print("  Tapez |cffffffff/auberdine guild log|r pour l'historique, |cffffffff/auberdine guild members|r pour la liste.")
end

function GT:PrintLog(n)
    local g = AuberdineExporterDB and AuberdineExporterDB.guild
    if not g or not g.log or #g.log == 0 then
        GuildLog("Journal vide.")
        return
    end
    n = tonumber(n) or 20
    local logCount = #g.log
    local startIdx = math.max(1, logCount - n + 1)
    GuildLog(string.format("Journal (%d derniers / %d) :", math.min(n, logCount), logCount))
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
    local g = AuberdineExporterDB and AuberdineExporterDB.guild
    if not g or not g.roster or next(g.roster) == nil then
        GuildLog("Aucun membre en mémoire. Lancez |cffffffff/auberdine guild scan|r.")
        return
    end
    -- Trier par rankIndex puis nom
    local list = {}
    for _, m in pairs(g.roster) do list[#list + 1] = m end
    table.sort(list, function(a, b)
        if (a.rankIndex or 99) ~= (b.rankIndex or 99) then
            return (a.rankIndex or 99) < (b.rankIndex or 99)
        end
        return (a.name or "") < (b.name or "")
    end)
    GuildLog(string.format("%d membre(s) :", #list))
    for _, m in ipairs(list) do
        local status = m.online and "|cff00ff00●|r" or "|cff666666○|r"
        print(string.format("  %s |cffffffff%s|r (niv %s) - %s",
            status, m.name or "?", tostring(m.level or "?"), m.rankName or "?"))
    end
end

function GT:ClearData()
    if AuberdineExporterDB then
        AuberdineExporterDB.guild = nil
    end
    EnsureGuildDB()
    GuildLog("Données de guilde réinitialisées.")
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
    EnsureGuildDB()
    -- Premier scan après un court délai (laisser le roster se peupler)
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function() GT:RequestRoster() end)
        C_Timer.After(8, function() GT:OnRosterUpdate(true) end)
    end
    -- Re-scan périodique
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(PERIODIC_SCAN, function()
            if IsInGuild() then GT:RequestRoster() end
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
