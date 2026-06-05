# Changelog - Version 1.6.3

## 🏰 **Version 1.6.3** - Intégration du suivi de guilde
*Date de sortie: 5 juin 2026*

> **Résumé** — Fusionne le module de **suivi d'activité de guilde façon GRM**
> (développé en parallèle, étiqueté v1.5.0) par-dessus la base v1.6.2
> (quêtes, stats, money, PvP, recettes). Aucune fonctionnalité existante n'est
> retirée ; le module guilde s'ajoute à l'export auberdine.eu.

### ✅ **Nouvelle fonctionnalité majeure : suivi de guilde**

Module `GuildTracker.lua` inspiré de GRM (Guild Roster Manager). L'addon
photographie le roster de guilde, détecte les changements et journalise
l'historique horodaté, puis l'inclut dans l'export.

**Événements suivis (horodatés) :** `JOIN`, `LEAVE`, `KICK` (avec l'auteur),
`PROMOTE` / `DEMOTE` (auteur + rang), `NOTE` (modification de note publique).

**Double source, comme GRM :**
1. Diff du roster (`C_GuildInfo.GuildRoster()` + `GUILD_ROSTER_UPDATE` +
   `GetGuildRosterInfo`), comparé à la photo précédente (clé = GUID stable).
2. Parsing des messages système (`CHAT_MSG_SYSTEM`) via les *global strings*
   Blizzard (`ERR_GUILD_*`) pour l'auteur exact d'un kick/promotion —
   compatible **toutes langues** sans table de traduction.

Le premier scan amorce la photo **silencieusement** (pas de flood de `JOIN`) ;
re-scan périodique (60 s) pour capter les changements faits par d'autres.

### 🗂️ **Multi-guildes + partage sélectif**
- Stockage **par guilde** (`AuberdineExporterDB.guilds[NomGuilde-Royaume]`) :
  les alts dans des guildes différentes ne s'écrasent plus.
- Migration automatique de l'ancien format mono-guilde.
- Drapeau `share` par guilde pour choisir les guildes exportées.

### 🪶 **Export économe (delta par défaut)**
- **Mode `delta`** : seuls les événements depuis le dernier export (champ
  `since`), plafonnés à 30 jours ; le roster n'est pas renvoyé.
- **Mode `full`** : roster complet + journal, au 1er export d'une guilde ou via
  `resync` manuel.
- Sérialisation maigre + notes publiques exportées en option.

### 🖥️ **UI**
- Rétention de log configurable + bouton *clear-log* par guilde.
- Dropdown de rôle intégré dans les cartes de personnage.

### 🎛️ **Commandes**
`/auberdine guild` (résumé), `scan`, `members`, `log [n]`, `list`,
`share <on|off>`, `resync`, `clear`.

### 📚 **Documentation**
- `docs/GUILD-TRACKING.md` — fonctionnement détaillé du module.
- `server/GUILD-IMPORT.md` — contrat d'import serveur (clé `guilds`,
  upsert `full` / append+dédoublonnage `delta`).

### 🔧 **Notes de fusion**
- Version alignée sur **1.6.3** (`.toc`, `create-release.sh`, fallback Lua).
- Interface conservée à **11508** (base v1.6.2).
- `GuildTracker.lua` ajouté au `.toc` et au packaging de release.
