# auberdine-uploader

Démon léger multi-OS qui transmet à auberdine.eu :

- les **exports** de l'addon (contenu de la SavedVariable `AuberdineExporterDB`) ;
- les **segments bruts de log de combat de donjon**, découpés selon le manifeste publié par l'addon.

Voir la conception complète dans [`../docs/UPLOADER-ARCHITECTURE.md`](../docs/UPLOADER-ARCHITECTURE.md).

## Principe

L'uploader est un **pont mince** disque → serveur. Il ne fait aucune analyse
métier : il lit, déduplique, transmet, et retient ce qui est déjà parti. Toute
l'intelligence du découpage des runs vit dans l'addon (manifeste) ; l'analyse
des logs vit côté auberdine.eu.

```
SavedVariable ─┐
               ├─▶ watcher (polling) ─▶ dédup/état ─▶ upload (gzip, retry) ─▶ auberdine.eu
WoWCombatLog ──┘                              ▲
                                   manifeste de runs (addon)
```

## Build

Aucune dépendance externe (stdlib uniquement) — build hors-ligne.

```bash
cd uploader
go build -o auberdine-uploader ./cmd/auberdine-uploader
go test ./...
```

## Commandes

```bash
auberdine-uploader            # lance le démon (surveillance)
auberdine-uploader status     # état : chemins, config, identité Discord
auberdine-uploader doctor     # diagnostique la détection des fichiers
```

## Configuration

Fichier JSON dans le répertoire de config utilisateur
(`~/.config/auberdine-uploader/config.json` sur Linux/macOS,
`%AppData%\auberdine-uploader\config.json` sur Windows) :

```jsonc
{
  "wowPath": "",                 // vide => auto-détection ; sinon dossier _classic_era_
  "endpoint": "",                // base de l'API d'ingestion auberdine.eu (à figer)
  "uploadExports": true,         // consentement : exports
  "uploadDungeonLogs": true,     // consentement : logs de donjon
  "pollIntervalSeconds": 5,
  "discord": {}                  // rempli après login OAuth
}
```

L'état technique (hashs de dédup, offsets de log, runs déjà transmis) est stocké
séparément dans le répertoire de cache utilisateur.

## Structure

| Paquet | Rôle |
|--------|------|
| `internal/luasv` | parseur générique de SavedVariables Lua |
| `internal/config` | configuration persistante |
| `internal/discovery` | détection multi-OS des chemins WoW |
| `internal/upload` | interface + client HTTP (gzip, retry, auth) |
| `internal/app` | démon : surveillance, dédup, pipeline d'envoi |
| `cmd/auberdine-uploader` | binaire et sous-commandes |

## État d'avancement

Implémenté (P0) :

- [x] Parseur SavedVariables Lua (testé)
- [x] Détection multi-OS des chemins (Windows / macOS / Linux-Wine)
- [x] Surveillance par polling léger, sans dépendance
- [x] Pipeline d'export : parse → dédup → upload
- [x] Consommation du manifeste de runs → upload de segments bruts de log
- [x] Client HTTP gzip + retry à backoff exponentiel
- [x] État technique persistant (dédup, offsets)
- [x] Commandes `daemon` / `status` / `doctor`

À venir :

- [ ] **Tray** (icône barre des tâches) : quit / pause / login Discord / logout Discord
- [ ] **Discord OAuth** (flux navigateur + redirection loopback)
- [ ] **Manifeste côté addon** (`LoggingCombat` + `uploaderManifest`) — dépendance amont
- [ ] **Contrat d'API d'ingestion** auberdine.eu (endpoints + auth) — dépendance amont
- [ ] Empaquetage Homebrew / Scoop / systemd-user
```
