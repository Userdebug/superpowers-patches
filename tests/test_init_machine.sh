#!/usr/bin/env bash
# test_init_machine.sh — init-machine.sh, exécuté sur un HOME simulé, doit :
#   1. déclarer superpowers (pin #v7.0.2) + plugin personnel dans la config
#      globale (clé "plugin" V1 fraîche / "plugins" V2 existante, jamais de
#      conversion prématurée) + glob d'instructions du triptyque,
#   2. installer le plugin personnel,
#   3. installer la commande /capacites dans ~/.config/opencode/commands/ (config universelle),
#   4. propager le miroir personal-skills,
#   5. être idempotent (re-run sans doublon ni bascule de clé).
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
# Le template doit prescrire une NOUVELLE LIGNE FINALE pour le fichier d'état
# (sans quoi le modèle régénère un fichier sans \n final — vu sur School-App/POSS APP).
grep -qi "nouvelle ligne finale" "$PATCH_DIR/templates/project/commands/capacites.md" \
    || { echo "FAIL : template /capacites ne prescrit pas la nouvelle ligne finale" >&2; exit 1; }

# Miroir personal-skills propagé : IDENTIQUE au compte réel du dépôt.
[ -d "$CFG_DIR/personal-skills/using-superpowers" ] || { echo "FAIL : miroir personal-skills absent (hub manquant)" >&2; exit 1; }
expected=$(find "$PATCH_DIR/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l)
nb=$(find "$CFG_DIR/personal-skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l)
[ "$nb" -eq "$expected" ] || { echo "FAIL : miroir incomplet (${nb}/${expected} skills)" >&2; exit 1; }

# --- Migration v2 : pin, glob instructions, clé V1 sur machine fraîche -------

# Pin superpowers gelé sur #v7.0.2 (hooks compaction/generate, ids nus, marqueur strict).
grep -q 'superpowers@git+https://github.com/obra/superpowers.git#v7.0.2' "$GLOBAL_CFG" \
    || { echo "FAIL : pin superpowers #v7.0.2 absent de la config" >&2; exit 1; }

# Glob d'instructions du triptyque déclaré en config (plus injecté par plugin).
grep -q '\.opencode/instructions/\*\.md' "$GLOBAL_CFG" \
    || { echo "FAIL : glob instructions absent de la config" >&2; exit 1; }

# Machine fraîche : clé V1 "plugin" — JAMAIS de conversion V2 prématurée
# (v1.19.3 perd les specs git dans "plugins").
if grep -q '"plugins"' "$GLOBAL_CFG"; then
    echo "FAIL : clé V2 \"plugins\" créée sur une config fraîche" >&2; exit 1
fi

# Ordre + idempotence : superpowers juste avant le personnel, un seul glob.
python3 - "$GLOBAL_CFG" <<'PY' || { echo "FAIL : config fraîche non conforme" >&2; exit 1; }
import json, sys
cfg = json.load(open(sys.argv[1]))
p = cfg['plugin']
up = next(i for i, e in enumerate(p) if isinstance(e, str) and e.startswith('superpowers@'))
assert up + 1 < len(p) and p[up + 1].endswith('/plugins/personal-skills.js'), p
assert p[up] == 'superpowers@git+https://github.com/obra/superpowers.git#v7.0.2', p
assert cfg['instructions'].count('.opencode/instructions/*.md') == 1, cfg['instructions']
assert len(p) == 2, p
PY

# Idempotence : seconde exécution sans rien dupliquer ni convertir la clé.
HOME="$TMP/home" "${PATCH_DIR}/init-machine.sh" > "$TMP/out2.log" 2>&1 \
    || { echo "init-machine (re-run) a échoué :" >&2; cat "$TMP/out2.log" >&2; exit 1; }
python3 - "$GLOBAL_CFG" <<'PY' || { echo "FAIL : re-run non idempotent" >&2; exit 1; }
import json, sys
cfg = json.load(open(sys.argv[1]))
assert 'plugins' not in cfg, 'la clé V1 ne doit jamais basculer en plugins'
p = cfg['plugin']
assert len(p) == 2, p
assert cfg['instructions'].count('.opencode/instructions/*.md') == 1
PY
echo "  [fresh] : OK (clé V1 préservée, pin #v7.0.2, glob instructions, idempotent)"

# --- Clé adaptative : config déjà en forme V2 ⇒ "plugins" conservée ----------

HOME2="$TMP/home-v2"
mkdir -p "$HOME2/.config/opencode"
cat > "$HOME2/.config/opencode/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugins": [
    "superpowers@git+https://github.com/obra/superpowers.git#v7.0.2",
    "/opt/autre-plugin.js"
  ],
  "instructions": ["AGENTS.md"]
}
EOF
HOME="$HOME2" "${PATCH_DIR}/init-machine.sh" > "$TMP/out-v2.log" 2>&1 \
    || { echo "init-machine (config V2) a échoué :" >&2; cat "$TMP/out-v2.log" >&2; exit 1; }
python3 - "$HOME2/.config/opencode/opencode.json" "$HOME2" <<'PY' || { echo "FAIL : scénario config V2" >&2; exit 1; }
import json, sys, os
cfg = json.load(open(sys.argv[1]))
home = sys.argv[2]
assert 'plugins' in cfg and 'plugin' not in cfg, sorted(cfg)
p = cfg['plugins']
up = next(i for i, e in enumerate(p) if isinstance(e, str) and e.startswith('superpowers@'))
assert p[up + 1] == os.path.join(home, '.config/opencode/plugins/personal-skills.js'), p
assert '/opt/autre-plugin.js' in p, 'une entrée tierce ne doit pas être perdue'
assert cfg['instructions'] == ['AGENTS.md', '.opencode/instructions/*.md'], cfg['instructions']
PY
echo "  [config-v2] : OK (clé plugins conservée, entrée tierce préservée, glob ajouté)"

# --- Clé adaptative : config V1 avec entrées existantes ---------------------

HOME3="$TMP/home-v1"
mkdir -p "$HOME3/.config/opencode"
cat > "$HOME3/.config/opencode/opencode.jsonc" <<EOF
{
  // config existante, superpowers non piné
  "plugin": [
    "superpowers@git+https://github.com/obra/superpowers.git",
    "/opt/existant.js"
  ]
}
EOF
HOME="$HOME3" "${PATCH_DIR}/init-machine.sh" > "$TMP/out-v1.log" 2>&1 \
    || { echo "init-machine (config V1 existante) a échoué :" >&2; cat "$TMP/out-v1.log" >&2; exit 1; }
python3 - "$HOME3/.config/opencode/opencode.jsonc" "$HOME3" <<'PY' || { echo "FAIL : scénario config V1 existante" >&2; exit 1;}
import json, sys, os, re
raw = open(sys.argv[1], encoding='utf-8').read()
raw = re.sub(r'^\s*//.*$', '', raw, flags=re.M)  # commentaires JSONC du test (pas les https://)
cfg = json.loads(raw)
home = sys.argv[2]
assert 'plugins' not in cfg, 'pas de conversion V2 sur une config V1'
p = cfg['plugin']
assert p[0] == 'superpowers@git+https://github.com/obra/superpowers.git', 'pin existant conservé tel quel'
assert p[1] == os.path.join(home, '.config/opencode/plugins/personal-skills.js'), p
assert '/opt/existant.js' in p, 'entrée existante perdue'
assert cfg['instructions'] == ['.opencode/instructions/*.md'], cfg['instructions']
PY
echo "  [config-v1] : OK (clé plugin conservée, pin non écrasé, entrée existante préservée)"

echo "test_init_machine : OK"
