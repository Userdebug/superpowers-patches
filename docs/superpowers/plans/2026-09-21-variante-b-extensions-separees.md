# Variante B — extensions personnelles séparées du cache superpowers — Plan d'implémentation

> **Pour les workers agentiques :** skills requises — `test-driven-development`, `executing-plans`. Étapes en checkboxes `- [ ]`.

**Goal :** découpler les 13 skills personnelles du cache du paquet superpowers. Une mise à jour du paquet ne doit plus rien casser (ni ré-injection, ni backup) : opencode charge les extensions depuis un dossier personnel poussé en DERNIER dans `skills.paths` par un mini-plugin local, et le bootstrap de session (hub `using-superpowers`) est remplacé par la version personnelle.

**Spec (constat validé expérimentalement le 21/09/2026, conversations précédentes) :**
- VE-001 : le loader opencode est « dernier-écrit-gagne » ; ordre de scan : `~/.claude` + `~/.agents` (externes) → config dirs (`{skill,skills}/**/SKILL.md`) → `skills.paths` (un par un) → `skills.urls`.
- VE-002 : `superpowers.js` (plugin cache) pousse SON dossier de skills à la FIN de `config.skills.paths` dans son hook `config()` (lignes 107-113). Le cache gagne donc toujours les collisions en approche naïve (il est plus tardif).
- VE-003 : un mini-plugin déclaré APRÈS superpowers dans le tableau `plugin`, qui pousse un dossier personnel (non « skills », non scanné par config-dirs) en dernière position, fait gagner les 13 collisions vers la version PERSONNELLE (validé : 3 runs stables, `opencode debug skill`).
- VE-004 : le bootstrap de session est injecté par le hook `experimental.chat.messages.transform` de `superpowers.js` (lignes 124-137), lu depuis le cache (`using-superpowers/SKILL.md`, ligne 67). Il faut donc AUSSI remplacer ce bootstrap par la version personnelle dans notre plugin (déclaré après → son hook tourne après → remplace le texte injecté, ou détecte `EXTREMELY_IMPORTANT` déjà présent et renonce).
- VE-005 : `~/.config/opencode/skills` est scanné TÔT (config dirs) → perd contre le cache. Approche naïve invalidée.

**Architecture retenue :**
- Les 13 restent SOURCE = `skills/` du dépôt.
- `propager_skills.sh` déploie le dossier complet vers `~/.config/opencode/personal-skills/` (toujours écrasé, miroir fidèle — la session opencode le charge) ET gère `~/.agents/skills/` (autres harnais : Claude Code, Cursor… — curatées préservées, `--force`).
- Mini-plugin `plugin/personal-skills.js` installé à `~/.config/opencode/plugins/personal-skills.js`, déclaré APRÈS `superpowers` dans `opencode.jsonc`. Deux hooks :
  1. `config()` : pousse `personal-skills` en dernière position de `skills.paths`.
  2. `experimental.chat.messages.transform` : remplace le bootstrap injecté par le texte personnel (`personal-skills/using-superpowers/SKILL.md`), ou injecte le sien si absent (détection `EXTREMELY_IMPORTANT`).
- `reinjecter.sh` disparaît (plus rien à ré-injecter : le cache reste intouché, une MAJ superpowers réécrit le cache → rien à faire). Backup `_backup_cache/` ne sert plus.
- `init-machine.sh` : déclare superpowers + notre plugin (dans cet ordre), installe le plugin, lance propager. Plus de reinjecter.

**Tech Stack :** bash (`set -euo pipefail`), Node ≥ 18 (plugin ESM + tests unitaires `node --test`), `cmp`/`cp -r`/`mktemp`. Aucune dépendance ajoutée au runtime opencode (hooks natifs). Node 20.15.1 présent.

## Contraintes globales

