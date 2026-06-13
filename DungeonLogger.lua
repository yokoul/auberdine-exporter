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

-- État du run en cours (nil si hors donjon).
local activeRun = nil

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
    }
    upsertRun(activeRun)
    LoggingCombat(true)
    print(string.format("|cff00ff00AuberdineExporter:|r log de donjon démarré (%s)", activeRun.instance))
end

-- Clôt le run courant à la sortie du donjon.
local function finishRun()
    if not activeRun then return end
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
