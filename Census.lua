-- AuberdineExporter - Recensement du royaume (census)
--
-- Accumule les joueurs CROISÉS en jeu (nom, niveau, classe, race, faction,
-- zone, guilde) pour transmission communautaire à Auberdine.eu.
--
-- OPT-IN : désactivé par défaut. Contribution facultative — chacun peut aider
-- à recenser la population du royaume s'il le souhaite.
--
-- ┌─ Pourquoi pas /who ? ────────────────────────────────────────────────────┐
-- │ C_FriendList.SendWho() est une fonction PROTÉGÉE dans le client Classic   │
-- │ Era : un addon ne peut pas la déclencher (anti-spam recensement). On      │
-- │ passe donc par la CAPTURE PASSIVE par rencontre, qui ne touche aucune     │
-- │ fonction protégée :                                                       │
-- │   * plaques de nom (nameplates) — tout ce qui s'affiche autour de vous ;  │
-- │   * cible, survol (mouseover), membres de groupe/raid ;                   │
-- │   * résultats d'un /who que VOUS lancez (on lit, on n'appelle jamais).    │
-- │ Avantage inattendu : capte aussi la faction adverse (nameplates ennemis). │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- Les données voyagent dans l'export perso signé (clé top-level `census`),
-- écrit au logout — aucun canal séparé, aucun changement du client Go.

AuberdineExporter = AuberdineExporter or {}
local Census = {}
AuberdineExporter.Census = Census

-- ===================== Configuration =====================

local SWEEP_INTERVAL = 60               -- balayage des unités visibles toutes les 60s
local PRUNE_AFTER    = 14 * 24 * 3600   -- oubli des âmes vues il y a +14 jours

-- ===================== État interne =====================

local started = false

-- ===================== Réglages (lazy init) =====================

local function CensusSettings()
    if type(AuberdineExporterDB) ~= "table" then
        return { enabled = false }
    end
    AuberdineExporterDB.settings = AuberdineExporterDB.settings or {}
    local s = AuberdineExporterDB.settings.census
    if type(s) ~= "table" then
        s = {}
        AuberdineExporterDB.settings.census = s
    end
    if s.enabled == nil then s.enabled = false end  -- OPT-IN strict : off par défaut
    return s
end
function Census:GetSettings() return CensusSettings() end

-- ===================== Stockage =====================

local function EnsureDB()
    AuberdineExporterDB = AuberdineExporterDB or {}
    AuberdineExporterDB.census = AuberdineExporterDB.census or {}
    local c = AuberdineExporterDB.census
    c.players = c.players or {}     -- [name] = { level, class, race, faction, zone, guild, seenAt }
    c.lastSweep = c.lastSweep or 0
    return c
end

-- ===================== Helpers =====================

local function IsValidRealm()
    return AuberdineExporter.IsOnAuberdine and AuberdineExporter:IsOnAuberdine()
end

local function CensusPrint(msg)
    print("|cff00ff00AuberdineExporter|r |cff66ccff[Recensement]|r " .. msg)
end

local function StripRealm(name)
    if not name then return name end
    return name:match("^([^%-]+)") or name
end

-- True si le royaume fourni est un AUTRE royaume que le nôtre. En BG cross-realm
-- on croise des joueurs d'autres serveurs : on ne recense QUE notre royaume,
-- sinon le registre Auberdine se pollue (et un homonyme étranger écraserait un
-- local après StripRealm).
local function IsForeignRealm(realm)
    return realm ~= nil and realm ~= "" and realm ~= GetRealmName()
end

local function FactionToken(unit)
    local f = UnitFactionGroup(unit)
    if f == "Alliance" then return "ALLIANCE" end
    if f == "Horde" then return "HORDE" end
    return nil
end

local function CountPlayers(db)
    local n = 0
    for _ in pairs(db.players) do n = n + 1 end
    return n
end

-- ===================== Capture =====================

local function RecordPlayer(name, data)
    name = StripRealm(name)
    if not name or name == "" then return false end

    local db = EnsureDB()
    local prev = db.players[name]
    -- Niveau : UnitLevel renvoie -1 pour une unité « ?? » (trop loin/haut).
    -- On conserve alors le dernier niveau connu plutôt que de l'écraser.
    local level = data.level
    if (not level or level < 1) and prev then level = prev.level end

    db.players[name] = {
        level   = level,
        class   = data.class or (prev and prev.class) or nil,
        race    = data.race or (prev and prev.race) or nil,
        faction = data.faction or (prev and prev.faction) or nil,
        zone    = data.zone or (prev and prev.zone) or nil,
        guild   = data.guild or (prev and prev.guild) or nil,
        seenAt  = time(),
    }
    return prev == nil
end

