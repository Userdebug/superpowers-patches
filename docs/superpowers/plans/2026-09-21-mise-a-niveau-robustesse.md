# Mise à niveau robustesse + exactitude doc — Plan d'implémentation

> **Pour les workers agentiques :** skills requises — `subagent-driven-development` (recommandé) ou `executing-plans`. Étapes en checkboxes `- [ ]`.

**Goal :** corriger les 4 écarts vérifiés (doc du chargement inexacte, curatées `~/.agents/skills/` périmées, faille des annexes racines dans `reinjecter.sh`, tableau README obsolète) avec harnais de tests.

**Architecture :** `reinjecter.sh` sync toute annexe du dossier patch (pas seulement `references/`) ; `propager_skills.sh` reçoit `--force <skill>` (backup avant écrasement) pour resynchroniser les curatées hors cache ; README reflète la réalité opencode (source de chargement = cache plugin) ; deux harnais bash à HOME temporaire prouvent les comportements sans toucher le système réel.

**Tech Stack :** bash (`set -euo pipefail`), `cmp`/`cp -r`/`mktemp` — pas de dépendances externes.

**Spec :** constat d'analyse (CE-001 → CE-004) — voir conversation ; ce plan argumente depuis ce constat.
- CE-001 : README affirme que la session charge `~/.agents/skills/`, or opencode charge le cache plugin (`node_modules/superpowers/skills/`).
- CE-002 : curatées `~/.agents/skills/ui-governance` et `code-refactor` périmées vs patch (jamais écrasées par défaut).
- CE-003 : `reinjecter.sh` ne sync que `SKILL.md` + `references/` des skills présentes upstream → annexe racine (`security-review/cloud-infrastructure-security.md`) ne suivrait plus le patch.
- CE-004 : tableau README « skills ajoutées » obsolète (les 13 existent désormais upstream).

## Contraintes globales

- Style de commits du repo : conventional commits **en français** (`fix(scope): …`).
- Dossiers gitignorés : `_backup_cache/`, `.idea/`, `.worktrees/`. Les backups de propager vont HORS de `~/.agents/skills/` (→ `~/.agents/skills_backup/`) pour ne jamais être scannés comme skill.
- `reinjecter.sh` et `propager_skills.sh` restent idempotents.
- Aucune dépendance supplémentaire ; tests lancés via `bash <script>`.
- Tout chemin du système (cache plugin, `~/.agents/skills/`) est révélé par `$HOME` au runtime ; les harnais de test n'y touchent jamais (HOME temporaire).

---

### Task 1 — `reinjecter.sh` : synchroniser toutes les annexes des skills présentes upstream

**Fichier :**
- Modify: `reinjecter.sh:60-72`

**Interfaces :**
- Consumes : structure du dossier patch `skills/<nom>/` (SKILL.md, annexes racine, `references/`).
- Produces : pour toute skill présente upstream, le dossier cache plugin `.../skills/<nom>/` contient SKILL.md + TOUTES les annexes identiques au patch, avec backups horodatés.

- [ ] **Step 1 : remplacer le bloc « Fichiers annexes »** (boucle `references/`) par une synchronisation générique de toute entrée du dossier patch (hors `SKILL.md`), avec backup de l'existant :

```bash
# Annexes root (ex. security-review/cloud-infrastructure-security.md) + references/
for annexe in "${skill_dir}"/*; do
    [ -e "$annexe" ] || continue
    nom="$(basename "$annexe")"
    [ "$nom" = "SKILL.md" ] && continue
    dest_annexe="${cible}/skills/${skill}/${nom}"
    if [ -e "$dest_annexe" ]; then
        rm -rf "${backup_dir}/${nom}"
        cp -r "$dest_annexe" "${backup_dir}/"
    fi
    rm -rf "$dest_annexe"
    cp -r "$annexe" "$dest_annexe"
    nb_fichiers=$((nb_fichiers + 1))
    echo "  ${skill}/${nom} : synchronisé"
done
```

- [ ] **Step 2 : preuve de non-régression** — `bash -n reinjecter.sh` + `bash tests/test_reinjecter.sh` : PASS.
- [ ] **Step 3 : commit**

```bash
git add reinjecter.sh
git commit -m "fix(reinjecter): synchronise toutes les annexes des skills patchées (root + references/)"
```

### Task 2 — Harnais de test `tests/test_reinjecter.sh`

**Fichier :**
- Create: `tests/test_reinjecter.sh`

