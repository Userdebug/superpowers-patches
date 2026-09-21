#!/usr/bin/env bash
# test_plugin.sh — tests unitaires du mini-plugin personnel (variante B).
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PATCH_DIR"
node --test tests/plugin-unit.test.mjs >/dev/null
echo "test_plugin : OK"