# AuberdineExporter v1.3.3b - Changelog

## 🎯 Objectif principal
Restaurer la possibilité d'éditer manuellement l'accountKey via l'interface graphique pour permettre aux joueurs en multicompte de configurer le même accountKey sur plusieurs personnages.

## ✅ Modifications effectuées

### 1. Mise à jour de version
- **Fichier**: `AuberdineExporter.toc`
  - Version: `1.3.3a` → `1.3.3b`
- **Fichier**: `UI/AuberdineMainFrame.lua`
  - Titre interface: `"Auberdine Exporter v1.3.3a"` → `"Auberdine Exporter v1.3.3b"`

### 2. Interface graphique pour AccountKey
- **Nouvelle fonction**: `AuberdineExporterUI:CreateAccountKeyEditFrame()`
  - Fenêtre modale d'édition de l'accountKey
  - Champ de saisie pré-rempli avec l'accountKey actuelle
  - Validation en temps réel du format AB-XXXX-YYYY
  - Boutons Valider/Annuler
  - Gestion des erreurs et messages de succès

### 3. AccountKey cliquable
- **Modification**: Section d'affichage de l'accountKey dans `CreateCharacterInfoSection()`
  - Remplacement du texte statique par un bouton invisible cliquable
  - Ajout d'un tooltip explicatif au survol
  - Changement de couleur (gris → jaune) au survol
  - Texte mis à jour: `"ID Compte: XXX (cliquez pour modifier)"`

### 4. Actualisation dynamique
- **Nouvelle fonction**: `AuberdineExporterUI:RefreshAccountKeyDisplay(frame)`
  - Fonction dédiée pour mettre à jour uniquement l'affichage de l'accountKey
  - Recherche récursive du bouton accountKey dans l'interface
  - Appel automatique après modification réussie

## 🔧 Fonctionnalités techniques

### Compatibilité
- ✅ Compatible avec la fonction existante `AuberdineExporter:SetAccountKey()`
- ✅ Compatible avec la commande slash `/auberdine accountkey`
- ✅ Utilise les mêmes fonctions de validation (`IsValidAccountKey`)
- ✅ Aucune modification des structures de données existantes

### Interface utilisateur
- ✅ Fenêtre modale avec fond semi-transparent
- ✅ Draggable (déplaçable)
- ✅ Support de la touche Échap pour fermer
- ✅ Support de la touche Entrée pour valider
- ✅ Tooltip informatif avec instructions
- ✅ Feedback visuel (changement de couleur au survol)

### Validation et sécurité
- ✅ Format requis: `AB-XXXX-YYYY` (X = lettre ou chiffre)
- ✅ Conversion automatique en majuscules
- ✅ Suppression des espaces automatique
- ✅ Messages d'erreur explicites
- ✅ Limitation à 11 caractères maximum

## 🎮 Utilisation pour les joueurs

### Workflow multi-comptes
1. **Sur le compte principal**:
   - Ouvrir `/auberdine ui`
   - Cliquer sur l'ID Compte en bas de l'interface
   - Noter l'accountKey affichée

2. **Sur les comptes secondaires**:
   - Ouvrir `/auberdine ui`
   - Cliquer sur l'ID Compte
   - Saisir la même accountKey que le compte principal
   - Valider

3. **Résultat**: Tous les comptes utilisent la même accountKey pour les exports

### Alternative par commande
- Afficher l'accountKey: `/auberdine accountkey`
- Modifier l'accountKey: `/auberdine accountkey AB-1234-ABCD`
- Générer une nouvelle clé: `/auberdine generatekey`

## 🔍 Tests recommandés

1. **Test d'affichage**: Vérifier que l'accountKey est cliquable avec tooltip
2. **Test d'édition**: Ouvrir la fenêtre et modifier l'accountKey
3. **Test de validation**: Essayer des formats invalides
4. **Test de compatibilité**: Vérifier que les commandes slash fonctionnent toujours
5. **Test multi-comptes**: Configurer plusieurs personnages avec la même clé

## 📋 Notes de développement

### Architecture
- Fonctions UI séparées et modulaires
- Pas de modification des fonctions core existantes
- Réutilisation des fonctions de validation existantes
- Pattern Observer pour la mise à jour de l'affichage

### Performance
- Fonction de refresh ciblée (mise à jour de l'accountKey seulement)
- Fenêtre d'édition créée à la demande
- Pas d'impact sur les performances générales

### Maintenance
- Code bien documenté avec commentaires français
- Structure cohérente avec le reste du projet
- Facilement extensible pour futures fonctionnalités

---

**Version**: 1.3.3b  
**Date**: 24 septembre 2025  
**Auteur**: yokoul - auberdine.eu