# Installation d'AuberdineExporter

## 📋 Prérequis

- **World of Warcraft Classic Era** installé
- **Client français ou anglais** recommandé
- **Accès admin** pour l'installation (Windows)

## 🚀 Installation

### Méthode 1 : Téléchargement GitHub (Recommandé)

1. **Télécharger** la dernière version :
   - Allez sur [Releases](https://github.com/yokoul/auberdine-exporter/releases)
   - Téléchargez `AuberdineExporter-vX.X.X.zip`

2. **Décompresser** :
   ```
   📁 AuberdineExporter-vX.X.X.zip
   └── 📁 AuberdineExporter/
       ├── 📄 AuberdineExporter.lua
       ├── 📄 AuberdineExporter.toc
       ├── 📁 UI/
       └── 📁 Libs/
   ```

3. **Installer** :
   - Copiez le dossier `AuberdineExporter` dans :
   ```
   World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/
   ```

### Méthode 2 : Git Clone

```bash
# Naviguer vers le dossier AddOns
cd "World of Warcraft/_classic_era_/Interface/AddOns/"

# Cloner le projet
git clone https://github.com/yokoul/auberdine-exporter.git AuberdineExporter

# Vérifier l'installation
ls -la AuberdineExporter/
```

### Méthode 3 : Copie manuelle

Si vous avez les fichiers sources :

```bash
# Créer le dossier addon
mkdir -p "World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter"

# Copier les fichiers essentiels
cp AuberdineExporter.lua "World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/"
cp AuberdineExporter.toc "World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/"
cp -r UI/ "World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/"
cp -r Libs/ "World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/"
```

## 🎮 Activation dans WoW

1. **Lancer WoW Classic Era**
2. **Écran de sélection de personnage** :
   - Cliquez sur "AddOns" (bas à gauche)
   - Vérifiez que **AuberdineExporter** est coché ✅
   - Cliquez "Okay"

3. **Entrer en jeu** :
   - Vous devriez voir le bouton minimap d'Auberdine
   - Tapez `/auberdine` pour tester

## ✅ Vérification

### Interface
- **Bouton minimap** : petit icône rond près de la minimap
- **Commande slash** : `/auberdine` dans le chat

### Test rapide
```
/auberdine help     # Affiche l'aide
/auberdine export   # Lance un export test
```

### Messages attendus
```
[AuberdineExporter] Addon chargé avec succès !
[AuberdineExporter] Version 1.3.0 (Base64 sécurisé)
[AuberdineExporter] Tapez /auberdine pour commencer
```

## 🔧 Résolution de problèmes

### Addon non visible
1. **Vérifiez le chemin** :
   ```
   World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/
   ├── AuberdineExporter.lua
   ├── AuberdineExporter.toc
   ├── UI/
   └── Libs/
   ```

2. **Fichier .toc** doit être présent et valide
3. **Redémarrez WoW** complètement
4. **Activez l'addon** dans l'écran de sélection

### Erreurs LUA
1. **Vérifiez les dépendances** :
   - LibRecipes-3.0 présent ?
   - LibStub présent ?

2. **Interface outdatée** :
   - Cochez "Load out of date AddOns" dans les paramètres

3. **Conflit d'addons** :
   - Désactivez autres addons temporairement
   - Testez AuberdineExporter seul

### Bouton minimap absent
1. **Reset position** :
   ```
   /auberdine
   /reload
   ```

2. **Conflit avec autres boutons minimap** :
   - Certains addons peuvent cacher le bouton
   - Utilisez `/auberdine` à la place

## 🔄 Mise à jour

### Automatique (Git)
```bash
cd "World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter"
git pull origin main
```

### Manuelle
1. Téléchargez la nouvelle version
2. Sauvegardez vos données (`WTF/Account/...`)
3. Remplacez les fichiers anciens
4. Redémarrez WoW

## 📍 Chemins complets

### Windows
```
C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\AuberdineExporter\
```

### macOS
```
/Applications/World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/
```

### Linux
```
~/World of Warcraft/_classic_era_/Interface/AddOns/AuberdineExporter/
```

## 🆘 Support

Si l'installation ne fonctionne pas :

1. **Discord** : [#support-addon](https://discord.gg/auberdine)
2. **GitHub Issues** : [Créer un ticket](https://github.com/yokoul/auberdine-exporter/issues)
3. **Forum** : [auberdine.eu/forum](https://auberdine.eu/forum)

Include dans votre message :
- Version de WoW Classic Era
- Système d'exploitation
- Message d'erreur exact
- Capture d'écran si possible
