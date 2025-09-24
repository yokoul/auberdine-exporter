#!/bin/bash

# Script de création du build 1.3.3b
# Ce script crée une nouvelle version du build avec les modifications AccountKey

echo "=== Création du build AuberdineExporter v1.3.3b ==="

# Variables
BUILD_DIR="build_1.3.3b"
ADDON_NAME="AuberdineExporter"
VERSION="v1.3.3b"

# Nettoyer le répertoire de build s'il existe
if [ -d "$BUILD_DIR" ]; then
    echo "Nettoyage du répertoire existant..."
    rm -rf "$BUILD_DIR"
fi

# Créer la structure de build
echo "Création de la structure de build..."
mkdir -p "$BUILD_DIR/$ADDON_NAME"

# Copier les fichiers principaux
echo "Copie des fichiers principaux..."
cp "AuberdineExporter.lua" "$BUILD_DIR/$ADDON_NAME/"
cp "AuberdineExporter.toc" "$BUILD_DIR/$ADDON_NAME/"
cp "LICENSE" "$BUILD_DIR/$ADDON_NAME/"

# Copier les librairies
echo "Copie des librairies..."
cp -r "Libs" "$BUILD_DIR/$ADDON_NAME/"

# Copier l'interface utilisateur
echo "Copie de l'interface utilisateur..."
cp -r "UI" "$BUILD_DIR/$ADDON_NAME/"

# Créer l'archive
echo "Création de l'archive..."
cd "$BUILD_DIR"
zip -r "${ADDON_NAME}-${VERSION}.zip" "$ADDON_NAME"
cd ..

echo "=== Build créé avec succès ==="
echo "Fichier: $BUILD_DIR/${ADDON_NAME}-${VERSION}.zip"
echo ""
echo "=== Fonctionnalités nouvelles v1.3.3b ==="
echo "✅ AccountKey cliquable dans l'interface"
echo "✅ Fenêtre d'édition modale pour l'AccountKey"
echo "✅ Validation en temps réel du format AB-XXXX-YYYY"
echo "✅ Tooltip informatif au survol"
echo "✅ Intégration avec les commandes slash existantes"
echo "✅ Rafraîchissement automatique de l'affichage"
echo ""
echo "=== Tests recommandés ==="
echo "1. Installer l'addon depuis l'archive"
echo "2. Lancer /auberdine ui"
echo "3. Cliquer sur l'ID Compte en bas de l'interface"
echo "4. Tester l'édition de l'AccountKey"
echo "5. Vérifier la compatibilité avec /auberdine accountkey"
echo ""
echo "=== Installation ==="
echo "1. Extraire ${ADDON_NAME}-${VERSION}.zip"
echo "2. Placer le dossier AuberdineExporter dans Interface/AddOns/"
echo "3. Redémarrer WoW Classic Era"