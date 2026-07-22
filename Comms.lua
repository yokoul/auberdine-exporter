-- Comms.lua — mesh addon-à-addon d'Auberdine (modèle Nova World Buffs)
--
-- Relie les utilisateurs de l'addon entre eux via C_ChatInfo.SendAddonMessage
-- (canal GUILD + canal custom "auberdine"), dans les DEUX sens :
--   * DESCENDANT : ceux dont l'AuberdineUploader a un agenda frais le
--     rebroadcasten ; ceux SANS uploader le reçoivent et l'affichent
--     (Worldbuffs.lua, feed relayé). Bonus pour tous : les SavedVariables ne
--     se relisant jamais en session, seul le relais d'un pair fraîchement
--     loggué rafraîchit l'agenda EN COURS de session.
--   * MONTANT : chaque observation directe est broadcastée ; les porteurs
--     d'uploader stockent les observations des pairs sans uploader
--     (relayed = true) et leur uploader les pousse vers /ingest.
--
-- Kinds du protocole (v1) :
--   F/R  agenda worldbuffs planifié (descendant, requête/réponse)
--   S    pose de world buff observée (WorldbuffLogger.lua)
--   W    mort de world boss observée (WorldbossLogger.lua) + annonce en jeu
--   K    boss de raid vaincu (KillLogger.lua) + annonce en jeu
--   L    butin épique de raid capté (LootTracker.lua), pas d'annonce
--
-- CONFIANCE : un message addon est forgeable par n'importe quel joueur. Les
-- observations relayées sont donc marquées relayed=true de bout en bout — le
-- serveur les trace et les agrégats sensibles (Hall of Fame, `verified`) ne
-- comptent que les observations directes authentifiées. Anti-boucle : seules
-- les observations DIRECTES sont émises (hop max 1), jamais un relais.
--
-- Paramétrable dans les réglages, ACTIF par défaut (les données échangées
-- sont celles d'utilisateurs de l'addon, déjà consentants par installation).

AuberdineComms = AuberdineComms or {}
local Comms = AuberdineComms

-- ===================== Configuration =====================

local PREFIX = "AubExp"            -- prefix addon (16 caractères max)
local CHANNEL_NAME = "auberdine"   -- canal custom cross-guilde, retiré du chat
local SCHEMA = "1"                 -- version du protocole filaire

local MSG_MAX = 240                -- octets utiles par message (plafond 255)
local SEND_SPACING = 0.5           -- s entre deux envois (throttle doux)
local JOIN_DELAY = 12              -- s après PEW avant de joindre le canal
local ANNOUNCE_DELAY = 25          -- s après PEW : broadcast/REQ de l'agenda
local STALE_SECONDS = 12 * 3600    -- agenda plus vieux : on ne le relaie plus
local REQ_IF_OLDER = 2 * 3600      -- agenda généré il y a +2 h → on quémande
local REQUERY_EVERY = 25 * 60      -- sans agenda frais : on requémande à ce rythme
local FEED_MAX_ENTRIES = 12        -- entrées max broadcastées / acceptées ×2
local RELAY_BURST_MAX = 80         -- observations relayées acceptées / fenêtre
local RELAY_BURST_WINDOW = 600     -- s (fenêtre glissante anti-flood)

-- Séparateurs de contrôle (jamais présents dans du texte de jeu) :
local FS = "\31"  -- champs du message
local RS = "\30"  -- entrées d'agenda entre elles
local GS = "\29"  -- champs d'une entrée d'agenda

-- ===================== Réglages (lazy init) =====================

local function CommsSettings()
    if type(AuberdineExporterDB) ~= "table" then
        return { enabled = true }
    end
    AuberdineExporterDB.settings = AuberdineExporterDB.settings or {}
    local s = AuberdineExporterDB.settings.comms
    if type(s) ~= "table" then
        s = {}
        AuberdineExporterDB.settings.comms = s
    end
    if s.enabled == nil then s.enabled = true end  -- ACTIF par défaut
    return s
end
function Comms:GetSettings() return CommsSettings() end
function Comms:IsEnabled() return CommsSettings().enabled and true or false end

