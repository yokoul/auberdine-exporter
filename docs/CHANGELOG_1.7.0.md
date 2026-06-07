# AuberdineExporter 1.7.0

## Nouveautés

- **Journal de combat de donjon** (`DungeonLogger.lua`) : à l'entrée d'un
  donjon 5 joueurs, l'addon active automatiquement le journal de combat du
  client (`LoggingCombat`) et balise le run dans un manifeste (SavedVariables).
  À la sortie, le run est clos — message en vert dans le chat aux deux moments.
- Le manifeste est conçu pour **Auberdine Uploader**, le compagnon de bureau :
  il découpe `WoWCombatLog` selon les fenêtres du manifeste et transmet les
  segments à auberdine.eu, où les runs sont analysés (boss, durée,
  participants). Installation de l'uploader en une ligne :
  - macOS / Linux : `curl -fsSL https://auberdine.eu/uploader/install.sh | sh`
  - Windows : `irm https://auberdine.eu/uploader/install.ps1 | iex`

## Notes

- Le journal de donjon est **actif par défaut** ; réglage `dungeonLogging`
  dans les options (et bascule « Envoyer les logs de donjon » dans le menu de
  l'uploader, côté transmission).
- Donjons 5 joueurs uniquement pour l'instant (`instanceType == "party"`).
- **Nouveau fichier dans le .toc** : après mise à jour, un redémarrage
  complet du client WoW est nécessaire (un `/reload` ne suffit pas à charger
  un fichier ajouté).
