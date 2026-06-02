# Changelog - Version 1.6.2

## ⚔️ **Version 1.6.2** - Données PvP + export des stats/argent
*Date de sortie: 2 juin 2026*

> **Résumé** — Ajoute la collecte PvP complète (système d'honneur Classic Era)
> et **répare** un oubli de la v1.6.0 : les stats du personnage et l'argent
> étaient stockés mais jamais inclus dans le JSON d'export.

### ✅ **Nouvelles fonctionnalités**

#### ⚔️ Collecte PvP (export auberdine.eu)
- Nouveau champ `character.pvp` (snapshot rafraîchi à chaque login) :
  - `lifetimeHonorableKills`, `lifetimeDishonorableKills`, `highestRank` — via `GetPVPLifetimeStats()`
  - `thisWeekHonorableKills`, `thisWeekContribution` — via `GetPVPThisWeekStats()`
  - `lastWeekHonorableKills`, `lastWeekContribution`, `lastWeekStanding` — via `GetPVPLastWeekStats()`
  - `yesterdayHonorableKills`, `yesterdayContribution` — via `GetPVPYesterdayStats()`
  - `rankIndex` (`UnitPVPRank`), `rankNumber` + `rankName` (`GetPVPRankInfo`) — le **nom du rang est le titre PvP** vanilla (Soldat → Maréchal de la Garde)
  - `scannedAt` — horodatage du snapshot
- Chaque API est gardée (`if X then`) : si une fonction est absente sur le client,
  le champ correspondant est simplement omis (pas de crash).

### 🐛 **Correctifs**

#### 💰 Export des stats du personnage & de l'argent (oubli v1.6.0)
- La v1.6.0 stockait `stats` (PV, mana, force, agilité, endurance, intelligence,
  esprit, armure) et `money` dans la SavedVariable, **mais ne les ajoutait pas
  au JSON d'export**. Corrigé : ils partent désormais dans l'export.
- `character.money` — cuivre total.
- `character.attributes` — stats physiques. ⚠️ **Clé `attributes`** (et non
  `stats`) pour ne pas entrer en collision avec le champ `stats` existant qui
  contient les compteurs d'agrégats (`totalProfessions`, `totalRecipes`, …).

### 🔧 **Technique**
- `create-release.sh` : bump `VERSION` 1.6.1 → 1.6.2.
- `character.pvp` est recalculé à chaque init de personnage (login) — pas de
  nouvel event nécessaire ; snapshot once-per-session, comme `stats`/`money`/`reputations`.