local function debugPrint(msg)
    if AuberdineExporterDB and AuberdineExporterDB.settings
        and AuberdineExporterDB.settings.verboseDebug then
        print("|cff00ff00Auberdine:|r [comms] " .. msg)
    end
end

local function onSupportedRealm()
    if AuberdineExporter and AuberdineExporter.IsOnAuberdine then
        return AuberdineExporter:IsOnAuberdine()
    end
    return true
end

-- ===================== Émission (file espacée) =====================

-- Pas de ChatThrottleLib vendorée : nos volumes (2-3 messages épisodiques)
-- restent loin du throttle Blizzard, une file espacée de 0,5 s suffit.
local sendQueue = {}
local pumping = false

local function channelId()
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then return id end
    return nil
end

local function pump()
    local item = table.remove(sendQueue, 1)
    if not item then pumping = false return end
    C_ChatInfo.SendAddonMessage(PREFIX, item.msg, item.chatType, item.target)
    C_Timer.After(SEND_SPACING, pump)
end

local function enqueue(msg, chatType, target)
    sendQueue[#sendQueue + 1] = { msg = msg, chatType = chatType, target = target }
    if not pumping then
        pumping = true
        C_Timer.After(0, pump)
    end
end

-- Envoie sur tous les transports disponibles (guilde + canal custom).
local function broadcast(msg)
    if #msg > 253 then msg = msg:sub(1, 253) end
    if IsInGuild() then enqueue(msg, "GUILD") end
    local id = channelId()
    if id then enqueue(msg, "CHANNEL", id) end
end

-- ===================== Canal custom =====================

-- Joindre trop tôt après le login vole le slot des canaux serveur (Général…) :
-- on attend JOIN_DELAY puis on retente tant que le canal n'est pas là.
local joinTries = 0

local function hideChannelFromChat()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local cf = _G["ChatFrame" .. i]
        if cf and ChatFrame_RemoveChannel then
            ChatFrame_RemoveChannel(cf, CHANNEL_NAME)
        end
    end
end

local function ensureChannel()
    if not Comms:IsEnabled() or not onSupportedRealm() then return end
    if channelId() then hideChannelFromChat() return end
    joinTries = joinTries + 1
    if joinTries > 5 then return end
    JoinChannelByName(CHANNEL_NAME)
    C_Timer.After(10, ensureChannel)
end

-- ===================== Agenda : sérialisation =====================

-- 1␟F␟<generatedAt>␟buff␝at␝guild␝faction␞buff␝at␝…  (chunks < MSG_MAX,
-- chacun auto-suffisant : les entrées sont indépendantes, le récepteur
-- fusionne les chunks d'un même generatedAt).
local function serializeFeedChunks(feed)
    local chunks = {}
    local header = SCHEMA .. FS .. "F" .. FS .. tostring(feed.generatedAt) .. FS
    local cur = nil
    local count = 0
    local now = time()
    for _, e in ipairs(feed.entries) do
        local at = tonumber(e.at)
        if at and at >= now - 1800 and count < FEED_MAX_ENTRIES then
            count = count + 1
            local blob = table.concat({
                tostring(e.buff or ""):sub(1, 48),
                tostring(at),
                tostring(e.guild or ""):sub(1, 48),
                tostring(e.faction or ""),
            }, GS)
            if cur and #cur + #blob + 1 > MSG_MAX then
                chunks[#chunks + 1] = cur
                cur = nil
            end
            cur = cur and (cur .. RS .. blob) or (header .. blob)
        end
    end
    if cur then chunks[#chunks + 1] = cur end
    return chunks
end

-- generatedAt le plus frais VU passer (émis ou reçu) : sert à taire les
-- réponses redondantes quand un pair a déjà répondu à une requête.
local lastSeenGen = 0

local function broadcastFeed(reason)
    local feed = AuberdineWorldbuffs and AuberdineWorldbuffs.GetBestFeed
        and AuberdineWorldbuffs.GetBestFeed() or nil
    if not feed or feed.age > STALE_SECONDS then return end
    local chunks = serializeFeedChunks(feed)
    for _, c in ipairs(chunks) do broadcast(c) end
    if #chunks > 0 then
        lastSeenGen = math.max(lastSeenGen, feed.generatedAt)
        debugPrint("agenda broadcasté (" .. reason .. ", " .. #chunks .. " msg)")
    end
end

local function requestFeed()
    local feed = AuberdineWorldbuffs and AuberdineWorldbuffs.GetBestFeed
        and AuberdineWorldbuffs.GetBestFeed() or nil
    local have = feed and feed.generatedAt or 0
    broadcast(SCHEMA .. FS .. "R" .. FS .. tostring(have))
    debugPrint("agenda demandé aux pairs (have=" .. have .. ")")
end

-- Requête UNIQUE au login = angle mort : un pair qui a l'agenda mais se
-- connecte APRÈS nous ne nous l'enverra jamais (il ne rediffuse qu'à SON
-- login ou sur requête). Tant qu'on n'a rien de frais à montrer — pas
-- d'uploader, ou uploader en panne — on requémande donc périodiquement.
-- Un porteur d'uploader au feed frais ne quémande pas (il OFFRE), et dès
-- qu'un relais frais arrive, feed.age/generatedAt repassent sous les seuils
-- et la requête s'éteint d'elle-même — pas de trafic inutile.
local function scheduleRequery()
    C_Timer.After(REQUERY_EVERY, function()
        if Comms:IsEnabled() and onSupportedRealm() then
            local feed = AuberdineWorldbuffs and AuberdineWorldbuffs.GetBestFeed
                and AuberdineWorldbuffs.GetBestFeed() or nil
            if (not feed) or feed.age > STALE_SECONDS
                or (time() - feed.generatedAt > REQ_IF_OLDER) then
                requestFeed()
            end
        end
        scheduleRequery()
    end)
end

-- ===================== Observations : émission =====================

-- Émission différée d'une observation directe : jitter 0-3 s pour étaler les
-- 40 broadcasts simultanés d'un même événement de raid (pose, kill, loot).
local function broadcastJittered(msg)
    C_Timer.After(math.random() * 3, function()
        if Comms:IsEnabled() then broadcast(msg) end
    end)
end

-- Appelé par WorldbuffLogger.record() sur une observation DIRECTE uniquement
-- (jamais pour un relais reçu : hop max 1, pas de boucle).
function Comms:BroadcastSighting(s)
    if not self:IsEnabled() or not onSupportedRealm() then return end
    broadcastJittered(table.concat({
        SCHEMA, "S",
        tostring(s.spellId), tostring(s.at),
        tostring(s.name or ""):sub(1, 48),
        tostring(s.character or ""):sub(1, 48),
        tostring(s.realm or ""):sub(1, 48),
        tostring(s.guild or ""):sub(1, 48),
        tostring(s.faction or ""),
        tostring(s.zone or ""):sub(1, 48),
    }, FS))
end

-- World boss observé — MORT ou PRÉSENCE (WorldbossLogger, directe uniquement).
-- kind (fields[11]) et subzone (fields[12]) sont AJOUTÉS EN FIN : les clients
-- d'avant la présence lisent fields[3..10] et ignorent la queue → compatible.
function Comms:BroadcastWorldboss(s)
    if not self:IsEnabled() or not onSupportedRealm() then return end
    broadcastJittered(table.concat({
        SCHEMA, "W",
        tostring(s.npcId), tostring(s.at),
        tostring(s.name or ""):sub(1, 48),
        tostring(s.character or ""):sub(1, 48),
        tostring(s.realm or ""):sub(1, 48),
        tostring(s.guild or ""):sub(1, 48),
        tostring(s.faction or ""),
        tostring(s.zone or ""):sub(1, 48),
        (s.kind == "alive") and "alive" or "death",
        tostring(s.subzone or ""):sub(1, 48),
    }, FS))
end

-- Observation worldboss ÉTENDUE — esprit croisé (shade) ou absence signalée
-- (absent). Kind « B » À PART, même layout que W : les clients ≤ 1.7.10
-- coercent tout kind W inconnu en 'death' (fausse mort relayée) — sur un
-- kind de message inconnu, ils ignorent la trame entière. C'est le but.
function Comms:BroadcastBossExtra(s)
    if not self:IsEnabled() or not onSupportedRealm() then return end
    broadcastJittered(table.concat({
        SCHEMA, "B",
        tostring(s.npcId), tostring(s.at),
        tostring(s.name or ""):sub(1, 48),
        tostring(s.character or ""):sub(1, 48),
        tostring(s.realm or ""):sub(1, 48),
        tostring(s.guild or ""):sub(1, 48),
        tostring(s.faction or ""),
        tostring(s.zone or ""):sub(1, 48),
        tostring(s.kind or ""),
        tostring(s.subzone or ""):sub(1, 48),
    }, FS))
end

-- Boss de raid vaincu (KillLogger.record, directe uniquement).
function Comms:BroadcastKill(s)
    if not self:IsEnabled() or not onSupportedRealm() then return end
    broadcastJittered(table.concat({
        SCHEMA, "K",
        tostring(s.encounterId), tostring(s.at),
        tostring(s.name or ""):sub(1, 48),
        tostring(s.character or ""):sub(1, 48),
        tostring(s.realm or ""):sub(1, 48),
        tostring(s.guild or ""):sub(1, 48),
        tostring(s.faction or ""),
        tostring(s.instanceId or 0),
    }, FS))
end

-- Butin épique capté (LootTracker, direct uniquement). Le message porte les
-- champs qui composent le loot_uid du broadcasteur (recipient, bossId,
-- itemId, at) : le récepteur reconstruit EXACTEMENT le même uid, donc le
-- serveur déduplique relais et export direct entre eux.
function Comms:BroadcastLoot(s)
    if not self:IsEnabled() or not onSupportedRealm() then return end
    broadcastJittered(table.concat({
        SCHEMA, "L",
        tostring(s.itemId), tostring(s.itemQuality or ""),
        tostring(s.lootedAt),
        tostring(s.recipient or ""):sub(1, 48),
        tostring(s.bossId or 0),
        tostring(s.bossName or ""):sub(1, 48),
        tostring(s.instanceId or 0),
        tostring(s.instanceName or ""):sub(1, 48),
        tostring(s.itemName or ""):sub(1, 48),
        s.bossKill == true and "1" or (s.bossKill == false and "0" or ""),
    }, FS))
end

-- ===================== Réception =====================

-- Seuls les clients avec un uploader ACTIF stockent les observations des
-- pairs : sans lui, le journal relayé ne serait jamais poussé (poids mort).
-- Preuve d'uploader = agenda écrit récemment dans AuberdineWorldbuffsFeed
-- (fichier posé hors-jeu par le client local, jamais par le relais).
local function hasLocalUploader()
    local feed = AuberdineWorldbuffsFeed
    local fetchedAt = type(feed) == "table" and tonumber(feed.fetchedAt) or nil
    return fetchedAt ~= nil and (time() - fetchedAt) < 7 * 24 * 3600
end

-- Anti-flood : fenêtre glissante d'acceptation des observations relayées.
local relayTimes = {}

local function relayBudgetOk()
    local now = GetTime()
    local kept = {}
    for _, t in ipairs(relayTimes) do
        if now - t < RELAY_BURST_WINDOW then kept[#kept + 1] = t end
    end
    relayTimes = kept
    if #relayTimes >= RELAY_BURST_MAX then return false end
    relayTimes[#relayTimes + 1] = now
    return true
end

local replyTimer = nil

-- Fenêtre de plausibilité commune aux observations relayées : quasi temps
-- réel, hors [-2 h, +10 min] = rebut.
local function plausibleAt(raw)
    local now = (GetServerTime and GetServerTime() or time())
    local at = tonumber(raw)
    if not at or at < now - 7200 or at > now + 600 then return nil end
    return at
end

local function cleanFaction(raw)
    local faction = tostring(raw or ""):upper()
    if faction ~= "HORDE" and faction ~= "ALLIANCE" then return "" end
    return faction
end

local function onSighting(fields)
    if not hasLocalUploader() then return end
    if not relayBudgetOk() then return end
    local at = plausibleAt(fields[4])
    if not at then return end
    local added = AuberdineWorldbuffLogger and AuberdineWorldbuffLogger.AddRelayed
        and AuberdineWorldbuffLogger.AddRelayed({
            spellId = tonumber(fields[3]),
            at = at,
            name = fields[5],
            character = fields[6],
            realm = fields[7],
            guild = fields[8],
            faction = cleanFaction(fields[9]),
            zone = fields[10],
        })
    if added then
        debugPrint("pose relayée : " .. tostring(fields[5]) .. " par " .. tostring(fields[6]))
    end
end

-- Mort de world boss relayée : l'ANNONCE est pour tout le monde, le stockage
-- (voie montante) pour les seuls porteurs d'uploader — même règle que les
-- poses. Le budget anti-flood s'applique avant tout (annonce comprise).
local function onWorldboss(fields)
    if not relayBudgetOk() then return end
    local at = plausibleAt(fields[4])
    if not at then return end
    -- kind/subzone absents = message d'un client d'avant la présence → 'death'.
    local kind = (fields[11] == "alive") and "alive" or "death"
    local added = AuberdineWorldbossLogger and AuberdineWorldbossLogger.AddRelayed
        and AuberdineWorldbossLogger.AddRelayed({
            npcId = tonumber(fields[3]),
            at = at,
            name = fields[5],
            character = fields[6],
            realm = fields[7],
            guild = fields[8],
            faction = cleanFaction(fields[9]),
            zone = fields[10],
            kind = kind,
            subzone = fields[12],
        }, hasLocalUploader())
    if added then
        debugPrint("world boss relayé (" .. kind .. ") : " .. tostring(fields[5]) .. " par " .. tostring(fields[6]))
    end
end

-- Observation worldboss étendue relayée (kind B) : shade / absent SEULEMENT
-- — tout le reste est rejeté (un death/alive légitime voyage sur W).
-- Silencieux chez le receveur (pas d'annonce), stockage réservé aux porteurs
-- d'uploader, comme les autres kinds.
local function onBossExtra(fields)
    if not relayBudgetOk() then return end
    local at = plausibleAt(fields[4])
    if not at then return end
    local kind = fields[11]
    if kind ~= "shade" and kind ~= "absent" then return end
    local added = AuberdineWorldbossLogger and AuberdineWorldbossLogger.AddRelayed
        and AuberdineWorldbossLogger.AddRelayed({
            npcId = tonumber(fields[3]),
            at = at,
            name = fields[5],
            character = fields[6],
            realm = fields[7],
            guild = fields[8],
            faction = cleanFaction(fields[9]),
            zone = fields[10],
            kind = kind,
            subzone = fields[12],
        }, hasLocalUploader())
    if added then
        debugPrint("worldboss extra relayé (" .. kind .. ") par " .. tostring(fields[6]))
    end
end

-- Boss de raid vaincu, relayé : même partage annonce/stockage que W.
local function onKill(fields)
    if not relayBudgetOk() then return end
    local at = plausibleAt(fields[4])
    if not at then return end
    local added = AuberdineKillLogger and AuberdineKillLogger.AddRelayed
        and AuberdineKillLogger.AddRelayed({
            encounterId = tonumber(fields[3]),
            at = at,
            name = fields[5],
            character = fields[6],
            realm = fields[7],
            guild = fields[8],
            faction = cleanFaction(fields[9]),
            instanceId = tonumber(fields[10]),
        }, hasLocalUploader())
    if added then
        debugPrint("kill relayé : " .. tostring(fields[5]) .. " (" .. tostring(fields[8]) .. ")")
    end
end

-- Butin épique relayé : stockage seul (pas d'annonce — le butin est déjà
-- affiché en clair dans le chat du raid, et l'annoncer à toute la guilde
-- serait du spam les soirs de raid).
local function onLoot(fields)
    if not hasLocalUploader() then return end
    if not relayBudgetOk() then return end
    local at = plausibleAt(fields[5])
    if not at then return end
    local tracker = AuberdineExporter and AuberdineExporter.LootTracker
    local bossKillRaw = fields[12]
    local added = tracker and tracker.AddRelayed
        and tracker.AddRelayed({
            itemId = tonumber(fields[3]),
            itemQuality = tonumber(fields[4]),
            lootedAt = at,
            recipient = fields[6],
            bossId = tonumber(fields[7]),
            bossName = fields[8],
            instanceId = tonumber(fields[9]),
            instanceName = fields[10],
            itemName = fields[11],
            bossKill = (bossKillRaw == "1" and true) or (bossKillRaw == "0" and false) or nil,
        })
    if added then
        debugPrint("loot relayé : " .. tostring(fields[11]) .. " → " .. tostring(fields[6]))
    end
end

local function onFeed(fields)
    local gen = tonumber(fields[3])
    if not gen then return end
    lastSeenGen = math.max(lastSeenGen, gen)
    local entries = {}
    for entryStr in string.gmatch(fields[4] or "", "[^\30]+") do
        local buff, at, guild, faction = strsplit(GS, entryStr)
        at = tonumber(at)
        faction = tostring(faction or ""):upper()
        if faction ~= "HORDE" and faction ~= "ALLIANCE" then faction = "" end
        if buff and buff ~= "" and at and #entries < FEED_MAX_ENTRIES then
            entries[#entries + 1] = {
                buff = buff:sub(1, 48), at = at,
                guild = (guild or ""):sub(1, 48), faction = faction,
            }
        end
    end
    if #entries == 0 then return end
    if AuberdineWorldbuffs and AuberdineWorldbuffs.AcceptRelayedFeed then
        if AuberdineWorldbuffs.AcceptRelayedFeed(gen, entries) then
            debugPrint("agenda relayé reçu (gen=" .. gen .. ", " .. #entries .. " entrées)")
        end
    end
end

local function onRequest(fields)
    local have = tonumber(fields[3]) or 0
    local feed = AuberdineWorldbuffs and AuberdineWorldbuffs.GetBestFeed
        and AuberdineWorldbuffs.GetBestFeed() or nil
    if not feed or feed.generatedAt <= have or feed.age > STALE_SECONDS then return end
    -- Délai aléatoire anti-tempête : le premier pair qui répond taira les
    -- autres (leur lastSeenGen aura rattrapé le sien).
    local myGen = feed.generatedAt
    if replyTimer then replyTimer:Cancel() end
    replyTimer = C_Timer.NewTimer(2 + math.random() * 4, function()
        replyTimer = nil
        if lastSeenGen < myGen then broadcastFeed("réponse à une requête") end
    end)
end

local function onAddonMessage(prefix, msg, _, sender)
    if prefix ~= PREFIX then return end
    if not Comms:IsEnabled() or not onSupportedRealm() then return end
    local short = Ambiguate and Ambiguate(sender or "", "none") or sender
    if short == UnitName("player") then return end
    local fields = { strsplit(FS, msg or "") }
    if fields[1] ~= SCHEMA then return end  -- protocole inconnu : on ignore
    local kind = fields[2]
    if kind == "S" then
        onSighting(fields)
    elseif kind == "W" then
        onWorldboss(fields)
    elseif kind == "B" then
        onBossExtra(fields)
    elseif kind == "K" then
        onKill(fields)
    elseif kind == "L" then
        onLoot(fields)
    elseif kind == "F" then
        onFeed(fields)
    elseif kind == "R" then
        onRequest(fields)
    end
end

-- ===================== Activation / désactivation =====================

function Comms:Enable()
    CommsSettings().enabled = true
    joinTries = 0
    ensureChannel()
end

function Comms:Disable()
    CommsSettings().enabled = false
    if channelId() then LeaveChannelByName(CHANNEL_NAME) end
end

-- ===================== Événements =====================

local loginDone = false
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        onAddonMessage(...)
        return
    end
    -- PLAYER_ENTERING_WORLD (login/reload uniquement, pas les instances)
    if loginDone then return end
    loginDone = true
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    if not Comms:IsEnabled() or not onSupportedRealm() then return end
    C_Timer.After(JOIN_DELAY, ensureChannel)
    C_Timer.After(ANNOUNCE_DELAY, function()
        if not Comms:IsEnabled() then return end
        local feed = AuberdineWorldbuffs and AuberdineWorldbuffs.GetBestFeed
            and AuberdineWorldbuffs.GetBestFeed() or nil
        if feed and feed.age <= STALE_SECONDS and feed.generatedAt > lastSeenGen then
            -- Notre agenda (uploader ou relais persisté) est ce qu'on a vu de
            -- plus frais : on l'offre au mesh — chaque login réinjecte de la
            -- fraîcheur chez ceux dont la session a vieilli.
            broadcastFeed("login")
        elseif not feed or time() - feed.generatedAt > REQ_IF_OLDER then
            requestFeed()
        end
    end)
    scheduleRequery()
end)
