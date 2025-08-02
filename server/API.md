# API Reference - AuberdineExporter Base64

## Modules disponibles

### `verifyBase64Export.js`

#### `verifySignature(exportData)`
Auto-détecte et valide un export AuberdineExporter.

**Paramètres:**
- `exportData` (Object|String) - Données d'export (objet ou JSON string)

**Retour:**
```javascript
{
  valid: boolean,              // true si la signature est valide
  error?: string,              // Message d'erreur si invalid
  expected?: string,           // Signature attendue (debug)
  received?: string,           // Signature reçue (debug)
  metadata?: {                 // Métadonnées de validation
    timestamp: number,
    nonce: string,
    hasChallenge: boolean,
    algorithm: string,
    challengeValid: boolean,
    dataSize: number,          // Taille Base64
    decodedSize: number        // Taille JSON décodé
  }
}
```

#### `verifyBase64Signature(exportData)`
Valide spécifiquement un export au format Base64.

#### `extractDataFromBase64Export(exportData)`
Extrait et décode les données de jeu depuis un export Base64.

**Retour:**
```javascript
{
  characters: {
    "CharName-Realm": {
      info: { name, level, class, race, ... },
      professions: { ... },
      skills: { ... },
      reputations: { ... }
    }
  },
  summary: {
    totalCharacters: number,
    totalProfessions: number,
    totalRecipes: number
  }
}
```

#### `md5_sumhexa(data)`
Calcule un hash MD5 compatible avec l'addon Lua.

### `test-base64-system.js`

#### `runTests()`
Exécute une suite de tests complète du système.

#### `analyzeExport(filename)`
Analyse et affiche les détails d'un export spécifique.

## Utilisation pratique

### Validation simple
```javascript
const { verifySignature } = require('./verifyBase64Export');

const exportData = JSON.parse(fs.readFileSync('export.json', 'utf8'));
const result = verifySignature(exportData);

if (result.valid) {
    console.log('✅ Export valide');
} else {
    console.log('❌ Export invalide:', result.error);
}
```

### Extraction et traitement des données
```javascript
const { verifySignature, extractDataFromBase64Export } = require('./verifyBase64Export');

// 1. Valider
const validation = verifySignature(exportData);
if (!validation.valid) {
    throw new Error('Export invalide: ' + validation.error);
}

// 2. Extraire les données
const gameData = extractDataFromBase64Export(exportData);

// 3. Traiter
for (const [charKey, character] of Object.entries(gameData.characters)) {
    console.log(`${character.info.name}: ${character.stats.totalRecipes} recettes`);
    
    for (const [profName, profession] of Object.entries(character.professions)) {
        console.log(`  ${profName}: ${profession.level}/${profession.maxLevel}`);
    }
}
```

### Intégration serveur web (Express)
```javascript
const express = require('express');
const { verifySignature, extractDataFromBase64Export } = require('./verifyBase64Export');

app.post('/api/upload-export', (req, res) => {
    try {
        // Valider l'export
        const validation = verifySignature(req.body);
        if (!validation.valid) {
            return res.status(400).json({ 
                error: 'Export invalide', 
                details: validation.error 
            });
        }
        
        // Extraire les données
        const gameData = extractDataFromBase64Export(req.body);
        
        // Traiter et sauvegarder
        // ... votre logique métier ...
        
        res.json({
            success: true,
            characters: Object.keys(gameData.characters).length,
            recipes: gameData.summary.totalRecipes
        });
        
    } catch (error) {
        res.status(500).json({ error: 'Erreur serveur', details: error.message });
    }
});
```

### Validation par lot
```javascript
const fs = require('fs');
const path = require('path');
const { verifySignature } = require('./verifyBase64Export');

function validateDirectory(dirPath) {
    const files = fs.readdirSync(dirPath).filter(f => f.endsWith('.json'));
    const results = {};
    
    for (const file of files) {
        try {
            const exportData = JSON.parse(fs.readFileSync(path.join(dirPath, file), 'utf8'));
            results[file] = verifySignature(exportData);
        } catch (error) {
            results[file] = { valid: false, error: error.message };
        }
    }
    
    return results;
}

// Usage
const results = validateDirectory('./exports/');
const valid = Object.values(results).filter(r => r.valid).length;
console.log(`${valid}/${Object.keys(results).length} exports valides`);
```

## Codes d'erreur

| Erreur | Description | Action |
|--------|-------------|---------|
| `"Format Base64 invalide - champs manquants"` | Export incomplet | Vérifier la structure |
| `"Algorithme non supporté"` | Format legacy ou inconnu | Mettre à jour l'addon |
| `"DataChecksum invalide"` | Données Base64 modifiées | Vérifier l'intégrité |
| `"Erreur de décodage Base64"` | Base64 corrompu | Régénérer l'export |
| `"Challenge invalide"` | Configuration serveur incorrecte | Vérifier `secret.json` |

## Performance

### Benchmarks typiques
- **Validation** : ~10ms pour 30KB d'export
- **Décodage** : ~5ms pour 11KB de données JSON
- **Checksum** : ~9ms pour 100KB de données

### Optimisations
- Cache les résultats de validation (basé sur timestamp + nonce)
- Validez le checksum avant la signature (plus rapide)
- Utilisez des streams pour les très gros exports

## Debugging

### Logs détaillés
```javascript
// Activer le debug dans verifyBase64Export.js
const DEBUG = true;

if (DEBUG) {
    console.log('DEBUG - Signature components:');
    console.log('  dataBase64 length:', exportData.dataBase64.length);
    console.log('  signatureBase length:', signatureBase.length);
    console.log('  signature1:', signature1);
    console.log('  signature2:', signature2);
    console.log('  finalSignature:', expectedSignature);
}
```

### Test de composants individuels
```javascript
const { md5_sumhexa } = require('./verifyBase64Export');

// Test du hash
console.log('Hash test:', md5_sumhexa('test data'));

// Test Base64
const data = '{"test": true}';
const b64 = Buffer.from(data).toString('base64');
const decoded = Buffer.from(b64, 'base64').toString('utf8');
console.log('Round-trip:', data === decoded);
```

---
*Documentation API générée le 27 juillet 2025*
