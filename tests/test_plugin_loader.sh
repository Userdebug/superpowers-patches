#!/usr/bin/env bash
# test_plugin_loader.sh — test d'intégration loader : les 13 skills du dépôt
# doivent résoudre vers le miroir PERSONAL (opensource), pas vers le cache
# du paquet superpowers. Aucun appel modèle ; opencode debug skill suffit.
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v opencode >/dev/null 2>&1 || { echo "ERREUR : opencode absent du PATH" >&2; exit 1; }

CFG="$TMP/cfg"
mkdir -p "$CFG/plugins" "$CFG/personal-skills"
cp "$PATCH_DIR/plugin/personal-skills.js" "$CFG/plugins/"

cat > "$CFG/opencode.jsonc" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": [
    "superpowers@git+https://github.com/obra/superpowers.git",
    "$CFG/plugins/personal-skills.js"
  ]
}
EOF

for skill in "$PATCH_DIR"/skills/*/; do
    cp -r "$skill" "$CFG/personal-skills/"
done

OPENCODE_CONFIG_DIR="$CFG" opencode debug skill > "$TMP/out.json" 2> "$TMP/err.log" \
    || { cat "$TMP/err.log" >&2; echo "FAIL: opencode debug skill a échoué" >&2; exit 1; }

nb=0
for skill in "$PATCH_DIR"/skills/*/; do
    n="$(basename "$skill")"
    if ! grep -q "\"location\".*personal-skills/${n}/SKILL.md" "$TMP/out.json"; then
        echo "FAIL: ${n} ne résout PAS vers PERSONAL (cache? autre?)" >&2
        grep "\"name\": \"${n}\"" "$TMP/out.json" || true
        exit 1
    fi
    nb=$((nb + 1))
done

# Le hub using-superpowers chargé doit être NOTRE version curatée (marqueur
# « Semantic Tool Mapping (capability-first) »), pas le SKILL.md du cache.
if ! grep -q "Semantic Tool Mapping (capability-first)" "$TMP/out.json"; then
    echo "FAIL: using-superpowers ne contient pas notre marqueur curaté" >&2
    exit 1
fi

echo "test_plugin_loader : OK (${nb} skills → personal-skills, hub = version personnelle curatée)"