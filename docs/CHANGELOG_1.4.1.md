# Changelog - Version 1.4.1

## 💾 **Version 1.4.1** - Snapshot local complet (futur client Electron)
*Date de sortie: 7 mai 2026*

### ✅ **Nouvelle fonctionnalité**
- **Snapshot brut local des sacs et de la banque** stocké uniquement dans la
  SavedVariable (`AuberdineExporterDB`). Cette donnée alimentera un futur
  client Electron local et **n'est PAS incluse dans les exports** envoyés à
  auberdine.eu.

### 📦 **Structure stockée**
Pour chaque personnage :

```lua
AuberdineExporterDB.characters[charKey].localSnapshot = {
    lastUpdate, lastBagsUpdate, lastBankUpdate,
    bags = {
        [bagId] = { numSlots, slots = { [slot] = { ...item brut... } } }
    },
    keyring = { numSlots, slots = { ... } },  -- Classic Era
    bank = {
        main = { numSlots, slots = { ... } },
        bags = { [5..11] = { numSlots, slots = { ... } } }
    }
}
```

Chaque entrée d'objet expose tous les champs disponibles (selon l'API
`C_Container` / legacy + `GetItemInfo`) : `bag`, `slot`, `link`,
`itemString`, `hyperlink`, `iconFileID`, `stackCount`, `quality`, `isLocked`,
`isReadable`, `hasLoot`, `isFiltered`, `hasNoValue`, `isBound`, `itemId`,
`name`, `itemLevel`, `requiredLevel`, `type`, `subType`, `maxStackCount`,
`equipLoc`, `sellPrice`, `classID`, `subClassID`, `bindType`.

### 🔁 **Synchronisation**
- Mis à jour automatiquement en parallèle de `ScanBags` / `ScanBank`
  (events `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, etc.).
- Inclus dans `ScanFullInventory` (login + `/auberdine scan`).

### 🆕 **Commande**
- `/auberdine localsnapshot` (alias `snapshot`, `snap`) : force un rescan
  immédiat et affiche les compteurs et horodatages des derniers snapshots.

### 🛡️ **Étanchéité avec l'export**
- `localSnapshot` n'est référencé dans aucune des deux fonctions d'export
  (`ExportToJSON` et `ExportToSimpleJSON`) — celles-ci construisent leur
  payload en sélectionnant explicitement les champs (`info`, `configuration`,
  `inventory`, `consumables`, …). Toute donnée hors de cette liste reste
  strictement locale.

### 📁 **Fichiers Modifiés**
- `AuberdineExporter.lua` : module snapshot local, nouvelle commande slash,
  hooks dans `RunBagsScan` / `RunBankScan` / `ScanFullInventory`.
- `AuberdineExporter.toc` : version 1.4.1.
- `create-release.sh` : version 1.4.1.
- `docs/CHANGELOG_1.4.1.md` : ce changelog.
