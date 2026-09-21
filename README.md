# Patches de skills superpowers — règles « racine d'abord »

## Pourquoi

Le 22/08/2026, un bug d'affichage (« Mensualité 11 » au lieu du nom du mois) a d'abord
été « corrigé » par un formatter dans l'UI — masquant une donnée faussée à la source
au lieu de la réparer. La vraie correction (générateur unique + migration idempotente
des lignes existantes + seeds alignés) est venue ensuite.

Ces patches injectent la règle **dans les skills elles-mêmes** pour qu'elle s'applique
à chaque session, sans dépendre du hasard :

| Skill | Insertions |
|---|---|
| `systematic-debugging/SKILL.md` | Phase 1 : nouvel item « 6. Trace Displayed/Stored Data To Its Producer » (trouver le producteur avant tout fix ; interdiction de compenser en aval ; les 3 volets du vrai fix + cas d'école « Mensualité 11 »). Phase 4 : « root cause = producteur de la donnée, migration incluse ». Red Flags : ligne « it's just a display issue ». Rationalizations : ligne « downstream formatter ». |
| `brainstorming/SKILL.md` | Chemin Bounded, étape 1 : tracer l'origine d'une valeur erronée avant tout design qui la transformerait en aval. |

### Skills suivies/patchées par ce dépôt

**Constat du 21/09/2026 : les 13 skills suivies existent désormais dans le paquet
upstream → elles sont « patchées ». La branche « ajout » (skill absente upstream)
reste gérée par `reinjecter.sh` si le paquet upstream rétrécit.**

À l'origine (23/08/2026), elles étaient **ajoutées** : le script copiait le dossier
entier quand la skill n'existait pas dans le cache. Source : bibliothèque
`/media/Nak/6BF6-E97C/multiagent/skills`, retravaillées selon la méthodologie
`writing-skills` (frontmatter correct, triggers précis, outils désignés par
capacités et non par providers, chemins génériques).

Depuis qu'elles existent toutes upstream, `reinjecter.sh` les **patche** à la place
(présente upstream → patch du SKILL.md + annexes ; absente → ajout complet du
dossier) : les deux branches restent prises en charge par le même script.

| Skill suivie | Apport | Origine |
|---|---|---|
| `ui-governance/SKILL.md` | Réutilisation obligatoire des composants/tokens UI existants avant toute création ; zéro style codé en dur | Skill personnelle (`ui-governance.md` sans SKILL.md → ne chargeait jamais) ; réécrite |
| `resolve-ambiguity/SKILL.md` | Protocole de résolution d'ambiguïté : discovery → triage blocking/deferrable → questions compactes avec défauts | Adoptée quasi telle quelle (qualité déjà au niveau writing-skills) |
| `simplification/SKILL.md` | Nettoyage tactique + cascades d'élimination conceptuelle ; VCS plutôt que .bak ; diagnostics IDE d'abord | Améliorée depuis la source Kilo Code |
| `code-refactor/SKILL.md` | Refactoring universel ; découverte par capacités sémantiques (search_symbol → call hierarchy → fallback texte), rename sémantique obligatoire, règle « un producteur par donnée dérivée » | Réécrite (la source était grep-centrée, aveugle aux alias) |
| `learning/SKILL.md` | Base de connaissances persistante `{repo}/docs/learnings/` : find / evaluate (tiers) / draft / micro-approval / maintenance JIT | Généralisée (chemins Kilo retirés) |
| `modularization/SKILL.md` | Restructuration monolithique → modulaire (`src/` pur, `ops/`, `data/` gitignoré, `extensions/`, `tests/` unit/integration/fixtures) ; 4 phases à **Gateways** de validation utilisateur obligatoires, `git mv` pour l'historique, config dynamique + isolation de test | Réécrite en anglais (la source FR avait un frontmatter absent et des commandes provider-spécifiques) |

**Note de chargement** : les skills patchées/ajoutées n'apparaissent dans une session
OpenCode qu'après redémarrage (l'inventaire est établi au démarrage).

## Installation — deux scripts, deux niveaux

Ce dépôt est **autonome** : il ne patche que le cache du paquet, jamais de
chemin machine en dur. Workflow complet :

### 1. Nouvelle machine — `./init-machine.sh` (UNE fois)

