-- KillLogger.lua — boss de raid vaincus, observés en jeu
--
-- Sur ENCOUNTER_END réussi en instance de raid, on enregistre le kill dans
-- AuberdineExporterDB.raidkillSightings et on le broadcast sur le mesh
-- (Comms.lua, kind K). L'uploader pousse le journal vers
-- /ingest/raidkills/sightings : le site affiche le progress de guilde en
-- quasi temps réel, sans attendre le passage des logs WCL.
--
-- Côté jeu, la valeur est l'ANNONCE : les membres de guilde hors raid (et le
-- canal auberdine) voient « <Guilde> a vaincu <Boss> ! » au moment du kill.
-- L'annonce se coupe dans les réglages du mesh (settings.comms.killAnnounce).

local DEDUP_WINDOW = 1800          -- s : re-kill du même boss < 30 min = même événement
local MAX_ENTRIES = 120            -- plafond dur du journal
local MAX_AGE = 30 * 24 * 3600     -- purge des kills de plus de 30 jours

AuberdineKillLogger = AuberdineKillLogger or {}

local function sightings()
  AuberdineExporterDB = AuberdineExporterDB or {}
  if type(AuberdineExporterDB.raidkillSightings) ~= "table" then
    AuberdineExporterDB.raidkillSightings = {}
  end
  return AuberdineExporterDB.raidkillSightings
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

local function alreadyLogged(list, encounterId, at, character)
  for _, s in ipairs(list) do
    if s.encounterId == encounterId and math.abs((tonumber(s.at) or 0) - at) < DEDUP_WINDOW
        and (character == nil or s.character == character) then
      return true
    end
  end
  return false
end

local function announceEnabled()
  if not (AuberdineComms and AuberdineComms.GetSettings) then return true end
  local s = AuberdineComms:GetSettings()
  if s.killAnnounce == nil then return true end  -- ACTIF par défaut
  return s.killAnnounce and true or false
end

-- Annonce dédupée par (encounterId, guilde) : 40 raideurs broadcastent le
-- même kill, on ne l'affiche qu'une fois.
local announced = {}  -- "encounterId|guild" → dernier at annoncé

local function announce(encounterId, name, guild, at)
  if not announceEnabled() then return end
  local key = tostring(encounterId) .. "|" .. tostring(guild or "")
  if announced[key] and math.abs(announced[key] - at) < DEDUP_WINDOW then return end
  announced[key] = at
  local who = (guild and guild ~= "") and ("|cffffd100" .. guild .. "|r") or "Un raid"
  print("|cff00ff00Auberdine:|r " .. who .. " a vaincu |cffff8000" .. tostring(name or "?") .. "|r !")
end

local function record(encounterId, encounterName)
  local list = sightings()
  local at = GetServerTime and GetServerTime() or time()
  if alreadyLogged(list, encounterId, at, UnitName("player")) then return end
  local guild = GetGuildInfo("player")
  local faction = UnitFactionGroup("player")
  local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  local entry = {
    encounterId = encounterId,
    name = encounterName or "",
    at = at,
    character = UnitName("player"),
    realm = GetRealmName(),
    guild = guild or "",
    faction = faction and faction:upper() or "",
    instanceId = instanceID or 0,
  }
  list[#list + 1] = entry
  prune(list)
  -- Observation DIRECTE uniquement : broadcast aux pairs (Comms.lua, hop 1).
  -- Pas d'annonce locale — le raideur voit déjà son kill ; l'annonce est pour
  -- ceux qui le REÇOIVENT (guilde hors raid, canal auberdine).
  if AuberdineComms and AuberdineComms.BroadcastKill then
    AuberdineComms:BroadcastKill(entry)
  end
end

-- Kill reçu d'un pair via le mesh (Comms.lua). L'annonce est pour tout le
-- monde ; le STOCKAGE est réservé aux porteurs d'uploader (décidé par
-- l'appelant, comme pour les poses de world buffs).
function AuberdineKillLogger.AddRelayed(s, storeIt)
  if type(s) ~= "table" then return false end
  local encounterId = tonumber(s.encounterId)
  local at = tonumber(s.at)
  local character = type(s.character) == "string" and s.character or ""
  local realm = type(s.realm) == "string" and s.realm or ""
  if not encounterId or encounterId <= 0 or not at or character == "" or realm == "" then
    return false
  end
  announce(encounterId, s.name, s.guild, at)
  if not storeIt then return false end
  -- Jamais soi-même en relais (sa propre observation directe fait foi).
  if character == UnitName("player") and realm == GetRealmName() then return false end
  local list = sightings()
  if alreadyLogged(list, encounterId, at, character) then return false end
  list[#list + 1] = {
    encounterId = encounterId,
    name = tostring(s.name or ""),
    at = at,
    character = character,
    realm = realm,
    guild = tostring(s.guild or ""),
    faction = tostring(s.faction or ""),
    instanceId = tonumber(s.instanceId) or 0,
    relayed = true,
  }
  prune(list)
  return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, ...)
  if AuberdineExporter and AuberdineExporter.IsOnAuberdine
      and not AuberdineExporter:IsOnAuberdine() then
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    prune(sightings())
    return
  end
  local encounterID, encounterName, _, _, success = ...
  if success ~= 1 then return end
  local inInstance, instanceType = IsInInstance()
  if not (inInstance and instanceType == "raid") then return end
  record(encounterID, encounterName)
end)
