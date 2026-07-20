-- AuberdineExporter - Butin de raid (raid loots, « façon Gargul »)
--
-- Capte les objets ÉPIQUES tombés en RAID et leur destinataire, pour les
-- transmettre à Auberdine.eu (journal du joueur + tableau de butin de la
-- guilde). Deux sources, fusionnées ici puis dédupliquées par loot_uid :
--
--   * 'chat'   : capture PASSIVE de CHAT_MSG_LOOT. Les messages de butin épique
--                sont déjà diffusés à tout le raid par le client — on ne fait
--                que les lire (aucune fonction protégée). Le boss vient du
--                dernier ENCOUNTER_END. Marche dès qu'UN raideur a l'addon.
--   * 'gargul' : si l'addon Gargul est présent (chez le master looter), on lit
--                son historique d'attributions → disposition (attribué/
--                désenchanté/banque) + raison. Best-effort, défensif.
--
-- Le serveur rattache ensuite chaque loot à une entrée de raid (log WCL) par
-- recoupement temporel — l'addon n'envoie donc PAS d'ID de boss, juste le nom
-- (libellé) et l'horodatage. Cf. server/RAID-LOOT-IMPORT.md.
--
-- Les données voyagent dans l'export perso signé (clé top-level `raidLoots`),
-- écrit au logout — aucun canal séparé, aucun changement du client Go.

AuberdineExporter = AuberdineExporter or {}
local LootTracker = {}
AuberdineExporter.LootTracker = LootTracker

-- ===================== Configuration =====================

local PRUNE_AFTER  = 30 * 24 * 3600   -- oubli des loots de +30 jours (payload borné)
local BOSS_WINDOW  = 10 * 60          -- un loot est rattaché au boss si tué il y a <10 min
local MAX_LOOTS    = 600              -- garde-fou de taille de la SavedVariable
local GARGUL_MATCH_WINDOW = 10 * 60   -- fusion gargul↔chat : même item/destinataire à ±10 min

-- Couleur du lien d'item → qualité WoW. Locale-proof et indépendant du cache
-- (GetItemInfo peut renvoyer nil pour un objet pas encore chargé ; la couleur,
-- elle, est toujours dans le lien diffusé). On ne garde QUE les épiques (4+).
local QUALITY_BY_COLOR = {
    ["9d9d9d"] = 0,  -- médiocre
    ["ffffff"] = 1,  -- commun
    ["1eff00"] = 2,  -- inhabituel
    ["0070dd"] = 3,  -- rare
    ["a335ee"] = 4,  -- épique
    ["ff8000"] = 5,  -- légendaire
}

-- ===================== État interne =====================

local started = false
local currentBoss = nil   -- { name, id, at } posé par ENCOUNTER_END

-- ===================== Réglages (lazy init) =====================
-- ON par défaut : le butin épique de raid est déjà public (diffusé en /raid).
-- Ce n'est pas une donnée privée comme le recensement → pas d'opt-in strict.

local function LootSettings()
    if type(AuberdineExporterDB) ~= "table" then
        return { enabled = true }
    end
    AuberdineExporterDB.settings = AuberdineExporterDB.settings or {}
    local s = AuberdineExporterDB.settings.raidLoot
    if type(s) ~= "table" then
        s = {}
        AuberdineExporterDB.settings.raidLoot = s
    end
    if s.enabled == nil then s.enabled = true end
    return s
end
function LootTracker:GetSettings() return LootSettings() end

-- ===================== Stockage =====================

local function EnsureDB()
    AuberdineExporterDB = AuberdineExporterDB or {}
    AuberdineExporterDB.raidLoots = AuberdineExporterDB.raidLoots or {}
    local d = AuberdineExporterDB.raidLoots
    d.items = d.items or {}   -- [loot_uid] = { ... }
    return d
end

-- ===================== Helpers =====================

local function IsValidRealm()
    return AuberdineExporter.IsOnAuberdine and AuberdineExporter:IsOnAuberdine()
end

local function LootPrint(msg)
    print("|cff00ff00AuberdineExporter|r |cffffd100[Butin]|r " .. msg)
end

local function StripRealm(name)
    if not name then return name end
    return name:match("^([^%-]+)") or name
end

-- En instance de raid ? (les épiques de donjon ne matcheraient aucun raid WCL)
local function InRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

local function CountItems(d)
    local n = 0
    for _ in pairs(d.items) do n = n + 1 end
    return n