```bash
git clone https://github.com/Userdebug/superpowers-patches.git
cd superpowers-patches
./init-machine.sh
# → déclare le plugin superpowers dans ~/.config/opencode/opencode.jsonc
#   (opencode le télécharge au prochain démarrage) puis lance reinjecter.sh
```

Redémarrer OpenCode : les skills patchées/ajoutées et le hub STEP 0 sont
alors **automatiquement actifs dans tous les projets** de la machine.

Après chaque mise à jour du paquet superpowers (cache écrasé), relancer
`./reinjecter.sh` — idempotent, backups horodatés automatiques.

### 2. Chaque projet — `./init-project.sh` (UNE fois par projet)

```bash
./init-project.sh /chemin/du/projet
```

Installe le triptyque qui persiste l'état des outils par projet, à l'abri
de `/init` :

| Élément | Destination | Rôle |
|---|---|---|
| commande `/capacites` | `.opencode/commands/capacites.md` | sonde live + régénère l'état |
| dossier d'état | `.opencode/instructions/` | reçoit `capacites-outils.md` |
| branchement | `opencode.json` (`"instructions"`, fusion idempotente) | charge l'état dans chaque session |

Ensuite dans OpenCode : `/capacites`, puis committer `opencode.json` + `.opencode/`.

Sans cette étape, le patch reste actif mais rien n'est persisté : chaque
session re-sonde depuis zéro. Règle : l'état des outils ne vit JAMAIS dans
AGENTS.md (réécrit par `/init`) — uniquement dans ce fichier dédié, avec les
faits datés en plus dans AGENTS.md.

## Après chaque mise à jour du paquet superpowers

Les fichiers du cache (`~/.cache/opencode/packages/superpowers@*/...`) sont écrasés
lors des mises à jour. Relancer :

```bash
./reinjecter.sh
./propager_skills.sh                                         # skills absentes de ~/.agents/skills/
cp skills/using-superpowers/SKILL.md ~/.agents/skills/using-superpowers/SKILL.md
cp skills/using-superpowers/references/opencode.md ~/.agents/skills/using-superpowers/references/opencode.md
```

Le script détecte automatiquement toutes les versions installées, sauvegarde l'état
courant dans `_backup_cache/<horodatage>/` puis applique les patches. Depuis la version
actuelle, il synchronise **toutes les annexes** des skills patchées — le dossier
`references/` (ex. `using-superpowers/references/opencode.md`,
`pre-deploy/references/build-matrix.md`) **et** les annexes racines des dossiers skills
(ex. `security-review/cloud-infrastructure-security.md`). Idempotent.

**Exception hub :** `using-superpowers` doit toujours suivre le patch. Sa copie
dans `~/.agents/skills/` (servant les AUTRES harnais — Claude Code, Cursor…) est
donc resynchronisée à la MAIN via les `cp` ci-dessous après chaque retouche du
hub — la session opencode, elle, charge le hub depuis le cache plugin comme les
autres skills. Les autres skills présentes dans `~/.agents/skills/` restent
préservées par `propager_skills.sh`.

Si une mise à jour upstream restructure un fichier (skill renommée, etc.), le script
avertit et ignore ce fichier : mettre à jour alors manuellement le patch ici.

## Pilotage générique d'OpenCode — le hub et sa référence de plateforme

Le but est de **piloter OpenCode depuis ses sources de pilotage** de façon
**générique** : la config injectée ne doit rien connaître du projet courant.
Elle s'applique à tout harnais opencode — CLI/TUI, extension VS Code (config
réinjectée telle quelle), JetBrains via le pont `pycharm_*` — bref, partout où
opencode démarre avec ces sources.

### Les sources de pilotage (hiérarchie)

1. **`using-superpowers/SKILL.md` (le hub)** — racine du pilotage, chargé à
   chaque session : règle d'invocation, priorités de skills, « STEP 0 » de
   découverte des capacités, mapping sémantique fournisseur-agnostique.
2. **`using-superpowers/references/opencode.md`** — fiche plateforme : carte
   des outils natifs (`todowrite`/`task`/`skill`/`edit`/…), conventions subagents,
   providers sémantiques (JetBrains / VS Code LSP / mode CLI natif), règles git.
3. **Les autres SKILL.md patchées/ajoutées** — implémentations, invoquées via le
   déclencheur du hub ou leur `description` (`<available_skills>`).
4. **`AGENTS.md` / instructions projet** — projet uniquement, jamais injectées
   ici ; elles *supplantent* les skills si conflit.

