-- WorldbossLogger.lua — world bosses OBSERVÉS en jeu (mort ET présence)
--
-- Les world bosses ERA (Azuregos, Kazzak, dragons du Cauchemar) sont loggés
-- en trash par WarcraftLogs : aucun ID d'encounter exploitable côté site.
-- Ce module comble le trou par DEUX signaux, chacun horodaté et zoné :
--   * MORT (kind='death')  : UNIT_DIED du PNJ dans le combat log.
--   * PRÉSENCE (kind='alive'): le PNJ est vu VIVANT — ciblé, survolé, ou sa
--     plaque de nom apparaît (passer à côté suffit si les plaques ennemies
--     sont actives). Une présence dit « il est debout, là ».
--
-- Le serveur confronte les deux : une présence postérieure à la fenêtre de
-- respawn écrase toute spéculation de retour (un raid sans addon a pu re-tuer
-- et laisser respawn hors de notre vue). Une présence ne se périme jamais
-- d'elle-même côté serveur — on remonte juste QUAND elle a été vue.
--
-- Diffusion : mesh addon-à-addon (Comms.lua, kind W, hop 1) + uploader →
-- /ingest/worldbosses/sightings. Aucun cri sur un canal : seul un print LOCAL
-- (visible du seul joueur) signale la détection.

local DEATH_DEDUP = 3600       -- s : même mort revue dans la fenêtre = même pose
local ALIVE_DEDUP = 600        -- s : même boss revu vivant = même observation
local SHADE_DEDUP = 6 * 3600   -- s : même esprit recroisé = même constat de mort
local ABSENT_DEDUP = 1800      -- s : anti double-signalement manuel d'absence
local MAX_ENTRIES = 80         -- plafond dur (morts + présences + relais)
local MAX_AGE = 30 * 24 * 3600 -- purge des observations de plus de 30 jours

-- npc_id (cmangos) → nom canonique. destName du CLEU est localisé — on l'envoie
-- tel quel en `name` ; le serveur mappe par npc_id, jamais par libellé.
local WORLD_BOSSES = {
  [6109]  = "Azuregos",
  [12397] = "Seigneur Kazzak",
  [14887] = "Ysondre",
  [14888] = "Léthon",
  [14889] = "Émeriss",
  [14890] = "Taerar",
}

-- PNJ fantômes : n'apparaissent qu'APRÈS la mort du boss et persistent
-- ~toute la fenêtre de respawn. En croiser un est une PREUVE de mort passée
-- (kind='shade'), même sans avoir vu le combat — pas une contradiction d'un
-- boss revu debout depuis (respawn précoce/reset : les deux coexistent, le
-- serveur fait primer la présence directe). npc_id esprit → npc_id boss.
local SHADES = {
  [15481] = 6109, -- Esprit d'Azuregos (GUID relevé en jeu, Azshara)
}

