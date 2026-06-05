# Suivi de guilde (Guild Tracking) — v1.5.0

Module inspiré de **GRM (Guild Roster Manager)**, permettant de collecter et
d'exporter l'état et l'historique d'activité de vos guildes vers
[auberdine.eu](https://auberdine.eu), **en gardant l'export léger**.

## Fonctionnement

Le suivi combine **deux sources de vérité** (comme GRM) :

1. **Snapshot du roster + diff d'état**
   - `C_GuildInfo.GuildRoster()` (rate-limité à 10 s) + événement
     `GUILD_ROSTER_UPDATE`, puis `GetGuildRosterInfo(i)` pour chaque membre.
   - Photo indexée par **GUID** (clé stable), comparée à la précédente :
     `JOIN`, `LEAVE`, `PROMOTE`/`DEMOTE` (rankIndex), `NOTE` (note publique).

2. **Parsing des messages système (`CHAT_MSG_SYSTEM`)**
   - Global strings Blizzard (`ERR_GUILD_*`) → fonctionne dans **toutes les
     langues**. Sert à récupérer l'**acteur** d'un kick/promotion et à
     distinguer un départ volontaire (`LEAVE`) d'une expulsion (`KICK`).

Le premier scan **amorce silencieusement** la photo (pas de flood `JOIN`). Un
re-scan périodique (60 s) capte les changements faits par d'autres.

## Stockage multi-guildes

Vos alts peuvent être dans des guildes différentes : chaque guilde a sa propre
entrée, indexée par `NomGuilde-Royaume`.

```lua
AuberdineExporterDB.guilds = {
  ["Ma Guilde-Auberdine"] = {
    name, realm, faction, lastScan, lastExportTs,
    share = true,                       -- exporter cette guilde ?
    ranks  = { [rankIndex] = rankName },
    roster = { [guid] = { name, class, level, rankIndex, rankName,
                          publicNote, online, firstSeen, joinDate } },
    log    = { { ts, type, target, actor, detail, fromRank, fromNote } },
  },
  ["Autre Guilde-Auberdine"] = { ... , share = false },
}
```

> Migration automatique : l'ancien `AuberdineExporterDB.guild` (mono-guilde) est
> déplacé vers `guilds[clé]` au premier chargement.

## Export économe (delta par défaut)

L'export d'un gros roster + tout l'historique peut dépasser la limite de
~50 KO. La stratégie minimise donc la taille :

- **Mode `delta` (par défaut)** : on n'exporte que les **événements depuis le
  dernier export** (champ `since`), **plafonnés à 30 jours**. Le roster n'est
  **pas** renvoyé — le serveur reconstruit l'état à partir du journal.
- **Mode `full`** : roster courant complet + journal (≤ 30 j). Déclenché
  automatiquement au **premier** export d'une guilde, ou manuellement via le
  bouton **« Forcer un export complet (resync) »** / `/auberdine guild resync`.
- **Partage par guilde** : seules les guildes avec `share = true` sont
  exportées.
- **Sérialisation maigre** : les champs inutiles au serveur (`zone`, `online`,
  `firstSeen`, `guid`, `rankName` des membres…) ne sont **pas** exportés.
- **Notes publiques** : exportées seulement si l'option est cochée.

> ⚠️ `lastExportTs` avance à chaque génération d'export (best-effort). Le serveur
> doit **dédoublonner** les événements (`ts` + `type` + `target`) et **upserter**
> le roster en mode `full`. En cas de doute (export non importé), un
> **resync** renvoie l'état complet.

### Contrat serveur (clé `guilds` du payload)

```json
{
  "guilds": [
    {
      "name": "Ma Guilde", "realm": "Auberdine", "faction": "Alliance",
      "mode": "full", "since": 1730800000, "exportedAt": 1733400000,
      "ranks": { "0": "Guild Master", "1": "Officier", "4": "Membre" },
      "memberCount": 42,
      "members": [
        { "name": "Carnalis", "class": "MAGE", "level": 60,
          "rankIndex": 0, "publicNote": "chef", "joinDate": 1733000000 }
      ],
      "log": [
        { "ts": 1733400500, "type": "PROMOTE", "target": "Bob",
          "actor": "Yan", "detail": "Officier" }
      ]
    },
    {
      "name": "Autre Guilde", "realm": "Auberdine",
      "mode": "delta", "since": 1733300000, "exportedAt": 1733400000,
      "log": [ { "ts": 1733401000, "type": "KICK", "target": "BadGuy", "actor": "Yan" } ]
    }
  ]
}
```

- `mode: "full"` → **remplacer/upserter** le roster + appliquer le journal.
- `mode: "delta"` → **appliquer le journal** au roster déjà connu (append +
  dédoublonnage), pas de roster fourni.

## Options dans l'UI (onglet Réglages → « Suivi de guilde »)

- ☑ **Activer le suivi de guilde** (interrupteur global)
- ☑ **Exporter les notes publiques** (décoché = export plus léger)
- ☑ **Journaliser les changements de note** (décoché = moins de bruit)
- 🔢 **Taille max du journal par guilde** (rétention configurable, 50 à 50000 ;
  les plus anciens événements sont purgés au-delà)
- ☑ **Partager « Nom de guilde »** par guilde, avec **taille estimée** du
  prochain export (KB) — et un bouton **« Vider »** pour effacer le journal de
  cette guilde (le roster est conservé)
- 🔘 **Forcer un export complet (resync)**

## Commandes

```
/auberdine guild              # Résumé de la guilde courante + taille export estimée
/auberdine guild scan         # Forcer un scan du roster
/auberdine guild members      # Lister les membres (triés par rang)
/auberdine guild log [n]      # n derniers événements (défaut 20)
/auberdine guild list         # Lister les guildes suivies et leur partage
/auberdine guild share on|off # (Dé)activer le partage de la guilde courante
/auberdine guild resync       # Forcer un export complet au prochain export
/auberdine guild clear        # Réinitialiser les données de la guilde courante
```

## Vie privée

- Les **notes officier ne sont jamais collectées ni exportées**.
- Suivi actif uniquement sur le serveur Auberdine et si le perso est en guilde.

## Limites assumées (vs GRM)

- Pas de synchronisation P2P inter-joueurs : le vecteur de partage est l'export
  serveur auberdine.eu.
- Le regroupement des alts reste **manuel** (système main/alt existant).
- Pas d'anniversaires / événements calendrier.
