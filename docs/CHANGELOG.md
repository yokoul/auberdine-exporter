# AuberdineExporter - Changelog Complet

## 🔧 **Version 1.3.5** - Compatibilité patch WoW 1.15.8
*Date de sortie: 22 octobre 2025*

### 🎮 **Compatibilité**
- **Interface TOC mise à jour** : `11508` pour WoW Classic Era **1.15.8.63829**
- Compatibilité assurée avec le dernier patch de WoW Classic Era

---

## 🔧 **Version 1.3.4** - Validation serveur, suppression de personnages et compatibilité patch 1.15.8
*Date de sortie: 22 octobre 2025*

### ✅ **Mise à Jour de Compatibilité**
- **Interface TOC** : Mise à jour vers `11508` pour WoW Classic Era 1.15.8.63829
- **Compatibilité patch** : Addon maintenant reconnu comme compatible avec le dernier patch
- **API validation** : Vérification de toutes les API utilisées - aucun changement requis
- **Fonctionnalités** : Toutes les fonctionnalités existantes préservées

### 🔍 **Vérifications Effectuées**
- ✅ API Core : `GetRealmName`, `UnitName`, `UnitGUID`, `UnitLevel`, `UnitClass`, `UnitRace`
- ✅ API Professions : `GetProfessions`, `GetNumSkillLines`, `GetSkillLineInfo`
- ✅ API Interface : `CreateFrame`, `StaticPopup`, `UIDropDownMenu`, `C_Timer`
- ✅ API Metadata : `GetAddOnMetadata`
- ✅ Toutes les fonctionnalités de l'addon testées et fonctionnelles

---

## 🚀 **Version 1.3.4** - Validation Serveur + Suppression Personnages
*Date de sortie: 20 octobre 2025*berdineExporter - Changelog Complet

## � **Version 1.3.4** - Validation Serveur + Suppression Personnages
*Date de sortie: 20 octobre 2025*

### ✅ **Nouvelles Fonctionnalités Majeures**

#### 🛡️ **Validation du Serveur Auberdine**
- **Restriction serveur** : L'addon ne fonctionne désormais que sur le serveur Auberdine
- **Fonction publique** : `AuberdineExporter:IsOnAuberdine()` pour vérifier le serveur
- **Sécurisation complète** : Collecte de données bloquée sur autres serveurs
- **Messages informatifs** : Affichage clair du serveur actuel si non-Auberdine
- **Optimisation performance** : Arrêt précoce de l'addon sur serveurs non-supportés

#### 🗑️ **Suppression de Personnages**
- **Interface graphique** : Bouton rouge avec croix sur chaque mini-carte personnage
- **Commandes slash** : `/auberdine delete <nom-serveur> confirm`
- **Double confirmation** : Popup d'avertissement + confirmation obligatoire
- **Nettoyage complet** : Suppression de toutes les données (recettes, skills, réputations, liens)
- **Re-scan possible** : Personnage peut être re-détecté après suppression

### 🔧 **Améliorations et Sécurités**

#### **Validation Multi-niveaux**
- Initialisation des personnages
- Événements de scan des professions (TRADE_SKILL_SHOW, CRAFT_SHOW)
- Commandes slash (/auberdine, /ae, /aubex)
- Événement de connexion joueur (PLAYER_LOGIN)

#### **Sécurités Suppression**
- **Messages d'avertissement** : "Cette action est IRRÉVERSIBLE !"
- **Différenciation claire** : Distinction avec la désactivation d'export
- **Recherche intelligente** : Par nom de personnage ou clé complète
- **Actualisation interface** : Mise à jour automatique après suppression

### 💻 **Code Technique**
```lua
-- Validation serveur
function AuberdineExporter:IsOnAuberdine()
    local realmName = GetRealmName()
    return realmName == "Auberdine" or realmName == "auberdine" or realmName == "AUBERDINE"
end

-- Suppression personnage
function DeleteCharacter(charKey, suppressMessage)
    -- Suppression complète avec nettoyage des liens
end
```

### 📋 **Nouvelles Commandes**
- `/auberdine delete <nom-serveur>` - Demander suppression personnage
- `/auberdine delete <nom-serveur> confirm` - Confirmer suppression
- `/auberdine help` - Aide mise à jour avec nouvelles commandes

---

## 🎨 **Version 1.3.3b** - Interface AccountKey Éditable
*Date de sortie: 24 septembre 2025*

