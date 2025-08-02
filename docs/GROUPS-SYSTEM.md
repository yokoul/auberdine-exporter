# Système de groupes multi-comptes v1.3.2

## Vue d'ensemble

AuberdineExporter v1.3.2 introduit un système de clés d'identification unique et de noms de groupes personnalisés pour éviter les collisions entre utilisateurs et faciliter le regroupement de plusieurs comptes WoW.

## Fonctionnalités ajoutées

### 1. Clés d'identification uniques

Chaque installation d'AuberdineExporter génère automatiquement une clé unique au format `AB-7K9M-X2P4` :
- **Préfixe** : `AB-` (AuberdineExporter)
- **Format** : 4 caractères + tiret + 4 caractères
- **Caractères** : A-Z et 0-9 (36 possibilités par position)
- **Total** : Plus de 1,6 million de combinaisons possibles

### 2. Noms de groupes auto-générés

Au lieu d'utiliser "default" pour tous les utilisateurs, le système génère automatiquement des noms uniques :
- **Format** : MotComposé-Nombre (ex: `DragonRouge-42`)
- **Mots disponibles** : 15 mots pour chaque partie (225 combinaisons)
- **Nombres** : 10-99 (90 possibilités)
- **Total** : Plus de 20 000 combinaisons possibles

Exemples générés :
- `DragonRouge-42`
- `LuneArgent-67`
- `FlammeNoir-23`
- `CristalMystique-89`

### 3. Nouvelles commandes

#### `/auberdine accountkey`
Affiche la clé d'identification unique de votre compte :
```
AuberdineExporter: Clé d'identification unique: AB-X7K9-M2P4
Cette clé permet de lier vos comptes WoW dans le système de groupes.
Partagez cette clé avec vos autres comptes pour les regrouper.
```

#### `/auberdine groupname [nouveau_nom]`
Affiche ou modifie le nom de votre groupe :
```
# Afficher le nom actuel
/auberdine groupname
> AuberdineExporter: Nom de groupe actuel: DragonRouge-42

# Changer le nom
/auberdine groupname MesPersonnages
> AuberdineExporter: Nom de groupe changé: MesPersonnages
```

## Métadonnées d'export

Les exports JSON incluent maintenant ces informations dans les métadonnées :
```json
{
  "metadata": {
    "accountKey": "AB-X7K9-M2P4",
    "accountGroup": "DragonRouge-42",
    "addon": "AuberdineExporter",
    "version": "1.3.2",
    ...
  }
}
```

## Cas d'usage

### Utilisateur avec un seul compte
- **Avant** : Groupe "default" (risque de collision)
- **Après** : Groupe "DragonRouge-42" (unique automatiquement)

### Utilisateur avec plusieurs comptes WoW
1. Compte 1 génère automatiquement "LuneArgent-67"
2. Compte 2 peut utiliser `/auberdine groupname LuneArgent-67` 
3. Les deux comptes appartiennent maintenant au même groupe
4. Partage de la clé unique entre comptes pour identification

### Utilisateur en guilde/communauté
1. Choix d'un nom de groupe commun : `/auberdine groupname CarnAlliance`
2. Partage du nom avec les autres membres
3. Chacun configure son groupe avec le même nom
4. Les clés uniques permettent de distinguer les comptes individuels

## Avantages

1. **Pas de collision** : Fini les conflits avec "default" ou "auberdine"
2. **Facilité d'usage** : Configuration automatique sans intervention
3. **Flexibilité** : Possibilité de personnaliser après coup
4. **Identification unique** : Chaque compte a sa propre clé
5. **Regroupement simple** : Nom de groupe partageable facilement

## Compatibilité

- **Complet** : Compatible avec toutes les fonctionnalités existantes
- **Migration** : Les anciens comptes reçoivent automatiquement une clé et un nom
- **Rétrocompatible** : Les exports existants continuent de fonctionner

## Implémentation technique

### Génération de clé unique
```lua
local function GenerateUniqueAccountKey()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local key = "AB-"
    -- Premier bloc
    for i = 1, 4 do
        local index = math.random(1, string.len(chars))
        key = key .. string.sub(chars, index, index)
    end
    key = key .. "-"
    -- Deuxième bloc
    for i = 1, 4 do
        local index = math.random(1, string.len(chars))
        key = key .. string.sub(chars, index, index)
    end
    return key
end
```

### Génération de nom de groupe
```lua
local function GenerateDefaultGroupName()
    local words1 = {"Dragon", "Lune", "Soleil", "Ombre", "Flamme", ...}
    local words2 = {"Rouge", "Bleu", "Vert", "Noir", "Blanc", ...}
    
    local word1 = words1[math.random(1, #words1)]
    local word2 = words2[math.random(1, #words2)]
    local number = math.random(10, 99)
    
    return word1 .. word2 .. "-" .. number
end
```

Cette implémentation garantit l'unicité tout en conservant la simplicité d'usage pour l'utilisateur final.
