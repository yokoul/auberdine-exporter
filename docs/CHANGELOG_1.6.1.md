# Changelog - Version 1.6.1

## 📜 **Version 1.6.1** - Journal des recettes apprises & capture fiable des IDs
*Date de sortie: 2 juin 2026*

> **Résumé** — Cette version répare la capture des identifiants de recettes
> (qui ne fonctionnait pas sur Classic Era) et ajoute un **journal horodaté
> des recettes apprises**, exploitable côté auberdine.eu pour l'intégration au
> journal du personnage.

### 🐛 **Correctifs**

#### 🔗 Capture fiable des IDs de recettes (association auberdine.eu)
- **Problème** : sur Classic Era, `GetTradeSkillRecipeLink()` ne renvoie
  aucune valeur pour la plupart des métiers d'objets. Résultat : les recettes
  étaient exportées **avec le seul nom** (`id` absent), et l'association
  recette ↔ objet ressortait `null()` à l'import.
- **Correctif** : la capture passe désormais par le **lien de l'objet créé**
  (`GetTradeSkillItemLink(i)`), fiable sur Era. On en extrait l'`itemID`, puis
  `LibRecipes:GetItemInfo(itemID)` résout `recipeID` **et** `spellID`.
- Chaque recette stocke et exporte maintenant `id` (spellID), `itemID` et
  `recipeID` (en plus de `name` et `spellLink`). `idSource = "libitem"` indique
  une résolution via LibRecipes.
- **Dégradation gracieuse** : si l'objet créé est absent du dataset Era de
  LibRecipes, l'`itemID` reste capturé (couverture mesurée **100 % des
  recettes ont un `itemID`**, ~52 % l'association complète sur un échantillon
  Ingénierie de 187 recettes) — l'association reste possible par itemID ou par
  nom.

### ✅ **Nouvelles fonctionnalités**

#### 📜 Journal des recettes apprises (export auberdine.eu)
- Nouveau champ `character.learnedRecipes` : map
  `{ ["<spellID|itemID|nom>"] = { name, spellID, itemID, recipeID, profession, learnedAt } }`.
- Chaque entrée porte un **horodatage** (`learnedAt`) pour reconstituer la
  frise « le JJ/MM à HH:MM, recette Z apprise », sur le modèle de
  `completedQuests`.
- L'association `recipeID`/`itemID` est résolue **au moment de la capture** via
  LibRecipes → pas de `null()` à l'import.
- **Détection hybride** :
  - **Event live** `LEARNED_SPELL_IN_TAB` — capture à l'instant exact de
    l'apprentissage, filtrée par LibRecipes pour ne garder que les vraies
    recettes (exclut les sorts de classe).
  - **Diff au scan** des métiers — filet de sécurité : à l'ouverture d'une
    fenêtre de métier, les recettes absentes du dernier scan génèrent une
    entrée (comparaison par **nom**, stable).
- **Baseline silencieuse** : au premier scan d'un métier, les recettes déjà
  connues constituent la base et **ne créent aucune entrée de journal** (évite
  de dater faussement tout l'existant « apprises maintenant »). Seules les
  recettes apprises **après** sont journalisées.

### 🔧 **Technique**
- `create-release.sh` : `VERSION` réaligné sur le `.toc` (était resté à 1.5.1).
- Nouvel event enregistré : `LEARNED_SPELL_IN_TAB`.
- Migration transparente : `learnedRecipes` est ajouté aux personnages
  existants au login (champ vide), sans toucher aux données déjà collectées.
