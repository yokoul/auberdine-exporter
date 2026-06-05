# Suivi de guilde (Guild Tracking) — v1.5.0

Module inspiré de **GRM (Guild Roster Manager)**, permettant de collecter et
d'exporter l'état et l'historique d'activité de votre guilde vers
[auberdine.eu](https://auberdine.eu).

## Fonctionnement

Le suivi combine **deux sources de vérité** (exactement comme GRM) :

1. **Snapshot du roster + diff d'état**
   - On appelle `C_GuildInfo.GuildRoster()` (rate-limité à 10 s par Blizzard),
     puis on écoute l'événement `GUILD_ROSTER_UPDATE`.
   - On itère `1..GetNumGuildMembers()` via `GetGuildRosterInfo(i)` pour
     construire une photo du roster, indexée par **GUID** (clé stable).
   - On compare cette photo à la précédente pour détecter :
     - **entrée** (membre nouveau) → `JOIN`
     - **sortie** (membre disparu) → `LEAVE`
     - **changement de rang** (`rankIndex` différent ; un index plus bas = rang
       plus élevé) → `PROMOTE` / `DEMOTE`
     - **note publique modifiée** → `NOTE`

2. **Parsing des messages système (`CHAT_MSG_SYSTEM`)**
   - Le diff seul ne distingue pas un départ volontaire d'une expulsion, ni
     *qui* a promu/kické. On matche donc les *global strings* localisées de
     Blizzard (`ERR_GUILD_JOIN_S`, `ERR_GUILD_LEAVE_S`, `ERR_GUILD_REMOVE_SS`,
     `ERR_GUILD_PROMOTE_SSS`, `ERR_GUILD_DEMOTE_SSS`) → fonctionne dans **toutes
     les langues** sans table de traduction.
   - L'acteur extrait est mis en tampon (indice) puis fusionné avec l'événement
     détecté par le diff : un `LEAVE` devient `KICK` avec l'auteur, une
     promotion/rétrogradation reçoit son auteur.

Le premier scan après connexion **amorce silencieusement** la photo (aucun
flood de `JOIN` pour les membres déjà présents). Un re-scan périodique
(60 s) capte les changements faits par d'autres officiers.

## Données collectées

Stockées dans `AuberdineExporterDB.guild` :

| Champ | Description |
|-------|-------------|
| `name`, `realm`, `faction` | Identité de la guilde |
| `ranks` | Table `rankIndex → rankName` |
| `roster` | Membres (nom, classe, niveau, rang, **note publique**, première vue, date d'entrée) |
| `log` | Journal horodaté append-only (max 1000 entrées) : `JOIN`, `LEAVE`, `KICK`, `PROMOTE`, `DEMOTE`, `NOTE` |

> **Vie privée :** les **notes officier** ne sont **jamais** collectées ni
> exportées. Seules les notes publiques le sont.

## Commandes

```
/auberdine guild              # Résumé (membres, rangs, taille du journal)
/auberdine guild scan         # Forcer un scan du roster
/auberdine guild members      # Lister les membres (triés par rang)
/auberdine guild log [n]      # Afficher les n derniers événements (défaut 20)
/auberdine guild clear        # Réinitialiser les données de guilde
```

## Export

Les données de guilde sont injectées dans le payload d'export sous la clé
`guild` (puis encodées en Base64 + signées comme le reste) :

```json
{
  "guild": {
    "name": "Ma Guilde",
    "realm": "Auberdine",
    "faction": "Alliance",
    "lastScan": 1733400000,
    "memberCount": 42,
    "ranks": { "0": "Guild Master", "1": "Officier", "4": "Membre" },
    "members": [
      { "name": "Carnalis", "class": "MAGE", "level": 60,
        "rankIndex": 0, "rankName": "Guild Master",
        "publicNote": "chef", "joinDate": 1733000000, "firstSeen": 1733000000 }
    ],
    "log": [
      { "ts": 1733400500, "type": "PROMOTE", "target": "Bob",
        "actor": "Yan", "detail": "Officier", "fromRank": "Membre" },
      { "ts": 1733401000, "type": "KICK", "target": "BadGuy", "actor": "Yan" }
    ]
  }
}
```

## Limites assumées (vs GRM)

- Pas de synchronisation P2P inter-joueurs : le vecteur de partage est l'export
  serveur auberdine.eu (plus simple et robuste).
- Le regroupement des alts reste **manuel** et réutilise le système main/alt
  existant de l'addon (`/auberdine settype`, `/auberdine linkto`).
- Pas d'anniversaires / événements calendrier.
