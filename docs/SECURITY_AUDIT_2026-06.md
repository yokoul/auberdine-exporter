# Audit de sécurité — AuberdineExporter

**Date :** 2026-06-11
**Périmètre :** dépôt `yokoul/auberdine-exporter` (addon WoW Lua, uploader Go, scripts serveur Node.js, scripts d'installation). Le serveur d'ingestion auberdine.eu lui-même n'est **pas** dans ce dépôt et n'a donc pas pu être audité directement.

---

## Résumé

| # | Sévérité | Constat | État |
|---|----------|---------|------|
| 1 | **Critique** | Le « système de validation cryptographique » de l'export est entièrement falsifiable : aucun secret n'entre dans le calcul de la signature. | À corriger |
| 2 | **Élevée** | `server/secret.json` était versionné dans git (et reste dans l'historique). | Partiellement corrigé |
| 3 | **Moyenne** | La fonction de hachage « MD5 » est un DJB2 maison : ni résistant aux préimages, ni aux collisions. | À corriger |
| 4 | **Moyenne** | `docs/SECURITY.md` survend des garanties de sécurité qui n'existent pas (faux sentiment de sûreté). | À corriger |
| 5 | Faible | Flux `connect` : la clé API transite en paramètre d'URL sur le loopback (pas de PKCE). | Acceptable, à noter |
| 6 | Info | Points positifs de l'uploader Go (à conserver). | OK |

---

## 1. Critique — La signature d'export n'offre aucune garantie d'authenticité

**Fichiers :** `AuberdineExporter.lua` (l. 1646-1664, 2095-2132), `server/verifyBase64Export.js`, `server/verifyExport.js`.

La signature est calculée ainsi (addon, format Base64) :

```
signatureBase  = dataBase64 + clientKey + nonce + challenge
signature1     = hash(signatureBase)
signature2     = hash(signature1 + timestamp + clientKey)
finalSignature = hash(signature2 + nonce)
```

Chacune des entrées est **publique ou présente dans l'export lui-même** :

- `dataBase64` — c'est la charge utile, transmise en clair ;
- `clientKey = "auberdine-v1"` — codé en dur dans l'addon open-source (`AuberdineExporter.lua:663`) ;
- `challenge = "auberdine-2025-recipe-export"` — codé en dur (`AuberdineExporter.lua:666`), répété dans la doc et les tests ;
- `nonce` et `timestamp` — émis tels quels dans `signatureInfo`.

**Aucune clé secrète n'intervient.** Le `privateKey` chargé depuis `secret.json` est lu par les vérificateurs mais **jamais utilisé** dans le calcul (`verifyBase64Export.js` le charge puis ne s'en sert pas ; `verifyExport.js` signe avec `clientKey`, pas avec `privateKey`).

**Conséquence :** n'importe qui peut fabriquer un export arbitraire (faux personnages, niveaux gonflés, recettes inventées) et produire une signature valide — il suffit de réexécuter l'algorithme, entièrement disponible dans le dépôt. Toute la section « Détection de falsification » de `docs/SECURITY.md` est donc fausse : modifier les données **puis recalculer la signature** passe la validation.

**Surface d'impact réelle :** la voie d'upload de l'uploader Go est protégée par une vraie clé API (`Authorization: Bearer ak_…`) — c'est *elle* qui authentifie l'expéditeur, pas la signature. Le risque porte donc sur **la voie d'import manuel** (l'utilisateur copie/colle un export Base64 sur le site) et sur tout traitement serveur qui ferait *confiance* à la signature pour garantir l'intégrité — typiquement les classements / le recensement (census), où un joueur peut s'auto-attribuer des données.

**Recommandations (par ordre de robustesse) :**

1. **Le serveur est la source de vérité.** Ne jamais accepter de données « parce qu'elles sont signées ». Recouper côté serveur ce qui est vérifiable (clé API → identité Discord ; déduplication ; bornes de valeurs plausibles).
2. Si une signature client est conservée pour de l'**intégrité de transport**, la nommer comme telle (checksum), pas comme une garantie d'authenticité.
3. Une vraie authenticité exige une **signature asymétrique** (clé privée serveur jamais distribuée, ou HMAC avec secret par-compte délivré via le flux `connect`). Tout secret embarqué dans l'addon open-source est, par définition, public.

## 2. Élevée — Secret versionné dans git

**Fichier :** `server/secret.json`.

Le fichier contenant `privateKey` était suivi par git, alors que `server/secret.example.json` indique explicitement : *« Ce fichier ne doit JAMAIS être versionné — ajoutez-le à .gitignore »*.

**Corrigé dans cette branche :** `git rm --cached server/secret.json` + ajout à `.gitignore`.

**Reste à faire (décision du propriétaire — opération destructive) :**
- La valeur reste présente dans **l'historique git** (`git log -- server/secret.json`). Si cette valeur a une quelconque importance, il faut la **révoquer/changer** côté serveur, puis éventuellement purger l'historique (`git filter-repo`) — un rewrite d'historique impacte tous les clones et n'a pas été effectué ici.
- En pratique le `privateKey` actuel (`auberdine-secret-2025`) n'étant utilisé nulle part (constat #1), sa fuite est de faible valeur — mais l'hygiène doit être corrigée avant qu'un *vrai* secret n'y atterrisse.

## 3. Moyenne — Hachage non cryptographique présenté comme « MD5 »

**Fichier :** `AuberdineExporter.lua:1646` (`md5_sumhexa`), répliqué dans `server/*.js`.

```lua
local hash = 5381
hash = ((hash * 33) + c) % 2147483647   -- DJB2 tronqué sur 31 bits
```

C'est un DJB2 réduit modulo 2³¹, pas MD5. L'espace de sortie effectif est d'environ 16 caractères hexadécimaux (`pass2 .. pass3`, complété puis tronqué à 32) — ni résistant aux préimages, ni aux collisions. Même si un secret était introduit (constat #1), cette primitive ne supporterait pas un usage cryptographique. À remplacer par une vraie fonction (SHA-256 ; HMAC-SHA256 si un secret est en jeu). `docs/SECURITY.md` mentionne d'ailleurs SHA-256 comme « évolution future » — c'est en réalité un prérequis.

## 4. Moyenne — Documentation trompeuse

**Fichier :** `docs/SECURITY.md`.

Le document affirme une « validation cryptographique avancée », « impossible sans le code source complet », et liste des scénarios d'attaque « bloqués » qui ne le sont pas (constat #1). Au-delà de l'inexactitude technique, cela crée un faux sentiment de sécurité qui peut conduire à fonder des décisions serveur sur la signature. À réécrire pour refléter le modèle réel : **l'authentification repose sur la clé API ; la signature d'export est au mieux un checksum d'intégrité de transport.**

## 5. Faible — Flux `connect` (loopback OAuth-like)

**Fichier :** `uploader/internal/connect/connect.go`.

L'implémentation suit correctement le pattern loopback natif (RFC 8252) : écoute sur `127.0.0.1:0`, `state` anti-CSRF aléatoire (16 octets), vérification du préfixe `ak_`, timeout. Deux points mineurs :

- La clé API revient en **paramètre d'URL** (`/callback?key=ak_…`). Sur le loopback le risque est faible, mais les query strings peuvent fuiter dans des journaux/historiques. Un POST ou un échange via `state` (pattern PKCE/code) serait plus propre.
- Pas de vérification d'`Origin`/`Referer` sur le handler `/callback` ; le `state` à usage unique reste la défense principale, ce qui est conforme au pattern.

Acceptable en l'état pour un client premier-parti ; à garder en tête si la surface s'étend.

## 6. Info — Points positifs à conserver

- **Uploader Go — auto-update (`internal/selfupdate/selfupdate.go`)** : HTTPS imposé, **vérification SHA-256 avant** toute substitution du binaire, taille bornée (100 Mo), restauration sur échec, refus de mise à jour sur build `dev`. Bonne chaîne de confiance (le SHA-256 provient de la réponse `/ingest/status` authentifiée en TLS).
- **Config (`internal/config/config.go`)** : la clé API est écrite en `0600`, dans le répertoire de config utilisateur standard. `profileSuffix` neutralise les séparateurs de chemin (anti-évasion de répertoire).
- **Transport (`internal/upload/upload.go`)** : Bearer token, backoff exponentiel, distinction correcte erreurs transitoires/définitives, corps de réponse borné (`LimitReader 1 Mo`).
- **Installation** : services posés en espace utilisateur, **sans élévation** ; pas de `sudo`/admin requis.

---

## Plan d'action priorisé

1. **(Critique)** Côté serveur auberdine.eu : ne pas faire reposer l'intégrité/authenticité des données sur la signature client. Authentifier via la clé API, recouper et borner les données, dédupliquer. Pour l'import manuel, traiter les données comme non fiables.
2. **(Élevée)** Décider du sort de l'historique git de `secret.json` (révocation de la valeur si pertinente ; purge d'historique si souhaitée). Le suivi du fichier est déjà stoppé dans cette branche.
3. **(Moyenne)** Remplacer `md5_sumhexa` par SHA-256/HMAC-SHA256 si une signature est conservée.
4. **(Moyenne)** Réécrire `docs/SECURITY.md` pour décrire le modèle de menace réel.
5. **(Faible)** Envisager POST + PKCE pour le flux `connect` si la surface s'élargit.

*Note : le code serveur d'ingestion (auberdine.eu) ne figure pas dans ce dépôt. Les conclusions #1 et #4 supposent que la validation de référence (`server/verify*.js`) reflète la logique réelle. Si le serveur applique déjà des contrôles indépendants (recoupement par clé API, bornes), l'impact pratique du #1 est d'autant réduit — à confirmer côté serveur.*