end

-- Extrait { itemId, itemLink, itemName, quality } d'un lien d'objet, ou nil.
local function ParseItemLink(link)
    if not link then return nil end
    local color = link:match("|c%x%x(%x%x%x%x%x%x)|Hitem:")  -- saute l'octet alpha
    local itemId = link:match("|Hitem:(%d+)")
    local itemName = link:match("|h%[(.-)%]|h")
    if not itemId then return nil end
    local quality = color and QUALITY_BY_COLOR[color:lower()] or nil
    return {
        itemId = tonumber(itemId),
        itemLink = link,
        itemName = itemName,
        quality = quality,
    }
end

-- Construit, à partir d'un GlobalString de butin, un pattern Lua à captures.
-- Échappe les magic-chars, transforme %s→(.-) et %d→(%d+). Locale-safe.
local function ToLootPattern(globalStr)
    if not globalStr then return nil end
    -- 1. échappe les magic-chars Lua. Le `%` des `%s`/`%d` n'est PAS dans la
    --    classe → les spécificateurs de format survivent intacts.
    local p = globalStr:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    -- 2. `%s` → capture non-greedy, `%d` → capture de chiffres. Le pattern
    --    "%%s" matche le littéral `%s` (2 car.) ; la sub "(%%d+)" produit
    --    littéralement "(%d+)".
    p = p:gsub("%%s", "(.-)")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p
end

-- Patterns de butin (construits une fois). Ordre : multiples avant simples
-- (le pattern simple matcherait aussi un message multiple en tronquant).
local PATTERNS = nil
local function BuildPatterns()
    if PATTERNS then return PATTERNS end
    local me = UnitName("player")
    PATTERNS = {
        -- self multiple : item, qty
        { p = ToLootPattern(LOOT_ITEM_SELF_MULTIPLE), self = true,  item = 1, qty = 2 },
        -- self : item
        { p = ToLootPattern(LOOT_ITEM_SELF),          self = true,  item = 1 },
        -- autre, multiple : who, item, qty
        { p = ToLootPattern(LOOT_ITEM_MULTIPLE),      self = false, who = 1, item = 2, qty = 3 },
        -- autre : who, item
        { p = ToLootPattern(LOOT_ITEM),               self = false, who = 1, item = 2 },
    }
    PATTERNS._me = me
    return PATTERNS
end

-- Identité stable d'un drop physique (idempotence ré-export + fusion gargul).
local function LootUid(recipient, itemId, bossId, ts)
    return string.format("%s:%d:%d:%d", StripRealm(recipient or "?"), bossId or 0, itemId or 0, ts or 0)
end

-- ===================== Capture passive (chat) =====================

local function RecordLoot(entry)
    local d = EnsureDB()
    local uid = entry.lootUid
    -- Fusion : si la prise existe déjà (ré-émission, ou même drop revu), on
    -- complète les champs manquants sans écraser (gargul reste autoritaire).
    local prev = d.items[uid]
    if prev then
        prev.itemName    = prev.itemName    or entry.itemName
        prev.itemLink    = prev.itemLink    or entry.itemLink
        prev.bossName    = prev.bossName    or entry.bossName
        if entry.source == "gargul" then
            prev.source      = "gargul"
            prev.disposition = entry.disposition or prev.disposition
            prev.reason      = entry.reason or prev.reason
            prev.awardedBy   = entry.awardedBy or prev.awardedBy
        end
        return false
    end
    d.items[uid] = entry
    -- Rétention : si on dépasse le plafond, oublie les plus anciens.
    if CountItems(d) > MAX_LOOTS then
        local oldestUid, oldestAt
        for k, v in pairs(d.items) do
            if not oldestAt or (v.lootedAt or 0) < oldestAt then oldestAt = v.lootedAt or 0; oldestUid = k end
        end
        if oldestUid then d.items[oldestUid] = nil end
    end
    return true
end