### ✅ **Fonctionnalités**
- **AccountKey cliquable** : Clic sur l'ID compte pour éditer
- **Interface graphique** : Fenêtre modale d'édition avec validation temps réel
- **Tooltip informatif** : Instructions au survol
- **Actualisation dynamique** : Mise à jour immédiate de l'affichage
- **Multi-comptes facilité** : Configuration simplifiée de la même clé sur plusieurs personnages

### 🔧 **Interface Utilisateur**
- Fenêtre draggable avec fond semi-transparent
- Support Échap (fermer) et Entrée (valider)
- Validation format AB-XXXX-YYYY
- Messages d'erreur explicites
- Feedback visuel (changement couleur au survol)

---

## 🏗️ **Version 1.3.3a** - Optimisation Interface
*Date de sortie: septembre 2025*

### ✅ **Améliorations Interface**
- **Cartes compactes** : Réduction 140x80 → 120x70 pixels
- **Multi-lignes** : 5 cartes par ligne maximum
- **Hiérarchie intégrée** : Déplacée dans la sidebar
- **Scroll simplifié** : Navigation verticale uniquement
- **Bordures modernes** : 1px, textes compacts, polices ajustées

---

## 🔄 **Version 1.3.3** - Interface Unifiée
*Date de sortie: septembre 2025*

### ✅ **Refonte Majeure**
- **Interface unifiée** : Fusion complète en une seule fenêtre (1000x700px)
- **Layout colonnes** : Sidebar gauche (180px) + zone principale
- **Barres scroll corrigées** : Drag & drop fonctionnel
- **Navigation simplifiée** : Plus besoin de fenêtres séparées

### 🎮 **Fonctionnalités Préservées**
- Toutes les fonctions d'export conservées
- Gestion types personnages (Main/Alt/Banque/Mule)
- Organisation par groupes avec édition
- Connexions visuelles entre personnages
- Export sélectif avec toggles individuels

---

## 📊 **Historique des Versions Antérieures**

### **Version 1.3.2** - Système de Groupes Multi-comptes
- Gestion avancée des personnages (types, liens familiaux)
- Export sélectif par personnage
- Système de groupes d'identification unique
- Commandes de gestion des comptes

### **Version 1.3.1** - Interface Française
- Interface entièrement traduite en français
- Amélioration ergonomie et centrage
- Icône de fond ab256 dans zones de texte

### **Version 1.3.0** - Format Base64 Sécurisé
- Format d'export sécurisé Base64
- Validation et vérification d'intégrité
- Protection contre la falsification

### **Version 1.2.x** - Format JSON (Legacy)
- Format JSON original (déprécié)
- Fonctionnalités de base

---

## 🔧 **Installation et Usage**

### **Installation**
1. Télécharger AuberdineExporter v1.3.4
2. Extraire dans `Interface/AddOns/`
3. Redémarrer WoW Classic Era
4. **IMPORTANT** : Vérifier que vous êtes sur le serveur Auberdine

### **Commandes Principales**
```bash
/auberdine                    # Interface principale
/auberdine scan              # Scanner métiers
/auberdine characters        # Lister personnages
/auberdine delete <nom>      # Supprimer personnage
/auberdine help              # Aide complète
```

### **Gestion Multi-comptes**
```bash
/auberdine accountkey        # Voir clé actuelle
/auberdine generatekey       # Générer nouvelle clé
/auberdine groupname <nom>   # Définir nom de groupe
```

---

## ⚠️ **Notes Importantes**

### **Restriction Serveur (v1.3.4+)**
Cette version ne fonctionnera **QUE** sur le serveur Auberdine. Sur d'autres serveurs :
- Messages d'information automatiques
- Addon se désactive pour économiser les ressources
- Données existantes préservées (non-destructeur)

### **Suppression vs Désactivation**
| Action | Effet | Usage Recommandé |
|--------|-------|------------------|
| **Désactiver Export** | Garde données, exclut de l'export | Personnage temporairement inactif |
| **Supprimer Personnage** | Efface toutes les données | Personnage définitivement abandonné |

### **Re-scan après Suppression**
- La suppression n'est jamais définitive
- Re-connexion avec le personnage → Re-détection automatique
- Toutes les données sont re-scannées fraîchement
- Configuration (type, groupe) à redéfinir

---

**Compatibilité** : WoW Classic Era  
**Serveur** : Auberdine uniquement (v1.3.4+)  
**Auteur** : yokoul - auberdine.eu