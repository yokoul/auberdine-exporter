# Fusion de l'interface utilisateur - AuberdineExporter v1.3.3a

## Objectif accompli ✅
Optimisation complète de l'interface avec cartes compactes, affichage multi-lignes et hiérarchie intégrée dans la sidebar.

## Modifications v1.3.3a (Optimisation cartes et navigation)
- **Cartes compactes** : Réduction de 140x80 à 120x70 pixels pour optimiser l'espace
- **Multi-lignes** : Affichage automatique de 5 cartes par ligne maximum
- **Hiérarchie déplacée** : Intégration dans la sidebar sous les boutons d'action
- **Scroll simplifié** : Suppression du scroll horizontal, navigation verticale uniquement
- **Interface moderne** : Bordures 1px, textes compacts, polices ajustées

## Modifications v1.3.3 (Version précédente)
- **Interface unifiée** : Fusion complète des deux fenêtres en une seule
- **Barres de scroll corrigées** : Drag & drop fonctionnel sur les barres de scroll personnalisées
- **Version mise à jour** : Passage en v1.3.3 avec notes améliorées

## Modifications apportées

### 1. Nouvelle architecture de l'interface principale
- **Taille agrandie** : Fenêtre principale passée de 650x500 à 1000x700 pixels
- **Layout en colonnes** : Sidebar gauche (180px) + zone principale (reste de l'espace)
- **Titre mis à jour** : "Famille d'Auberdine - Interface Unifiée"

### 2. Sidebar gauche (remplace les boutons horizontaux)
- **Export Auberdine** : Export JSON pour auberdine.eu
- **Export CSV** : Export au format tableur 
- **Supprimer Cache** : Reset des données
- **Actualiser Vue** : Recharge l'affichage des personnages
- **Aide** : Popup d'aide contextuelle

### 3. Zone principale unifiée
- **Affichage des cartes personnages** directement intégré
- **Scroll bidirectionnel** avec barres personnalisées (vertical + horizontal avec Shift)
- **Légende intégrée** en bas avec codes couleurs et informations
- **Interactions complètes** : édition groupes, types de personnages, activation/désactivation export

### 4. Fonctions supprimées/simplifiées
- `ShowCharacterConfigFrame()` → Redirection vers interface unifiée
- Suppression des fonctions obsolètes liées à l'ancienne fenêtre séparée
- Code dupliqué nettoyé

### 5. Fonctionnalités préservées
- **Toutes les fonctions d'export** conservées
- **Gestion des types de personnages** (Main/Alt/Banque/Mule)
- **Organisation par groupes** avec édition
- **Connexions visuelles** entre personnages
- **Export sélectif** avec toggles individuels

## Utilisation
1. **Clic sur le bouton minimap** → Ouvre directement l'interface unifiée
2. **Sidebar gauche** → Actions d'export et gestion
3. **Zone principale** → Visualisation et configuration des personnages
4. **Pas de fenêtre séparée** → Tout accessible en un seul endroit

## Avantages
- ✅ **Simplicité d'accès** : Plus besoin de naviguer entre fenêtres
- ✅ **Moins de clics** : Fonctions export directement accessibles
- ✅ **Interface plus spacieuse** : Meilleure visualisation des personnages
- ✅ **Workflow amélioré** : Export et configuration au même endroit
- ✅ **Rétrocompatibilité** : Anciens boutons/commandes redirigent vers nouvelle interface

## Compatibilité
- ✅ Fonctions Lua existantes préservées
- ✅ Commandes slash inchangées
- ✅ API d'export conservée
- ✅ Données utilisateur non affectées