local function HandleLootMessage(msg)
    if not LootSettings().enabled then return end
    if not InRaidInstance() then return end           -- raids seulement
    if not IsValidRealm() then return end

    local link = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not link then return end
    local item = ParseItemLink(link)
    if not item or not item.itemId then return end
    if not item.quality or item.quality < 4 then return end  -- épiques seulement

    -- Destinataire : "Vous" → soi-même, sinon le nom capturé.
    local P = BuildPatterns()
    local recipient
    for _, def in ipairs(P) do
        if def.p then
            local c1, c2, c3 = msg:match(def.p)
            if c1 then
                recipient = def.self and P._me or c1
                break
            end
        end
    end
    if not recipient then return end

    local ts = time()
    local boss = currentBoss
    local bossName, bossId, bossKill = nil, 0, nil
    if boss and (ts - (boss.at or 0)) <= BOSS_WINDOW then
        bossName = boss.name
        bossId = boss.id or 0
        -- Transmis au serveur : un loot ramassé après un WIPE (butin de
        -- trash, corps relevé tard) ne doit pas être recoupé comme si le
        -- boss était mort à cet horodatage.
        bossKill = boss.success
    end

    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    local uid = LootUid(recipient, item.itemId, bossId, ts)
    local entry = {
        lootUid      = uid,
        recipient    = StripRealm(recipient),
        itemId       = item.itemId,
        itemName     = item.itemName,
        itemLink     = item.itemLink,
        itemQuality  = item.quality,
        bossName     = bossName,
        bossKill     = bossKill,
        instanceName = name,
        instanceId   = instanceID or 0,
        lootedAt     = ts,
        source       = "chat",
    }
    local isNew = RecordLoot(entry)
    -- Capture DIRECTE et nouvelle : broadcast aux pairs (Comms.lua, kind L,
    -- hop 1). Un pair porteur d'uploader hors du raid pourra porter ce loot
    -- dans son export si aucun raideur n'exporte jamais le sien.
    if isNew and AuberdineComms and AuberdineComms.BroadcastLoot then
        AuberdineComms:BroadcastLoot(entry)
    end
end

-- Butin reçu d'un pair via le mesh (Comms.lua). Le loot_uid est reconstruit
-- avec les champs du BROADCASTEUR (mêmes recipient/bossId/itemId/at) : si
-- l'observateur d'origine exporte un jour lui-même, le serveur fusionne les
-- deux lignes sur cet uid et la version directe prime (relayed 1 → 0).
-- Garde anti-doublon locale : un drop déjà capté en direct (uid décalé de
-- quelques secondes entre observateurs) n'est pas re-stocké en relais.
function LootTracker.AddRelayed(s)
    if type(s) ~= "table" then return false end
    if not LootSettings().enabled then return false end
    if not IsValidRealm() then return false end
    local itemId = tonumber(s.itemId)
    local at = tonumber(s.lootedAt)
    local recipient = type(s.recipient) == "string" and StripRealm(s.recipient) or ""
    local quality = tonumber(s.itemQuality)
    if not itemId or itemId <= 0 or not at or recipient == "" then return false end
    if quality and quality < 4 then return false end  -- épiques seulement

    local d = EnsureDB()
    for _, v in pairs(d.items) do
        if v.itemId == itemId and v.recipient == recipient
            and math.abs((v.lootedAt or 0) - at) <= 10 then
            return false  -- même drop déjà capté (direct ou relais antérieur)
        end
    end
    local bossId = tonumber(s.bossId) or 0
    return RecordLoot({
        lootUid      = LootUid(recipient, itemId, bossId, at),
        recipient    = recipient,
        itemId       = itemId,
        itemName     = type(s.itemName) == "string" and s.itemName or nil,
        itemLink     = nil,  -- le lien complet ne voyage pas (trop long)
        itemQuality  = quality,
        bossName     = type(s.bossName) == "string" and s.bossName or nil,
        bossKill     = s.bossKill,
        instanceName = type(s.instanceName) == "string" and s.instanceName or nil,
        instanceId   = tonumber(s.instanceId) or 0,
        lootedAt     = at,
        source       = "chat",
        relayed      = true,
    })
end

-- ===================== Lecture Gargul (best-effort) =====================
-- Gargul stocke un historique d'attributions dans sa SavedVariable. Schéma non
-- garanti (addon tiers) → lecture DÉFENSIVE sous pcall, ignore tout ce qui ne
-- ressemble pas à ce qu'on attend. Non installé chez le dev : à valider en réel.

