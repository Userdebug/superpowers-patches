#!/usr/bin/env bash
# init-machine.sh — préparation d'une NOUVELLE machine (à exécuter UNE fois).
#
# Prérequis : ce dépôt cloné + opencode installé.
# Actions :
#   1. Vérifie/crée la config globale opencode avec le plugin superpowers déclaré
#      (opencode télécharge et installe le plugin au prochain démarrage).
#   2. Injecte les patches de skills dans le cache du paquet (reinjeter.sh).
#
# Ensuite, pour CHAQUE projet : ./init-project.sh /chemin/du/projet
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/opencode"
PLUGIN_DECL='superpowers@git+https://github.com/obra/superpowers.git'

command -v opencode >/dev/null 2>&1 \
    || echo "AVERTISSEMENT : opencode introuvable dans le PATH — installe-le avant de continuer." >&2

# --- 1. Config globale : déclaration du plugin ---
GLOBAL_CFG=""
for f in "${CONFIG_DIR}/opencode.json" "${CONFIG_DIR}/opencode.jsonc"; do
    [ -f "$f" ] && GLOBAL_CFG="$f" && break
done

if [ -z "$GLOBAL_CFG" ]; then
    mkdir -p "$CONFIG_DIR"
    GLOBAL_CFG="${CONFIG_DIR}/opencode.json"
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "plugin": ["%s"]\n}\n' \
        "$PLUGIN_DECL" > "$GLOBAL_CFG"
    echo "[OK] Config globale créée avec le plugin superpowers : ${GLOBAL_CFG}"
elif grep -q 'superpowers@git' "$GLOBAL_CFG"; then
    echo "[OK] Plugin déjà déclaré dans ${GLOBAL_CFG}"
else
    echo "ACTION MANUELLE : ajoute au tableau \"plugin\" de ${GLOBAL_CFG} :" >&2
    echo "  \"plugin\": [\"${PLUGIN_DECL}\"]" >&2
    exit 1
fi

# --- 2. Injection des patches dans le cache du paquet ---
"${SCRIPT_DIR}/reinjecter.sh"

echo ""
echo "Machine initialisée. Étapes suivantes :"
echo "  1. Redémarre OpenCode (le plugin se télécharge si première installation)"
echo "  2. Par projet : ${SCRIPT_DIR}/init-project.sh /chemin/du/projet"
