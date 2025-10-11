# Modification - Validation du Serveur Auberdine

## Problème Identifié
L'addon AuberdineExporter collectait et exportait les données des personnages sur tous les serveurs WoW Classic, pas seulement sur Auberdine.

## Solution Implémentée

### 1. Fonction de Validation du Serveur
- **Ajout d'une fonction publique** : `AuberdineExporter:IsOnAuberdine()`
- **Fonction locale helper** : `IsValidRealm()`
- **Validation flexible** : Accepte "Auberdine", "auberdine", "AUBERDINE" pour couvrir les différentes casses possibles

### 2. Points de Validation Ajoutés

#### A. Initialisation des Données des Personnages
- **Fonction** : `InitializeCharacterData()`
- **Action** : Arrêt de l'initialisation si serveur non-Auberdine avec message d'erreur

#### B. Événement de Connexion Joueur
- **Événement** : `PLAYER_LOGIN`
- **Action** : Validation précoce + arrêt de l'initialisation complète de l'addon

#### C. Événements de Scan des Professions
- **Événements** : `TRADE_SKILL_SHOW`, `CRAFT_SHOW`
- **Action** : Scan bloqué sur serveurs non-Auberdine

#### D. Commandes Slash
- **Fonction** : `HandleSlashCommand()`
- **Action** : Toutes les commandes `/auberdine`, `/ae`, `/aubex` bloquées avec message explicatif

### 3. Messages d'Information
- Messages d'erreur clairs en français
- Affichage du nom du serveur actuel
- Messages explicatifs pour guider l'utilisateur

### 4. Comportement sur Serveur Non-Auberdine
1. **Au chargement** : Message d'addon désactivé
2. **Sur commande** : Message d'erreur avec serveur actuel
3. **Sur scan** : Aucune collecte de données
4. **Fonctions existantes** : Les données déjà collectées restent accessibles

## Code Ajouté

```lua
-- Fonction publique de validation
function AuberdineExporter:IsOnAuberdine()
    local realmName = GetRealmName()
    return realmName == "Auberdine" or realmName == "auberdine" or realmName == "AUBERDINE"
end

-- Validation dans InitializeCharacterData()
if not IsValidRealm() then
    print("|cffff0000AuberdineExporter:|r Cet addon ne fonctionne que sur le serveur Auberdine...")
    return nil
end

-- Validation dans PLAYER_LOGIN
if not IsValidRealm() then
    print("|cffff0000AuberdineExporter:|r Addon désactivé - Serveur non supporté...")
    return
end

-- Validation dans les commandes
if not IsValidRealm() then
    print("|cffff0000AuberdineExporter:|r Cette commande ne fonctionne que sur le serveur Auberdine.")
    return
end
```

## Impact
- ✅ **Sécurisé** : Plus de collecte accidentelle sur autres serveurs
- ✅ **Informatif** : Messages clairs pour l'utilisateur
- ✅ **Non-destructeur** : Données existantes préservées
- ✅ **Performance** : Arrêt précoce sur serveurs non-supportés

## Tests Recommandés
1. Tester sur serveur Auberdine (fonctionnement normal)
2. Tester sur autre serveur (messages d'erreur appropriés)
3. Vérifier que les commandes sont bloquées sur autres serveurs
4. S'assurer que l'interface ne s'affiche pas sur autres serveurs