# Guide d'utilisation d'AuberdineExporter

## 🚀 Démarrage rapide

1. **Connectez-vous** à votre personnage WoW Classic Era
2. **Ouvrez les fenêtres de métiers** (optionnel mais recommandé)
3. **Cliquez sur le bouton minimap** d'Auberdine
4. **Cliquez "Exporter mes données"**
5. **Copiez le texte généré**
6. **Collez sur [auberdine.eu/import](https://auberdine.eu/import)**

## 🎮 Interface utilisateur

### Bouton minimap
- **Clic gauche** : Ouvre l'interface principale
- **Clic droit** : Menu contextuel rapide
- **Position** : Près de la minimap, déplaçable

### Interface principale
```
┌─────────────────────────────┐
│    🏔️ AuberdineExporter    │
├─────────────────────────────┤
│ [Exporter] [Config] [Help]  │
├─────────────────────────────┤
│                             │
│  📊 Statut personnage :     │
│  • Nom : Yokoul             │
│  • Niveau : 60              │
│  • Classe : Mage            │
│  • Guilde : <Les Irréductibles> │
│                             │
│  🔧 Métiers détectés :      │
│  • Alchimie (300/300)       │
│  • Herboristerie (300/300)  │
│                             │
│  📜 Recettes : 156 trouvées │
│  🏆 Réputations : 18 factions│
│                             │
│ [📤 Exporter mes données]   │
│                             │
└─────────────────────────────┘
```

### Boutons principaux
- **Exporter** : Lance l'export complet
- **Config** : Options et paramètres
- **Help** : Aide et documentation

## 📊 Export des données

### Préparation optimale
1. **Connexion avec tous vos personnages** (dans la session)
2. **Ouverture des fenêtres de métiers** :
   ```
   - Alchimie (K)
   - Forge (?)
   - Cuisine (?)
   - Couture (?)
   - Enchantement (?)
   - Ingénierie (?)
   - Premiers secours (?)
   - Herboristerie (?)
   - Minage (?)
   - Dépeçage (?)
   ```

### Processus d'export
1. **Cliquez "Exporter mes données"**
2. **Scanning automatique** :
   ```
   [AuberdineExporter] Scanning character: Yokoul
   [AuberdineExporter] ✓ Professions scanned
   [AuberdineExporter] ✓ Recipes detected: 156
   [AuberdineExporter] ✓ Reputation factions: 18
   [AuberdineExporter] ✓ Skills recorded
   [AuberdineExporter] Preparing Base64 export...
   [AuberdineExporter] ✓ Export ready!
   ```

3. **Fenêtre de résultat** :
   ```
   ┌─────────────────────────────┐
   │      📤 Export généré      │
   ├─────────────────────────────┤
   │                             │
   │ 🔒 Format : Base64 sécurisé │
   │ 📊 Taille : 45,2 KB        │
   │ 👥 Personnages : 3          │
   │ 🔑 Signature : ✓ Valide     │
   │                             │
   │ ┌─────────────────────────┐ │
   │ │eyJjaGFyYWN0ZXJzIjp7Li4u│ │
   │ │LiJ9LCJzaWduYXR1cmUiOi4u│ │
   │ │LiwidmFsaWRhdGlvbiI6ey4u│ │
   │ │ ... (copier tout)        │ │
   │ └─────────────────────────┘ │
   │                             │
   │ [📋 Copier] [🌐 auberdine.eu] │
   │                             │
   └─────────────────────────────┘
   ```

4. **Cliquez "Copier"** pour copier dans le presse-papier

### Import sur auberdine.eu
1. **Allez sur** [auberdine.eu/import](https://auberdine.eu/import)
2. **Collez** le texte dans la zone de texte
3. **Cliquez "Valider l'import"**
4. **Vérification automatique** :
   ```
   ✅ Format Base64 : Valide
   ✅ Signature : Vérifiée
   ✅ Données : 3 personnages détectés
   ✅ Import : Succès !
   ```

## 🎯 Commandes slash

### Commandes principales
```bash
/auberdine                 # Ouvre l'interface
/auberdine export          # Export immédiat
/auberdine help            # Affiche l'aide
/auberdine config          # Configuration
/auberdine version         # Version de l'addon
```

### Commandes de debug
```bash
/auberdine debug           # Mode debug ON/OFF
/auberdine status          # Statut détaillé
/auberdine reset           # Reset configuration
/auberdine test            # Test des fonctions
```

### Exemples d'usage
```
# Export rapide sans interface
/auberdine export

# Vérifier le fonctionnement
/auberdine status

# En cas de problème
/auberdine debug
/auberdine test
```

## ⚙️ Configuration

### Options disponibles
- **Auto-scan** : Scanner automatiquement à la connexion
- **Debug mode** : Messages détaillés dans le chat
- **Minimap button** : Afficher/cacher le bouton minimap
- **Multi-character** : Inclure tous les personnages de la session
- **Language** : Langue des données exportées

### Accès configuration
1. **Interface** : Bouton "Config" dans l'interface principale
2. **Commande** : `/auberdine config`
3. **Clic droit** : Sur le bouton minimap

## 📈 Optimisations

### Performance
- **Scanner régulièrement** : Mettez à jour vos recettes
- **Sessions groupées** : Connectez plusieurs personnages
- **Métiers ouverts** : Pour detection maximale des recettes

### Qualité des données
1. **Recettes** : Ouvrez toutes les fenêtres de métiers
2. **Réputations** : Vérifiez l'onglet réputations
3. **Skills** : Compétences à jour dans l'onglet skills
4. **Multi-chars** : Connectez tous vos alts dans la session

## 🔍 Diagnostic

### Vérification export
```bash
# Test de l'export
/auberdine test

# Vérification de signature
/auberdine status
```

### Messages d'erreur courants

#### "No recipe data found"
```
Solution : Ouvrez les fenêtres de métiers avant l'export
```

#### "Signature validation failed"
```
Solution : Relancez l'export, problème temporaire
```

#### "No characters detected"
```
Solution : Connectez-vous avec vos personnages dans la session
```

### Mode debug
```bash
/auberdine debug
# Active les messages détaillés pour diagnostic
```

## 🚨 Résolution de problèmes

### Export vide ou incomplet
1. **Ouvrez toutes les fenêtres de métiers**
2. **Attendez quelques secondes**
3. **Relancez l'export**

### Validation échoue sur auberdine.eu
1. **Recopiez l'export complet** (sans espaces/retours ligne)
2. **Vérifiez la signature** avec `/auberdine status`
3. **Regenerez un nouvel export**

### Bouton minimap invisible
1. **Reset addon** : `/auberdine reset`
2. **Reload interface** : `/reload`
3. **Utilisez les commandes slash** à la place

## 💡 Conseils d'usage

### Workflow optimal
1. **Connectez tous vos alts** dans la session
2. **Ouvrez un métier par personnage** pour scanner
3. **Export unique** avec tous les personnages
4. **Import sur auberdine.eu**

### Fréquence d'export
- **Nouvelle recette** : Export immédiat
- **Nouveau personnage** : Export de session
- **Changement de guilde** : Export mise à jour
- **Routine** : Export hebdomadaire recommandé

### Sécurité
- **Format Base64** : Impossibilité de falsification
- **Signature unique** : Chaque export est unique
- **Validation serveur** : Vérification automatique côté auberdine.eu

## 📞 Support

### Auto-diagnostic
1. `/auberdine status` - État de l'addon
2. `/auberdine test` - Test des fonctionnalités
3. `/auberdine debug` - Mode debug pour logs

### Communauté
- **Discord** : [#help-addon](https://discord.gg/auberdine)
- **Forum** : [auberdine.eu/forum/addon](https://auberdine.eu/forum)
- **GitHub** : [Issues tracker](https://github.com/yokoul/auberdine-exporter/issues)

### Rapporter un bug
Include :
- Version addon (`/auberdine version`)
- Étapes de reproduction
- Message d'erreur exact
- Capture d'écran si nécessaire
