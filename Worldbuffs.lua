-- Worldbuffs.lua — Agenda des world buffs planifiés (flux descendant AWB)
--
-- Canal « du royaume vers le joueur », côté données : le client
-- AuberdineUploader écrit l'agenda des poses planifiées (source bot AWB via
-- /ingest/feed/worldbuffs) dans la SavedVariable AuberdineWorldbuffsFeed —
-- même mécanique que la boîte de réception (Inbox.lua) : écriture HORS-JEU,
-- lecture au chargement uniquement. L'affichage se greffe sur le tooltip du
-- bouton minimap.
--
-- FRAÎCHEUR : l'uploader repose fetchedAt à chaque cycle (au plus toutes les
-- heures). Au-delà de STALE_SECONDS (12 h), l'agenda est considéré périmé et
-- n'est plus affiché — mieux vaut rien qu'un horaire faux.
--
-- DEUXIÈME SOURCE : le mesh addon (Comms.lua) relaie l'agenda entre joueurs.
-- Un feed relayé accepté est persisté dans AuberdineExporterDB.wbRelayFeed
-- (NOTRE SavedVariable — jamais AuberdineWorldbuffsFeed, propriété exclusive
-- de l'uploader, écrite hors-jeu). À la lecture, la source au generatedAt le
-- plus récent gagne : un joueur sans uploader vit du relais, un joueur avec
-- uploader profite d'un relais plus frais que son fichier figé en session.
--
-- Contrat (écrit par l'uploader) :
--   AuberdineWorldbuffsFeed = {
--     schema = 1,
--     fetchedAt = 1752831000,     -- epoch s : pose de l'uploader (fraîcheur)
--     generatedAt = 1752830990,   -- epoch s : génération côté serveur
--     entries = {                 -- séquence, tri chronologique croissant
--       { buff = "Onyxia",        -- libellé lisible (tel qu'annoncé sur AWB)
--         at = 1752861600,        -- epoch s UTC de la pose
--         guild = "Constellation",-- optionnel
--         faction = "HORDE" },    -- optionnel : "HORDE" | "ALLIANCE"
--     },
--   }

local STALE_SECONDS = 12 * 3600 -- au-delà : données périmées, affichage coupé
local GRACE_PAST = 30 * 60      -- pose passée depuis moins de 30 min : « en cours »
local MAX_LINES = 6

local DAYS_FR = { "dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam." }

local FACTION_RGB = {
  HORDE = { 0.9, 0.25, 0.25 },
  ALLIANCE = { 0.35, 0.55, 1.0 },
}

AuberdineWorldbuffs = AuberdineWorldbuffs or {}

-- « aujourd'hui 20:30 », « demain 20:30 », « jeu. 24/07 20:30 » (heure locale
-- du client : les epochs du flux sont UTC, date() applique le fuseau local).
local function formatWhen(at)
  local d = date("*t", at)
  local today = date("*t", time())
  local tomorrow = date("*t", time() + 86400)
  local day
  if d.year == today.year and d.yday == today.yday then
    day = "aujourd'hui"
  elseif d.year == tomorrow.year and d.yday == tomorrow.yday then
    day = "demain"
  else
    day = string.format("%s %02d/%02d", DAYS_FR[d.wday] or "", d.day, d.month)
  end
  return string.format("%s %02d:%02d", day, d.hour, d.min)
end

local function formatAge(seconds)
  if seconds < 90 then return "à l'instant" end
  if seconds < 5400 then return string.format("il y a %d min", math.floor(seconds / 60 + 0.5)) end
  return string.format("il y a %d h", math.floor(seconds / 3600 + 0.5))
end

-- Meilleure source d'agenda disponible : le fichier de l'uploader
-- (AuberdineWorldbuffsFeed) ou le relais des pairs (wbRelayFeed), au
-- generatedAt le plus récent. L'âge est celui de la RÉCEPTION locale
-- (fetchedAt / receivedAt) : c'est lui qui mesure la péremption.
-- nil si aucune source n'a jamais existé.
function AuberdineWorldbuffs.GetBestFeed()
  local best = nil
  local feed = AuberdineWorldbuffsFeed
  if type(feed) == "table" and type(feed.entries) == "table" and tonumber(feed.fetchedAt) then
    best = {
      generatedAt = tonumber(feed.generatedAt) or tonumber(feed.fetchedAt),
      age = math.max(0, time() - tonumber(feed.fetchedAt)),
      entries = feed.entries,
      source = "uploader",
    }
  end
  local relay = type(AuberdineExporterDB) == "table" and AuberdineExporterDB.wbRelayFeed or nil
  if type(relay) == "table" and type(relay.entries) == "table" and tonumber(relay.receivedAt) then
    local rgen = tonumber(relay.generatedAt) or 0
    if not best or rgen > best.generatedAt then
      best = {
        generatedAt = rgen,
        age = math.max(0, time() - tonumber(relay.receivedAt)),
        entries = relay.entries,
        source = "relay",
      }
    end
  end
  return best
end

-- Feed relayé par un pair (Comms.lua). Adopté s'il est plus récent que le
-- relais déjà stocké ; fusionné s'il s'agit d'un autre chunk du même feed
-- (même generatedAt, entrées indépendantes). Jamais écrit dans
-- AuberdineWorldbuffsFeed : cette SavedVariable appartient à l'uploader.
local RELAY_MAX_ENTRIES = 24

function AuberdineWorldbuffs.AcceptRelayedFeed(generatedAt, entries)
  generatedAt = tonumber(generatedAt)
  if not generatedAt or type(entries) ~= "table" or #entries == 0 then return false end
  local now = time()
  -- Plausibilité : un agenda ne vient ni du passé lointain ni du futur.
  if generatedAt < now - STALE_SECONDS or generatedAt > now + 600 then return false end
  AuberdineExporterDB = AuberdineExporterDB or {}
  local cur = AuberdineExporterDB.wbRelayFeed
  local curGen = type(cur) == "table" and tonumber(cur.generatedAt) or 0
  if generatedAt < curGen then return false end
  local function entryKey(e)
    return tostring(e.buff) .. "|" .. tostring(e.at) .. "|" .. tostring(e.guild or "")
  end
  if generatedAt == curGen and type(cur) == "table" and type(cur.entries) == "table" then
    local seen = {}
    for _, e in ipairs(cur.entries) do seen[entryKey(e)] = true end
    for _, e in ipairs(entries) do
      if not seen[entryKey(e)] and #cur.entries < RELAY_MAX_ENTRIES then
        cur.entries[#cur.entries + 1] = e
      end
    end
    cur.receivedAt = now
  else
    while #entries > RELAY_MAX_ENTRIES do table.remove(entries) end
    AuberdineExporterDB.wbRelayFeed = {
      generatedAt = generatedAt,
      receivedAt = now,
      entries = entries,
    }
  end
  return true
end

-- Prochaines poses (les poses de moins de GRACE_PAST restent listées comme
-- « en cours »), triées, plafonnées à MAX_LINES. nil si aucune source.
function AuberdineWorldbuffs.GetUpcoming()
  local best = AuberdineWorldbuffs.GetBestFeed()
  if not best then return nil end
  local now = time()
  local list = {}
  for _, e in ipairs(best.entries) do
    local at = tonumber(e.at)
    if at and at >= now - GRACE_PAST then
      list[#list + 1] = e
    end
  end
  table.sort(list, function(a, b) return (tonumber(a.at) or 0) < (tonumber(b.at) or 0) end)
  while #list > MAX_LINES do table.remove(list) end
  return list
end

-- Âge des données en secondes, ou nil si aucune source n'a jamais existé.
function AuberdineWorldbuffs.GetAge()
  local best = AuberdineWorldbuffs.GetBestFeed()
  return best and best.age or nil
end

-- Greffe la section agenda sur un tooltip déjà ouvert (bouton minimap).
-- Silencieux si aucune source n'a jamais existé (ni uploader, ni relais).
function AuberdineWorldbuffs.AddToTooltip(tt)
  local best = AuberdineWorldbuffs.GetBestFeed()
  local age = best and best.age or nil
  if not age then return end

  tt:AddLine(" ")
  tt:AddLine("|cffffd200World buffs planifiés|r")

  if age > STALE_SECONDS then
    tt:AddLine("Agenda indisponible (données de plus de 12 h).", 0.55, 0.55, 0.55, true)
    tt:Show()
    return
  end

  local upcoming = AuberdineWorldbuffs.GetUpcoming() or {}
  if #upcoming == 0 then
    tt:AddLine("Aucune pose planifiée.", 0.55, 0.55, 0.55)
  end
  local now = time()
  for _, e in ipairs(upcoming) do
    local at = tonumber(e.at) or 0
    local left
    if at <= now then
      left = string.format("%s — |cff33ff66en cours|r", tostring(e.buff))
    else
      left = string.format("%s — %s", tostring(e.buff), formatWhen(at))
    end
    local rgb = FACTION_RGB[e.faction or ""]
    if e.guild and e.guild ~= "" then
      if rgb then
        tt:AddDoubleLine(left, e.guild, 1, 0.82, 0, rgb[1], rgb[2], rgb[3])
      else
        tt:AddDoubleLine(left, e.guild, 1, 0.82, 0, 0.8, 0.8, 0.8)
      end
    else
      tt:AddLine(left, 1, 0.82, 0)
    end
  end
  local via = (best.source == "relay") and " · relais d'un joueur" or ""
  tt:AddLine("MàJ " .. formatAge(age) .. via, 0.55, 0.55, 0.55)
  tt:Show()
end

-- Sortie chat de secours :  /auberdine wb  (ou /ae wb)
function AuberdineWorldbuffs.PrintUpcoming()
  local prefix = "|cff00ff00Auberdine:|r "
  local best = AuberdineWorldbuffs.GetBestFeed()
  local age = best and best.age or nil
  if not age then
    print(prefix .. "Agenda des world buffs indisponible (client AuberdineUploader requis, ou attendre le relais d'un joueur qui l'a).")
    return
  end
  if age > STALE_SECONDS then
    print(prefix .. "Agenda des world buffs périmé (données de plus de 12 h — uploader arrêté ?).")
    return
  end
  local upcoming = AuberdineWorldbuffs.GetUpcoming() or {}
  if #upcoming == 0 then
    print(prefix .. "Aucune pose de world buff planifiée. (MàJ " .. formatAge(age) .. ")")
    return
  end
  local via = (best.source == "relay") and " · relais" or ""
  print(prefix .. "World buffs planifiés (MàJ " .. formatAge(age) .. via .. ") :")
  local now = time()
  for _, e in ipairs(upcoming) do
    local at = tonumber(e.at) or 0
    local when = at <= now and "en cours" or formatWhen(at)
    local who = (e.guild and e.guild ~= "") and (" — " .. e.guild) or ""
    print(string.format("  %s : %s%s", tostring(e.buff), when, who))
  end
end
