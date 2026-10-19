#!/usr/bin/env bash
# init-machine.sh — préparation d'une NOUVELLE machine (à exécuter UNE fois).
#
# Prérequis : ce dépôt cloné + opencode installé.
# Actions :
#   1. Vérifie/crée la config globale opencode avec le plugin superpowers déclaré
#      (opencode télécharge et installe le plugin au prochain démarrage), puis
#      notre mini-plugin personnel plugin/personal-skills.js installé APRÈS
#      superpowers dans le tableau de plugins (ordre = victoire du bootstrap
#      personnel sur le cache — le loader « dernier écrit gagne »), plus le
#      glob d'instructions du triptyque (déclaré en config). Clé de tableau :
#      "plugins" si la config est déjà en forme V2, sinon "plugin" (V1 — lu
#      nativement par v2 aussi ; attention, v1.19.3 perd les specs git dans
#      "plugins", donc jamais de conversion V2 prématurée sur machine fraîche).
#   2. Installe la commande universelle /capacites (~/.config/opencode/commands/) :
#      disponible dans CHAQUE projet opencode — avec le glob d'instructions du
#      triptyque déclaré en config globale, AUCUNE action par projet n'est
#      nécessaire (le fichier d'état est régénéré dans le projet par /capacites).
#   3. Propage les skills : miroir opencode ~/.config/opencode/personal-skills/
#      + ~/.agents/skills/ (autres harnais, curatées préservées).
#
# Ensuite, dans un projet : /capacites, puis committer le fichier d'état généré.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/opencode"
PLUGIN_DECL='superpowers@git+https://github.com/obra/superpowers.git#v7.0.0'
INSTRUCTION_GLOB='.opencode/instructions/*.md'
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
    echo "ACTION MANUELLE : ajoute au tableau de plugins (\"plugin\" ou \"plugins\") de ${GLOBAL_CFG} :" >&2
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

# Déclare le plugin personnel APRÈS superpowers dans le tableau "plugins",
# migre un éventuel "plugin" V1 vers "plugins" et garantit le glob
# d'instructions du triptyque. opencode.json / opencode.jsonc (commentaires) :
# injection JSONC par python3, sinon ACTION MANUELLE (script interrompu — la
# déclaration est obligatoire).
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

path, personal, upstream, glob = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
raw = open(path, encoding='utf-8').read()
try:
    cfg = json.loads(strip_jsonc(raw))
except Exception as e:
    print(f"PARSE_ERR:{e}"); sys.exit(2)

def is_personal(entry):
    if not isinstance(entry, str):
        return False
    return os.path.realpath(os.path.expanduser(entry)) == os.path.realpath(os.path.expanduser(personal))

# Clé adaptative : "plugins" si déjà présente (forme V2), sinon "plugin" (V1).
# JAMAIS de conversion de clé prématurée : v1.19.3 perd les specs git dans
# "plugins" (seuls les chemins fichiers survivent) — la conversion native se
# fait après installation v2. Si les deux clés coexistent, fusion en "plugins".
native = isinstance(cfg.get('plugins'), list)
merged = []
for k in ('plugins', 'plugin'):
    v = cfg.pop(k, None)
    if isinstance(v, list):
        merged.extend(v)

# Dédoublonnage : entrées strictement identiques + doublons du plugin
# personnel (chemin absolu et ~ pointent au même fichier).
seen = set()
plugins = []
for p in merged:
    key = os.path.realpath(os.path.expanduser(p)) if isinstance(p, str) else json.dumps(p, sort_keys=True)
    if key in seen:
        continue
    seen.add(key)
    plugins.append(p)

# Superpowers juste avant le personnel (ordre = victoire du bootstrap
# personnel). Un éventuel pin déjà présent est conservé tel quel.
up = next((p for p in plugins if isinstance(p, str) and p.startswith('superpowers@')), upstream)
plugins = [p for p in plugins if not is_personal(p)]
if up not in plugins:
    plugins.insert(0, up)
idx = plugins.index(up)
if idx + 1 == len(plugins) or not is_personal(plugins[idx + 1]):
    plugins.insert(idx + 1, personal)
cfg['plugins' if native else 'plugin'] = plugins

# Glob d'instructions du triptyque : déclaré en config (idempotent).
instructions = cfg.get('instructions')
if not isinstance(instructions, list):
    instructions = []
if glob not in instructions:
    instructions.append(glob)
cfg['instructions'] = instructions
tmp = path + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
os.replace(tmp, path)
PY
)

if command -v python3 >/dev/null 2>&1; then
    if out=$(python3 -c "$PY_INJECT" "$GLOBAL_CFG" "$PERSONAL_PLUGIN" "$PLUGIN_DECL" "$INSTRUCTION_GLOB" 2>&1); then
        if [ -z "$out" ]; then
            echo "[OK] Plugin personnel déclaré APRÈS superpowers dans ${GLOBAL_CFG} (+ glob instructions)"
        else
            echo "ERREUR python3 : ${out}" >&2
            exit 1
        fi
    else
        echo "ERREUR : ${out}" >&2
        echo "ACTION MANUELLE : ajoute \"${PERSONAL_PLUGIN}\" DANS le tableau de plugins (\"plugin\" ou \"plugins\") de ${GLOBAL_CFG}, APRÈS l'entrée superpowers, plus \".opencode/instructions/*.md\" dans \"instructions\", puis relance le script." >&2
        exit 1
    fi
else
    echo "ERREUR : python3 absent." >&2
    echo "ACTION MANUELLE : ajoute \"${PERSONAL_PLUGIN}\" DANS le tableau de plugins (\"plugin\" ou \"plugins\") de ${GLOBAL_CFG}, APRÈS l'entrée superpowers, plus \".opencode/instructions/*.md\" dans \"instructions\"." >&2
    exit 1
fi

# --- 3. Commande /capacites universelle (config universelle — option B) ---
# Installée au niveau MACHINE : disponible dans chaque projet opencode, sans
# action par projet. La commande sonde la session courante et régénère
# .opencode/instructions/capacites-outils.md dans le répertoire courant.
COMMANDS_DIR="${CONFIG_DIR}/commands"
mkdir -p "${COMMANDS_DIR}"
TPL_CMD="${SCRIPT_DIR}/templates/project/commands/capacites.md"
CAPACITES_CMD="${COMMANDS_DIR}/capacites.md"
[ -f "$TPL_CMD" ] || { echo "ERREUR : template de la commande /capacites introuvable (${TPL_CMD})." >&2; exit 1; }
if cmp -s "$TPL_CMD" "$CAPACITES_CMD"; then
    echo "[OK] Commande /capacites déjà à jour : ${CAPACITES_CMD}"
else
    cp "$TPL_CMD" "$CAPACITES_CMD"
    echo "[OK] Commande /capacites installée (globale) : ${CAPACITES_CMD}"
fi
# Le glob d'instructions du triptyque est déclaré dans la config GLOBALE par
# ce script (config.instructions) : rien à écrire dans la config du projet.

# --- 4. Propagation des skills : miroir opencode + ~/.agents/skills/ ---
"${SCRIPT_DIR}/propager_skills.sh"

echo ""
echo "Machine initialisée. Étapes suivantes :"
echo "  1. Redémarre OpenCode (plugins chargés au démarrage ; le miroir personal-skills y est poussé en dernière position)"
echo "  2. Dans CHAQUE projet (config universelle) : tape /capacites, puis committe le fichier d'état généré (.opencode/instructions/)"