- Style de commits : conventional commits **en français** (`feat(scope): …`).
- Dossiers gitignorés : `_backup_cache/`, `.idea/`, `.worktrees/`. Backups `--force` de propager → HORS de `~/.agents/skills/` (→ `~/.agents/skills_backup/`).
- `propager_skills.sh` reste idempotent. Le dossier `personal-skills` est un MIROIR (toujours écrasé) ; `~/.agents/skills` garde la préservation des curatées + `--force`.
- Le plugin se construit sans dépendance : uniquement `path`, `fs`, `os` (comme `superpowers.js`). Export nommé `PersonalSkillsPlugin` + helpers purs testables.
- Chemin personnel du plugin : `path.join(configDir, 'personal-skills')` avec `configDir = OPENCODE_CONFIG_DIR` si défini, sinon `~/.config/opencode` (même logique que `superpowers.js`).
- Tests unitaires du plugin : fichier `.mjs` ESM lancé via `node --test` (import direct du `.js` ESM du plugin — protégé par `plugin/package.json` `{"type":"module"}`).
- Test loader intégration : `OPENCODE_CONFIG_DIR` temporaire + `HOME` réel (résolution paquet superpowers depuis le cache réel), assertions sur `opencode debug skill`. Pas d'appel modèle.

---

### Task 1 — Mini-plugin `plugin/personal-skills.js` (hooks config + bootstrap)

**Fichiers :**
- Create: `plugin/personal-skills.js`
- Create: `plugin/package.json` (`{"type":"module"}`)
- Test: `tests/plugin-unit.test.mjs`

**Interfaces :**
- Produces : export `PersonalSkillsPlugin` (factory async, contrat opencode), exports purs `extractAndStripFrontmatter(content)`, `buildBootstrapContent(body, toolMapping)`, `readBootstrap(personalDir)`, `applyBootstrap(messages, bootstrap)`.
  - Tests consomment uniquement les exports purs + un hook `config()` appelé sur un objet config factice.

- [ ] **Step 1 : écrire le test unitaire (RED)** — `tests/plugin-unit.test.mjs` :

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import {
  extractAndStripFrontmatter,
  buildBootstrapContent,
  applyBootstrap,
} from '../plugin/personal-skills.js';

test('extractAndStripFrontmatter retire le frontmatter, garde le corps', () => {
  const src = '---\nname: x\n---\nCORPS';
  assert.equal(extractAndStripFrontmatter(src), 'CORPS');
});

test('buildBootstrapContent enveloppe le corps et images le mapping', () => {
  const b = buildBootstrapContent('MARCHEUR', 'OUTILS');
  assert.ok(b.includes('<EXTREMELY_IMPORTANT>'));
  assert.ok(b.includes('MARCHEUR'));
  assert.ok(b.includes('OUTILS'));
});

test('applyBootstrap remplace un bootstrap existant', () => {
  const messages = [{ info: { role: 'user' }, parts: [{ type: 'text', text: 'old EXTREMELY_IMPORTANT x' }] }];
  applyBootstrap(messages, 'NEW');
  assert.ok(messages[0].parts[0].text.includes('NEW'));
});

test('applyBootstrap injecte si aucun bootstrap présent', () => {
  const messages = [{ info: { role: 'user' }, parts: [{ type: 'text', text: 'bonjour' }] }];
  applyBootstrap(messages, 'NEW');
  assert.ok(messages[0].parts[0].text.includes('NEW'));
});
```

- [ ] **Step 2 : vérifier l'échec (RED)** — les imports échouent (`plugin/personal-skills.js` inexistant).

- [ ] **Step 3 : écrire le plugin minimal** — `plugin/personal-skills.js` :

```js
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

export const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return content;
  return match[2];
};

export const buildBootstrapContent = (body, toolMapping) =>
  `<EXTREMELY_IMPORTANT>\n` +
  `You have superpowers.\n\n` +
  `**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "using-superpowers" again - that would be redundant.**\n\n` +
  `${body}\n\n` +
  `${toolMapping}\n` +
  `</EXTREMELY_IMPORTANT>`;

const TOOL_MAPPING = `**Tool Mapping for OpenCode:**
When skills request actions, substitute OpenCode equivalents:
- Create or update todos → \`todowrite\`
- \`Subagent (general-purpose):\` → \`task\` with \`subagent_type: "general"\`
- Invoke a skill → OpenCode's native \`skill\` tool
- Read files → \`read\`
- Create, edit, or delete files → \`apply_patch\`
- Run shell commands → \`bash\`
- Search files → \`grep\`, \`glob\`
- Fetch a URL → \`webfetch\`

Use OpenCode's native \`skill\` tool to list and load skills.`;

