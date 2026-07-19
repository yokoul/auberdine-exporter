-- Comms.lua — mesh addon-à-addon du canal worldbuffs (modèle Nova World Buffs)
--
-- Relie les utilisateurs de l'addon entre eux via C_ChatInfo.SendAddonMessage
-- (canal GUILD + canal custom "auberdine"), dans les DEUX sens :
--   * DESCENDANT : ceux dont l'AuberdineUploader a un agenda frais le
--     rebroadcasten ; ceux SANS uploader le reçoivent et l'affichent
--     (Worldbuffs.lua, feed relayé). Bonus pour tous : les SavedVariables ne
--     se relisant jamais en session, seul le relais d'un pair fraîchement
--     loggué rafraîchit l'agenda EN COURS de session.
--   * MONTANT : chaque pose observée (WorldbuffLogger.lua) est broadcastée ;
--     les porteurs d'uploader stockent les observations des pairs sans
--     uploader (relayed = true) et leur uploader les pousse vers
--     /ingest/worldbuffs/sightings.
--
-- CONFIANCE : un message addon est forgeable par n'importe quel joueur. Les
-- observations relayées sont donc marquées relayed=true de bout en bout — le
-- serveur les trace et les agrégats sensibles (Hall of Fame) ne comptent que
-- les observations directes authentifiées. Anti-boucle : seules les
-- observations DIRECTES sont émises (hop max 1), jamais un relais.
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

-- ===================== Poses observées : émission =====================

-- Appelé par WorldbuffLogger.record() sur une observation DIRECTE uniquement
-- (jamais pour un relais reçu : hop max 1, pas de boucle). Jitter 0-3 s pour
-- étaler les 40 broadcasts simultanés d'une pose de raid.
function Comms:BroadcastSighting(s)
    if not self:IsEnabled() or not onSupportedRealm() then return end
    local msg = table.concat({
        SCHEMA, "S",
        tostring(s.spellId), tostring(s.at),
        tostring(s.name or ""):sub(1, 48),
        tostring(s.character or ""):sub(1, 48),
        tostring(s.realm or ""):sub(1, 48),
        tostring(s.guild or ""):sub(1, 48),
        tostring(s.faction or ""),
        tostring(s.zone or ""):sub(1, 48),
    }, FS)
    C_Timer.After(math.random() * 3, function()
        if Comms:IsEnabled() then broadcast(msg) end
    end)
end

-- ===================== Réception =====================

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

local function onSighting(fields)
    if not relayBudgetOk() then return end
    local now = (GetServerTime and GetServerTime() or time())
    local at = tonumber(fields[4])
    -- Une pose relayée est quasi temps réel : hors [-2 h, +10 min] = rebut.
    if not at or at < now - 7200 or at > now + 600 then return end
    local faction = tostring(fields[9] or ""):upper()
    if faction ~= "HORDE" and faction ~= "ALLIANCE" then faction = "" end
    local added = AuberdineWorldbuffLogger and AuberdineWorldbuffLogger.AddRelayed
        and AuberdineWorldbuffLogger.AddRelayed({
            spellId = tonumber(fields[3]),
            at = at,
            name = fields[5],
            character = fields[6],
            realm = fields[7],
            guild = fields[8],
            faction = faction,
            zone = fields[10],
        })
    if added then
        debugPrint("pose relayée : " .. tostring(fields[5]) .. " par " .. tostring(fields[6]))
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
end)
