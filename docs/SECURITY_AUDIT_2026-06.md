# Audit de sécurité — AuberdineExporter

**Date :** 2026-06-11
**Périmètre :** dépôt `yokoul/auberdine-exporter` (addon WoW Lua, uploader Go, scripts serveur Node.js, scripts d'installation). Le serveur d'ingestion auberdine.eu lui-même n'est **pas** dans ce dépôt et n'a donc pas pu être audité directement.

> **Modèle de menace retenu (confirmé par le mainteneur).** La signature d'export et la « clé » de `secret.json` ne visent **pas** une authenticité cryptographique : elles sont un **frein contre la modification manuelle de l'export par un joueur** (gonfler ses recettes/personnages avant import). La valeur est **publique par conception** — c'est la raison de sa présence dans le dépôt. Cet audit en tient compte : il ne traite pas la clé publique comme un secret fuité, mais signale les endroits où la doc laisse croire à une garantie plus forte qu'elle ne l'est.

---

## Résumé

| # | Sévérité | Constat | État |
|---|----------|---------|------|
| 1 | Info / Doc | La signature d'export est un frein anti-bidouille, pas un contrôle d'authenticité — elle est reproductible par quiconque lit le code. Conforme à l'intention ; seul le serveur peut faire autorité. | À garder en tête |
| 2 | **Moyenne** | `docs/SECURITY.md` survend la mécanique comme « validation cryptographique avancée » / « impossible sans le code source » — faux, et risque de fonder des décisions serveur dessus. | À corriger |
| 3 | Faible | `md5_sumhexa` est un DJB2 tronqué nommé « MD5 » : suffisant comme frein, mais le nom induit en erreur. | Cosmétique |
| 4 | Faible | Message contradictoire : `secret.example.json` dit « JAMAIS versionné » alors que la clé est publique par design et que `verify*.js` la lit au runtime. | À clarifier |
| 5 | Faible | Flux `connect` : la clé API transite en paramètre d'URL sur le loopback (pas de PKCE). | Acceptable, à noter |
| 6 | Info | Points positifs de l'uploader Go (à conserver). | OK |

---

## 1. Info — La signature d'export est un frein, pas une authentification

**Fichiers :** `AuberdineExporter.lua` (l. 1646-1664, 2095-2132), `server/verifyBase64Export.js`, `server/verifyExport.js`.

La signature combine `dataBase64`, `clientKey` (`auberdine-v1`), `nonce`, `challenge` (`auberdine-2025-recipe-export`) puis trois passes de hachage. Toutes les entrées sont publiques ou présentes dans l'export ; le `privateKey` de `secret.json` n'entre pas dans le calcul.

**C'est conforme à l'intention** : décourager un joueur lambda d'éditer son export à la main (un export modifié sans recalcul échoue à la validation). Contre quelqu'un qui lit le dépôt open-source, le frein n'existe plus — mais ce n'est pas le public visé.

La seule recommandation qui demeure est **architecturale, pas un défaut de code** :

- **Le serveur auberdine.eu doit rester la source de vérité.** Pour tout ce qui a un enjeu (classements, census, leaderboards), ne pas accorder de confiance à la signature seule. L'authentification réelle de la voie uploader est déjà la **clé API** (`Authorization: Bearer ak_…`) — c'est la bonne approche. Pour la voie d'import manuel (copier-coller sur le site), traiter les données comme déclaratives : recouper, borner les valeurs plausibles, dédupliquer.

Aucune action de code requise dans ce dépôt sur ce point.

## 2. Moyenne — `docs/SECURITY.md` survend la mécanique

**Fichier :** `docs/SECURITY.md`.

Le document parle de « système de validation cryptographique avancé », affirme qu'une falsification est « impossible sans le code source complet » et que la signature « garantit l'authenticité ». Or le code source *est* public et la signature est reproductible. Le risque n'est pas la mécanique (qui joue bien son rôle de frein) mais la **promesse** : un lecteur — ou un développeur serveur — pourrait fonder une décision de confiance sur cette garantie inexistante.

**Recommandation :** réécrire la doc pour décrire le modèle réel — « frein anti-modification côté client ; l'authenticité repose sur la clé API et les recoupements serveur ». C'est un simple alignement de la documentation sur l'intention déjà retenue.

## 3. Faible — Nommage « MD5 » trompeur (cosmétique)

`md5_sumhexa` (`AuberdineExporter.lua:1646`) est un DJB2 tronqué sur 31 bits, répliqué dans `server/*.js`. Parfaitement acceptable pour un frein anti-bidouille — mais le nom `md5` et la mention « MD5 natif » dans la doc laissent croire à une primitive cryptographique. Renommer (`obfHash`, `tamperGuard`…) clarifierait l'intention. Aucune urgence.

## 4. Faible — Consigne contradictoire sur `secret.json`

`server/secret.example.json` affirme : *« Ce fichier ne doit JAMAIS être versionné »*. Dans les faits, la valeur est **publique par conception** et `verify*.js` la lit au runtime ; `secret.json` est donc légitimement présent dans le dépôt. La note de l'exemple est trompeuse au vu de l'usage réel.

**Recommandation :** soit retirer/atténuer la mention « JAMAIS versionné » dans `secret.example.json` (puisque la valeur est publique), soit, si un *vrai* secret devait un jour y être ajouté, refactorer pour le sortir du dépôt à ce moment-là. En l'état, **aucun retrait n'est nécessaire** et le fichier reste suivi.

## 5. Faible — Flux `connect` (loopback OAuth-like)

**Fichier :** `uploader/internal/connect/connect.go`.

Bon suivi du pattern loopback natif (RFC 8252) : écoute sur `127.0.0.1:0`, `state` anti-CSRF aléatoire (16 octets), vérification du préfixe `ak_`, timeout. Deux points mineurs : la clé revient en **paramètre d'URL** (`/callback?key=ak_…`, susceptible de fuiter dans des journaux) et il n'y a pas de contrôle d'`Origin` (le `state` à usage unique reste la défense, conforme au pattern). Acceptable pour un client premier-parti.

## 6. Info — Points positifs à conserver

- **Auto-update (`internal/selfupdate/selfupdate.go`)** : HTTPS imposé, **vérification SHA-256 avant** substitution du binaire, taille bornée (100 Mo), restauration sur échec, pas de mise à jour sur build `dev`. La chaîne de confiance (SHA-256 issu de la réponse `/ingest/status` en TLS) est saine.
- **Config (`internal/config/config.go`)** : clé API écrite en `0600` ; `profileSuffix` neutralise les séparateurs de chemin (anti-évasion de répertoire).
- **Transport (`internal/upload/upload.go`)** : Bearer token, backoff exponentiel, distinction correcte transitoire/définitif, corps de réponse borné (`LimitReader 1 Mo`).
- **Installation** : services en espace utilisateur, **sans élévation**.

---

## Plan d'action priorisé

1. **(Moyenne)** Aligner `docs/SECURITY.md` sur le modèle réel : frein client + autorité serveur via clé API. Supprimer les promesses d'« impossible à falsifier ».
2. **(Faible)** Clarifier la note de `secret.example.json` (valeur publique → la mention « JAMAIS versionné » n'a pas lieu d'être).
3. **(Faible)** Renommer `md5_sumhexa` pour ne plus suggérer une primitive cryptographique.
4. **(Faible)** Envisager POST + PKCE pour `connect` si la surface s'élargit.
5. **(Architectural, hors dépôt)** S'assurer que le serveur auberdine.eu reste la source de vérité (clé API + recoupements) — particulièrement pour la voie d'import manuel.

*Note : le code serveur d'ingestion (auberdine.eu) ne figure pas dans ce dépôt. Si le serveur applique déjà des contrôles indépendants (recoupement par clé API, bornes), le point #5 est déjà couvert — à confirmer côté serveur.*
