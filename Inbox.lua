-- Inbox.lua — Boîte de réception des messages descendants (site → uploader → addon)
--
-- Canal « du royaume vers le joueur ». Le client AuberdineUploader dépose des
-- messages dans la SavedVariable AuberdineUploaderInbox (écrite HORS-JEU, quand
-- WoW est fermé : un addon ne lit ses SavedVariables qu'au chargement, jamais à
-- chaud). À la connexion, on affiche en pop-up les messages encore jamais vus et
-- on mémorise leur identifiant dans AuberdineExporterDB.seenMessages — pour ne
-- pas les remontrer, et pour que l'uploader puisse les acquitter (lecture de
-- seenMessages).
--
-- LIMITE assumée : livraison « au prochain login / /reload », PAS en temps réel
-- (WoW ne relit jamais les SavedVariables en cours de session).
--
-- Contrat (écrit par l'uploader dans le fichier de SavedVariables) :
--   AuberdineUploaderInbox = {
--     schema = 1,
--     messages = {
--       { id = "abc123",                       -- requis : identifiant stable
--         kind = "info"|"warning"|"success",   -- défaut "info"
--         title = "Titre",                      -- optionnel
--         body = "Texte du message",            -- requis
--         createdAt = 1719500000,               -- epoch s (tri)
--         expiresAt = 1719600000 },             -- optionnel : périme l'affichage
--     },
--   }

local PREFIX = "|cff00ff00Auberdine|r"

local KIND_COLOR = {
  info    = "ffd200", -- or
  warning = "ff8000", -- orange
  success = "33ff66", -- vert
}

-- Au-delà de ce nombre, WoW empile mal les pop-ups : les suivantes ne passent
-- qu'en chat (elles restent marquées « vues »).
local MAX_POPUPS = 3

-- Pop-up native réutilisée pour chaque message (le texte est passé à l'affichage
-- via StaticPopup_Show). preferredIndex 3 évite le bug de taint des index bas.
StaticPopupDialogs["AUBERDINE_UPLOADER_MSG"] = {
  text = "%s",
  button1 = OKAY,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

AuberdineInbox = AuberdineInbox or {}

local function composeText(msg)
  local color = KIND_COLOR[msg.kind or "info"] or KIND_COLOR.info
  local title = (msg.title and msg.title ~= "")
      and ("|cff" .. color .. msg.title .. "|r\n\n") or ""
  return title .. (msg.body or "")
end

-- Affiche les messages non encore vus de la boîte de réception.
function AuberdineInbox.Process()
  local inbox = AuberdineUploaderInbox
  if type(inbox) ~= "table" or type(inbox.messages) ~= "table" then return end

  AuberdineExporterDB = AuberdineExporterDB or {}
  local seen = AuberdineExporterDB.seenMessages
  if type(seen) ~= "table" then
    seen = {}
    AuberdineExporterDB.seenMessages = seen
  end

  local now = time()

  -- Collecte les non-vus encore valides ; les expirés sont marqués vus sans
  -- affichage (purge douce).
  local pending = {}
  for _, m in ipairs(inbox.messages) do
    if type(m) == "table" and m.id and not seen[m.id] then
      if m.expiresAt and now > m.expiresAt then
        seen[m.id] = now
      else
        pending[#pending + 1] = m
      end
    end
  end
  table.sort(pending, function(a, b) return (a.createdAt or 0) < (b.createdAt or 0) end)

  local shown = 0
  for _, m in ipairs(pending) do
    seen[m.id] = now
    -- Trace persistante en chat (subsiste après fermeture de la pop-up).
    print(PREFIX .. " " .. (m.title and (m.title .. " — ") or "") .. (m.body or ""))
    if shown < MAX_POPUPS then
      StaticPopup_Show("AUBERDINE_UPLOADER_MSG", composeText(m))
      shown = shown + 1
    end
  end
end

-- Injecte un message de test et l'affiche, pour vérifier le rendu sans
-- l'uploader :  /run AuberdineInbox.Test()
function AuberdineInbox.Test()
  AuberdineUploaderInbox = AuberdineUploaderInbox or { schema = 1, messages = {} }
  AuberdineUploaderInbox.messages = AuberdineUploaderInbox.messages or {}
  table.insert(AuberdineUploaderInbox.messages, {
    id = "test-" .. tostring(time()),
    kind = "info",
    title = "Message de test",
    body = "Ceci est un message de test de la boîte de réception Auberdine.",
    createdAt = time(),
  })
  AuberdineInbox.Process()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  -- Réservé au royaume supporté, comme le reste de l'addon.
  if AuberdineExporter and AuberdineExporter.IsOnAuberdine
      and not AuberdineExporter:IsOnAuberdine() then
    return
  end
  -- Léger délai : laisse le cadre de chat et la DB principale se mettre en place
  -- après la connexion avant d'afficher quoi que ce soit.
  if C_Timer and C_Timer.After then
    C_Timer.After(4, AuberdineInbox.Process)
  else
    AuberdineInbox.Process()
  end
end)
