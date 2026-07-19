-- WorldbuffLogger.lua — journal des poses de world buffs OBSERVÉES
--
-- Voie montante du canal worldbuffs (le pendant de Worldbuffs.lua, qui
-- descend l'agenda planifié) : quand le joueur REÇOIT un world buff collectif
-- (tête d'Onyxia/Nefarian, Rend, cœur de Hakkar), on enregistre la pose dans
-- AuberdineExporterDB.wbSightings. L'uploader les relaie vers
-- /ingest/worldbuffs/sightings ; le serveur croise ensuite observé vs
-- planifié (ratés de poses) et alimente les statistiques par faction/guilde.
--
-- DÉTECTION : diff des auras du joueur sur UNIT_AURA (pas de CLEU : les
-- spellIds y sont moins fiables et le yell des PNJ est localisé). Une aura
-- suivie qui APPARAÎT avec une durée restante quasi pleine = pose fraîche.
-- Le filtre de durée écarte les restaurations de Chronoflacon et les buffs
-- déjà portés au login/reload (durée entamée).
--
-- Volontairement limité aux poses COLLECTIVES annoncées sur AWB — pas de
-- Fleur-de-chant ni de tributs DM (buffs individuels : que du bruit).

local FRESH_MARGIN = 300     -- s manquantes tolérées pour une pose « fraîche »
local DEDUP_WINDOW = 1800    -- s : même buff revu dans la fenêtre = même pose
local MAX_ENTRIES = 400      -- plafond dur du journal (poses propres + relais)
local MAX_AGE = 30 * 24 * 3600 -- purge des observations de plus de 30 jours

-- spellId → durée pleine du buff (s). Étendre ici pour suivre d'autres poses.
local TRACKED = {
  [22888] = 7200, -- Cri de ralliement du tueur de dragons (Onyxia / Nefarian)
  [16609] = 3600, -- Bénédiction du chef de guerre (Rend)
  [24425] = 7200, -- Esprit de Zandalar (cœur de Hakkar)
}

AuberdineWorldbuffLogger = AuberdineWorldbuffLogger or {}

-- Auras suivies vues au dernier scan (spellId → true) : le diff n'enregistre
-- que les apparitions, pas les rafraîchissements de scan.
local present = {}

local function sightings()
  AuberdineExporterDB = AuberdineExporterDB or {}
  if type(AuberdineExporterDB.wbSightings) ~= "table" then
    AuberdineExporterDB.wbSightings = {}
  end
  return AuberdineExporterDB.wbSightings
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
    table.remove(list, 1) -- les plus anciennes d'abord (liste en ordre d'ajout)
  end
end

local function alreadyLogged(list, spellId, at)
  for _, s in ipairs(list) do
    if s.spellId == spellId and math.abs((tonumber(s.at) or 0) - at) < DEDUP_WINDOW then
      return true
    end
  end
  return false
end

local function record(spellId, name)
  local list = sightings()
  local at = GetServerTime and GetServerTime() or time()
  if alreadyLogged(list, spellId, at) then return end
  local guild = GetGuildInfo("player")
  local faction = UnitFactionGroup("player") -- token non localisé "Horde"/"Alliance"
  local entry = {
    spellId = spellId,
    name = name,
    at = at,
    character = UnitName("player"),
    realm = GetRealmName(),
    guild = guild or "",
    faction = faction and faction:upper() or "",
    zone = GetRealZoneText() or "",
  }
  list[#list + 1] = entry
  prune(list)
  if AuberdineExporterDB.settings and AuberdineExporterDB.settings.verboseDebug then
    print("|cff00ff00Auberdine:|r pose observée : " .. tostring(name) .. " (" .. spellId .. ")")
  end
  -- Observation DIRECTE uniquement : broadcast aux pairs (Comms.lua, hop 1).
  if AuberdineComms and AuberdineComms.BroadcastSighting then
    AuberdineComms:BroadcastSighting(entry)
  end
end

-- Observation reçue d'un pair via le mesh addon (Comms.lua). Stockée
-- relayed = true : l'uploader la pousse telle quelle, le serveur la trace —
-- et un pair sans uploader garde la sienne en direct (non relayed) s'il
-- l'observe aussi. Dédup par PERSONNAGE : la même pose vue par 30 joueurs
-- fait 30 observations légitimes (grain individuel voulu côté serveur).
function AuberdineWorldbuffLogger.AddRelayed(s)
  if type(s) ~= "table" then return false end
  local spellId = tonumber(s.spellId)
  local at = tonumber(s.at)
  local character = type(s.character) == "string" and s.character or ""
  local realm = type(s.realm) == "string" and s.realm or ""
  if not spellId or spellId <= 0 or not at or character == "" or realm == "" then
    return false
  end
  -- Jamais soi-même en relais (sa propre observation directe fait foi).
  if character == UnitName("player") and realm == GetRealmName() then return false end
  local list = sightings()
  for _, e in ipairs(list) do
    if e.spellId == spellId and e.character == character and (e.realm or "") == realm
        and math.abs((tonumber(e.at) or 0) - at) < DEDUP_WINDOW then
      return false
    end
  end
  list[#list + 1] = {
    spellId = spellId,
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

-- Scanne les buffs du joueur et enregistre les apparitions fraîches.
local function scan()
  local seen = {}
  for i = 1, 40 do
    local name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
    if not name then break end
    local full = spellId and TRACKED[spellId]
    if full then
      seen[spellId] = true
      if not present[spellId] then
        -- Durée restante quasi pleine = pose fraîche (écarte Chronoflacon et
        -- buffs déjà entamés portés au moment du login).
        local remaining = (expirationTime or 0) - GetTime()
        if remaining >= full - FRESH_MARGIN then
          record(spellId, name)
        end
      end
    end
  end
  present = seen
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
if f.RegisterUnitEvent then
  f:RegisterUnitEvent("UNIT_AURA", "player")
else
  f:RegisterEvent("UNIT_AURA")
end
f:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_AURA" and unit ~= "player" then return end
  -- Réservé au royaume supporté, comme le reste de l'addon.
  if AuberdineExporter and AuberdineExporter.IsOnAuberdine
      and not AuberdineExporter:IsOnAuberdine() then
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    -- Amorce l'état « présent » sans enregistrer : un monde qui se charge
    -- n'est jamais une pose (le filtre de durée protège déjà, ceinture et
    -- bretelles) ; puis purge du journal.
    prune(sightings())
  end
  scan()
end)
