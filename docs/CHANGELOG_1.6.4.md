# Changelog - Version 1.6.4

## 🔁 **Version 1.6.4** - Refresh automatique des rangs de guilde
*Date de sortie: 5 juin 2026*

> **Résumé** — Corrige un point d'ergonomie du suivi de guilde : les **rangs et
> le roster** ne partaient que lors d'un export complet (`full`), déclenché
> uniquement au 1ᵉʳ export ou via un *resync* manuel dans les réglages. Résultat :
> après le premier envoi, les noms de rangs personnalisés ne se mettaient plus à
> jour sans intervention. Désormais c'est **automatique**.

### ✅ **Export complet périodique automatique**
- Un export `full` (roster + table des rangs `rankIndex → nom personnalisé`) se
  déclenche **tout seul** dès que le dernier full date de plus de **7 jours**.
- S'ajoute aux déclencheurs existants : 1ᵉʳ export d'une guilde, et *resync*
  manuel (bouton « Forcer un export complet » dans les Réglages).
- Suivi **par guilde** (`lastFullExportTs`) : chaque guilde se rafraîchit
  indépendamment.
- Léger : au plus un export complet par semaine et par guilde ; entre deux, les
  exports `delta` économes continuent de transmettre les événements
  (`JOIN`/`LEAVE`/`KICK`/`PROMOTE`/`DEMOTE`/`NOTE`).

### 🔧 **Détail technique**
- Logique centralisée dans `ShouldFullExport(g, s, now)` (pas de duplication),
  utilisée à la fois par l'estimation de taille et la génération du payload.
- Constante `FULL_REFRESH_INTERVAL = 7 jours` dans `GuildTracker.lua`.
