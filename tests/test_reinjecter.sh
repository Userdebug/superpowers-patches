#!/usr/bin/env bash
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CACHE="$TMP/home/.cache/opencode/packages/superpowers@fake/node_modules/superpowers"
mkdir -p "$CACHE/skills/systematic-debugging" \
         "$CACHE/skills/pre-deploy/references" \
         "$CACHE/skills/security-review"

echo "old"       > "$CACHE/skills/systematic-debugging/SKILL.md"
echo "old-ref"   > "$CACHE/skills/pre-deploy/references/build-matrix.md"
echo "old-annexe"> "$CACHE/skills/security-review/cloud-infrastructure-security.md"
echo "old-skill" > "$CACHE/skills/security-review/SKILL.md"

HOME="$TMP/home" "$PATCH_DIR/reinjecter.sh" >/dev/null

cmp -s "$PATCH_DIR/skills/systematic-debugging/SKILL.md" \
      "$CACHE/skills/systematic-debugging/SKILL.md" \
  || { echo "FAIL: SKILL.md non patché"; exit 1; }
cmp -s "$PATCH_DIR/skills/pre-deploy/references/build-matrix.md" \
      "$CACHE/skills/pre-deploy/references/build-matrix.md" \
  || { echo "FAIL: references/ non synchronisée"; exit 1; }
cmp -s "$PATCH_DIR/skills/security-review/cloud-infrastructure-security.md" \
      "$CACHE/skills/security-review/cloud-infrastructure-security.md" \
  || { echo "FAIL: annexe racine non synchronisée (CE-003)"; exit 1; }

bkp="$(ls -d "$PATCH_DIR"/_backup_cache/*/security-review 2>/dev/null | head -1)"
[ -n "$bkp" ] || { echo "FAIL: backup horodaté manquant"; exit 1; }

HOME="$TMP/home" "$PATCH_DIR/reinjecter.sh" >/dev/null   # idempotence
cmp -s "$PATCH_DIR/skills/systematic-debugging/SKILL.md" \
      "$CACHE/skills/systematic-debugging/SKILL.md" \
  || { echo "FAIL: non-idempotent"; exit 1; }

rm -rf "$PATCH_DIR"/_backup_cache
echo "test_reinjecter : OK"