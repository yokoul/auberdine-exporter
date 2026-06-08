-- AuberdineExporter - Recensement du royaume (census)
--
-- Balaye la population visible via /who et accumule les joueurs vus
-- (nom, niveau, classe, race, faction, zone, guilde) pour transmission
-- communautaire à Auberdine.eu. Inspiré de CensusPlus (vanilla).
--
-- OPT-IN : désactivé par défaut. C'est une contribution facultative — chacun
-- peut aider à recenser la population du royaume s'il le souhaite.
--
-- Contraintes /who :
--   * ne voit que SA propre faction (un scan Alliance ne voit que l'Alliance) ;
--   * plafonne à ~50 résultats par requête.
-- Stratégie : balayage par CLASSE, subdivisé par TRANCHE DE NIVEAU si une
-- classe sature. Tâche de fond throttlée, relancée chaque heure pour varier
-- les fenêtres horaires. Les données voyagent dans l'export perso signé
-- (clé top-level `census`), écrit au logout — aucun canal séparé.

AuberdineExporter = AuberdineExporter or {}
local Census = {}
AuberdineExporter.Census = Census

-- ===================== Configuration =====================

local WHO_THROTTLE        = 3            -- secondes min entre deux requêtes /who
local SATURATION          = 49          -- au-delà → subdivision (plafond serveur ~50)
local FULL_SWEEP_INTERVAL = 3600        -- balayage complet toutes les heures
local INITIAL_DELAY       = 30          -- délai après login avant le 1er balayage
local PRUNE_AFTER         = 14 * 24 * 3600  -- oubli des âmes vues il y a +14 jours

-- Classes Classic — libellés FR (le client français renvoie le localisé dans
-- /who, et le filtre c-"..." accepte ce même libellé).
local CLASSES = {
    "Guerrier", "Paladin", "Chasseur", "Voleur", "Prêtre",
    "Chaman", "Mage", "Démoniste", "Druide",
}

-- Tranches de niveau pour subdivision quand une classe sature.
local LEVEL_BANDS = { {1,9}, {10,19}, {20,29}, {30,39}, {40,49}, {50,59}, {60,60} }

-- ===================== État interne =====================

local queue          = {}      -- file de requêtes { class = "...", band = {min,max} | nil }
local currentItem    = nil
local sweeping       = false
local awaitingResult = false
local started        = false

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

local function PlayerFaction()
    local f = UnitFactionGroup("player")
    if f == "Alliance" then return "ALLIANCE" end
    if f == "Horde" then return "HORDE" end
    return nil
end

local function BuildFilter(item)
    local filter = 'c-"' .. item.class .. '"'
    if item.band then
        filter = filter .. " " .. item.band[1] .. "-" .. item.band[2]
    end
    return filter
end

local function CountPlayers(db)
    local n = 0
    for _ in pairs(db.players) do n = n + 1 end
    return n
end

-- ===================== Moteur de balayage =====================

local function RecordPlayer(info, faction)
    local name = StripRealm(info.fullName)
    if not name or name == "" then return end
    local lvl = tonumber(info.level) or 0
    if lvl < 1 then return end

    local guild = info.fullGuildName
    if guild == "" then guild = nil end

    EnsureDB().players[name] = {
        level   = lvl,
        class   = info.classStr,
        race    = info.raceStr,
        faction = faction,
        zone    = info.area,
        guild   = guild,
        seenAt  = time(),
    }
end

local function ProcessNext()
    local item = table.remove(queue, 1)
    if not item then
        sweeping = false
        currentItem = nil
        CensusPrint("balayage terminé — " .. CountPlayers(EnsureDB()) .. " âmes connues.")
        return
    end

    currentItem = item
    awaitingResult = true
    local filter = BuildFilter(item)

    -- SetWhoToUI(false) : on ne veut pas faire surgir la fenêtre Qui à chaque
    -- requête. Les résultats restent lisibles via WHO_LIST_UPDATE + GetWhoInfo.
    if C_FriendList and C_FriendList.SetWhoToUI then C_FriendList.SetWhoToUI(false) end

    if C_FriendList and C_FriendList.SendWho then
        C_FriendList.SendWho(filter)
    else
        -- API indisponible → on abandonne proprement le balayage.
        sweeping = false
        currentItem = nil
        awaitingResult = false
    end
end

local function OnWhoResult()
    if not sweeping or not currentItem or not awaitingResult then return end
    awaitingResult = false

    local faction = PlayerFaction()
    local num = (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()) or 0
    for i = 1, num do
        local info = C_FriendList and C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(i)
        if info and info.fullName then RecordPlayer(info, faction) end
    end

    -- Subdivision si saturation : classe entière → par tranche de niveau.
    if num >= SATURATION then
        if not currentItem.band then
            for _, b in ipairs(LEVEL_BANDS) do
                queue[#queue + 1] = { class = currentItem.class, band = b }
            end
        else
            -- Une tranche fine reste saturée : recensement partiel assumé (pas
            -- de cap silencieux — on le signale).
            CensusPrint("tranche saturée (" .. num .. "+), recensement partiel : " .. BuildFilter(currentItem))
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(WHO_THROTTLE, ProcessNext)
    else
        ProcessNext()
    end
end

-- Lance un balayage complet du royaume (une requête /who par classe au départ).
-- `manual` force le scan même si l'auto-balayage est en pause (mais jamais si
-- l'opt-in global est désactivé).
function Census:StartSweep(manual)
    if not IsValidRealm() then
        if manual then CensusPrint("indisponible hors du royaume Auberdine.") end
        return
    end
    if not CensusSettings().enabled then
        if manual then CensusPrint("recensement désactivé (activez-le dans les réglages).") end
        return
    end
    if sweeping then
        if manual then CensusPrint("un balayage est déjà en cours.") end
        return
    end

    local faction = PlayerFaction()
    if not faction then return end

    sweeping = true
    queue = {}
    for _, cls in ipairs(CLASSES) do
        queue[#queue + 1] = { class = cls }
    end
    EnsureDB().lastSweep = time()
    CensusPrint("balayage du royaume démarré (" .. faction .. ", faction visible uniquement)…")
    ProcessNext()
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
            }
        end
    end

    return {
        scannerFaction = PlayerFaction(),
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

    if C_Timer and C_Timer.After then
        C_Timer.After(INITIAL_DELAY, function()
            if CensusSettings().enabled then Census:StartSweep(false) end
        end)
    end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(FULL_SWEEP_INTERVAL, function()
            if CensusSettings().enabled then Census:StartSweep(false) end
        end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("WHO_LIST_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        StartCensus()
    elseif event == "WHO_LIST_UPDATE" then
        OnWhoResult()
    end
end)
