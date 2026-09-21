#!/usr/bin/env bash
# test_plugin_loader.sh — test d'intégration loader : les 13 skills du dépôt
# doivent résoudre vers le miroir PERSONAL (opensource), pas vers le cache
# du paquet superpowers. Aucun appel modèle ; opencode debug skill suffit.
#
# HERMÉTICITÉ : opencode scanne AUSSI ~/.config/opencode/plugins/ (plugins
# globaux) même quand OPENCODE_CONFIG_DIR pointe ailleurs ; si le plugin
# personnel y est installé (machine réelle), il polluait le sandbox et l'ordre
# de poussée changeait (cache gagnait). D'où XDG_CONFIG_HOME isolé par run.
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v opencode >/dev/null 2>&1 || { echo "ERREUR : opencode absent du PATH" >&2; exit 1; }

CFG="$TMP/cfg"
mkdir -p "$CFG/plugins" "$CFG/personal-skills"
cp "$PATCH_DIR/plugin/personal-skills.js" "$CFG/plugins/"

# Le plugin personnel doit gagner quelle que soit l'ordre de déclaration
# (invariant contrôlé empiriquement sur opencode 1.18.x).
for ORDER in superpowers-first personal-first; do
    if [ "$ORDER" = superpowers-first ]; then
        cat > "$CFG/opencode.jsonc" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": [
    "superpowers@git+https://github.com/obra/superpowers.git",
    "$CFG/plugins/personal-skills.js"
  ]
}
EOF
    else
        cat > "$CFG/opencode.jsonc" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": [
    "$CFG/plugins/personal-skills.js",
    "superpowers@git+https://github.com/obra/superpowers.git"
  ]
}
EOF
    fi

    for skill in "$PATCH_DIR"/skills/*/; do
        cp -r "$skill" "$CFG/personal-skills/"
    done

    # Marqueur unique injecté DANS la copie miroir du hub : prouve que le
    # contenu chargé vient de PERSONAL (et non du cache superpowers, identique).
    MARKER="marker-variante-b-${ORDER}-$(date +%s)"
    printf '\n\n> %s\n' "$MARKER" >> "$CFG/personal-skills/using-superpowers/SKILL.md"

    OPENCODE_CONFIG_DIR="$CFG" XDG_CONFIG_HOME="$TMP/xdg" opencode debug skill > "$TMP/out.json" 2> "$TMP/err.log" \
        || { cat "$TMP/err.log" >&2; echo "FAIL [${ORDER}]: opencode debug skill a échoué" >&2; exit 1; }

    nb=0
    for skill in "$PATCH_DIR"/skills/*/; do
        n="$(basename "$skill")"
        if ! grep -q "\"location\".*personal-skills/${n}/SKILL.md" "$TMP/out.json"; then
            echo "FAIL [${ORDER}]: ${n} ne résout PAS vers PERSONAL (cache? autre?)" >&2
            grep "\"name\": \"${n}\"" "$TMP/out.json" || true
            exit 1
        fi
        nb=$((nb + 1))
    done

    # Le hub using-superpowers chargé doit être NOTRE version curatée : le
    # marqueur unique présent UNIQUEMENT dans la copie miroir.
    if ! grep -q "$MARKER" "$TMP/out.json"; then
        echo "FAIL [${ORDER}]: using-superpowers ne contient pas notre marqueur curaté" >&2
        exit 1
    fi

    # Config universelle (option B) : le plugin injecte le glob d'instructions
    # du triptyque capacités dans la config résolue — applicable à tout projet.
    OPENCODE_CONFIG_DIR="$CFG" XDG_CONFIG_HOME="$TMP/xdg" opencode debug config > "$TMP/config.json" 2> "$TMP/err.log" \
        || { cat "$TMP/err.log" >&2; echo "FAIL [${ORDER}]: opencode debug config a échoué" >&2; exit 1; }
    if ! grep -q '"\.opencode/instructions/\*\.md"' "$TMP/config.json"; then
        echo "FAIL [${ORDER}]: glob instructions du triptyque absent de la config résolue" >&2
        exit 1
    fi
    echo "  [${ORDER}] : OK (${nb} skills → personal-skills, hub = version personnelle curatée, config universelle injectée)"
done

echo "test_plugin_loader : OK"
