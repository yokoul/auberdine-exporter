# Changelog - AuberdineExporter

## v1.3.2 (Août 2025) - Gestion avancée des personnages

### 🆕 Nouvelles fonctionnalités

#### 👥 Système de gestion des personnages
- **Types de personnages** : Définissez vos personnages comme main, alt, bank ou mule
- **Liaison main/alt** : Reliez vos alts à votre personnage principal
- **Groupes de comptes** : Organisez plusieurs comptes WoW sous une même structure
- **Export sélectif** : Choisissez quels personnages inclure dans l'export

#### 🔑 Système de clés uniques et noms auto-générés (NOUVEAU)
- **Clés d'identification uniques** : Format AB-X7K9-M2P4 pour éviter les collisions
- **Noms de groupes auto-générés** : DragonRouge-42, LuneArgent-67 au lieu de "default"
- **Plus de 20 000 combinaisons** : Adieu les conflits de noms entre utilisateurs
- **Partage facilité** : Clés uniques partageables entre comptes multiples

#### 🎮 Interface améliorée
- **Nouvel onglet "Character Config"** : Interface dédiée à la gestion des personnages
- **Configuration rapide** : Boutons pour définir type et groupe en un clic
- **Vue d'ensemble** : Affichage organisé par groupe de compte
- **Support de la touche ESC** : Fermeture intuitive des fenêtres
- **Layering amélioré** : Plus de problèmes de transparence et d'accessibilité

#### ⌨️ Nouvelles commandes
```bash
/auberdine settype <main|alt|bank|mule>  # Définir le type de personnage
/auberdine linkto <personnage>           # Lier au personnage principal
/auberdine account <groupe>              # Définir le groupe de compte
/auberdine export <enable|disable>       # Activer/désactiver l'export
/auberdine config                        # Afficher la configuration
/auberdine accountkey                    # Afficher votre clé unique (NOUVEAU)
/auberdine groupname [nom]               # Gérer le nom de votre groupe (NOUVEAU)
```

#### 📊 Export enrichi
- **Métadonnées de configuration** : Types et liens inclus dans l'export
- **Relations entre personnages** : Mapping des liens main/alt
- **Statistiques par type** : Répartition des personnages par catégorie
- **Groupes de comptes** : Organisation dans l'export final
- **Clé d'identification unique** : Présente dans chaque export (NOUVEAU)
- **Nom de groupe personnalisé** : Remplace "default" générique (NOUVEAU)

### 🔧 Améliorations et corrections de bugs

#### 🎯 Problème de positionnement minimap corrigé
- **RÉSOLU** : Décalage entre image du bouton et cercle de la minimap
- Correction des références d'icônes (ab64.png au lieu d'anciennes versions)
- Amélioration du calcul de position du bouton minimap

#### 🪟 Interface utilisateur améliorée
- **RÉSOLU** : Problèmes de layering et transparence des fenêtres
- **NOUVEAU** : Support de la touche ESC pour fermer les fenêtres
- **NOUVEAU** : Frame strata FULLSCREEN_DIALOG pour meilleure accessibilité
- Configuration d'opacité appropriée pour éviter les fenêtres transparentes

#### ⚡ Prévention des collisions d'utilisateurs
- **RÉSOLU** : Tous les utilisateurs utilisaient "default" ou "auberdine" comme nom de groupe
- **NOUVEAU** : Génération automatique de noms uniques (DragonRouge-42, etc.)
- **NOUVEAU** : Clés d'identification uniques pour distinguer les comptes
- Plus de 20 000 combinaisons possibles pour éviter les conflits

#### 📝 Commandes slash améliorées
- Support des arguments multiples pour les commandes
- Commande `/auberdine characters` redirigée vers la liste de configuration
- **NOUVEAU** : Aide mise à jour avec les nouvelles fonctionnalités de groupes
- **NOUVEAU** : Section d'aide dédiée aux groupes multi-comptes

#### 🔄 Base de données étendue
- Nouvelle structure `characterSettings` pour les paramètres personnage
- Structure `accountLinks` pour les relations entre comptes
- **NOUVEAU** : Stockage des clés uniques et noms de groupes personnalisés
- Rétrocompatibilité assurée avec les versions précédentes

### 🧩 Structure des données v1.3.2

```lua
AuberdineExporterDB = {
    version = "1.3.2",
    characters = { ... },           -- Données existantes
    settings = { ... },             -- Paramètres existants
    characterSettings = {           -- NOUVEAU
        ["CharName-Realm"] = {
            exportEnabled = true,
            characterType = "main",
            mainCharacter = "CharName-Realm",
            accountGroup = "default",
            notes = "",
            lastModified = timestamp
        }
    },
    accountLinks = {}               -- NOUVEAU (pour futures extensions)
}
```

### 📈 Export enrichi v1.3.2

L'export JSON inclut maintenant :

```json
{
    "characters": {
        "CharName-Realm": {
            "info": { ... },
            "configuration": {          // NOUVEAU
                "characterType": "main",
                "mainCharacter": "CharName-Realm", 
                "accountGroup": "default",
                "exportEnabled": true,
                "lastModified": timestamp,
                "notes": ""
            },
            "professions": { ... }
        }
    },
    "relationships": {              // NOUVEAU
        "accountGroups": {
            "default": ["CharName-Realm"]
        },
        "mainCharacters": {
            "CharName-Realm": "CharName-Realm"
        },
        "characterTypes": {
            "CharName-Realm": "main"
        }
    },
    "summary": {
        "charactersByType": {       // NOUVEAU
            "main": 1,
            "alt": 0,
            "bank": 0
        },
        "accountGroups": {          // NOUVEAU
            "default": 1
        }
    }
}
```

### 🎯 Cas d'usage typiques

#### Configuration d'un main avec alts
```bash
# Sur votre personnage principal
/auberdine settype main
/auberdine account compte1

# Sur vos alts
/auberdine settype alt
/auberdine linkto MonMain
/auberdine account compte1
```

#### Personnage banque dédié
```bash
/auberdine settype bank
/auberdine account compte1
# Ce personnage sera identifié comme banque dans l'export
```

#### Gestion multi-comptes
```bash
# Compte 1
/auberdine account yoko-compte1

# Compte 2  
/auberdine account yoko-compte2
# Les deux seront groupés séparément mais exportés ensemble
```

---

## v1.3.1 (Juillet 2025) - Système Base64 sécurisé

### 🔒 Sécurité renforcée
- Implémentation du système Base64 pour éviter les erreurs JSON
- Signature cryptographique multi-passes MD5
- Challenge fixe "auberdine-2025-recipe-export"
- Taux de réussite validation : 0% → 100%

### 🚀 Performance
- Export ~50-100ms côté addon
- Validation ~5-10ms côté serveur
- Support des gros exports (>50KB)

### 🔧 Corrections
- Résolution des problèmes de formatage JSON
- Stabilisation de l'export multi-personnages
- Amélioration de la compatibilité ElvUI

---

## v1.3.0 (Juin 2025) - Release initiale

### ✨ Fonctionnalités de base
- Export multi-personnages complet
- Support de tous les métiers WoW Classic Era
- Interface moderne avec bouton minimap
- Système de validation côté serveur
- Documentation complète

### 🎮 Interface
- Bouton minimap draggable
- Interface principale avec onglets
- Export JSON/CSV/Web
- Gestion des données avec nettoyage sélectif

### ⌨️ Commandes
- Système de commandes slash complet
- Scanner automatique des métiers
- Statistiques détaillées
- Mode debug avancé