**Interfaces :**
- Consumes : `reinjecter.sh` fixé par Task 1 (annexes racine synchronisées), dossier patch `skills/` du repo.
- Produces : script executable `bash tests/test_reinjecter.sh` → « test_reinjecter : OK » si tous les `cmp` et checks passent, sinon exit 1 avec message.

- [ ] **Step 1 : écrire le harnais** (HOME temporaire, aucune écriture réelle — teste le bug CE-003 : annexe racine non synchronisée) :

```bash
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
```

- [ ] **Step 2 : vérifier le rouge avant le fix** — constat documentaire : sur le `reinjecter.sh` non modifié (boucle `references/` uniquement), la ligne « FAIL: annexe racine non synchronisée (CE-003) » se produit. Ne PAS revenir en arrière sur le fix : l'ordre Task 1 → Task 2 garantit qu'on ne teste jamais l'ancien code.
- [ ] **Step 3 : vérifier le vert après Task 1** — `bash tests/test_reinjecter.sh` : « test_reinjecter : OK ».
- [ ] **Step 4 : commit**

```bash
git add tests/test_reinjecter.sh
git commit -m "test(reinjecter): harnais d'intégration HOME temporaire (annexes root, backup, idempotence)"
```

### Task 3 — `propager_skills.sh` : option `--force <skill>` avec backup

