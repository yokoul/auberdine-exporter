# Brief serveur — page de connexion de l'uploader (`/uploader/connect`)

> Destiné à l'agent auberdine.eu. Objectif : permettre au **client local
> AuberdineUploader** (démon de bureau) d'obtenir sa clé d'ingestion `ak_…`
> **sans CLI ni copier-coller**, via le navigateur, en réutilisant la session
> Discord déjà présente sur le site.
>
> C'est le pattern « loopback » des applications natives (RFC 8252) : le client
> ouvre une page du site, le site (authentifié par cookie) crée/renvoie la clé
> et **redirige vers un petit serveur local** que le client écoute sur
> `127.0.0.1`. Le site reste l'autorité ; le client ne manipule jamais Discord.

## Endpoint à créer

```
GET /uploader/connect?port=<int>&state=<opaque>
```

- **Auth** : session Discord du site (cookie). Si l'utilisateur n'est pas
  connecté → flux de login Discord habituel, puis retour sur cette URL (mêmes
  `port` / `state` préservés).
- **Paramètres** :
  - `port` (requis) : port TCP du serveur loopback du client. **Valider** :
    entier dans `1024–65535`. Sinon `400`.
  - `state` (requis) : nonce opaque généré par le client (anti-CSRF). À
    **réinjecter tel quel** dans la redirection, sans interprétation. Borne de
    longueur raisonnable (ex. ≤ 128 car., alphanumérique + `-_`). Sinon `400`.

## Comportement

1. Résoudre le `discord_id` depuis la session.
2. Récupérer/forger la clé **famille `ingest`** (mécanique existante `ensure` /
   `regenerate` de §1.2 du contrat) :
   - **Aucune clé ingest** → `ensure` (création) → on dispose du secret `ak_…`.
   - **Clé ingest déjà existante** → le secret ne peut pas être re-montré
     (stockage hash). Afficher une page de confirmation :
     *« Un client est déjà connecté à ce compte. Reconnecter ici **révoquera**
     l'ancien client. [Confirmer] [Annuler] »*. Sur confirmation → `regenerate`
     → nouveau secret `ak_…`. (Cohérent avec « un seul client actif par compte ».)
3. **Rediriger** (302) vers le serveur loopback du client :

```
HTTP/1.1 302 Found
Location: http://127.0.0.1:<port>/callback?key=ak_<secret>&state=<state>
```

   - `key` : le secret en clair (transite uniquement sur `127.0.0.1`, jamais sur
     le réseau public).
   - `state` : exactement la valeur reçue.
   - En cas d'annulation/erreur, rediriger avec une erreur plutôt que la clé :
     `http://127.0.0.1:<port>/callback?error=<code>&state=<state>`
     (codes suggérés : `cancelled`, `not_authenticated`, `server_error`).

## Points d'attention

- **Validation stricte de `port`** (plage ephemeral) pour éviter une redirection
  vers un port arbitraire ; l'hôte est forcé à `127.0.0.1` par le serveur (jamais
  fourni par le client).
- **`state` à usage unique** côté client ; le serveur n'a qu'à le réémettre.
- Le client n'écoute que le temps de la connexion (listener éphémère, timeout
  ~3 min) puis ferme.
- Pas besoin de `client_id` Discord côté client ni d'OAuth client : l'autorité
  reste le site.

## Côté client (pour info, déjà implémenté)

- Démarre un serveur sur `127.0.0.1:<port aléatoire>`, route `GET /callback`.
- Génère `state` aléatoire, ouvre le navigateur sur
  `https://auberdine.eu/uploader/connect?port=…&state=…`.
- À réception du `/callback` : vérifie `state`, lit `key` (ou `error`), affiche
  une page « Vous pouvez fermer cet onglet », stocke la clé en `0o600`, et passe
  ensuite tous les appels `/ingest/*` en `Authorization: Bearer ak_…`.
- Déclenché par le bouton **« Se connecter à auberdine.eu »** du tray (et une
  commande `auberdine-uploader connect` de secours pour les machines headless,
  qui imprime l'URL si le navigateur ne s'ouvre pas).

## Récap du flux

```
Tray « Se connecter »
      │  (ouvre le navigateur)
      ▼
GET auberdine.eu/uploader/connect?port=P&state=S   ── cookie Discord ──┐
      │                                                                │
      │  ensure (1ʳᵉ fois)  /  regenerate (déjà connecté, après confirm)│
      ▼                                                                │
302 → http://127.0.0.1:P/callback?key=ak_…&state=S  ◀──────────────────┘
      │
      ▼
Démon : vérifie state, stocke la clé, tray « Connecté ✅ »
```
