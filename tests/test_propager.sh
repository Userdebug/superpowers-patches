#!/usr/bin/env bash
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

AGENTS="$TMP/home/.agents/skills"
mkdir -p "$AGENTS/code-refactor" "$AGENTS/ui-governance"

echo "OLD-CURATED" > "$AGENTS/code-refactor/SKILL.md"

# (a) Sans --force : la curatée n'est PAS écrasée
HOME="$TMP/home" "$PATCH_DIR/propager_skills.sh" >/dev/null
[ "$(cat "$AGENTS/code-refactor/SKILL.md")" = "OLD-CURATED" ] \
  || { echo "FAIL: curatée écrasée sans --force"; exit 1; }

# (a') Re-run sans --force : toujours préservée
HOME="$TMP/home" "$PATCH_DIR/propager_skills.sh" >/dev/null
[ "$(cat "$AGENTS/code-refactor/SKILL.md")" = "OLD-CURATED" ] \
  || { echo "FAIL: re-run a écrasé la curatée"; exit 1; }

# (b) Avec --force : curatée = patch + backup créé
HOME="$TMP/home" "$PATCH_DIR/propager_skills.sh" --force code-refactor >/dev/null
cmp -s "$PATCH_DIR/skills/code-refactor/SKILL.md" "$AGENTS/code-refactor/SKILL.md" \
  || { echo "FAIL: curatée != patch après --force"; exit 1; }
bkp="$(ls -d "$TMP"/home/.agents/skills_backup/*/code-refactor 2>/dev/null | head -1 || true)"
[ -n "$bkp" ] || { echo "FAIL: backup skills_backup manquant"; exit 1; }
[ "$(cat "$bkp/SKILL.md")" = "OLD-CURATED" ] \
  || { echo "FAIL: backup ne contient pas l'ancienne curatée"; exit 1; }

# (c) Miroir OpenCode personal-skills : TOUJOURS écrasé (source du patch)
PERSONAL="$TMP/home/.config/opencode/personal-skills"
[ -f "$PERSONAL/code-refactor/SKILL.md" ] \
  || { echo "FAIL: personal-skills non déployé"; exit 1; }
cmp -s "$PATCH_DIR/skills/code-refactor/SKILL.md" "$PERSONAL/code-refactor/SKILL.md" \
  || { echo "FAIL: personal-skills != patch"; exit 1; }

# (d) Idempotence miroir : ré-exécution sans erreur, hub + references/ déployés
HOME="$TMP/home" "$PATCH_DIR/propager_skills.sh" >/dev/null
cmp -s "$PATCH_DIR/skills/using-superpowers/SKILL.md" "$PERSONAL/using-superpowers/SKILL.md" \
  || { echo "FAIL: hub personal-skills != patch"; exit 1; }
[ -d "$PERSONAL/using-superpowers/references" ] \
  || { echo "FAIL: references/ non déployées"; exit 1; }

echo "test_propager : OK"