**Fichier :**
- Modify: `propager_skills.sh` (parser d'arguments + boucle)
- Create: `tests/test_propager.sh`

**Interfaces :**
- Consumes : dossier patch `skills/<nom>/` ; `$HOME/.agents/skills/` (curatées) ; usage `propager_skills.sh [--force <skill>]`.
- Produces : option `--force <skill>` (sans force : comportement inchangé, curatée jamais écrasée ; avec force : backup dans `$HOME/.agents/skills_backup/<horodatage>/<skill>/` puis re-copie du patch, et avertissement si la skill demandée n'est pas dans le patch).

- [ ] **Step 1 : parser `--force <skill>`** en tête (après `set -euo pipefail`, avant l'usage du script) :

```bash
FORCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE="${2:-}"; shift 2 ;;
        *) echo "usage: $0 [--force <skill>]" >&2; exit 1 ;;
    esac
done
```

- [ ] **Step 2 : modifier la boucle** — filtrer sur `$FORCE` si fourni ; si `dest/SKILL.md` existe **et** `--force` : sauvegarder la curatée dans `~/.agents/skills_backup/<horodatage>/<skill>/`, `rm -rf` puis re-copier depuis le patch ; sinon (défaut) comportement conservé « jamais écrasé » :

```bash
for src in "${SCRIPT_DIR}"/skills/*/SKILL.md; do
    [ -e "$src" ] || continue
    skill=$(basename "$(dirname "$src")")
    if [ -n "$FORCE" ] && [ "$skill" != "$FORCE" ]; then
        continue
    fi
    dest="${AGENTS_SKILLS}/${skill}"
    if [ -f "${dest}/SKILL.md" ]; then
        if [ -n "$FORCE" ]; then
            bkp="${HOME}/.agents/skills_backup/$(date +%Y%m%d-%H%M%S)/${skill}"
            mkdir -p "$bkp"
            cp -r "${dest}"/. "$bkp/"
            rm -rf "$dest"
            cp -r "$(dirname "$src")"/. "$dest/"
            echo "  ${skill}/ : FORCÉE (curatée → ${bkp})"
            nb=$((nb + 1))
        else
            echo "  ${skill}/ : déjà présent (curaté, ignoré — non écrasé)"
            continue
        fi
    else
        mkdir -p "$dest"
        cp -r "$(dirname "$src")"/. "$dest/"
        echo "  ${skill}/ : copiée vers ${dest}"
        nb=$((nb + 1))
    fi
done

if [ -n "$FORCE" ] && [ "$nb" -eq 0 ]; then
    echo "AVERTISSEMENT : skill « ${FORCE} » introuvable dans ${SCRIPT_DIR}/skills/." >&2
fi
```

- [ ] **Step 3 : harnais `tests/test_propager.sh`** (même patron HOME temporaire que Task 2) :

```bash
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

# (b) Avec --force : curatée = patch + backup créé
HOME="$TMP/home" "$PATCH_DIR/propager_skills.sh" --force code-refactor >/dev/null
cmp -s "$PATCH_DIR/skills/code-refactor/SKILL.md" "$AGENTS/code-refactor/SKILL.md" \
  || { echo "FAIL: curatée != patch après --force"; exit 1; }
bkp="$(ls -d "$TMP"/home/.agents/skills_backup/*/code-refactor 2>/dev/null | head -1)"
[ -n "$bkp" ] || { echo "FAIL: backup skills_backup manquant"; exit 1; }
[ "$(cat "$bkp/SKILL.md")" = "OLD-CURATED" ] \
  || { echo "FAIL: backup ne contient pas l'ancienne curatée"; exit 1; }

echo "test_propager : OK"
```

- [ ] **Step 4 : preuve** — `bash -n propager_skills.sh && bash tests/test_propager.sh` : « test_propager : OK ».
- [ ] **Step 5 : commit**

```bash
git add propager_skills.sh tests/test_propager.sh
git commit -m "feat(propager): option --force <skill> avec backup curatée (skills_backup)"
```

### Task 4 — Resynchroniser les curatées `ui-governance` et `code-refactor`

**Action système (hors repo), manuelle documentée.**

**Interfaces :**
- Consumes : `propager_skills.sh --force` (Task 3), dossier patch `skills/`.
- Produces : `~/.agents/skills/{ui-governance,code-refactor}/SKILL.md` = patch ; backups dans `~/.agents/skills_backup/<horodatage>/`.

- [ ] **Step 1 : exécuter la resynchronisation forcée** :

```bash
./propager_skills.sh --force ui-governance
./propager_skills.sh --force code-refactor
```

- [ ] **Step 2 : prouver l'alignement** — `cmp -s skills/<nom>/SKILL.md ~/.agents/skills/<nom>/SKILL.md` pour `ui-governance` puis `code-refactor` → exit 0 aux deux.
- [ ] **Step 3 : notifier** — l'inventaire des skills se reconstruit au démarrage d'opencode ; les versions curatées ne sont actives qu'après redémarrage. (Rapport : signaler B à l'utilisateur final.)

### Task 5 — README : exactitude du chargement, tableau skills, `--force`

**Fichier :**
- Modify: `README.md`

**Interfaces :**
- Consumes : état réel vérifié (chargement depuis le cache plugin), comportements de Task 1 (`reinjecter.sh` sync toutes les annexes) et Task 3 (`propager --force`, backups `~/.agents/skills_backup/`).
- Produces : README exact (source de chargement, tableau, restauration).

- [ ] **Step 1 — écart CE-001** : réécrire la section « Deux sources, deux rôles » — OpenCode charge les skills du **cache plugin** (`~/.cache/opencode/packages/superpowers@*/node_modules/superpowers/skills/`), aligné par `reinjecter.sh` ; `~/.agents/skills/` héberge les versions curatées pour les autres harnais (jamais écrasées par défaut).
- [ ] **Step 2 — écart CE-004** : retitrer le tableau « Skills ajoutées » → « Skills suivies/patchées par ce dépôt », dater le constat (« à cette date, les 13 existent dans le paquet upstream »), préciser que `reinjecter.sh` gère les deux cas (présente→patch / absente→ajout), et que la sync porte désormais sur **toutes** les annexes (Task 1). Mettre à jour le bloc « Après chaque mise à jour » (lignes de maintenance) en conséquence.
- [ ] **Step 3** : documenter `propager_skills.sh --force <skill>` + l'emplacement des backups `~/.agents/skills_backup/` et la restauration associée.
- [ ] **Step 4 : commit**

```bash
git add README.md
git commit -m "docs: source de chargement opencode (cache plugin), tableau skills, propager --force"
```

### Task 6 — Vérification finale + plan documenté

**Fichier :**
- Create: `docs/superpowers/plans/2026-09-21-mise-a-niveau-robustesse.md` (ce plan, déjà écrit)

**Interfaces :**
- Consumes : toutes les tasks précédentes ; le plan documenté.
- Produces : branche vérifiée (tests verts, scripts valides, cache réel injecté) + plan committé.

- [ ] **Step 1 : re-run réel `./reinjecter.sh`** (workflow documenté) — sortie propre (aucune « ERREUR »), backups créés dans `_backup_cache/`.
- [ ] **Step 2 : tests** — `bash tests/test_reinjecter.sh && bash tests/test_propager.sh` : OK ×2 ; `bash -n` sur les 3 scripts modifiés (`reinjecter.sh`, `propager_skills.sh`, et `init-machine.sh`/`init-project.sh` inchangés).
- [ ] **Step 3 : commit du plan** :

```bash
git add docs/superpowers/plans/2026-09-21-mise-a-niveau-robustesse.md
git commit -m "docs(plans): mise à niveau robustesse + exactitude doc"
```