local function CaptureUnit(unit)
    if not unit or not UnitExists(unit) then return false end
    if not UnitIsPlayer(unit) then return false end
    if UnitIsUnit(unit, "player") then return false end  -- soi-même

    local name, realm = UnitName(unit)
    if not name or name == "" or name == UNKNOWNOBJECT then return false end
    if IsForeignRealm(realm) then return false end  -- BG cross-realm : autre royaume

    local lvl = UnitLevel(unit)
    if not lvl or lvl < 1 then lvl = nil end
    local locClass = UnitClass(unit)
    local locRace  = UnitRace(unit)
    local zone = GetRealZoneText()
    if not zone or zone == "" then zone = GetZoneText() end

    return RecordPlayer(name, {
        level   = lvl,
        class   = locClass,
        race    = locRace,
        faction = FactionToken(unit),
        zone    = zone,
        guild   = GetGuildInfo(unit),  -- nil hors guilde
    })
end

-- Balaye toutes les unités actuellement visibles : nameplates + groupe/raid +
-- cible + survol. Purement local, aucun appel protégé.
local function SweepVisible()
    if not CensusSettings().enabled then return 0 end
    local fresh = 0

    -- Plaques de nom (tout ce qui s'affiche autour, alliés ET ennemis).
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit and CaptureUnit(unit) then fresh = fresh + 1 end
        end
    end

    -- Membres du groupe / raid.
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n > 0 then
        local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
        for i = 1, n do
            if CaptureUnit(prefix .. i) then fresh = fresh + 1 end
        end
    end

    if CaptureUnit("target") then fresh = fresh + 1 end
    if CaptureUnit("mouseover") then fresh = fresh + 1 end

    EnsureDB().lastSweep = time()
    return fresh
end

-- Balayage manuel (bouton « Recenser les alentours »).
function Census:ScanNow()
    if not IsValidRealm() then
        CensusPrint("indisponible hors du royaume Auberdine.")
        return
    end
    if not CensusSettings().enabled then
        CensusPrint("recensement désactivé (activez-le dans les réglages).")
        return
    end
    local fresh = SweepVisible()
    CensusPrint(fresh .. " nouvelle(s) âme(s) aux alentours — " .. CountPlayers(EnsureDB()) .. " connues au total.")
end

-- Harvest des résultats d'un /who lancé par le joueur (lecture seule : on
-- n'appelle JAMAIS SendWho, on lit juste ce que le client expose).
local function HarvestWho()
    if not CensusSettings().enabled then return end
    local num = (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()) or 0
    if num == 0 then return end
    local faction = FactionToken("player")  -- /who ne renvoie que SA faction
    local fresh = 0
    for i = 1, num do
        local info = C_FriendList and C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(i)
        -- info.fullName peut être "Nom-Royaume" → on écarte les autres royaumes.
        local foreign = false
        if info and info.fullName then
            local r = info.fullName:match("%-(.+)$")
            foreign = IsForeignRealm(r)
        end
        if info and info.fullName and not foreign then
            local guild = info.fullGuildName
            if guild == "" then guild = nil end
            if RecordPlayer(info.fullName, {
                level   = tonumber(info.level),
                class   = info.classStr,
                race    = info.raceStr,
                faction = faction,
                zone    = info.area,
                guild   = guild,
            }) then fresh = fresh + 1 end
        end
    end
    CensusPrint(string.format("/who relevé : %d résultat(s), %d nouvelle(s) — %d âmes connues.",
        num, fresh, CountPlayers(EnsureDB())))
end

-- ===================== Export (consommé par ExportToJSON) =====================
-- Émet la liste des âmes vues ; purge au passage les observations trop vieilles
-- pour garder le payload borné et frais.

function Census:GetExportData()
    local db = EnsureDB()
    local now = time()
    local players = {}

    for name, p in pairs(db.players) do
        if (now - (p.seenAt or 0)) > PRUNE_AFTER then
            db.players[name] = nil
        else
            players[#players + 1] = {
                name    = name,
                level   = p.level,
                class   = p.class,
                race    = p.race,
                faction = p.faction,
                zone    = p.zone,
                guild   = p.guild,
                seenAt  = p.seenAt,  -- date d'observation réelle (journal serveur)
            }
        end
    end

    return {
        scannerFaction = FactionToken("player"),
        scannedAt      = db.lastSweep or now,
        players        = players,
    }
end

-- ===================== Événements =====================

local function StartCensus()
    if started then return end
    if not IsValidRealm() then return end
    started = true
    EnsureDB()

    -- Balayage périodique des unités visibles (passif, non protégé).
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(SWEEP_INTERVAL, function()
            if CensusSettings().enabled then SweepVisible() end
        end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("WHO_LIST_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        StartCensus()
    elseif not CensusSettings().enabled then
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        CaptureUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CaptureUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CaptureUnit((...))
    elseif event == "GROUP_ROSTER_UPDATE" then
        SweepVisible()
    elseif event == "WHO_LIST_UPDATE" then
        HarvestWho()
    end
end)
