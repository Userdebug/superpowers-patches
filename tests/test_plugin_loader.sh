#!/usr/bin/env bash
# test_plugin_loader.sh — test d'intégration loader sous opencode 2.x.
#
# Vérifie, SANS appel modèle, sur un serveur opencode sandbox isolé :
#   1. le duo superpowers(#v7.0.2) + mini-plugin personnel charge sans échec ;
#   2. les 13 skills du dépôt résolvent avec le CONTENU du dépôt (jamais la
#      version du cache superpowers pour les ids partagés, jamais un miroir
#      ~/.agents/skills périmé) ;
#   3. le glob d'instructions du triptyque est présent dans la config résolue.
#
# Pourquoi le contenu et pas le chemin : opencode 2 découvre nativement
# ~/.agents/skills et, selon l'ordre des transforms, c'est ce scan qui peut
# gagner pour les ids partagés — le chemin du gagnant est interne au host.
# L'invariant réel est « la version servie == version du dépôt » (ce test
# attrape donc aussi un ~/.agents/skills non resynchronisé par propager).
#
# HERMÉTICITÉ : XDG_CONFIG_HOME, XDG_DATA_HOME et XDG_STATE_HOME sont isolés.
# Sans XDG_DATA_HOME isolé, le sandbox partage le opencode.db, les snapshots
# et le log de l'hôte ; sans XDG_STATE_HOME isolé, il enregistre son service
# et ses verrous chez l'hôte. Le cache ~/.cache/opencode reste réel pour
# résoudre superpowers hors-ligne ; ~/.agents/skills reste réel (c'est la
# machine cible — voir ci-dessus).
#
# PAS de `--service` : ce mode (lifecycle non nul) lance au boot
# resumeSuspendedSessions(), qui suppose orphelines les claims d'exécution de
# la base. Avec une base partagée, il « reprenait » la session de l'hôte en
# cours et injectait « The server restarted while you were working » en
# annulant le job shell — d'où les redémarrages observés. Un serveur simple
# (sans lifecycle) ne sweepe jamais.
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
SERVE_PID=""
cleanup() {
    [ -n "$SERVE_PID" ] && kill "$SERVE_PID" 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

command -v opencode >/dev/null 2>&1 || { echo "ERREUR : opencode absent du PATH" >&2; exit 1; }

# Le test cible opencode 2 (migration v2) : opencode 1 n'a ni API /api/skill
# ni sous-commande serve exploitable de la même façon.
VERSION="$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
case "$VERSION" in
    2.*|3.*) ;;
    *) echo "ERREUR : opencode 2+ requis (trouvé : ${VERSION:-inconnu})" >&2; exit 1 ;;
esac

