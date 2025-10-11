# Changelog - Version 1.3.4

## 🛡️ **Version 1.3.4** - Validation du Serveur Auberdine
*Date de sortie: 11 octobre 2025*

### ✅ **Nouvelles Fonctionnalités**
- **Validation du serveur** : L'addon ne fonctionne désormais que sur le serveur Auberdine
- **Fonction publique** : `AuberdineExporter:IsOnAuberdine()` pour vérifier le serveur
- **Sécurisation complète** : Collecte de données bloquée sur autres serveurs

### 🔧 **Améliorations**
- **Messages informatifs** : Affichage clair du serveur actuel si non-Auberdine
- **Optimisation performance** : Arrêt précoce de l'addon sur serveurs non-supportés
- **Validation multi-niveaux** :
  - Initialisation des personnages
  - Événements de scan des professions
  - Commandes slash (/auberdine, /ae, /aubex)
  - Événement de connexion joueur

### 🚫 **Comportement sur Serveurs Non-Auberdine**
- **Messages d'erreur explicites** en français
- **Commandes désactivées** avec explication
- **Interface non-initialisée** pour économiser les ressources
- **Données existantes préservées** (non-destructeur)

### 🔍 **Validation Flexible**
- Accepte : "Auberdine", "auberdine", "AUBERDINE"
- Compatible avec les différentes casses possibles

### 💻 **Code Technique**
```lua
-- Nouvelle fonction de validation
function AuberdineExporter:IsOnAuberdine()
    local realmName = GetRealmName()
    return realmName == "Auberdine" or realmName == "auberdine" or realmName == "AUBERDINE"
end

-- Validation dans InitializeCharacterData()
if not IsValidRealm() then
    print("|cffff0000AuberdineExporter:|r Cet addon ne fonctionne que sur le serveur Auberdine...")
    return nil
end
```

### 📁 **Fichiers Modifiés**
- `AuberdineExporter.lua` : Ajout validation + fonction publique
- `AuberdineExporter.toc` : Version 1.3.4
- `create-release.sh` : Version 1.3.4
- `README.md` : Documentation mise à jour

### 🎯 **Impact**
- ✅ **Sécurité** : Plus de collecte accidentelle sur autres serveurs
- ✅ **Performance** : Ressources économisées sur serveurs non-supportés
- ✅ **Expérience utilisateur** : Messages clairs et informatifs
- ✅ **Compatibilité** : Non-destructeur, données existantes préservées

---

## 📋 **Version Précédente: 1.3.3b**
- Interface française complète
- Amélioration ergonomie et centrage
- Correction conflits nommage UI

## 🔧 **Installation**
1. Télécharger AuberdineExporter v1.3.4
2. Extraire dans `Interface/AddOns/`
3. Redémarrer WoW Classic
4. Vérifier que vous êtes sur le serveur Auberdine

## ⚠️ **Important**
Cette version ne fonctionnera **QUE** sur le serveur Auberdine. Si vous jouez sur d'autres serveurs, l'addon affichera des messages d'information et se désactivera automatiquement.