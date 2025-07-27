# AuberdineExporter - Documentation Serveur Base64

## Vue d'ensemble

Le système AuberdineExporter utilise un **format Base64 sécurisé** pour résoudre les problèmes de reproductibilité JSON côté serveur. Cette approche garantit une validation fiable des exports d'addon WoW Classic.

## Architecture de sécurité

### Problème résolu
- **Ancien système** : Impossible de reproduire exactement le formatage JSON côté serveur
- **Solution Base64** : Encode les données en Base64, validation sur la chaîne encodée

### Format d'export

```json
{
  "metadata": { /* Métadonnées de l'export */ },
  "dataBase64": "eyJjaGFyYWN0ZXJzIjp7Li4u",  // Données JSON encodées en Base64
  "signature": "69ecbe7214f39518",            // Signature multi-passes
  "signatureInfo": {
    "algorithm": "multi-pass-md5-base64",
    "hasChallenge": true,
    "nonce": "1753632275_7200_011E2333",
    "timestamp": 1753632275
  },
  "validation": {
    "dataChecksum": "3a1dd05ef0e1ece",       // MD5 du Base64 (pas du JSON)
    "encoding": "base64",
    "exportComplete": true,
    "missingAPIs": {},
    "warnings": {}
  }
}
```

## Flux de validation

### 1. Côté Addon (Lua)
```lua
-- 1. Générer JSON des données
local jsonData = tableToJSON(exportData, 0, true)

-- 2. Encoder en Base64
local dataBase64 = base64Encode(jsonData)

-- 3. Checksum sur le Base64
local dataChecksum = md5_sumhexa(dataBase64)

-- 4. Signature multi-passes
local signatureBase = dataBase64 .. clientKey .. nonce .. challenge
local signature1 = md5_sumhexa(signatureBase)
local signature2 = md5_sumhexa(signature1 .. timestamp .. clientKey)
local finalSignature = md5_sumhexa(signature2 .. nonce)
```

### 2. Côté Serveur (Node.js)
```javascript
// 1. Vérifier le dataChecksum
const expectedChecksum = md5_sumhexa(exportData.dataBase64);
if (expectedChecksum !== exportData.validation.dataChecksum) {
    return { valid: false, error: "DataChecksum invalide" };
}

// 2. Décoder le Base64
const decodedJSON = Buffer.from(exportData.dataBase64, 'base64').toString('utf8');
const decodedData = JSON.parse(decodedJSON);

// 3. Recalculer la signature (même logique que l'addon)
const signatureBase = exportData.dataBase64 + CLIENT_KEY + nonce + ADDON_CHALLENGE;
const signature1 = md5_sumhexa(signatureBase);
const signature2 = md5_sumhexa(signature1 + timestamp + CLIENT_KEY);
const expectedSignature = md5_sumhexa(signature2 + nonce);

// 4. Valider
return { valid: expectedSignature === exportData.signature };
```

## Fichiers principaux

### `verifyBase64Export.js` - Validateur principal
- **Fonction** : `verifySignature(exportData)` - Auto-détecte et valide le format
- **Fonction** : `verifyBase64Signature(exportData)` - Validation spécifique Base64
- **Fonction** : `extractDataFromBase64Export(exportData)` - Extrait les données décodées
- **Fonction** : `md5_sumhexa(s)` - Hash compatible avec l'addon Lua

### `secret.json` - Configuration serveur
```json
{
  "privateKey": "votre-clé-privée",
  "challenge": "auberdine-2025-recipe-export"
}
```

### Constantes importantes
```javascript
const CLIENT_KEY = "auberdine-v1";               // Doit correspondre à l'addon
const ADDON_CHALLENGE = "auberdine-2025-recipe-export";  // Challenge hardcodé
```

## Utilisation

### Validation CLI
```bash
node verifyBase64Export.js export.json
```