CFG="$TMP/cfg"
mkdir -p "$CFG/plugins" "$CFG/personal-skills"
cp "$PATCH_DIR/plugin/personal-skills.js" "$CFG/plugins/"
for skill in "$PATCH_DIR"/skills/*/; do
    cp -r "$skill" "$CFG/personal-skills/"
done

cat > "$CFG/opencode.jsonc" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugins": [
    "superpowers@git+https://github.com/obra/superpowers.git#v7.0.2",
    "$CFG/plugins/personal-skills.js"
  ],
  "instructions": [".opencode/instructions/*.md"]
}
EOF

# --- 1. Config sandbox déclarée ----------------------------------------------
# NB : depuis opencode 2, `opencode debug config` ignore OPENCODE_CONFIG_DIR
# (il lit la config réelle) — l'assertion de config résolue passe donc par
# /api/config du serveur sandbox, plus bas.
grep -q '\.opencode/instructions/\*\.md' "$CFG/opencode.jsonc" \
    || { echo "FAIL : glob instructions absent du fichier de config sandbox" >&2; exit 1; }

# --- 2. Serveur sandbox : chargement plugins + résolution des skills ---------
# Le chargement des plugins est ASYNCHRONE dans opencode 2 (services de
# location bootés au premier hit API, plugins activés ~2-3 s après) : on
# poll jusqu'à ce que les deux plugins soient actifs et les skills présents.
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
# Mot de passe connu d'avance : fourni via OPENCODE_PASSWORD (le mode `serve`
# simple n'écrit pas service.json, contrairement à `--service`).
PW="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
OPENCODE_CONFIG_DIR="$CFG" XDG_CONFIG_HOME="$TMP/xdg" \
    XDG_DATA_HOME="$TMP/data" XDG_STATE_HOME="$TMP/state" \
    OPENCODE_PASSWORD="$PW" \
    opencode serve --hostname 127.0.0.1 --port "$PORT" > "$TMP/serve.log" 2>&1 &
SERVE_PID=$!

UP=""
for _ in $(seq 1 60); do
    if curl -s -m 2 -u "opencode:$PW" "http://127.0.0.1:$PORT/openapi.json" -o /dev/null; then
        UP=1
        break
    fi
    kill -0 "$SERVE_PID" 2>/dev/null || { cat "$TMP/serve.log" >&2; echo "FAIL : opencode serve est mort au démarrage" >&2; exit 1; }
    sleep 0.5
done
[ -n "$UP" ] || { cat "$TMP/serve.log" >&2; echo "FAIL : serveur sandbox non prêt (API)" >&2; exit 1; }

# Garde-fou d'isolation : data et state sont bien privés au sandbox. Une
# régression ici (XDG non isolé) réintroduit le partage de la base hôte.
[ -d "$TMP/data/opencode" ] && [ -d "$TMP/state/opencode" ] \
    || { echo "FAIL : XDG_DATA_HOME/XDG_STATE_HOME non isolés" >&2; exit 1; }

READY=""
for _ in $(seq 1 120); do
    curl -s -m 5 -u "opencode:$PW" --get --data-urlencode "location[directory]=$PATCH_DIR" \
        "http://127.0.0.1:$PORT/api/plugin" > "$TMP/plugins.json" 2>/dev/null || true
    curl -s -m 5 -u "opencode:$PW" --get --data-urlencode "location[directory]=$PATCH_DIR" \
        "http://127.0.0.1:$PORT/api/skill" > "$TMP/skills.json" 2>/dev/null || true
    if python3 - "$TMP/plugins.json" "$TMP/skills.json" <<'PY' 2>/dev/null
import json, sys
plugins = json.load(open(sys.argv[1]))["data"]
skills = json.load(open(sys.argv[2]))["data"]
ids = {p["id"] for p in plugins if p.get("source", {}).get("type") != "builtin"}
sys.exit(0 if {"superpowers", "personal-skills"} <= ids and len(skills) >= 13 else 1)
PY
    then
        READY=1
        break
    fi
    sleep 0.5
done
[ -n "$READY" ] || { cat "$TMP/serve.log" >&2; echo "FAIL : plugins/skills non chargés dans le serveur sandbox (timeout)" >&2; exit 1; }

# Les hits API ont ouvert la base : elle doit être la base PRIVÉE du sandbox.
[ -f "$TMP/data/opencode/opencode.db" ] \
    || { echo "FAIL : le sandbox n'utilise pas sa propre base (partage de la base hôte)" >&2; exit 1; }

curl -s -m 10 -u "opencode:$PW" "http://127.0.0.1:$PORT/api/config" > "$TMP/config.json" \
    || { echo "FAIL : /api/config a échoué" >&2; exit 1; }
grep -q '\.opencode/instructions/\*\.md' "$TMP/config.json" \
    || { echo "FAIL : glob instructions absent de la config résolue" >&2; exit 1; }
grep -q 'superpowers@git+https://github.com/obra/superpowers.git#v7.0.2' "$TMP/config.json" \
    || { echo "FAIL : pin superpowers #v7.0.2 absent de la config résolue" >&2; exit 1; }
grep -q "$CFG/plugins/personal-skills.js" "$TMP/config.json" \
    || { echo "FAIL : plugin personnel absent de la config résolue" >&2; exit 1; }

python3 - "$TMP/skills.json" "$TMP/plugins.json" "$PATCH_DIR" <<'PY' || exit 1
import json, sys, os

skills_path, plugins_path, patch_dir = sys.argv[1:4]
skills = {s["id"]: s for s in json.load(open(skills_path))["data"]}
plugins = json.load(open(plugins_path))["data"]

# (a) Plugins : duo chargé, actif, sans échec.
by_id = {}
for p in plugins:
    if p.get("source", {}).get("type") != "builtin":
        by_id.setdefault(p["id"], []).append(p)
for pid in ("superpowers", "personal-skills"):
    entries = by_id.get(pid, [])
    if not entries:
        print(f"FAIL : plugin {pid} absent de /api/plugin", file=sys.stderr); sys.exit(1)
    if len(entries) > 1:
        print(f"FAIL : plugin {pid} chargé {len(entries)} fois (duplicate ID)", file=sys.stderr); sys.exit(1)
    status = entries[0].get("state", {}).get("status")
    if status != "active":
        print(f"FAIL : plugin {pid} non actif (status={status}, "
              f"failure={entries[0].get('state', {}).get('failure')})", file=sys.stderr); sys.exit(1)

# (b) Les 13 skills du dépôt : présents, contenu == dépôt, hors cache superpowers.
repo_skills = sorted(
    d for d in os.listdir(os.path.join(patch_dir, "skills"))
    if os.path.isfile(os.path.join(patch_dir, "skills", d, "SKILL.md"))
)
assert len(repo_skills) >= 13, f"skills dépôt incomplet: {repo_skills}"

fail = []
for name in repo_skills:
    s = skills.get(name)
    if not s:
        fail.append(f"{name} : ABSENT du registre"); continue
    resolved = s.get("path") or ""
    if any(m in resolved for m in (
        "/node_modules/superpowers/skills/",
        "/packages/superpowers@",
        "/npm/git-superpowers",
    )):
        fail.append(f"{name} : résout vers le cache superpowers ({resolved})"); continue
    if not os.path.isfile(resolved):
        fail.append(f"{name} : chemin résolu introuvable ({resolved})"); continue
    with open(os.path.join(patch_dir, "skills", name, "SKILL.md"), "rb") as a, \
         open(resolved, "rb") as b:
        if a.read() != b.read():
            fail.append(f"{name} : contenu != dépôt (miroir périmé ?) {resolved}")
if fail:
    print("FAIL :", *fail, sep="\n  ", file=sys.stderr); sys.exit(1)

print(f"  [serve] : OK ({len(repo_skills)} skills == dépôt, "
      f"plugins actifs, {len(skills)} skills au total)")
PY
echo "test_plugin_loader : OK"
