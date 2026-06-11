#!/usr/bin/env bash
# Construit et publie une release de l'uploader sur GitHub.
#
#   uploader/scripts/release.sh v0.2.0 ["Titre de la release"]
#
# - injecte la version dans le binaire (ldflags -X internal/version.Version) ;
#   c'est elle qui pilote la mise à jour automatique des clients installés —
#   le tag git, la version injectée et le tag de release DOIVENT coïncider,
#   d'où ce script plutôt que des builds à la main ;
# - construit les 4 plateformes avec le tray (darwin nécessite CGO/Cocoa,
#   windows et linux passent en pur Go) ;
# - produit SHA256SUMS (consommé par auberdine.eu pour annoncer la release
#   aux clients : l'empreinte est vérifiée avant toute substitution) ;
# - SIGNE chaque binaire en ed25519 (cmd/relsign) avec la clé privée du
#   mainteneur — hors serveur ; les clients vérifient la signature contre la
#   clé publique embarquée avant tout swap (audit 2026-06, point 1) ;
# - crée la release GitHub (gh) — binaires + SHA256SUMS + .sig.
#
# À lancer depuis un macOS avec Xcode CLT (cross darwin amd64+arm64).
set -euo pipefail

TAG="${1:?usage: release.sh vX.Y.Z [titre]}"
TITLE="${2:-Auberdine Uploader $TAG}"
case "$TAG" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "tag invalide: $TAG (attendu vX.Y.Z)" >&2; exit 1 ;; esac

cd "$(dirname "$0")/.."
REPO_ROOT="$(git rev-parse --show-toplevel)"

LDFLAGS="-s -w -X github.com/yokoul/auberdine-exporter/uploader/internal/version.Version=$TAG"
DIST="dist"
rm -rf "$DIST" && mkdir -p "$DIST"

build() { # build GOOS GOARCH CGO sortie
    local goos="$1" goarch="$2" cgo="$3" out="$4"
    echo "-> $out"
    # Windows : sous-système GUI obligatoire (-H windowsgui). Sans lui le PE
    # reste en sous-système console et Windows alloue une fenêtre console à
    # tout démarrage sans console parente — clé Run à l'ouverture de session
    # ET surtout relance détachée du self-update (restart_windows.go), d'où
    # un terminal fantôme persistant au milieu de l'écran. console_windows.go
    # suppose précisément ce flag pour son AttachConsole conditionnel.
    local ldflags="$LDFLAGS"
    [ "$goos" = windows ] && ldflags="$ldflags -H windowsgui"
    CGO_ENABLED="$cgo" GOOS="$goos" GOARCH="$goarch" \
        go build -tags tray -trimpath -ldflags "$ldflags" \
        -o "$DIST/$out" ./cmd/auberdine-uploader
}

build darwin  arm64 1 auberdine-uploader-darwin-arm64
build darwin  amd64 1 auberdine-uploader-darwin-amd64
build linux   amd64 0 auberdine-uploader-linux-amd64
build windows amd64 0 auberdine-uploader-windows-amd64.exe

( cd "$DIST" && shasum -a 256 auberdine-uploader-* > SHA256SUMS )
echo && cat "$DIST/SHA256SUMS" && echo

# Signature ed25519 de chaque binaire : la clé privée vit sur le poste du
# mainteneur, JAMAIS sur le serveur — auberdine.eu ne fait que relayer les
# .sig publiés ici, les clients vérifient contre la clé publique embarquée.
# Étape OBLIGATOIRE : les clients signés refusent toute mise à jour sans .sig.
KEYFILE="${AUBERDINE_RELSIGN_KEY:-$HOME/.config/auberdine/release-signing.key}"
if [ ! -f "$KEYFILE" ]; then
    echo "clé de signature absente: $KEYFILE" >&2
    echo "(une seule fois : go run ./cmd/relsign keygen -key \"$KEYFILE\")" >&2
    exit 1
fi
for f in "$DIST"/auberdine-uploader-*; do
    case "$f" in *.sig) continue ;; esac
    go run ./cmd/relsign sign -key "$KEYFILE" "$f"
done

# Tag git sur le commit courant (s'il n'existe pas déjà), puis release.
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    git tag "$TAG"
    git push origin "$TAG"
fi

gh release create "$TAG" \
    --repo "$(git -C "$REPO_ROOT" remote get-url origin | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')" \
    --title "$TITLE" \
    --generate-notes \
    "$DIST"/auberdine-uploader-* "$DIST/SHA256SUMS"

echo
echo "Release $TAG publiée. Les clients installés se mettront à jour"
echo "automatiquement (contrôle au démarrage puis quotidien)."