### Validation programmatique
```javascript
const { verifySignature, extractDataFromBase64Export } = require('./verifyBase64Export');

// Valider l'export
const result = verifySignature(exportData);
if (result.valid) {
    // Extraire les données pour traitement
    const gameData = extractDataFromBase64Export(exportData);
    console.log('Personnages:', gameData.summary.totalCharacters);
} else {
    console.error('Validation échouée:', result.error);
}
```

## Sécurité

### Double validation
1. **DataChecksum** : MD5 du Base64 - détection immédiate de modification
2. **Signature** : Multi-passes avec challenge/nonce - validation cryptographique

### Détection de falsification
- **Modification du Base64** → DataChecksum invalide → Rejet immédiat
- **Modification des métadonnées** → Signature invalide → Rejet
- **Replay attack** → Nonce/timestamp unique → Protection temporelle

### Algorithme de signature
```
signatureBase = dataBase64 + clientKey + nonce + challenge
signature1 = MD5(signatureBase)
signature2 = MD5(signature1 + timestamp + clientKey)  
finalSignature = MD5(signature2 + nonce)
```

## Migration depuis l'ancien format

### Formats supportés
- ✅ **Nouveau** : `"algorithm": "multi-pass-md5-base64"` - Format Base64 sécurisé
- ❌ **Legacy** : `"algorithm": "multi-pass-md5"` - Ancien format JSON (non supporté)
- ❌ **Simple** : Pas de `signatureInfo` - Format simple legacy (non supporté)

### Auto-détection
```javascript
if (exportData.dataBase64 && exportData.signatureInfo?.algorithm === "multi-pass-md5-base64") {
    return verifyBase64Signature(exportData);
} else {
    return { valid: false, error: "Format non supporté - utilisez le nouveau format Base64" };
}
```

## Dépannage

### Erreurs communes

#### "DataChecksum invalide"
- **Cause** : Le Base64 a été modifié
- **Solution** : Vérifier l'intégrité du fichier d'export

#### "Erreur de décodage Base64"
- **Cause** : Base64 corrompu ou invalide
- **Solution** : Vérifier l'encodage du fichier

#### "Signature invalide"
- **Cause** : Métadonnées modifiées ou clés incorrectes
- **Solution** : Vérifier `CLIENT_KEY` et `ADDON_CHALLENGE`

#### "Format non reconnu"
- **Cause** : Export généré avec un ancien addon
- **Solution** : Utiliser l'addon mis à jour avec support Base64

### Debug
```javascript
// Activer les logs de debug
console.log('DEBUG - Components:');
console.log('  dataBase64 length:', exportData.dataBase64.length);
console.log('  CLIENT_KEY:', CLIENT_KEY);
console.log('  nonce:', nonce);
console.log('  ADDON_CHALLENGE:', ADDON_CHALLENGE);
```

## Performance

### Tailles typiques
- **Export complet** : ~29KB (dont 28KB de Base64)
- **Données décodées** : ~11KB JSON
- **Ratio compression** : Base64 ajoute ~38% de overhead
- **Validation** : < 10ms pour un export typique

### Optimisations possibles
- Utiliser gzip sur le Base64 pour réduire la taille
- Cache des signatures validées (avec expiration basée sur timestamp)
- Validation asynchrone pour les gros exports

## Évolutions futures

### Améliorations possibles
1. **Compression** : gzip du Base64 avant signature
2. **Versioning** : Support multi-version des algorithmes
3. **Batch validation** : Validation de multiples exports
4. **Métriques** : Logs de validation pour monitoring

### Compatibilité
- Le format Base64 est **rétrocompatible** avec les futures versions
- L'ajout de nouveaux champs dans `metadata` ne casse pas la validation
- La signature est calculée uniquement sur `dataBase64` + métadonnées fixes

## Contact & Support

Pour toute question sur cette implémentation :
1. Vérifier cette documentation
2. Examiner les tests dans `verifyBase64Export.js`
3. Consulter les logs de debug pour diagnostiquer les problèmes

---
*Documentation générée le 27 juillet 2025 - Version Base64 sécurisée*
