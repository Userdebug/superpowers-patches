#!/usr/bin/env bash
# init-project.sh — intégration du triptyque capacités dans UN projet
# (à exécuter UNE fois par projet, après init-machine.sh).
#
# Usage : ./init-project.sh [/chemin/du/projet]   (défaut : répertoire courant)
#
# Actions :
#   1. Installe la commande /capacites        → <projet>/.opencode/commands/
#   2. Prépare le dossier d'état              → <projet>/.opencode/instructions/
#   3. Branche le chargement de l'état        → <projet>/opencode.json ("instructions")
#      (fusion idempotente si le fichier existe déjà)
#
# Ensuite (dans OpenCode) : /capacites génère l'état réel depuis des sondes live,
# puis committer opencode.json + .opencode/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJET="${1:-$PWD}"

if [ ! -d "$PROJET" ]; then
    echo "ERREUR : « ${PROJET} » n'est pas un dossier existant." >&2
    exit 1
fi

TPL_CMD="${SCRIPT_DIR}/templates/project/commands/capacites.md"
[ -f "$TPL_CMD" ] || { echo "ERREUR : template introuvable (${TPL_CMD})." >&2; exit 1; }

# --- 1 & 2. Commande /capacites + dossier d'état ---
mkdir -p "${PROJET}/.opencode/commands" "${PROJET}/.opencode/instructions"
cp "$TPL_CMD" "${PROJET}/.opencode/commands/capacites.md"
echo "[OK] Commande installée : ${PROJET}/.opencode/commands/capacites.md"

# --- 3. opencode.json : création ou fusion idempotente ---
if [ ! -f "${PROJET}/opencode.json" ] && [ -f "${PROJET}/opencode.jsonc" ]; then
    echo "ACTION MANUELLE : ${PROJET}/opencode.jsonc existe déjà (JSONC)." >&2
    echo "  Fusionne-y manuellement : \"instructions\": [\".opencode/instructions/*.md\"]" >&2
    exit 1
fi

python3 - "$PROJET" <<'PY'
import json, pathlib, sys
projet = pathlib.Path(sys.argv[1])
cfg = projet / "opencode.json"
data = {}
if cfg.exists():
    data = json.loads(cfg.read_text(encoding="utf-8"))
data.setdefault("$schema", "https://opencode.ai/config.json")
instr = list(data.get("instructions", []))
glob = ".opencode/instructions/*.md"
if glob not in instr:
    instr.append(glob)
data["instructions"] = instr
cfg.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"[OK] Config mise à jour : {cfg}")
PY

echo ""
echo "Projet initialisé. Étapes suivantes :"
echo "  1. Redémarre OpenCode dans ${PROJET}"
echo "  2. Tape /capacites  → génère .opencode/instructions/capacites-outils.md"
echo "  3. Committer : git add opencode.json .opencode && git commit -m 'chore(opencode): état capacités outils'"