export const readBootstrap = (personalDir) => {
  const hub = path.join(personalDir, 'using-superpowers', 'SKILL.md');
  if (!fs.existsSync(hub)) return null;
  const body = extractAndStripFrontmatter(fs.readFileSync(hub, 'utf8'));
  return buildBootstrapContent(body, TOOL_MAPPING);
};

export const applyBootstrap = (messages, bootstrap) => {
  const firstUser = messages.find((m) => m.info && m.info.role === 'user');
  if (!firstUser || !firstUser.parts || !firstUser.parts.length) return;
  const existing = firstUser.parts.find((p) => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'));
  if (existing) { existing.text = bootstrap; return; }
  const ref = firstUser.parts[0];
  firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
};

export const PersonalSkillsPlugin = async () => {
  const configDir = process.env.OPENCODE_CONFIG_DIR
    ? path.resolve(process.env.OPENCODE_CONFIG_DIR.trim())
    : path.join(os.homedir(), '.config', 'opencode');
  const personalSkillsDir = path.join(configDir, 'personal-skills');
  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(personalSkillsDir)) config.skills.paths.push(personalSkillsDir);
    },
    'experimental.chat.messages.transform': async (_input, output) => {
      if (!output.messages || !output.messages.length) return;
      const bootstrap = readBootstrap(personalSkillsDir);
      if (!bootstrap) return;
      applyBootstrap(output.messages, bootstrap);
    },
  };
};
```

- [ ] **Step 4 : vérifier le passage (GREEN)** — `mkdir -p plugin && cp …` puis `node --test tests/plugin-unit.test.mjs` : 4/4 PASS.
- [ ] **Step 5 : harnais bash** `tests/test_plugin.sh` (entrée standard) :

```bash
#!/usr/bin/env bash
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PATCH_DIR"
node --test tests/plugin-unit.test.mjs >/dev/null
echo "test_plugin : OK"
```

- [ ] **Step 6 : commit**

```bash
git add plugin/ tests/test_plugin.sh
git commit -m "feat(plugin): personal-skills.js — hooks config + bootstrap remplacé (variante B)"
```

### Task 2 — Test loader intégration (13 → PERSONAL)

**Fichiers :**
- Create: `tests/test_plugin_loader.sh`

**Interfaces :**
- Consumes : `opencode` dans PATH (1.18.x, plugin superpowers installé dans le cache réel), `plugin/personal-skills.js` (Task 1), dossier `skills/` du dépôt.
- Produces : script auto-contenu qui construit `$TMP/cfg/opencode.jsonc` (plugin superpowers + notre plugin), déploie les 13 dans `$TMP/cfg/personal-skills/`, lance `opencode debug skill` avec `OPENCODE_CONFIG_DIR=$TMP/cfg` (HOME réel), et vérifie que les 13 résolvent vers `personal-skills` (pas le cache).

- [ ] **Step 1 : écrire le test (RED attendu = sans plugin).** Construire le harnais :

```bash
#!/usr/bin/env bash
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

OPENCODE_CONFIG_DIR="$CFG" opencode debug skill > "$TMP/out.json" 2> "$TMP/err.log" || { cat "$TMP/err.log" >&2; exit 1; }

