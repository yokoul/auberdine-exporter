# Audit de sécurité — client `auberdine-uploader`

**Date :** 2026-06-11
**Question posée :** la présence de l'uploader sur le poste d'un utilisateur présente-t-elle un risque ou un trou de sécurité ?
**Périmètre :** tout le dossier `uploader/` (démon Go, flux de connexion, auto-update, installation, parseur SavedVariables, tray).

## Conclusion

**Aucune faille de sévérité élevée.** Le client est conçu de façon conservatrice et se comporte bien sur un poste utilisateur :

- **aucune élévation de privilèges** — tout vit dans le profil utilisateur (systemd `--user`, clé Run `HKCU`, LaunchAgent `gui/$uid`). Pas de `sudo`, pas d'admin, pas de service système ;
- **égress réseau limité** à un seul endpoint configuré (`https://auberdine.eu` par défaut), en **HTTPS avec vérification TLS standard** (aucun `InsecureSkipVerify`, aucun `http://` en dur pour les envois) ;
- **lecture de fichiers cantonnée** au dossier d'installation WoW : la SavedVariable de l'addon (`AuberdineExporter.lua`) et les logs de combat (`WoWCombatLog*.txt`). Le client ne parcourt jamais de fichiers personnels arbitraires ;
- **données émises** : uniquement l'export produit par l'addon et des segments de log de combat WoW, vers l'endpoint, authentifiés par la clé API de l'utilisateur — avec **consentement granulaire** (deux interrupteurs Exports / Logs de donjon, plus une Pause globale) ;
- **clé API stockée en `0600`** dans le répertoire de config utilisateur standard ;
- **aucune injection de commande** : tous les `exec.Command` passent des arguments en tableau (pas de shell). Le seul appel via shell (`powershell` dans `stopInstalled`, Windows) échappe correctement le chemin (`'` → `''`) et ne reçoit que le chemin du profil de l'utilisateur lui-même ;
- **dépendances minimales** : `fyne.io/systray`, `golang.org/x/sys`, `github.com/godbus/dbus/v5`. Surface supply-chain réduite.

En résumé : **installer l'uploader n'ouvre pas l'accès à la machine** à un tiers, n'élève aucun privilège et n'exfiltre pas de données hors du périmètre WoW vers un autre serveur que celui configuré.

Restent quelques points de **défense en profondeur** à connaître — aucun n'est un bug actif, ce sont des propriétés à durcir.

---

## Points à connaître (défense en profondeur)

### 1. Moyenne — L'auto-update est un canal d'exécution de code distant, dont la confiance repose entièrement sur le serveur

**Fichiers :** `internal/selfupdate/selfupdate.go`, `internal/app/app.go` (`maybeSelfUpdate`, contrôle au démarrage + toutes les 24 h).

Le mécanisme est correctement implémenté : HTTPS imposé (`Available()` exige `https://`), **SHA-256 vérifié avant** toute substitution, taille bornée (100 Mo), restauration de l'ancien binaire en cas d'échec, jamais de mise à jour sur un build `dev`. La chaîne est saine **tant qu'on fait confiance au serveur**.

Le point structurel : l'URL **et** le SHA-256 attendu proviennent tous deux de la **même réponse** `/ingest/status`. Le hash ne protège donc que contre une corruption en transit — **pas** contre un serveur malveillant ou compromis. Quiconque contrôle `auberdine.eu` (ou son pipeline de release, ou la chaîne TLS/DNS) peut faire pointer le client vers **n'importe quel binaire** ; celui-ci est téléchargé, installé et le processus **redémarré automatiquement**, sans aucune action de l'utilisateur, de façon persistante.

C'est le modèle de confiance inhérent à tout auto-updater — l'utilisateur fait déjà confiance à auberdine.eu en installant le logiciel. Mais c'est **la propriété la plus conséquente** d'avoir le client en place, et elle mérite d'être explicite.

**Durcissement recommandé :**
- **Signer les releases** avec une clé qui n'est **pas** détenue par le serveur d'ingestion (ex. `minisign` / `cosign`), embarquer la clé **publique** dans le binaire, et vérifier la signature avant le swap. Une compromission du serveur ne suffirait alors plus à pousser du code.
- Faire revérifier le schéma `https://` directement dans `download()` (aujourd'hui il dépend de `Available()` — défense en profondeur si un futur appelant court-circuitait ce garde-fou).
- Option de configuration pour figer/désactiver l'auto-update sur les postes sensibles (le champ `DisableAutoUpdate` existe déjà — bien documenter qu'il coupe ce canal).

