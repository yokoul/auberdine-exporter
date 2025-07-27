# AuberdineExporter

**Addon WoW Classic Era pour exporter vos recettes, métiers et réputations vers auberdine.eu**

## 🎯 Vue d'ensemble

AuberdineExporter est un addon sécurisé pour World of Warcraft Classic Era qui permet d'exporter toutes vos données de personnages (recettes, métiers, skills, réputations) vers [auberdine.eu](https://auberdine.eu) avec une validation cryptographique robuste.

## ✨ Fonctionnalités

- 🏗️ **Export multi-personnages** - Tous vos alts en un seul export
- 🔒 **Sécurité renforcée** - Format Base64 avec signature multi-passes  
- 📊 **Données complètes** - Recettes, métiers, skills, réputations
- 🎮 **Interface intuitive** - Bouton minimap + commandes slash
- ⚡ **Performance optimisée** - Export rapide et validation fiable
- 🌍 **Support multilingue** - Français, Anglais, autres locales

## 🚀 Installation

### Méthode 1 : Téléchargement direct
1. Téléchargez la [dernière version](https://github.com/yokoul/auberdine-exporter/releases)
2. Décompressez dans `World of Warcraft/_classic_era_/Interface/AddOns/`
3. Redémarrez WoW Classic

### Méthode 2 : Git
```bash
cd "World of Warcraft/_classic_era_/Interface/AddOns/"
git clone https://github.com/yokoul/auberdine-exporter.git AuberdineExporter
```

## 📖 Utilisation

### Interface
- **Bouton minimap** - Clic pour ouvrir l'interface
- **Menu principal** - Export, configuration, aide

### Commandes slash
```
/auberdine         # Ouvre l'interface principale
/auberdine export  # Lance l'export immédiatement  
/auberdine clear   # Nettoie les données en mémoire (garde le personnage actuel)
/auberdine size    # Affiche la taille des données stockées
/auberdine reset   # Remet à zéro toutes les données
/auberdine help    # Affiche l'aide
```

### Gestion des données
- **Nettoyage sélectif** : `/auberdine clear` supprime les données des autres personnages mais garde le personnage actuel
- **Vérification de taille** : `/auberdine size` pour voir l'espace utilisé par chaque personnage  
- **Interface de gestion** : Boutons "Clear Memory Data" et "Reset All Data" dans l'onglet Settings
- **Alerte automatique** : L'interface affiche un avertissement si les données deviennent trop volumineuses

> ⚠️ **Important** : Des exports trop volumineux (>50KB) peuvent échouer lors de l'import sur auberdine.eu. Utilisez le nettoyage sélectif pour réduire la taille.

### Export des données
1. Ouvrez toutes les fenêtres de métiers pour scanner les recettes
2. Cliquez sur "Exporter mes données"
3. Copiez le texte généré
4. Collez sur [auberdine.eu/import](https://auberdine.eu/import)

## 🔒 Sécurité

AuberdineExporter utilise un **système de validation cryptographique avancé** :

- **Format Base64** - Évite les problèmes de formatage JSON
- **Signature multi-passes** - MD5 avec challenge/nonce/timestamp
- **Détection de falsification** - Toute modification est immédiatement détectée
- **Challenge hardcodé** - Protection contre les exports non-autorisés
- **Nonce unique** - Chaque export a un identifiant unique

### Format de sécurité
```json
{
  "dataBase64": "eyJjaGFyYWN0ZXJzIjp7Li4u",
  "signature": "69ecbe7214f39518",
  "validation": {
    "dataChecksum": "3a1dd05ef0e1ece",
    "algorithm": "multi-pass-md5-base64"
  }
}
```

## 🛠️ Développement

### Structure du projet
```
AuberdineExporter/
├── AuberdineExporter.lua    # Addon principal
├── AuberdineExporter.toc    # Table of Contents WoW
├── UI/                      # Interface utilisateur
├── Libs/                    # Bibliothèques nécessaires
├── server/                  # Validation côté serveur
└── docs/                    # Documentation
```

### Serveur de validation
Le dossier `/server` contient un système Node.js complet pour valider les exports :

```bash
cd server/
node verifyBase64Export.js export.json    # Valider un export
node test-base64-system.js                # Tests automatisés
```

**Documentation serveur** : [server/README.md](./server/README.md)

## 📚 Documentation

| Fichier | Description |
|---------|-------------|
| [INSTALLATION.md](./docs/INSTALLATION.md) | Guide d'installation détaillé |
| [USAGE.md](./docs/USAGE.md) | Guide d'utilisation complet |
| [SECURITY.md](./docs/SECURITY.md) | Détails de sécurité et validation |
| [server/README.md](./server/README.md) | Documentation serveur |

## 🧪 Tests

### Tests addon (en jeu)
1. Installer l'addon
2. Tester l'export sur plusieurs personnages
3. Vérifier la validation sur auberdine.eu

### Tests serveur
```bash
cd server/
npm test                                   # Tests automatisés
node test-base64-system.js                # Suite complète
node test-base64-system.js mon-export.json # Analyser un export
```

## 🔄 Versions

### Version actuelle : **1.3.0** (Base64 sécurisé)
- ✅ Format Base64 avec validation reproductible à 100%
- ✅ Support multi-personnages complet
- ✅ Sécurité renforcée avec double validation
- ✅ Interface améliorée avec boutons en haut
- ✅ Documentation complète

### Historique
- **1.2.x** - Format JSON legacy (déprécié)
- **1.1.x** - Version initiale mono-personnage
- **1.0.x** - Prototype

## 🤝 Contribution

Les contributions sont les bienvenues ! 

1. Fork le projet
2. Créez une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commitez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push sur la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📞 Support

- **Issues** : [GitHub Issues](https://github.com/yokoul/auberdine-exporter/issues)
- **Discord** : [Serveur Auberdine](https://discord.gg/auberdine)
- **Forum** : [auberdine.eu/forum](https://auberdine.eu/forum)

## 📜 Licence

Ce projet est sous licence MIT. Voir [LICENSE](./LICENSE) pour plus de détails.

## 🏆 Remerciements

- **LibRecipes-3.0** - Données de recettes WoW Classic
- **Communauté Auberdine** - Tests et feedback
- **Blizzard Entertainment** - World of Warcraft Classic Era

---

**Fait avec ❤️ pour la communauté WoW Classic Era**

[auberdine.eu](https://auberdine.eu) | [Discord](https://discord.gg/auberdine) | [GitHub](https://github.com/yokoul/auberdine-exporter)
