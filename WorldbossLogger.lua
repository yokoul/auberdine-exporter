-- WorldbossLogger.lua — morts de world bosses OBSERVÉES en jeu
--
-- Les world bosses ERA (Azuregos, Kazzak, dragons du Cauchemar) sont loggés
-- en trash par WarcraftLogs : aucun ID d'encounter exploitable côté site.
-- Ce module comble le trou : quand la mort d'un de ces PNJ passe dans le
-- combat log (UNIT_DIED, portée ~50 m — être sur place suffit), on
-- l'enregistre dans AuberdineExporterDB.worldbossSightings, l'uploader la
-- pousse vers /ingest/worldbosses/sightings, et le site en tire des timers
-- de spawn communautaires.
--
-- Même modèle que WorldbuffLogger : observation DIRECTE broadcastée sur le
-- mesh (Comms.lua, kind W, hop 1), les pairs porteurs d'uploader stockent
-- les relais (relayed = true), et tout le monde voit l'annonce en jeu.

local DEDUP_WINDOW = 3600          -- s : un même boss ne meurt qu'une fois par spawn
local MAX_ENTRIES = 60             -- plafond dur (événements rares)
local MAX_AGE = 30 * 24 * 3600     -- purge des observations de plus de 30 jours

-- npc_id (cmangos) → nom canonique. Le CLEU donne destName localisé, on
-- l'envoie tel quel en `name` ; le serveur mappe par npc_id, pas par libellé.
local WORLD_BOSSES = {
  [6109]  = "Azuregos",
  [12397] = "Seigneur Kazzak",
  [14887] = "Ysondre",
  [14888] = "Léthon",
  [14889] = "Émeriss",
  [14890] = "Taerar",
}

AuberdineWorldbossLogger = AuberdineWorldbossLogger or {}

local function sightings()
  AuberdineExporterDB = AuberdineExporterDB or {}
  if type(AuberdineExporterDB.worldbossSightings) ~= "table" then
    AuberdineExporterDB.worldbossSightings = {}
  end
  return AuberdineExporterDB.worldbossSightings
end

local function prune(list)
  local cutoff = (GetServerTime and GetServerTime() or time()) - MAX_AGE
  local i = 1
  while i <= #list do
    if (tonumber(list[i].at) or 0) < cutoff then
      table.remove(list, i)
    else
      i = i + 1
    end
  end
  while #list > MAX_ENTRIES do
    table.remove(list, 1)
  end
end

local function alreadyLogged(list, npcId, at, character)
  for _, s in ipairs(list) do
    if s.npcId == npcId and math.abs((tonumber(s.at) or 0) - at) < DEDUP_WINDOW
        and (character == nil or s.character == character) then
      return true
    end
  end
  return false
end

-- Annonce en jeu (observation directe comme relais reçu) : c'est la valeur
-- communautaire immédiate — savoir que le boss vient de tomber. Dédupée par
-- le même DEDUP_WINDOW que le stockage.
local announced = {}  -- npcId → dernier at annoncé

local function announce(npcId, at)
  if announced[npcId] and math.abs(announced[npcId] - at) < DEDUP_WINDOW then return end
  announced[npcId] = at
  local name = WORLD_BOSSES[npcId] or ("PNJ " .. npcId)
  print("|cff00ff00Auberdine:|r |cffff8000" .. name .. "|r vient d'être vaincu !")
end

local function record(npcId, destName)
  local list = sightings()
  local at = GetServerTime and GetServerTime() or time()
  if alreadyLogged(list, npcId, at, UnitName("player")) then return end
  local guild = GetGuildInfo("player")
  local faction = UnitFactionGroup("player")
  local entry = {
    npcId = npcId,
    name = destName or WORLD_BOSSES[npcId],
    at = at,
    character = UnitName("player"),
    realm = GetRealmName(),
    guild = guild or "",
    faction = faction and faction:upper() or "",
    zone = GetRealZoneText() or "",
  }
  list[#list + 1] = entry
  prune(list)
  announce(npcId, at)
  -- Observation DIRECTE uniquement : broadcast aux pairs (Comms.lua, hop 1).
  if AuberdineComms and AuberdineComms.BroadcastWorldboss then
    AuberdineComms:BroadcastWorldboss(entry)
  end
end

-- Observation reçue d'un pair via le mesh (Comms.lua). L'annonce est pour
-- tout le monde ; le STOCKAGE est réservé aux porteurs d'uploader (décidé
-- par l'appelant, comme pour les poses de world buffs).
function AuberdineWorldbossLogger.AddRelayed(s, storeIt)
  if type(s) ~= "table" then return false end
  local npcId = tonumber(s.npcId)
  local at = tonumber(s.at)
  local character = type(s.character) == "string" and s.character or ""
  local realm = type(s.realm) == "string" and s.realm or ""
  if not npcId or not WORLD_BOSSES[npcId] or not at or character == "" or realm == "" then
    return false
  end
  announce(npcId, at)
  if not storeIt then return false end
  -- Jamais soi-même en relais (sa propre observation directe fait foi).
  if character == UnitName("player") and realm == GetRealmName() then return false end
  local list = sightings()
  if alreadyLogged(list, npcId, at, character) then return false end
  list[#list + 1] = {
    npcId = npcId,
    name = tostring(s.name or ""),
    at = at,
    character = character,
    realm = realm,
    guild = tostring(s.guild or ""),
    faction = tostring(s.faction or ""),
    zone = tostring(s.zone or ""),
    relayed = true,
  }
  prune(list)
  return true
end

-- Extrait le npc_id d'un GUID de créature ("Creature-0-…-npcId-spawnUID").
local function npcIdFromGuid(guid)
  if type(guid) ~= "string" then return nil end
  local unitType, _, _, _, _, npcId = strsplit("-", guid)
  if unitType ~= "Creature" then return nil end
  return tonumber(npcId)
end

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event)
  if AuberdineExporter and AuberdineExporter.IsOnAuberdine
      and not AuberdineExporter:IsOnAuberdine() then
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    prune(sightings())
    return
  end
  local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
  if subevent ~= "UNIT_DIED" then return end
  local npcId = npcIdFromGuid(destGUID)
  if npcId and WORLD_BOSSES[npcId] then
    record(npcId, destName)
  end
end)
