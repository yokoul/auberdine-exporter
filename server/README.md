# AuberdineExporter - Serveur de Validation

## 🎯 Vue d'ensemble

Serveur de validation pour les exports d'addon WoW Classic **AuberdineExporter**. 
Utilise un **format Base64 sécurisé** pour garantir la validation fiable des données de jeu.

## 🚀 Démarrage rapide

```bash
# 1. Configuration
cp secret.example.json secret.json
# Éditez secret.json avec vos paramètres

# 2. Test rapide
node verifyBase64Export.js test-export-b64.json

# 3. Suite de tests complète
node test-base64-system.js
```

## 📚 Documentation complète

| Fichier | Description |
|---------|-------------|
| **[README-Base64.md](./README-Base64.md)** | 📖 **Documentation principale** - Architecture, sécurité, format |
| **[API.md](./API.md)** | 🔧 **Référence API** - Fonctions, exemples d'usage, intégration |
| **[secret.example.json](./secret.example.json)** | ⚙️ **Configuration** - Exemple de configuration serveur |

## 🛠️ Fichiers principaux

| Fichier | Rôle |
|---------|------|
| `verifyBase64Export.js` | ✅ **Validateur principal** - Validation des exports Base64 |
| `test-base64-system.js` | 🧪 **Suite de tests** - Tests automatisés et analyse d'exports |
| `test-export-b64.json` | 📄 **Export d'exemple** - Export valide pour tests |

## ⚡ Usage rapide

### Validation CLI
```bash
node verifyBase64Export.js mon-export.json
```

### Validation programmatique
```javascript
const { verifySignature, extractDataFromBase64Export } = require('./verifyBase64Export');

const result = verifySignature(exportData);
if (result.valid) {
    const gameData = extractDataFromBase64Export(exportData);
    console.log(`${gameData.summary.totalCharacters} personnages, ${gameData.summary.totalRecipes} recettes`);
}
```

## 🔒 Sécurité

✅ **Double validation** : Checksum + Signature multi-passes  
✅ **Détection falsification** : Modification immédiatement détectée  
✅ **Protection replay** : Nonce unique + timestamp  
✅ **Challenge hardcodé** : Protection contre les exports non-autorisés  

## 📊 Format Base64

**Problème résolu** : Impossible de reproduire exactement le formatage JSON côté serveur  
**Solution** : Encoder les données en Base64, validation sur la chaîne encodée  
**Avantage** : Validation reproductible à 100%  

```json
{
  "dataBase64": "eyJjaGFyYWN0ZXJzIjp7Li4u",  // Données encodées
  "signature": "69ecbe7214f39518",           // Signature sécurisée
  "validation": {
    "dataChecksum": "3a1dd05ef0e1ece"      // MD5 du Base64
  }
}
```

## 🧪 Tests

```bash
# Tests automatisés
node test-base64-system.js

# Analyse d'un export spécifique  
node test-base64-system.js mon-export.json

# Test performance
node -e "require('./test-base64-system').runTests()"
```

## 🔄 Migration

- ✅ **Format Base64** : `"algorithm": "multi-pass-md5-base64"` (supporté)
- ❌ **Format Legacy** : `"algorithm": "multi-pass-md5"` (non supporté)
- ❌ **Format Simple** : Pas de `signatureInfo` (non supporté)

## 🚨 Dépannage

| Erreur | Solution |
|--------|----------|
| `DataChecksum invalide` | Données modifiées → Vérifier intégrité |
| `Format non reconnu` | Mettre à jour l'addon vers format Base64 |
| `Challenge invalide` | Vérifier `secret.json` |

## 📞 Support

1. 📖 Consulter la [documentation complète](./README-Base64.md)
2. 🔧 Vérifier la [référence API](./API.md)  
3. 🧪 Lancer les tests : `node test-base64-system.js`
4. 🔍 Analyser l'export : `node test-base64-system.js votre-export.json`

---
*Version Base64 sécurisée - Juillet 2025*
