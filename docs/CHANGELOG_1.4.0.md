# Changelog - Version 1.4.0

## 🎒 **Version 1.4.0** - Dressroom & Chambre froide
*Date de sortie: 7 mai 2026*

### ✅ **Nouvelles Fonctionnalités**
- **Collecte automatique de l'équipement** : tous les emplacements portés (1..19) sont scannés et exportés.
- **Collecte des sacs** : contenu complet du sac à dos et des 4 sacs principaux, avec quantités.
- **Collecte de la banque** : contenu de la banque principale et des sacs de banque, scanné automatiquement à l'ouverture du coffre-fort.
- **Collecte du trousseau** (keyring) sur Classic Era.
- **Agrégation des consommables** : potions, élixirs, flacons, parchemins, nourriture/boisson,
  bandages, améliorations d'objet (huiles, pierres à aiguiser, pierres à pondérer) et juju
  sont regroupés par item, classés par "bucket" (potion / elixir / flask / scroll / food /
  bandage / enhancement / juju / other) et avec une ventilation sacs / banque.

### 🔁 **Synchronisation automatique**
- Scan complet à la connexion (`PLAYER_ENTERING_WORLD`) avec délai pour laisser le cache
  `GetItemInfo` se peupler.
- Mise à jour des sacs sur `BAG_UPDATE_DELAYED`.
- Mise à jour de l'équipement sur `PLAYER_EQUIPMENT_CHANGED`.
- Mise à jour de la banque sur `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED` et
  `PLAYERBANKBAGSLOTS_CHANGED` (uniquement quand la banque est ouverte).
- Throttle interne (~2s) pour éviter les scans intempestifs.

### 📡 **Intégration export auberdine.eu**
- L'export JSON multi-personnages contient désormais, pour chaque personnage exporté :
  - `inventory.equipment` : objets équipés (slot → item)
  - `inventory.bags` : contenu des sacs (bagId → { numSlots, slots })
  - `inventory.bank` : contenu de la banque principale et des sacs de banque
  - `inventory.keyring` : trousseau (Classic Era)
  - `consumables.items` : agrégat des consommables avec compteur, bucket et localisation
- Les statistiques globales du `summary` incluent `totalEquipment`, `totalBagItems`,
  `totalBankItems` et `totalConsumables`.
- Le format JSON simple (`ExportToSimpleJSON`) inclut également l'inventaire et les
  consommables du personnage courant.
- Côté serveur Auberdine, ces données alimentent les vues **Dressroom** et
  **Chambre froide** des joueurs authentifiés sur leurs propres personnages.

### 🆕 **Nouvelles commandes**
- `/auberdine inventory` (alias `/auberdine inv`) : scan manuel de l'inventaire.
- `/auberdine consumables` (alias `consu`) : recalcule et affiche le résumé des
  consommables agrégés par bucket.
- `/auberdine scan` lance maintenant un scan complet (métiers + inventaire).

### 🖥️ **Interface principale**
- L'écran récapitulatif affiche par personnage le nombre d'objets équipés, en sacs,
  en banque et le nombre de consommables uniques.

### 📁 **Fichiers Modifiés**
- `AuberdineExporter.lua` : module de collecte inventaire + consommables, événements,
  intégration export, commandes slash.
- `AuberdineExporter.toc` : version 1.4.0 et notes.
- `README.md` : documentation des nouvelles fonctionnalités.
- `docs/CHANGELOG_1.4.0.md` : ce changelog.

### 🛡️ **Confidentialité**
- La collecte ne fonctionne que sur le serveur Auberdine (validation existante).
- Aucune donnée d'autres joueurs n'est collectée : l'addon ne lit que vos sacs, votre
  banque et votre équipement personnel.
