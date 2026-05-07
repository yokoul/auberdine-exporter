#!/bin/bash

# Script de création du ZIP de release pour CurseForge
# Usage: ./create-release.sh

VERSION="1.4.1"
ADDON_NAME="AuberdineExporter"
BUILD_DIR="build"
RELEASE_DIR="$BUILD_DIR/$ADDON_NAME"

echo "🚀 Création du package de release v$VERSION pour CurseForge..."

# Nettoyer le dossier de build
rm -rf "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

echo "📁 Copie des fichiers essentiels..."

# Fichiers principaux
cp "AuberdineExporter.lua" "$RELEASE_DIR/"
cp "AuberdineExporter.toc" "$RELEASE_DIR/"
cp "LICENSE" "$RELEASE_DIR/"

# Interface utilisateur
mkdir -p "$RELEASE_DIR/UI"
cp "UI/AuberdineMainFrame.lua" "$RELEASE_DIR/UI/"
cp "UI/AuberdineExportFrame.lua" "$RELEASE_DIR/UI/"
cp "UI/AuberdineMinimapButton.lua" "$RELEASE_DIR/UI/"

# Icônes (seulement les principales, pas les variantes 'a')
mkdir -p "$RELEASE_DIR/UI/Icons"
cp "UI/Icons/ab32.png" "$RELEASE_DIR/UI/Icons/"
cp "UI/Icons/ab64.png" "$RELEASE_DIR/UI/Icons/"
cp "UI/Icons/ab128.png" "$RELEASE_DIR/UI/Icons/"
cp "UI/Icons/ab256.png" "$RELEASE_DIR/UI/Icons/"
cp "UI/Icons/ab512.png" "$RELEASE_DIR/UI/Icons/"

# Bibliothèques
mkdir -p "$RELEASE_DIR/Libs/LibStub"
cp "Libs/LibStub/LibStub.lua" "$RELEASE_DIR/Libs/LibStub/"

mkdir -p "$RELEASE_DIR/Libs/LibRecipes-3.0"
cp "Libs/LibRecipes-3.0/LibRecipes-3.0.lua" "$RELEASE_DIR/Libs/LibRecipes-3.0/"
cp "Libs/LibRecipes-3.0/LibRecipes-3.0.toc" "$RELEASE_DIR/Libs/LibRecipes-3.0/"
cp "Libs/LibRecipes-3.0/LibRecipes-3.0_Vanilla.toc" "$RELEASE_DIR/Libs/LibRecipes-3.0/"
cp "Libs/LibRecipes-3.0/lib.xml" "$RELEASE_DIR/Libs/LibRecipes-3.0/"

# LibStub dans LibRecipes
mkdir -p "$RELEASE_DIR/Libs/LibRecipes-3.0/LibStub"
cp "Libs/LibRecipes-3.0/LibStub/LibStub.lua" "$RELEASE_DIR/Libs/LibRecipes-3.0/LibStub/"
cp "Libs/LibRecipes-3.0/LibStub/LibStub.toc" "$RELEASE_DIR/Libs/LibRecipes-3.0/LibStub/"

echo "📦 Création du ZIP..."

# Créer le ZIP de release
cd "$BUILD_DIR"
zip -r "${ADDON_NAME}-v${VERSION}.zip" "$ADDON_NAME" -x "*.DS_Store*"

cd ..

echo "✅ Package créé: $BUILD_DIR/${ADDON_NAME}-v${VERSION}.zip"
echo ""
echo "📊 Contenu du package:"
unzip -l "$BUILD_DIR/${ADDON_NAME}-v${VERSION}.zip"

echo ""
echo "🎯 Le fichier ZIP est prêt pour upload sur CurseForge !"
echo "📁 Emplacement: $(pwd)/$BUILD_DIR/${ADDON_NAME}-v${VERSION}.zip"
