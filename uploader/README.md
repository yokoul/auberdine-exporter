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
auberdine-uploader connect    # lie l'uploader à votre compte auberdine.eu (ouvre le navigateur)
auberdine-uploader status     # état : chemins, config, clé API
auberdine-uploader doctor     # diagnostique la détection des fichiers
```

Menu du tray : état/connexion · **Se connecter à auberdine.eu** · **Pause /
Reprendre** · **Envoyer les exports** · **Envoyer les logs de donjon** ·
**Quitter**.

## Configuration

Fichier JSON dans le répertoire de config utilisateur
(`~/.config/auberdine-uploader/config.json` sur Linux/macOS,
`%AppData%\auberdine-uploader\config.json` sur Windows) :

```jsonc
{
  "wowPath": "",                 // vide => auto-détection ; sinon dossier _classic_era_
  "endpoint": "https://auberdine.eu", // base de l'API d'ingestion
  "apiKey": "ak_…",              // clé d'ingestion — remplie par `connect`, pas à la main
  "uploadExports": true,         // consentement : exports
  "uploadDungeonLogs": true,     // consentement : logs de donjon
  "pollIntervalSeconds": 5
}
```

La **clé d'ingestion** (`ak_…`, scope `ingest:upload`) n'est **pas saisie à la
main** : elle est obtenue via **« Se connecter à auberdine.eu »** (tray) ou
`auberdine-uploader connect`. Le client ouvre le navigateur, le site (authentifié
par votre session Discord) crée la clé et la renvoie sur un serveur local
éphémère `127.0.0.1` (pattern loopback RFC 8252) ; aucun copier-coller. La clé
porte le `discord_id` qui déclenche l'auto-claim des personnages, et part ensuite
en `Authorization: Bearer` sur `/ingest/*`. Clé perdue / nouvelle machine :
relancer `connect` (révoque l'ancienne — un seul client actif par compte).

L'état technique (hashs de dédup, runs déjà transmis) est stocké séparément dans
le répertoire de cache utilisateur (surchargeable via `AUBERDINE_UPLOADER_STATE_DIR`).

## Structure

| Paquet | Rôle |
|--------|------|
| `internal/luasv` | parseur générique de SavedVariables Lua |
| `internal/config` | configuration persistante |
| `internal/discovery` | détection multi-OS des chemins WoW |
| `internal/upload` | interface + client HTTP (contrat /ingest v1 : status, export, combatlog) |
| `internal/connect` | provisioning de la clé par loopback navigateur (RFC 8252) |
| `internal/app` | démon : surveillance, dédup, pipeline d'envoi |
| `internal/tray` | icône de barre des tâches (build tag `tray`) + stub par défaut |
| `cmd/auberdine-uploader` | binaire et sous-commandes |

## État d'avancement

Implémenté :

- [x] Parseur SavedVariables Lua (testé)
- [x] Détection multi-OS des chemins (Windows / macOS / Linux-Wine)
- [x] Surveillance par polling léger, sans dépendance
- [x] **Contrat d'API d'ingestion v1** : `GET /ingest/status`, `POST /ingest/export`
      (`{jsonData}`), `POST /ingest/combatlog` (`{meta + logGzipBase64}`, sha256/sizeRaw)
- [x] **Authentification par clé API** (`Authorization: Bearer ak_…`, scope `ingest:upload`)
- [x] **Connexion sans CLI ni copier-coller** : provisioning de la clé par loopback navigateur (`connect` / bouton tray)
- [x] Pipeline d'export : l'addon publie l'export **signé** (`uploaderExport`), le démon le relaie → dédup → upload
- [x] Manifeste côté addon (`DungeonLogger.lua` : `LoggingCombat` + `uploaderManifest`)
- [x] Découpage des logs de donjon **par fenêtre temporelle** (timestamps → octets), gzip + base64
- [x] Gestion `duplicate` / erreurs définitives (4xx) vs transitoires (réseau, 429, 5xx) + backoff
- [x] État technique persistant (dédup), répertoire surchargeable
- [x] Commandes `daemon` / `status` / `doctor` / `tray`
- [x] **Tray** (build tag) : état, pause/reprendre, bascules exports & logs de donjon, quitter

À venir :

- [ ] Page serveur `/uploader/connect` côté auberdine.eu (cf. `../docs/UPLOADER-CONNECT-SERVER-BRIEF.md`)
- [ ] Empaquetage Homebrew / Scoop / systemd-user
```