local function HarvestGargul()
    if not LootSettings().enabled then return end
    if not IsValidRealm() then return end
    local ok = pcall(function()
        local g = _G.GargulDB
        if type(g) ~= "table" then return end
        -- Gargul range son journal d'attributions sous des clés variables selon
        -- la version (AwardHistory / LootHistory). On tente les deux.
        local history = g.AwardHistory or g.LootHistory
        if type(history) ~= "table" then return end

        for _, h in pairs(history) do
            if type(h) == "table" then
                local link = h.itemLink or h.ItemLink
                local who = h.awardedTo or h.winner or h.AwardedTo or h.Winner
                local ts = tonumber(h.timestamp or h.Timestamp or h.time)
                local item = ParseItemLink(link)
                if item and who and ts and item.quality and item.quality >= 4 then
                    -- disposition : Gargul marque les DE / banque de guilde.
                    local disposition = "awarded"
                    local lw = tostring(who):lower()
                    if lw:find("disenchant") or lw:find("_disenchant") then disposition = "disenchanted" end
                    if h.isBankItem or h.OS == "BANK" then disposition = "banked" end

                    -- Fusion avec la capture chat : le même drop physique a
                    -- déjà (le plus souvent) une entrée source=chat dont
                    -- l'uid inclut le bossId et l'heure exacte du message —
                    -- impossible de recomposer cette clé ici (Gargul a son
                    -- propre horodatage, décalé par la décision d'attribution).
                    -- On cherche donc l'entrée existante correspondante
                    -- (même item, même destinataire, ±10 min) et on la
                    -- complète au lieu de créer un doublon côté serveur.
                    local d = EnsureDB()
                    local strippedWho = StripRealm(who)
                    local uid = nil
                    for k, v in pairs(d.items) do
                        if v.itemId == item.itemId and v.recipient == strippedWho
                           and math.abs((v.lootedAt or 0) - ts) <= GARGUL_MATCH_WINDOW then
                            uid = k
                            break
                        end
                    end
                    uid = uid or LootUid(who, item.itemId, 0, ts)
                    RecordLoot({
                        lootUid      = uid,
                        recipient    = StripRealm(who),
                        itemId       = item.itemId,
                        itemName     = item.itemName,
                        itemLink     = item.itemLink,
                        itemQuality  = item.quality,
                        bossName     = nil,
                        instanceName = nil,
                        instanceId   = 0,
                        lootedAt     = ts,
                        source       = "gargul",
                        disposition  = disposition,
                        reason       = h.reason or h.note,
                        awardedBy    = h.awardedBy or h.master,
                    })
                end
            end
        end
    end)
    if not ok then
        -- silencieux : Gargul absent ou format inattendu, on s'en remet au chat.
    end
end

-- ===================== Export (consommé par ExportToJSON) =====================
-- Émet la liste des loots ; purge au passage les trop vieux. La liste complète
-- est ré-envoyée à chaque export — le serveur déduplique par loot_uid.

function LootTracker:GetExportData()
    -- Tente d'aspirer l'historique Gargul juste avant l'export (si présent).
    HarvestGargul()

    local d = EnsureDB()
    local now = time()
    local items = {}

    for uid, it in pairs(d.items) do
        if (now - (it.lootedAt or 0)) > PRUNE_AFTER then
            d.items[uid] = nil
        else
            items[#items + 1] = {
                lootUid     = uid,
                recipient   = it.recipient,
                itemId      = it.itemId,
                itemName    = it.itemName,
                itemLink    = it.itemLink,
                itemQuality = it.itemQuality,
                bossName    = it.bossName,
                bossKill    = it.bossKill,
                instanceName= it.instanceName,
                instanceId  = it.instanceId,
                lootedAt    = (it.lootedAt or now) * 1000,  -- epoch MS (aligné raid_analyses)
                source      = it.source,
                disposition = it.disposition,
                reason      = it.reason,
                awardedBy   = it.awardedBy,
                relayed     = it.relayed or nil,  -- capté par un pair via le mesh
            }
        end
    end

    return { schema = 1, items = items }
end

-- ===================== Événements =====================

local function StartLootTracker()
    if started then return end
    if not IsValidRealm() then return end
    started = true
    EnsureDB()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("CHAT_MSG_LOOT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        StartLootTracker()
    elseif not LootSettings().enabled then
        return
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        currentBoss = { id = encounterID, name = encounterName, at = time() }
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        -- Boss du dernier combat (réussi ou non) : le loot tombe juste
        -- après. On mémorise le succès pour que le serveur puisse écarter
        -- les loots post-wipe du recoupement avec les kills WCL.
        currentBoss = { id = encounterID, name = encounterName, at = time(), success = (success == 1) }
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        HandleLootMessage(msg)
    end
end)
