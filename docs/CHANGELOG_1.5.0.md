# Changelog - Version 1.5.0

## 🏰 **Version 1.5.0** - Suivi de guilde (Guild Tracking)
*Date de sortie: 5 juin 2026*

### ✅ **Nouvelle fonctionnalité majeure**
Module de **suivi des activités de guilde** inspiré de GRM (Guild Roster
Manager). L'addon photographie le roster de guilde, détecte les changements et
journalise l'historique, puis l'inclut dans l'export auberdine.eu.

**Événements suivis (horodatés) :**
- `JOIN` — entrée d'un membre
- `LEAVE` — départ volontaire
- `KICK` — expulsion (**avec l'auteur**)
- `PROMOTE` / `DEMOTE` — changement de rang (**avec l'auteur et le rang**)
- `NOTE` — modification d'une note publique

### 🔍 **Comment ça marche**
Combinaison de deux sources, comme GRM :
1. **Diff du roster** : `C_GuildInfo.GuildRoster()` + `GUILD_ROSTER_UPDATE` +
   `GetGuildRosterInfo(i)`, comparé à la photo précédente (clé = GUID stable).
2. **Parsing des messages système** (`CHAT_MSG_SYSTEM`) via les *global strings*
   Blizzard (`ERR_GUILD_*`) pour récupérer l'auteur exact d'un kick/promotion —
   compatible **toutes langues** sans table de traduction.

Le premier scan amorce la photo **silencieusement** (pas de flood de `JOIN`).
Un re-scan périodique (60 s) capte les changements faits par d'autres.

### 📦 **Structure stockée**
```lua
AuberdineExporterDB.guilds = {
    ["NomGuilde-Royaume"] = {
        name, realm, faction, lastScan, lastExportTs, share = true,
        ranks  = { [rankIndex] = rankName },
        roster = { [guid] = { name, class, level, rankIndex, rankName,
                              publicNote, online, firstSeen, joinDate } },
        log    = { { ts, type, target, actor, detail, fromRank, fromNote } },
    },
}
AuberdineExporterDB.settings.guild = {
    enabled = true, exportPublicNotes = true, trackNoteChanges = true,
}
```

### 🗂️ **Multi-guildes + partage sélectif**
- Stockage **par guilde** (`AuberdineExporterDB.guilds[NomGuilde-Royaume]`) :
  les alts dans des guildes différentes ne s'écrasent plus.
- Migration automatique de l'ancien format mono-guilde.
- Drapeau `share` par guilde : **choix des guildes que l'on exporte**.

### 🪶 **Export économe (delta par défaut)**
Pour éviter de dépasser la limite d'export (~50 KO) avec un gros roster :
- **Mode `delta` par défaut** : seuls les événements depuis le dernier export
  (champ `since`), **plafonnés à 30 jours** ; le roster n'est pas renvoyé.
- **Mode `full`** : roster complet + journal, au 1er export d'une guilde ou via
  **resync** manuel.
- Sérialisation maigre (champs inutiles au serveur retirés) + notes publiques
  exportées en option.
- Contrat serveur : `mode=full` → upsert roster + journal ; `mode=delta` →
  append/dédoublonnage du journal. Voir `docs/GUILD-TRACKING.md`.

### ⚙️ **Options dans l'UI (onglet Réglages → « Suivi de guilde »)**
- Activer le suivi · Exporter les notes publiques · Journaliser les changements
  de note · **Taille max du journal** (rétention configurable 50–50000) · case
  **Partager** par guilde (avec **taille estimée** du prochain export) + bouton
  **Vider** le journal d'une guilde · bouton **Forcer un export complet (resync)**.

### 🆕 **Commandes**
- `/auberdine guild` — résumé de la guilde courante + taille export estimée
- `/auberdine guild scan` — forcer un scan du roster
- `/auberdine guild members` — lister les membres (triés par rang)
- `/auberdine guild log [n]` — afficher les n derniers événements (défaut 20)
- `/auberdine guild list` — lister les guildes suivies et leur partage
- `/auberdine guild share <on|off>` — (dé)activer le partage de la guilde courante
- `/auberdine guild resync` — forcer un export complet au prochain export
- `/auberdine guild clear` — réinitialiser les données de la guilde courante

### 🛡️ **Vie privée**
- Les **notes officier ne sont jamais collectées ni exportées**. Seules les
  notes publiques le sont.
- Le suivi ne s'active que sur le serveur Auberdine et uniquement si le
  personnage est en guilde.

### 🔁 **Export**
- Les données de guilde sont injectées sous la clé `guild` dans
  `ExportToJSON`, puis encodées en Base64 et signées comme le reste du payload.
  Aucun changement au pipeline de signature.

### 📁 **Fichiers modifiés / ajoutés**
- `GuildTracker.lua` *(nouveau)* : module complet (scan, diff, parsing système,
  journal, export, commandes).
- `AuberdineExporter.lua` : injection `exportData.guilds`, sous-commandes
  `/auberdine guild …`, entrées d'aide, bump version fallback.
- `UI/AuberdineMainFrame.lua` : section « Suivi de guilde » dans l'onglet
  Réglages (toggles, partage par guilde + taille estimée, bouton resync).
- `AuberdineExporter.toc` : version 1.5.0, ajout de `GuildTracker.lua`, note.
- `create-release.sh` : version 1.5.0, inclusion de `GuildTracker.lua`.
- `docs/GUILD-TRACKING.md` *(nouveau)* : documentation détaillée.
- `docs/CHANGELOG_1.5.0.md` : ce changelog.
