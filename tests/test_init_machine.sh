#!/usr/bin/env bash
# test_init_machine.sh — init-machine.sh, exécuté sur un HOME simulé, doit :
#   1. déclarer superpowers + plugin personnel dans la config globale,
#   2. installer le plugin personnel,
#   3. installer la commande /capacites dans ~/.config/opencode/commands/ (config universelle),
#   4. propager le miroir personal-skills.
# Aucun appel modèle ; opencode n'est pas lancé ici.
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME"

"${PATCH_DIR}/init-machine.sh" > "$TMP/out.log" 2>&1 \
    || { echo "init-machine a échoué :" >&2; cat "$TMP/out.log" >&2; exit 1; }

CFG_DIR="$HOME/.config/opencode"

GLOBAL_CFG=""
for f in "$CFG_DIR"/opencode.json "$CFG_DIR"/opencode.jsonc; do
    [ -f "$f" ] && GLOBAL_CFG="$f" && break
done
[ -n "$GLOBAL_CFG" ] || { echo "FAIL : aucune config globale créée" >&2; exit 1; }
grep -q "superpowers@git" "$GLOBAL_CFG" || { echo "FAIL : superpowers non déclaré" >&2; exit 1; }
grep -q "personal-skills.js" "$GLOBAL_CFG" || { echo "FAIL : plugin personnel non déclaré" >&2; exit 1; }

[ -f "$CFG_DIR/plugins/personal-skills.js" ] || { echo "FAIL : plugin personnel non installé" >&2; exit 1; }
cmp -s "$CFG_DIR/plugins/personal-skills.js" "$PATCH_DIR/plugin/personal-skills.js" \
    || { echo "FAIL : plugin personnel non conforme au dépôt" >&2; exit 1; }

# Config universelle (option B) : commande /capacites au niveau machine.
[ -f "$CFG_DIR/commands/capacites.md" ] || { echo "FAIL : commande /capacites absente de ${CFG_DIR}/commands/" >&2; exit 1; }
cmp -s "$CFG_DIR/commands/capacites.md" "$PATCH_DIR/templates/project/commands/capacites.md" \
    || { echo "FAIL : commande /capacites non conforme au template" >&2; exit 1; }

# Miroir personal-skills propagé.
[ -d "$CFG_DIR/personal-skills/using-superpowers" ] || { echo "FAIL : miroir personal-skills absent (hub manquant)" >&2; exit 1; }
nb=$(find "$CFG_DIR/personal-skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l)
[ "$nb" -ge 13 ] || { echo "FAIL : miroir incomplet (${nb}/13)" >&2; exit 1; }

echo "test_init_machine : OK"