-- Zones de guet pour le signalement manuel d'absence (/auberdine absent) :
-- libellés FR et EN (GetRealZoneText est localisé). Les quatre portails du
-- Rêve partagent la même liste — on signale l'absence des QUATRE drakes à
-- cet endroit, le serveur ne retient que celui qu'il croyait là.
local DRAKES = { 14887, 14888, 14889, 14890 }
local ABSENT_ZONES = {
  ["Azshara"]            = { 6109 },
  ["Terres foudroyées"]  = { 12397 },
  ["Blasted Lands"]      = { 12397 },
  ["Bois de la Pénombre"] = DRAKES,
  ["Duskwood"]           = DRAKES,
  ["Orneval"]            = DRAKES,
  ["Ashenvale"]          = DRAKES,
  ["Feralas"]            = DRAKES,
  ["Hinterlands"]        = DRAKES,
  ["The Hinterlands"]    = DRAKES,
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

-- Dédup par (npcId, kind, personnage) dans la fenêtre propre au kind : une
-- présence et une mort ne se dédupliquent JAMAIS entre elles.
local DEDUP_WINDOWS = {
  alive = ALIVE_DEDUP, death = DEATH_DEDUP, shade = SHADE_DEDUP, absent = ABSENT_DEDUP,
}
local function alreadyLogged(list, npcId, at, character, kind)
  local window = DEDUP_WINDOWS[kind] or DEATH_DEDUP
  for _, s in ipairs(list) do
    if s.npcId == npcId and (s.kind or "death") == kind
        and math.abs((tonumber(s.at) or 0) - at) < window
        and (character == nil or s.character == character) then
      return true
    end
  end
  return false
end

local function debugOn()
  return AuberdineExporterDB and AuberdineExporterDB.settings
    and AuberdineExporterDB.settings.verboseDebug
end

-- Fabrique une entrée d'observation directe (mort ou présence).
local function makeEntry(npcId, name, kind)
  local guild = GetGuildInfo("player")
  local faction = UnitFactionGroup("player")
  return {
    npcId = npcId,
    name = name or WORLD_BOSSES[npcId],
    at = GetServerTime and GetServerTime() or time(),
    character = UnitName("player"),
    realm = GetRealmName(),
    guild = guild or "",
    faction = faction and faction:upper() or "",
    zone = GetRealZoneText() or "",
    subzone = (GetSubZoneText and GetSubZoneText()) or "",
    kind = kind,
  }
end

-- Annonce de mort (print LOCAL, self-only), dédupée par boss : 40 raideurs qui
-- relaient le même kill ne produisent qu'un seul « vaincu ! ». Vaut pour la
-- mort DIRECTE comme pour un relais reçu (parité avec la 1.7.8).
local killAnnounced = {}  -- npcId → dernier `at` annoncé
local function announceKill(npcId, name, at)
  if killAnnounced[npcId] and math.abs(killAnnounced[npcId] - at) < DEATH_DEDUP then return end
  killAnnounced[npcId] = at
  print("|cff00ff00Auberdine:|r |cffff8000" .. (name or WORLD_BOSSES[npcId] or "?") .. "|r vient d'être vaincu !")
end

-- MORT observée (combat log).
local function recordDeath(npcId, destName)
  local list = sightings()
  local entry = makeEntry(npcId, destName, "death")
  if alreadyLogged(list, npcId, entry.at, entry.character, "death") then return end
  list[#list + 1] = entry
  prune(list)
  announceKill(npcId, entry.name, entry.at)
  if AuberdineComms and AuberdineComms.BroadcastWorldboss then
    AuberdineComms:BroadcastWorldboss(entry)
  end
end

-- PRÉSENCE observée (cible / survol / plaque de nom).
local function recordAlive(npcId, unitName)
  local list = sightings()
  local entry = makeEntry(npcId, unitName, "alive")
  if alreadyLogged(list, npcId, entry.at, entry.character, "alive") then return end
  list[#list + 1] = entry
  prune(list)
  local where = entry.subzone ~= "" and (entry.zone .. ", " .. entry.subzone) or entry.zone
  print("|cff00ff00Auberdine:|r |cffff8000" .. entry.name .. "|r aperçu vivant — " .. where .. " (signalé)")
  if AuberdineComms and AuberdineComms.BroadcastWorldboss then
    AuberdineComms:BroadcastWorldboss(entry)
  end
end

-- ESPRIT croisé (preuve de mort passée). L'entrée porte le npc_id du BOSS,
-- pas de l'esprit : le serveur raisonne par boss. Diffusée sur le kind Comms
-- « B » (à part) : les clients ≤ 1.7.10 coerceraient un kind W inconnu en
-- fausse « mort vue » — sur B, ils ignorent le message entier.
local function recordShade(bossId, shadeName)
  local list = sightings()
  local entry = makeEntry(bossId, shadeName or WORLD_BOSSES[bossId], "shade")
  if alreadyLogged(list, bossId, entry.at, entry.character, "shade") then return end
  list[#list + 1] = entry
  prune(list)
  print("|cff00ff00Auberdine:|r L'esprit de |cffff8000" .. (WORLD_BOSSES[bossId] or "?")
    .. "|r hante les lieux — sa mort est constatée (signalé)")
  if AuberdineComms and AuberdineComms.BroadcastBossExtra then
    AuberdineComms:BroadcastBossExtra(entry)
  end
end

-- Signalement MANUEL d'absence (/auberdine absent) : « j'y suis, il n'y est
-- pas ». Témoignage, pas preuve — le serveur dégrade « vivant » en « non
-- confirmé », il ne fabrique jamais une mort. La zone du joueur détermine
-- le(s) boss concerné(s) ; aux portails du Rêve on signale les quatre drakes,
-- le serveur ne retient que celui qu'il croyait à CET endroit.
function AuberdineWorldbossLogger.ReportAbsent()
  local zone = GetRealZoneText() or ""
  local targets = ABSENT_ZONES[zone]
  if not targets then
    print("|cffff8000Auberdine:|r Aucun colosse errant n'est rattaché à « " .. zone
      .. " » — placez-vous sur sa zone de guet (Azshara, Terres foudroyées, ou un portail du Rêve).")
    return
  end
  local list = sightings()
  local reported = 0
  for _, bossId in ipairs(targets) do
    local entry = makeEntry(bossId, WORLD_BOSSES[bossId], "absent")
    if not alreadyLogged(list, bossId, entry.at, entry.character, "absent") then
      list[#list + 1] = entry
      reported = reported + 1
      if AuberdineComms and AuberdineComms.BroadcastBossExtra then
        AuberdineComms:BroadcastBossExtra(entry)
      end
    end
  end
  prune(list)
  if reported > 0 then
    print("|cff00ff00Auberdine:|r Absence signalée pour " .. zone
      .. " — le guet en tiendra compte. Merci du passage !")
  else
    print("|cffff8000Auberdine:|r Absence déjà signalée il y a peu — rien à ajouter.")
  end
end

-- Observation reçue d'un pair via le mesh (Comms.lua). L'annonce est un print
-- local pour tous ; le STOCKAGE (voie montante) est réservé aux porteurs
-- d'uploader (décidé par l'appelant, comme les poses de world buffs).
function AuberdineWorldbossLogger.AddRelayed(s, storeIt)
  if type(s) ~= "table" then return false end
  local npcId = tonumber(s.npcId)
  local at = tonumber(s.at)
  local character = type(s.character) == "string" and s.character or ""
  local realm = type(s.realm) == "string" and s.realm or ""
  -- Kinds admis en relais. Un kind inconnu redevient 'death' UNIQUEMENT sur
  -- le canal W historique (rétrocompat) ; shade/absent n'arrivent que par le
  -- kind Comms « B », déjà filtré côté réception.
  local kind = DEDUP_WINDOWS[s.kind] and s.kind or "death"
  if not npcId or not WORLD_BOSSES[npcId] or not at or character == "" or realm == "" then
    return false
  end
  -- Un kill relayé s'annonce (print local dédupé) chez tous les receveurs,
  -- comme en 1.7.8. Une PRÉSENCE relayée reste SILENCIEUSE (pas de spam, pas
  -- de fuite de découverte hors du site).
  if kind == "death" then announceKill(npcId, s.name, at) end
  if not storeIt then return false end
  -- Jamais soi-même en relais (sa propre observation directe fait foi).
  if character == UnitName("player") and realm == GetRealmName() then return false end
  local list = sightings()
  if alreadyLogged(list, npcId, at, character, kind) then return false end
  list[#list + 1] = {
    npcId = npcId,
    name = tostring(s.name or ""),
    at = at,
    character = character,
    realm = realm,
    guild = tostring(s.guild or ""),
    faction = tostring(s.faction or ""),
    zone = tostring(s.zone or ""),
    subzone = tostring(s.subzone or ""),
    kind = kind,
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

-- Une unité EST-elle un world boss VIVANT — ou son ESPRIT ? (un cadavre
-- ciblable ne compte pas comme présence — ceinture et bretelles avec le
-- plancher de respawn serveur.)
local function checkUnitAlive(unit)
  if not unit or not UnitExists(unit) then return end
  if UnitIsDead(unit) then return end
  local npcId = npcIdFromGuid(UnitGUID(unit))
  if not npcId then return end
  if WORLD_BOSSES[npcId] then
    recordAlive(npcId, UnitName(unit))
  elseif SHADES[npcId] then
    recordShade(SHADES[npcId], UnitName(unit))
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:SetScript("OnEvent", function(_, event, arg1)
  if AuberdineExporter and AuberdineExporter.IsOnAuberdine
      and not AuberdineExporter:IsOnAuberdine() then
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    prune(sightings())
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    if subevent ~= "UNIT_DIED" then return end
    local npcId = npcIdFromGuid(destGUID)
    if npcId and WORLD_BOSSES[npcId] then
      recordDeath(npcId, destName)
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    checkUnitAlive("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    checkUnitAlive("mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    checkUnitAlive(arg1)  -- arg1 = jeton d'unité de la plaque
  end
end)
