-- DungeonLogger.lua
--
-- Balisage des runs de donjon pour l'uploader local (voir
-- docs/UPLOADER-ARCHITECTURE.md §6).
--
-- À l'entrée d'un donjon 5 (instanceType "party"), on active le log de combat
-- du client (LoggingCombat) et on écrit un run "in_progress" dans la
-- SavedVariable. À la sortie, on le clôt en "complete". L'uploader consomme ce
-- manifeste pour découper le WoWCombatLog.txt aux bonnes fenêtres temporelles.
--
-- L'addon ne connaît pas les offsets en octets du log : il ne fournit que des
-- timestamps (startedAt / endedAt). C'est l'uploader qui mappe ces bornes vers
-- une plage d'octets.

local MANIFEST_SCHEMA = 1
local MAX_RUNS = 100 -- rétention : on borne la taille du manifeste

-- Échantillonnage d'étage (cf. replay /donjon/:code) : le log de combat ne
-- porte pas l'étage en Era (uiMapID = 0 en instance), mais le client le résout
-- bien — c'est ce que voit la minimap. On capte donc périodiquement
-- C_Map.GetBestMapForUnit (uiMapID de l'étage courant) + la position
-- normalisée sur cet étage, pour reconstituer côté serveur quel plan afficher
-- et à quel instant.
local FLOOR_SAMPLE_INTERVAL = 3 -- secondes entre deux échantillons
local MAX_FLOOR_SAMPLES = 1500 -- borne (≈ 75 min de run) ; on jette les plus vieux

-- État du run en cours (nil si hors donjon).
local activeRun = nil
-- Ticker d'échantillonnage d'étage, actif uniquement pendant un run.
local floorTicker = nil

-- Clé personnage "Nom-Royaume".
local function characterKey()
    local name = UnitName("player") or "unknown"
    local realm = GetRealmName() or "unknown"
    return name .. "-" .. realm
end

-- Le log de donjon est-il activé ? (réglage, défaut activé)
local function loggingEnabled()
    if not AuberdineExporterDB then return true end
    AuberdineExporterDB.settings = AuberdineExporterDB.settings or {}
    local v = AuberdineExporterDB.settings.dungeonLogging
    if v == nil then return true end
    return v and true or false
end

-- Garantit la présence de la table de manifeste.
local function ensureManifest()
    AuberdineExporterDB = AuberdineExporterDB or {}
    if type(AuberdineExporterDB.uploaderManifest) ~= "table" then
        AuberdineExporterDB.uploaderManifest = { schema = MANIFEST_SCHEMA, runs = {} }
    end
    local m = AuberdineExporterDB.uploaderManifest
    m.schema = MANIFEST_SCHEMA
    if type(m.runs) ~= "table" then m.runs = {} end
    return m
end

-- Insère ou met à jour un run (par id), puis applique la rétention.
local function upsertRun(run)
    local m = ensureManifest()
    for i, r in ipairs(m.runs) do
        if r.id == run.id then
            m.runs[i] = run
            return
        end
    end
    table.insert(m.runs, run)
    -- Rétention : ne conserver que les MAX_RUNS plus récents.
    while #m.runs > MAX_RUNS do
        table.remove(m.runs, 1)
    end
end

-- Capte l'étage courant (uiMapID) + position normalisée du joueur, et pousse
-- un échantillon { t, m, x, y } dans le run actif. Tolérant : si l'API ne rend
-- rien (transition de zone, position indispo), on ne pousse rien.
local function sampleFloor()
    if not activeRun then return end
    if not C_Map or not C_Map.GetBestMapForUnit then return end
    local uiMap = C_Map.GetBestMapForUnit("player")
    if not uiMap or uiMap == 0 then return end
    local x, y = 0, 0
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(uiMap, "player")
    if pos then
        local px, py = pos:GetXY()
        if px then x = px end
        if py then y = py end
    end
    activeRun.floors = activeRun.floors or {}
    local f = activeRun.floors
    -- On empile CHAQUE relevé (≈ toutes les 3 s) : c'est un fil de positions
    -- normalisées (x,y) ET d'étage (m), pas seulement la « hauteur ». Le serveur
    -- s'en sert pour la sélection d'étage et, en croisant les x,y avec les
    -- coordonnées-monde du log, pour caler la projection par étage.
    local last = f[#f]
    f[#f + 1] = { t = time(), m = uiMap, x = x, y = y }
    -- Retour visuel : uniquement aux transitions d'étage (pas à chaque tick).
    if not last or last.m ~= uiMap then
        print(string.format(
            "|cff66ccffAuberdineExporter:|r étage capté — uiMap %d (%.2f, %.2f)",
            uiMap, x, y))
    end
    while #f > MAX_FLOOR_SAMPLES do
        table.remove(f, 1)
    end
end

-- Lance / arrête le ticker d'échantillonnage d'étage.
local function startFloorSampling()
    if floorTicker then floorTicker:Cancel() end
    sampleFloor() -- premier point immédiat
    if C_Timer and C_Timer.NewTicker then
        floorTicker = C_Timer.NewTicker(FLOOR_SAMPLE_INTERVAL, sampleFloor)
    end
end
local function stopFloorSampling()
    if floorTicker then
        floorTicker:Cancel()
        floorTicker = nil
    end
    sampleFloor() -- dernier point à la sortie
end

-- Démarre un run à l'entrée d'un donjon.
local function startRun()
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    local started = time()
    activeRun = {
        id = string.format("%s-%s-%d", characterKey(), tostring(instanceID or 0), started),
        instance = name or "Unknown",
        instanceId = instanceID or 0,
        character = characterKey(),
        startedAt = started,
        endedAt = 0,
        status = "in_progress",
        floors = {},
    }
    upsertRun(activeRun)
    LoggingCombat(true)
    startFloorSampling()
    print(string.format("|cff00ff00AuberdineExporter:|r log de donjon démarré (%s)", activeRun.instance))
end

-- Clôt le run courant à la sortie du donjon.
local function finishRun()
    if not activeRun then return end
    stopFloorSampling()
    activeRun.endedAt = time()
    activeRun.status = "complete"
    upsertRun(activeRun)
    LoggingCombat(false)
    print(string.format("|cff00ff00AuberdineExporter:|r log de donjon terminé (%s)", activeRun.instance))
    activeRun = nil
end

-- Réévalue l'état d'instance et déclenche start/finish au besoin.
local function evaluate()
    if not AuberdineExporter or not AuberdineExporter:IsOnAuberdine() then return end
    if not loggingEnabled() then
        -- Si on désactive en cours de run, on clôt proprement.
        if activeRun then finishRun() end
        return
    end
    local inInstance, instanceType = IsInInstance()
    local inDungeon = inInstance and instanceType == "party"
    if inDungeon and not activeRun then
        startRun()
    elseif (not inDungeon) and activeRun then
        finishRun()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        -- Transition de zone (dont logout/reload) : si on quitte un donjon,
        -- la réévaluation au prochain ENTERING_WORLD s'en chargera ; mais en cas
        -- de déconnexion on clôt tout de suite pour ne pas laisser un run ouvert.
        if activeRun then finishRun() end
        return
    end
    -- Petit délai pour que GetInstanceInfo/IsInInstance soient à jour.
    C_Timer.After(1, evaluate)
end)
