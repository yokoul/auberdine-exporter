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

Le démon par défaut n'a **aucune dépendance externe** (stdlib uniquement) :

```bash
cd uploader
go build -o auberdine-uploader ./cmd/auberdine-uploader
go test ./...
```

Le **tray** (icône de barre des tâches) est optionnel, derrière le build tag
`tray` — il tire alors `fyne.io/systray` (D-Bus/StatusNotifierItem sur Linux,
natif sur macOS/Windows) :

```bash
go build -tags tray -o auberdine-uploader ./cmd/auberdine-uploader
```

## Commandes

```bash
auberdine-uploader            # lance le démon (surveillance, headless)
auberdine-uploader tray       # surveillance + icône de barre des tâches (binaire -tags tray)
auberdine-uploader status     # état : chemins, config, identité Discord
auberdine-uploader doctor     # diagnostique la détection des fichiers
```

Menu du tray : état actif/pause · **Pause / Reprendre** · **Login / Logout
Discord** · **Quitter**.

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
| `internal/auth` | identité Discord : logout + ouverture du login (OAuth différé) |
| `internal/tray` | icône de barre des tâches (build tag `tray`) + stub par défaut |
| `cmd/auberdine-uploader` | binaire et sous-commandes |

## État d'avancement

Implémenté (P0) :

- [x] Parseur SavedVariables Lua (testé)
- [x] Détection multi-OS des chemins (Windows / macOS / Linux-Wine)
- [x] Surveillance par polling léger, sans dépendance
- [x] Pipeline d'export : parse → dédup → upload
- [x] Manifeste côté addon (`DungeonLogger.lua` : `LoggingCombat` + `uploaderManifest`)
- [x] Découpage des logs de donjon **par fenêtre temporelle** (timestamps → octets) + envoi brut
- [x] Association de l'identifiant Discord à la publication (`X-Auberdine-Discord`)
- [x] Client HTTP gzip + retry à backoff exponentiel
- [x] État technique persistant (dédup, offsets)
- [x] Commandes `daemon` / `status` / `doctor` / `tray`
- [x] **Tray** (build tag) : état, pause/reprendre, login/logout Discord, quitter

À venir :

- [ ] **Discord OAuth** (flux navigateur + redirection loopback) — déférable ;
      pour l'instant logout fonctionnel + ouverture de la page de liaison
- [ ] **Contrat d'API d'ingestion** auberdine.eu (endpoints + auth) — dépendance amont
- [ ] Empaquetage Homebrew / Scoop / systemd-user
```
