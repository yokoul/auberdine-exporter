# Changelog - Version 1.5.1

## 🎒 **Version 1.5.1** - Dressroom, Chambre froide & Snapshot local
*Date de sortie: 9 mai 2026*

> **Note de version** — La 1.5.1 consolide les apports de plusieurs branches
> de développement qui n'avaient pas été publiés sous leur tag intermédiaire :
> la collecte d'inventaire/consommables (initialement marquée v1.4.0 par
> erreur en parallèle d'une v1.4.0 locale) et le snapshot local
> (initialement v1.4.1). Les versions 1.4.x n'ont jamais été publiées sur
> CurseForge — la branche live est passée 1.3.4 → 1.5.0 → **1.5.1**.

### ✅ **Nouvelles fonctionnalités**

#### 🎒 Collecte d'inventaire complet (export auberdine.eu)
- **Équipement porté** : tous les emplacements (1..19) sont scannés et exportés
  via `character.inventory.equipment` (en plus du champ existant `character.equipment`).
- **Sacs** : contenu complet du sac à dos et des 4 sacs principaux
  (`character.inventory.bags[bagId] = { numSlots, slots }`), avec quantités.
- **Banque** : contenu de la banque principale et des sacs de banque
  (`character.inventory.bank.{main, bags}`), scanné automatiquement à
  l'ouverture du coffre-fort.
- **Trousseau** (keyring) sur Classic Era.
- Chaque slot expose `id`, `name`, `link`, `iLevel`, `quality`, `count`,
  `equipLoc`, `type`, `subType`, `classID`, `subClassID`.

#### 🧊 Agrégation des consommables (export auberdine.eu)
- `character.consumables.items[itemID]` regroupe les potions, élixirs,
  flacons, parchemins, nourriture/boisson, bandages, améliorations d'objet
  (huiles, pierres à aiguiser, pierres de poids) et juju présents en sacs
  et en banque.
- Chaque entrée contient `id`, `name`, `link`, `quality`, `count`, `bucket`
  (potion / elixir / flask / scroll / food / bandage / enhancement / juju /
  other) et `locations.{bags, bank}` pour la ventilation.
- **Bucketing FR+EN** : `CONSUMABLE_NAME_HINTS` couvre les noms d'items
  français et anglais courants en Classic Era. Couverture mesurée ≈83 % sur
  un échantillon réel de 24 items consommables (les 4 résiduels sont des
  cas edge légitimes : junk, quest item, items au nom unique).

#### 💾 Snapshot brut local (NON exporté)
- `character.localSnapshot` stocke les sacs et la banque sous forme brute
  dans la SavedVariable `AuberdineExporterDB`. **Cette donnée n'est PAS
  incluse dans les exports auberdine.eu** ; elle est réservée à un futur
  client desktop local (Electron).
- Structure : `{ lastUpdate, lastBagsUpdate, lastBankUpdate, bags, keyring,
  bank }` avec tous les champs disponibles via `C_Container` et `GetItemInfo`.

### 🔁 **Synchronisation automatique**
- Scan complet à la connexion (`PLAYER_ENTERING_WORLD`) avec délai de 3 s
  pour laisser le cache `GetItemInfo` se peupler.
- Mise à jour des sacs sur `BAG_UPDATE_DELAYED`.
- Mise à jour de l'équipement sur `PLAYER_EQUIPMENT_CHANGED` (alimente à la
  fois `character.equipment` et `character.inventory.equipment`).
- Mise à jour de la banque sur `BANKFRAME_OPENED`,
  `PLAYERBANKSLOTS_CHANGED` et `PLAYERBANKBAGSLOTS_CHANGED` (uniquement
  quand la banque est ouverte).
- Throttle interne (~2 s) pour éviter les scans intempestifs.

### 📡 **Intégration export auberdine.eu**
- Le payload JSON multi-personnages contient désormais, pour chaque
  personnage exporté :
  - `inventory.equipment` (objets équipés, slot → item complet)
  - `inventory.bags` (contenu des sacs)
  - `inventory.bank` (banque principale + sacs de banque)
  - `inventory.keyring` (trousseau Classic Era)
  - `consumables.items` (agrégat avec compteur, bucket et localisation)
- Les statistiques globales du `summary` incluent `totalEquipment`,
  `totalBagItems`, `totalBankItems` et `totalConsumables`.
- Le format JSON simple (`ExportToSimpleJSON`) inclut également
  l'inventaire et les consommables du personnage courant.
- **Étanchéité du snapshot local** : `localSnapshot` n'est référencé dans
  aucune des deux fonctions d'export ; il reste strictement local.
- Côté serveur Auberdine, ces données alimenteront les vues **Dressroom**
  et **Chambre froide** des joueurs authentifiés sur leurs propres
  personnages.

### 🆕 **Nouvelles commandes**
- `/auberdine inventory` (alias `inv`) : scan manuel de l'inventaire
  (équipement, sacs, banque, consommables).
- `/auberdine consumables` (alias `consu`) : recalcule et affiche le résumé
  des consommables agrégés par bucket.
- `/auberdine localsnapshot` (alias `snapshot`, `snap`) : force un rescan
  immédiat du snapshot brut local et affiche les compteurs et horodatages.
- `/auberdine scan` lance maintenant un scan complet (métiers + inventaire).

### 📁 **Fichiers modifiés**
- `AuberdineExporter.lua` : modules de collecte inventaire, agrégation
  consommables, snapshot local, événements, intégration export, commandes
  slash, hints de bucketing FR+EN.
- `AuberdineExporter.toc` : version 1.5.1.
- `create-release.sh` : version 1.5.1.
- `README.md` : documentation de la version 1.5.1 (et rattrapage de la
  documentation 1.5.0).
- `docs/CHANGELOG_1.5.1.md` : ce changelog.

### 🛡️ **Confidentialité**
- La collecte ne fonctionne que sur le serveur Auberdine (validation
  existante).
- Aucune donnée d'autres joueurs n'est collectée : l'addon ne lit que vos
  sacs, votre banque et votre équipement personnel.
- Le snapshot local brut reste sur votre poste — aucun envoi serveur.
