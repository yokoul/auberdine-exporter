#!/usr/bin/env bash
#
# auberdine-switch.sh — bascule facile prod / dev pour l'uploader.
#
# Chaque environnement a son propre profil (fichier config + clé API séparés) :
#   prod → config.json            endpoint https://auberdine.eu
#   dev  → config.dev.json        endpoint http://localhost:3000
#
# Le script force l'endpoint correspondant à l'environnement choisi (déterministe,
# corrige un config.json qui pointerait au mauvais endroit) et relaie la commande
# au client (binaire installé si présent, sinon `go run`).
#
# Usage :
#   ./auberdine-switch.sh <prod|dev> [commande] [args...]
#
#   commande par défaut : status
#
# Exemples :
#   ./auberdine-switch.sh dev  connect     # 1re fois : crée la clé dev
#   ./auberdine-switch.sh prod connect     # 1re fois : crée la clé prod
#   ./auberdine-switch.sh dev  daemon      # lance l'uploader sur dev
#   ./auberdine-switch.sh prod status      # vérifie le profil/endpoint actif
#
# Surcharges possibles (variables d'env) :
#   PROD_ENDPOINT (défaut https://auberdine.eu)
#   DEV_ENDPOINT  (défaut http://localhost:3000)

set -euo pipefail

PROD_ENDPOINT="${PROD_ENDPOINT:-https://auberdine.eu}"
DEV_ENDPOINT="${DEV_ENDPOINT:-http://localhost:3000}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

env_name="${1:-}"
shift || true

case "$env_name" in
  prod|production)
    export AUBERDINE_PROFILE="prod"
    export AUBERDINE_ENDPOINT="$PROD_ENDPOINT"
    ;;
  dev|local)
    export AUBERDINE_PROFILE="dev"
    export AUBERDINE_ENDPOINT="$DEV_ENDPOINT"
    ;;
  ""|-h|--help|help)
    usage 0
    ;;
  *)
    echo "Environnement inconnu : '$env_name' (attendu : prod | dev)" >&2
    usage 1
    ;;
esac

# Commande par défaut : status.
if [ "$#" -eq 0 ]; then
  set -- status
fi

echo "→ [${AUBERDINE_PROFILE}] ${AUBERDINE_ENDPOINT}  —  $*"

# Résolution du client : binaire installé en priorité, sinon binaire local, sinon `go run`.
if command -v auberdine-uploader >/dev/null 2>&1; then
  exec auberdine-uploader "$@"
elif [ -x "$SCRIPT_DIR/auberdine-uploader" ]; then
  exec "$SCRIPT_DIR/auberdine-uploader" "$@"
else
  exec go run -C "$SCRIPT_DIR" ./cmd/auberdine-uploader "$@"
fi