### 2. Faible — Parseur SavedVariables : récursion non bornée et lecture sans plafond de taille

**Fichiers :** `internal/luasv/luasv.go` (`parseValue` ↔ `parseTable`), `internal/app/app.go` (`os.ReadFile(svPath)`).

`parseTable`/`parseValue` s'appellent mutuellement sans **limite de profondeur** : un `AuberdineExporter.lua` aux tables très profondément imbriquées peut épuiser la pile Go (panique **fatale**, non récupérable → arrêt du démon). De même, `os.ReadFile` charge le fichier **entièrement en mémoire** sans plafond.

Impact réel **faible** : le fichier est local et écrit par l'addon (de confiance) ou l'utilisateur lui-même — c'est au pire un déni de service du démon par un fichier corrompu/malveillant que l'attaquant aurait déjà pu planter (même utilisateur). Aucune élévation, aucune fuite. À durcir par robustesse :
- limite de profondeur de récursion dans le parseur ;
- plafond de taille à la lecture (ex. quelques dizaines de Mo) ;
- éventuellement `recover()` autour du parsing pour qu'un fichier d'un compte n'abatte pas le cycle des autres.

### 3. Faible — Flux `connect` : clé API en paramètre d'URL loopback, pas de PKCE

**Fichier :** `internal/connect/connect.go`.

Bon suivi du pattern loopback natif (RFC 8252) : `127.0.0.1:0`, `state` anti-CSRF aléatoire (16 octets), vérification du préfixe `ak_`, timeout 3 min, serveur éphémère. La clé revient toutefois en **query string** (`/callback?key=ak_…`) — susceptible d'atterrir dans des journaux —, et il n'y a pas de contrôle d'`Origin` (le `state` à usage unique reste la défense, conforme au pattern). Exposition **même-machine uniquement**. Acceptable pour un client premier-parti ; un POST ou un échange de type code/PKCE serait plus propre si la surface s'élargit.

### 4. Info — Surcharges par variables d'environnement

`AUBERDINE_ENDPOINT` (redirige l'endpoint) et `AUBERDINE_PROFILE` (choisit un fichier de config) sont pratiques pour le dev. Elles exigent un **contrôle local de l'environnement** (même utilisateur) — pas un vecteur distant. `profileSuffix` neutralise correctement les séparateurs de chemin (anti-évasion de répertoire). À garder en tête : un autre processus du même utilisateur pouvant fixer l'environnement du service pourrait rediriger les envois — mais ce niveau d'accès permet déjà bien d'autres choses.

---

## Ce qui est explicitement bien fait (à conserver)

| Domaine | Constat |
|---------|---------|
| Privilèges | Zéro élévation ; tout en espace utilisateur (systemd `--user` / `HKCU` Run / LaunchAgent). |
| Réseau | Un seul endpoint, HTTPS, TLS vérifié, timeouts, backoff, corps de réponse borné (`LimitReader 1 Mo`). |
| Secrets | Clé API en `0600` ; jamais loggée (masquée dans `status` via `maskKey`). |
| Périmètre données | Lecture limitée au dossier WoW ; consentement granulaire + pause. |
| Auto-update | HTTPS imposé, SHA-256 vérifié **avant** swap, taille bornée, restauration sur échec, pas de MAJ en `dev`. |
| Exec | Arguments en tableau partout ; pas d'interpolation shell de données non fiables ; échappement correct du seul appel PowerShell. |
| Désinstallation | Retire service + binaire, conserve config — propre et prévisible. |

## Priorités suggérées

1. **(Moyenne)** Signer les releases avec une clé hors-serveur et vérifier la signature dans `selfupdate` — referme le seul vrai canal d'exécution de code distant.
2. **(Faible)** Borner profondeur de récursion et taille de fichier dans `luasv` / la lecture des SavedVariables.
3. **(Faible)** `download()` : revérifier le schéma `https://` localement.
4. **(Faible)** `connect` : envisager POST/PKCE plutôt que la clé en query string.

*Note : ces points 2 à 4 sont du durcissement (défense en profondeur), pas des vulnérabilités exploitables à distance. Le point 1 décrit le modèle de confiance d'un auto-updater, pas un défaut de code — mais c'est la propriété qui mérite la décision la plus consciente.*
