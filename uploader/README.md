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

## Signature Windows (Authenticode)

Windows 11 avec **Smart App Control** actif bloque silencieusement les
exécutables non signés au lancement de session : l'icône du tray n'apparaît
plus, sans aucun message (événements Code Integrity 3033/3077). SAC n'offre
aucune exclusion par application — la seule vraie réponse est de signer le
binaire Windows.

La voie retenue : **SignPath Foundation** (signature Authenticode gratuite pour
les projets open source). Leur exigence centrale : ne signer que des artefacts
construits de façon traçable par une CI publique — c'est le rôle du workflow
`.github/workflows/uploader-build.yml`, qui reconstruit l'exe Windows avec
exactement les flags de `scripts/release.sh`.

Mise en route (une fois la candidature acceptée sur signpath.org) :

1. Installer la GitHub App SignPath sur le dépôt (demandé pendant la
   candidature).
2. Créer côté SignPath un projet `auberdine-uploader` avec une signing policy
   `release-signing` (slugs attendus par le workflow).
3. Dans le dépôt GitHub : variable `SIGNPATH_ORGANIZATION_ID` (Settings →
   Secrets and variables → Actions → Variables) + secret `SIGNPATH_API_TOKEN`.
4. Le job `sign-windows` s'activera alors de lui-même sur chaque tag `vX.Y.Z`
   et produira l'artefact `auberdine-uploader-windows-amd64-signed`.

**Articulation avec `release.sh`** : l'Authenticode modifie le PE, donc
l'empreinte SHA256 et la signature ed25519 doivent être refaites sur l'exe
*signé*. Séquence de release une fois SignPath actif : tagger/pousser d'abord,
attendre le job `sign-windows`, télécharger l'exe signé dans `dist/` à la place
du build local, puis laisser `release.sh` produire SHA256SUMS + `.sig` et
publier. (À automatiser dans `release.sh` quand la chaîne sera acceptée.)

## Commandes

```bash
auberdine-uploader            # lance le démon (surveillance, headless)
auberdine-uploader tray       # surveillance + icône de barre des tâches (binaire -tags tray)
auberdine-uploader connect    # lie l'uploader à votre compte auberdine.eu (ouvre le navigateur)
auberdine-uploader status     # état : chemins, config, clé API
auberdine-uploader doctor     # diagnostique la détection des fichiers + l'état du service
auberdine-uploader install    # installe le service utilisateur (démarre à l'ouverture de session)
auberdine-uploader uninstall  # retire le service (conserve config et clé)
```

Menu du tray : état/connexion · **Se connecter à auberdine.eu** · **Pause /
Reprendre** · **Envoyer les exports** · **Envoyer les logs de donjon** ·
**Quitter**.

## Installation en service utilisateur

`install` pose l'uploader en service de session — démarré à l'ouverture de
session, relancé en cas d'arrêt anormal, **sans aucune élévation de
privilèges**. Le binaire courant est d'abord copié vers un emplacement stable
du profil (installer depuis un dossier de téléchargement est donc sûr), puis :

| OS | Mécanisme | Emplacement |
|----|-----------|-------------|
| macOS | LaunchAgent (launchd, session Aqua) | `~/Library/LaunchAgents/eu.auberdine.uploader.plist`, journal dans `~/Library/Logs/auberdine-uploader.log` |
| Linux | unité systemd-user | `~/.config/systemd/user/auberdine-uploader.service`, journal via `journalctl --user -u auberdine-uploader` |
| Windows | clé Run par utilisateur (HKCU) | binaire sous `%LOCALAPPDATA%\auberdine-uploader\` |

Le mode suit le binaire : un binaire compilé `-tags tray` est installé avec son
icône de barre des tâches, un binaire standard tourne en démon discret.
`uninstall` retire le service et le binaire copié mais **conserve la
configuration et la clé** — réinstaller plus tard ne demande pas de refaire
`connect`. État visible dans `doctor`.

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

### Profils prod / dev

La clé d'ingestion est **liée à un environnement** : une clé prod n'authentifie
pas sur dev et inversement. Pour basculer facilement, utilisez des **profils**,
chacun avec son propre fichier config (endpoint + clé) :

- `AUBERDINE_PROFILE` choisit le profil → fichier `config.<profil>.json`.
  Vide / `prod` / `production` → `config.json` (défaut).
- `AUBERDINE_ENDPOINT` surcharge l'endpoint au vol (persisté au prochain
  `connect`) — pratique pour pointer un dev local sans éditer le fichier.

```bash
# Prod (profil par défaut) — une fois :
AUBERDINE_ENDPOINT=https://auberdine.eu auberdine-uploader connect
auberdine-uploader daemon            # ou le service installé

# Dev local — une fois :
AUBERDINE_PROFILE=dev AUBERDINE_ENDPOINT=http://localhost:3000 auberdine-uploader connect
AUBERDINE_PROFILE=dev auberdine-uploader daemon

# Vérifier le profil/endpoint actif :
auberdine-uploader status
AUBERDINE_PROFILE=dev auberdine-uploader status
```

Astuce : le **service installé** (`install`) tourne sur le profil par défaut
(prod). Gardez le dev pour un lancement manuel en terminal avec
`AUBERDINE_PROFILE=dev` — séparation nette prod (toujours actif) / dev (ponctuel).

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
