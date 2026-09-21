#!/usr/bin/env bash
# init-machine.sh — préparation d'une NOUVELLE machine (à exécuter UNE fois).
#
# Prérequis : ce dépôt cloné + opencode installé.
# Actions :
#   1. Vérifie/crée la config globale opencode avec le plugin superpowers déclaré
#      (opencode télécharge et installe le plugin au prochain démarrage), puis
#      notre mini-plugin personnel plugin/personal-skills.js installé APRÈS
#      superpowers dans le tableau "plugin" (ordre = victoire du bootstrap
#      personnel sur le cache — le loader « dernier écrit gagne »).
#   2. Propage les skills : miroir opencode ~/.config/opencode/personal-skills/
#      + ~/.agents/skills/ (autres harnais, curatées préservées).
#
# Ensuite, pour CHAQUE projet : ./init-project.sh /chemin/du/projet
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/opencode"
PLUGIN_DECL='superpowers@git+https://github.com/obra/superpowers.git'
PLUGINS_DIR="${CONFIG_DIR}/plugins"
PERSONAL_PLUGIN="${PLUGINS_DIR}/personal-skills.js"

command -v opencode >/dev/null 2>&1 \
    || echo "AVERTISSEMENT : opencode introuvable dans le PATH — installe-le avant de continuer." >&2

# --- 1. Config globale : déclaration du plugin superpowers ---
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

# --- 2. Installation du mini-plugin personnel ---
mkdir -p "${PLUGINS_DIR}"
if ! cmp -s "${SCRIPT_DIR}/plugin/personal-skills.js" "${PERSONAL_PLUGIN}"; then
    cp "${SCRIPT_DIR}/plugin/personal-skills.js" "${PERSONAL_PLUGIN}"
    echo "[OK] Plugin personnel installé : ${PERSONAL_PLUGIN}"
else
    echo "[OK] Plugin personnel déjà à jour : ${PERSONAL_PLUGIN}"
fi

# Déclare le plugin personnel APRÈS superpowers dans le tableau "plugin".
# opencode.json / opencode.jsonc (commentaires) : injection JSONC par python3,
# sinon ACTION MANUELLE (script interrompu — la déclaration est obligatoire).
PY_INJECT=$(cat <<'PY'
import json, sys, os, re

def strip_jsonc(text):
    # Retire les commentaires // et /* */ en dehors des chaînes (JSONC pur).
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"': in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if text.startswith('//', i):
            j = text.find('\n', i)
            i = j if j != -1 else n; continue
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = (j + 2) if j != -1 else n; continue
        out.append(c); i += 1
    return ''.join(out)

path, personal, upstream = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(path, encoding='utf-8').read()
try:
    cfg = json.loads(strip_jsonc(raw))
except Exception as e:
    print(f"PARSE_ERR:{e}"); sys.exit(2)
plugins = cfg.get('plugin')
if plugins is None:
    plugins = []
# Conserve les autres entrées ; garantit superpowers en tête puis personnel juste après.
plugins = [p for p in plugins if p != personal]
if upstream not in plugins:
    plugins = [upstream] + plugins
idx = plugins.index(upstream)
if idx + 1 == len(plugins) or plugins[idx + 1] != personal:
    plugins.insert(idx + 1, personal)
cfg['plugin'] = plugins
tmp = path + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
os.replace(tmp, path)
PY
)

if command -v python3 >/dev/null 2>&1; then
    if out=$(python3 -c "$PY_INJECT" "$GLOBAL_CFG" "$PERSONAL_PLUGIN" "$PLUGIN_DECL" 2>&1); then
        if [ -z "$out" ]; then
            echo "[OK] Plugin personnel déclaré APRÈS superpowers dans ${GLOBAL_CFG}"
        else
            echo "ERREUR python3 : ${out}" >&2
            exit 1
        fi
    else
        echo "ERREUR : ${out}" >&2
        echo "ACTION MANUELLE : ajoute \"${PERSONAL_PLUGIN}\" DANS le tableau \"plugin\" de ${GLOBAL_CFG}, APRÈS l'entrée superpowers, puis relance le script." >&2
        exit 1
    fi
else
    echo "ERREUR : python3 absent." >&2
    echo "ACTION MANUELLE : ajoute \"${PERSONAL_PLUGIN}\" DANS le tableau \"plugin\" de ${GLOBAL_CFG}, APRÈS l'entrée superpowers." >&2
    exit 1
fi

# --- 3. Propagation des skills : miroir opencode + ~/.agents/skills/ ---
"${SCRIPT_DIR}/propager_skills.sh"

echo ""
echo "Machine initialisée. Étapes suivantes :"
echo "  1. Redémarre OpenCode (plugins chargés au démarrage ; le miroir personal-skills y est poussé en dernière position)"
echo "  2. Par projet : ${SCRIPT_DIR}/init-project.sh /chemin/du/projet"