ok=1
for skill in "$PATCH_DIR"/skills/*/; do
  n="$(basename "$skill")"
  if ! grep -q "\"name\": \"${n}\"" "$TMP/out.json"; then
    echo "FAIL: skill ${n} absente de l'inventaire" >&2; ok=0
  elif ! grep -q "${CFG}/personal-skills/${n}" "$TMP/out.json"; then
    echo "FAIL: skill ${n} ne résout pas vers PERSONAL" >&2; ok=0
  fi
done
[ "$ok" -eq 1 ] || exit 1
echo "test_plugin_loader : OK ($(ls "$PATCH_DIR"/skills | wc -l) skills → PERSONAL)"
```

- [ ] **Step 2 : exécuter — vérifier que le test échoue SANS le plugin** (commenter l'entrée plugin perso dans `opencode.jsonc` → le cache gagne). Puis réactiver.
- [ ] **Step 3 : exécuter avec plugin — PASS** (13 → `personal-skills`).
- [ ] **Step 4 : commit**

```bash
git add tests/test_plugin_loader.sh
git commit -m "test(plugin): harnais loader — 13 skills résolvent vers personal-skills (variante B)"
```

### Task 3 — `propager_skills.sh` : deuxième destination `personal-skills`

**Fichiers :**
- Modify: `propager_skills.sh`
- Test: `tests/test_propager.sh` (étendre)

**Interfaces :**
- Consumes : dossier `skills/` du dépôt.
- Produces : (1) `~/.config/opencode/personal-skills/` = miroir complet toujours écrasé ; (2) `~/.agents/skills/` = préservation curatées + `--force <skill>` (comportement actuel conservé).

- [ ] **Step 1 : adapter le test (RED).** Ajouter à `tests/test_propager.sh` la vérification de la destination opencode (HOME temporaire) :

```bash
PERSONAL="$TMP/home/.config/opencode/personal-skills"
[ -f "$PERSONAL/code-refactor/SKILL.md" ] || { echo "FAIL: personal-skills non déployé"; exit 1; }
cmp -s "$PATCH_DIR/skills/code-refactor/SKILL.md" "$PERSONAL/code-refactor/SKILL.md" \
  || { echo "FAIL: personal-skills != patch"; exit 1; }
# ré-exécution : idempotence (miroir ré-écrasé sans erreur)
HOME="$TMP/home" "$PATCH_DIR/propager_skills.sh" >/dev/null
cmp -s "$PATCH_DIR/skills/using-superpowers/SKILL.md" "$PERSONAL/using-superpowers/SKILL.md" \
  || { echo "FAIL: hub personal-skills != patch"; exit 1; }
[ -d "$PERSONAL/using-superpowers/references" ] || { echo "FAIL: references/ non déployées"; exit 1; }
```

- [ ] **Step 2 : vérifier l'échec (RED)** — destination absente actuellement.
- [ ] **Step 3 : modifier `propager_skills.sh`** — après la boucle `~/.agents`, ajouter le miroir opencode (toujours écrasé) :

```bash
PERSONAL_SKILLS="${HOME}/.config/opencode/personal-skills"
mkdir -p "$PERSONAL_SKILLS"
nb_perso=0
for src in "${SCRIPT_DIR}"/skills/*/; do
    [ -d "$src" ] || continue
    skill="$(basename "$src")"
    rm -rf "${PERSONAL_SKILLS}/${skill}"
    cp -r "$src" "${PERSONAL_SKILLS}/${skill}"
    nb_perso=$((nb_perso + 1))
done
echo "Miroir OpenCode : ${nb_perso} skill(s) → ${PERSONAL_SKILLS}/"
```

Mettre à jour l'en-tête du script (nouveau rôle, deux destinations). `--force` reste dédié à `~/.agents/skills/`.

- [ ] **Step 4 : vérifier le passage (GREEN)** — `bash tests/test_propager.sh` : PASS.
- [ ] **Step 5 : commit**

```bash
git add propager_skills.sh tests/test_propager.sh
git commit -m "feat(propager): miroir opencode personal-skills (toujours écrasé) + ~/.agents préservé"
```

### Task 4 — Supprimer `reinjecter.sh`

**Fichiers :**
- Delete: `reinjecter.sh`
- Delete: `tests/test_reinjecter.sh`

**Interfaces :**
- Consumes : rien.
- Produces : le cache plugin n'est plus jamais touché par ce dépôt.

- [ ] **Step 1 : `git rm reinjecter.sh tests/test_reinjecter.sh`**
- [ ] **Step 2 : commit**

```bash
git commit -m "refactor: suppression de reinjecter.sh (cache superpowers jamais ré-injecté — variante B)"
```

### Task 5 — `init-machine.sh` : installer le plugin + déclarer l'ordre

**Fichiers :**
- Modify: `init-machine.sh`

**Interfaces :**
- Consumes : `plugin/personal-skills.js`, `propager_skills.sh`.
- Produces : `~/.config/opencode/plugins/personal-skills.js` créé ; `plugin` array contient superpowers PUIS notre plugin (ordre = victoire du bootstrap personnel) ; reinjecter ne doit plus être appelé.

- [ ] **Step 1 : adapter le script** — après la vérification du plugin superpowers :

```bash
PLUGINS_DIR="${CONFIG_DIR}/plugins"
mkdir -p "$PLUGINS_DIR"
if ! cmp -s "${SCRIPT_DIR}/plugin/personal-skills.js" "${PLUGINS_DIR}/personal-skills.js"; then
    cp "${SCRIPT_DIR}/plugin/personal-skills.js" "${PLUGINS_DIR}/personal-skills.js"
    echo "[OK] Plugin personnel installé : ${PLUGINS_DIR}/personal-skills.js"
