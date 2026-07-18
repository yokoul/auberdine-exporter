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

-- Prochaines poses (les poses de moins de GRACE_PAST restent listées comme
-- « en cours »), triées, plafonnées à MAX_LINES. nil si le flux est absent.
function AuberdineWorldbuffs.GetUpcoming()
  local feed = AuberdineWorldbuffsFeed
  if type(feed) ~= "table" or type(feed.entries) ~= "table" then return nil end
  local now = time()
  local list = {}
  for _, e in ipairs(feed.entries) do
    local at = tonumber(e.at)
    if at and at >= now - GRACE_PAST then
      list[#list + 1] = e
    end
  end
  table.sort(list, function(a, b) return (tonumber(a.at) or 0) < (tonumber(b.at) or 0) end)
  while #list > MAX_LINES do table.remove(list) end
  return list
end

-- Âge des données en secondes, ou nil si le flux n'a jamais été écrit.
function AuberdineWorldbuffs.GetAge()
  local feed = AuberdineWorldbuffsFeed
  local fetchedAt = type(feed) == "table" and tonumber(feed.fetchedAt) or nil
  if not fetchedAt then return nil end
  return math.max(0, time() - fetchedAt)
end

-- Greffe la section agenda sur un tooltip déjà ouvert (bouton minimap).
-- Silencieux si l'uploader n'a jamais écrit le flux (installation sans client).
function AuberdineWorldbuffs.AddToTooltip(tt)
  local age = AuberdineWorldbuffs.GetAge()
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
  tt:AddLine("MàJ " .. formatAge(age), 0.55, 0.55, 0.55)
  tt:Show()
end

-- Sortie chat de secours :  /auberdine wb  (ou /ae wb)
function AuberdineWorldbuffs.PrintUpcoming()
  local prefix = "|cff00ff00Auberdine:|r "
  local age = AuberdineWorldbuffs.GetAge()
  if not age then
    print(prefix .. "Agenda des world buffs indisponible (client AuberdineUploader requis).")
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
  print(prefix .. "World buffs planifiés (MàJ " .. formatAge(age) .. ") :")
  local now = time()
  for _, e in ipairs(upcoming) do
    local at = tonumber(e.at) or 0
    local when = at <= now and "en cours" or formatWhen(at)
    local who = (e.guild and e.guild ~= "") and (" — " .. e.guild) or ""
    print(string.format("  %s : %s%s", tostring(e.buff), when, who))
  end
end