### Sept 2026 — mise aux normes « pilotes » (ce commit)

| Correctif | Quoi | Pourquoi |
|---|---|---|
| Priorités hub | Déclencheurs génériques pour `resolve-ambiguity`, `dispatching-parallel-agents`, `simplification`, `learning`, `pre-deploy`, `coding-standards`, `security-review` | Ces skills n'étaient référencées nulle part (seul le mécanisme 2 `<available_skills>` les exposait). Le hub ne listait explicitement que brainstorming / systematic-debugging / using-git-worktrees. |
| `references/opencode.md` | Fiche outillage native OpenCode, ajoutée à `using-superpowers/references/` + entrée « OpenCode (CLI, TUI, VSCode extension) » dans « Platform Adaptation » du hub | Le hub disait « if your harness appears here, read its reference file » sans fichier pour OpenCode (codex.md / pi-tools.md / antigravity-tools.md / hermes-tools.md seuls). |
| `reinjecter.sh` | Synchronise **désormais toutes les annexes** (`references/` + annexes racines) des skills patchées | `pre-deploy/references/build-matrix.md` n'était jamais déployé ; idem pour l'opencode.md du hub. |
| `propager_skills.sh` + README | Exception **hub** documentée : `using-superpowers` doit suivre le patch → resync manuelle des cp vers `~/.agents/skills/` | `propager_skills.sh` ne copie que les skills ABSENTES (jamais d'écrasement des curatées), or le hub doit être à jour partout. |

**Vérification de cohérence** (triplet) : après réinjection, comparer que
`superpowers-patches/skills/<nom>` et le cache plugin contiennent la même version
du SKILL.md *et* des annexes `references/` : `cmp -s fichier1 fichier2`.
⚠️ `~/.agents/skills/<nom>` peut elle volontairement différer du patch pour les
skills curatées (sauf si `--force` a été utilisé) — l'égalité du triplet ne
vaut donc que pour cache plugin ↔ patch.

### Cycle de vie d'une amélioration de pilotage

```
1. Modifier le patch : superpowers-patches/skills/<nom>/SKILL.md (+ references/ au besoin)
2. ./reinjecter.sh                      → cache plugin (backup horodaté avant écrasement)
3. ./propager_skills.sh                 → skills absentes de ~/.agents/skills/
4. SI le hub a changé : cp manuel       → ~/.agents/skills/using-superpowers/ (exception)
5. Commiter + pousser ici               → disponible sur la prochaine machine/VSCode
6. Redémarrer opencode                  → inventaire des skills reconstruit
```

## Deux sources, deux rôles (important)

- **Cache plugin `~/.cache/opencode/packages/superpowers@*/node_modules/superpowers/skills/`**
  — reconstruit/écrasé par OpenCode à chaque mise à jour du paquet. C'est la source
  **réellement chargée par la session** OpenCode. `reinjecter.sh` le ré-aligne à
  l'identique du patch (SKILL.md + toutes les annexes).
- **`~/.agents/skills/`** — versions **curatées** (retravaillées) pour les **autres
  harnais** (Claude Code, Cursor, etc.). Par défaut, rien ne les écrase — seule une
  dérogation explicite (`propager_skills.sh --force`) resynchronise une curatée.

`propager_skills.sh` fait le pont vers `~/.agents/skills/` : il copie les skills
**absentes** de `superpowers-patches/skills/` vers `~/.agents/skills/`, **sans jamais
écraser** une skill curatée existante (elle est préservée). Il est appelé automatiquement
par `init-machine.sh` et peut être relancé manuellement si besoin.

### `--force` : resynchroniser une skill curatée

```bash
./propager_skills.sh --force <skill>
```

Resynchronise UNE skill curatée depuis le patch. Avant écrasement, la version curatée
est d'abord sauvegardée dans `~/.agents/skills_backup/<horodatage>/<skill>/` (hors de
`~/.agents/skills/`, pour n'être jamais scannée comme skill). **Restauration :** recopier
le contenu voulu depuis ce backup vers `~/.agents/skills/<skill>/`. Si `<skill>` est
absente du dossier `skills/` du patch, la commande émet un AVERTISSEMENT sur stderr et
sort en 0 (rien à faire).

## Restauration

Chaque réinjection sauvegarde la version écrasée. Pour revenir en arrière, copier
le contenu voulu depuis `_backup_cache/<horodatage>/<skill>/SKILL.md` vers le cache.
