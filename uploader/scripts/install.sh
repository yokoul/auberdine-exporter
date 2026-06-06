#!/bin/sh
# Auberdine Uploader — installation en une ligne (macOS / Linux) :
#
#   curl -fsSL https://auberdine.eu/uploader/install.sh | sh
#
# Télécharge le binaire depuis les releases GitHub, connecte le compte
# (navigateur, session Discord d'auberdine.eu) puis pose le service
# utilisateur — démarré à l'ouverture de session, sans élévation.
# curl ne pose pas la quarantaine Gatekeeper : aucune alerte à ignorer.
#
# Source : https://github.com/yokoul/auberdine-exporter (uploader/scripts/)
set -e

REPO="yokoul/auberdine-exporter"

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
    Darwin) os="darwin" ;;
    Linux)  os="linux" ;;
    *) echo "OS non supporté : $OS (Windows : irm https://auberdine.eu/uploader/install.ps1 | iex)" >&2; exit 1 ;;
esac
case "$ARCH" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64)  arch="amd64" ;;
    *) echo "Architecture non supportée : $ARCH" >&2; exit 1 ;;
esac

asset="auberdine-uploader-${os}-${arch}"
if [ "$os" = "linux" ] && [ "$arch" = "arm64" ]; then
    echo "linux-arm64 non publié pour l'instant — build depuis les sources :" >&2
    echo "  go build ./cmd/auberdine-uploader (dépôt $REPO, dossier uploader/)" >&2
    exit 1
fi

url="https://github.com/$REPO/releases/latest/download/$asset"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "→ Téléchargement de $asset…"
curl -fSL --progress-bar -o "$tmp/auberdine-uploader" "$url"
chmod +x "$tmp/auberdine-uploader"

# Connexion AVANT l'installation : le service démarre déjà connecté.
# (La clé vit dans la config utilisateur, indépendante du binaire.)
if "$tmp/auberdine-uploader" status 2>/dev/null | grep -q "configurée"; then
    echo "→ Clé d'ingestion déjà configurée — connexion conservée."
else
    echo "→ Connexion à auberdine.eu (le navigateur va s'ouvrir)…"
    "$tmp/auberdine-uploader" connect
fi

echo "→ Installation du service utilisateur…"
"$tmp/auberdine-uploader" install

echo ""
echo "Auberdine Uploader est installé : vos exports partiront tout seuls"
echo "à la prochaine déconnexion en jeu. Diagnostic : auberdine-uploader doctor"