fi
```

Puis, dans la config, s'assurer que le tableau `plugin` contient l'entrée superpowers puis `"${PLUGINS_DIR}/personal-skills.js"`. Si le fichier config est JSON pur (`python3` dispo + parse OK), injecter via `python3` (fusion idempotente) ; sinon ACTION MANUELLE comme aujourd'hui (afficher le tableau attendu). Supprimer l'appel à `${SCRIPT_DIR}/reinjecter.sh` ; garder `${SCRIPT_DIR}/propager_skills.sh`. Afficher à la fin : « Redémarre OpenCode (le plugin personnel est chargé au démarrage) ».

- [ ] **Step 2 : vérifier** — `bash -n init-machine.sh` ; tests : `bash tests/test_propager.sh`, `bash tests/test_plugin.sh`, `bash tests/test_plugin_loader.sh` : PASS.
- [ ] **Step 3 : commit**

```bash
git add init-machine.sh
git commit -m "feat(init-machine): install du plugin personnel + déclaration après superpowers"
```

### Task 6 — README : architecture variante B

**Fichiers :**
- Modify: `README.md`

**Interfaces :**
- Consumes : toutes les tasks précédentes (état final : pas de reinjecter, propager 2 destinations, plugin).
- Produces : documentation fidèle — plus aucune mention de ré-injection dans le cache après MAJ ; « Après chaque mise à jour du paquet » = rien à faire pour opencode (le plugin re-pousse le miroir à chaque démarrage) ; nouveau cycle de vie.

- [ ] **Step 1 : réécrire les sections concernées :**
  - « Installation » : init-machine installe les DEUX plugins (superpowers puis personnel) + propager.
  - « Après chaque mise à jour du paquet superpowers » → « Rien à faire : le cache est écrasé, le mini-plugin re-pousse le miroir personnel en dernière position ; la session charge les extensions personnelles. » `~/.agents/skills/` : relancer `./propager_skills.sh` (idempotent).
  - Nouveau « Cycle de vie » : modifier la skill → `./propager_skills.sh` → redémarrer opencode → commit/push.
  - « Deux sources, deux rôles » → trois couches : cache superpowers (amont, intouché), `personal-skills` (miroir chargé par opencode), `~/.agents/skills` (autres harnais). Expliquer la victoire « dernier écrite » et l'ordre du tableau `plugin` (superpowers puis personnel) : pourquoi il gagne.
  - Supprimer les mentions de `_backup_cache/`, `reinjecter.sh`, l'« exception hub » (le hub est désormais toujours la version personnelle pour opencode ; pour `~/.agents`, `--force using-superpowers`).
  - **Vérification de cohérence** : remplacer le triplet cache↔patch par : miroir `personal-skills` ≡ patch (via `cmp`), `~/.agents/skills` peut volontairement différer.

- [ ] **Step 2 : relire le README complet (aucune référence à reinjecter/_backup_cache) — `grep -n 'reinjecter\|_backup_cache' README.md` → 0 résultat.**
- [ ] **Step 3 : commit**

```bash
git add README.md
git commit -m "docs: README variante B — plugin personnel, pas de ré-injection, trois couches"
```

---

## Vérification finale

1. `bash tests/test_reinjecter.sh` → FICHIER SUPPRIMÉ (doit être absent — `git status` propre).
2. `bash tests/test_propager.sh`, `bash tests/test_plugin.sh`, `bash tests/test_plugin_loader.sh` : PASS.
3. `git log --oneline -8` : 6 commits (plugin, loader, propager, suppression, init-machine, docs).
4. Machine réelle (hors dépôt) : installer le plugin, mettre à jour `opencode.jsonc` (ordre), lancer `./propager_skills.sh`, vérifier `opencode debug skill` → 13 → `personal-skills`.