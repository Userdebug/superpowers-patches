# Patches de skills superpowers — extensions personnelles « racine d'abord »

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

### Skills suivies par ce dépôt

**Constat du 21/09/2026 : les 13 skills suivies existent dans le paquet upstream et
sont ici des EXTENSIONS PERSONNELLES curatées.** Elles ne sont plus « patchées dans le
cache » : depuis la variante B, elles sont **chargées par opencode depuis le miroir
personnel** (voir « Architecture »), qui gagne sur le cache upstream via le loader.

À l'origine (23/08/2026), elles étaient **ajoutées** : le script copiait le dossier
entier quand la skill n'existait pas dans le cache. Source : bibliothèque
`/media/Nak/6BF6-E97C/multiagent/skills`, retravaillées selon la méthodologie
`writing-skills` (frontmatter correct, triggers précis, outils désignés par
capacités et non par providers, chemins génériques).

| Skill suivie | Apport | Origine |
|---|---|---|
| `ui-governance/SKILL.md` | Réutilisation obligatoire des composants/tokens UI existants avant toute création ; zéro style codé en dur | Skill personnelle (`ui-governance.md` sans SKILL.md → ne chargeait jamais) ; réécrite |
| `resolve-ambiguity/SKILL.md` | Protocole de résolution d'ambiguïté : discovery → triage blocking/deferrable → questions compactes avec défauts | Adoptée quasi telle quelle (qualité déjà au niveau writing-skills) |
| `simplification/SKILL.md` | Nettoyage tactique + cascades d'élimination conceptuelle ; VCS plutôt que .bak ; diagnostics IDE d'abord | Améliorée depuis la source Kilo Code |
| `code-refactor/SKILL.md` | Refactoring universel ; découverte par capacités sémantiques (search_symbol → call hierarchy → fallback texte), rename sémantique obligatoire, règle « un producteur par donnée dérivée » | Réécrite (la source était grep-centrée, aveugle aux alias) |
| `learning/SKILL.md` | Base de connaissances persistante `{repo}/docs/learnings/` : find / evaluate (tiers) / draft / micro-approval / maintenance JIT | Généralisée (chemins Kilo retirés) |
| `modularization/SKILL.md` | Restructuration monolithique → modulaire (`src/` pur, `ops/`, `data/` gitignoré, `extensions/`, `tests/` unit/integration/fixtures) ; 4 phases à **Gateways** de validation utilisateur obligatoires, `git mv` pour l'historique, config dynamique + isolation de test | Réécrite en anglais (la source FR avait un frontmatter absent et des commandes provider-spécifiques) |

**Note de chargement** : les skills du miroir personnel n'apparaissent dans une session
OpenCode qu'après redémarrage (l'inventaire est établi au démarrage).

## Architecture — trois couches, aucune ré-injection

**Le cache du paquet superpowers n'est JAMAIS modifié par ce dépôt.** Un mini-plugin
personnel tire les extensions du miroir, qui gagne sur le cache — et une mise à jour du
paquet upstream n'exige donc plus aucune ré-injection.

Le loader opencode est « dernier écrit gagne ». `superpowers.js` pousse le dossier de
skills du cache en DERNIÈRE position de `skills.paths` (hook `config()`), donc le cache
gagne n'importe quel dossier scanné avant. Notre mini-plugin, déclaré **après**
superpowers dans le tableau `plugin` d'`opencode.json(c)`, pousse le miroir personnel
**encore après** → les 13 collisions se résolvent vers la version PERSONNELLE
(vérifié : `opencode debug skill`).

| Couche | Rôle | Écrasée par |
|---|---|---|
| Cache `~/.cache/opencode/packages/superpowers@*/node_modules/superpowers/skills/` | Skills upstream amont | opencode à chaque mise à jour du paquet. **Intouchée par ce dépôt.** |
| Miroir `~/.config/opencode/personal-skills/` | Source chargée par la session OpenCode (13 skills + hub `using-superpowers` curatés) | `propager_skills.sh` (toujours écrasé = fidèle au patch) |
| `~/.agents/skills/` | AUTRES harnais (Claude Code, Cursor, …) — versions curatées | jamais, sauf `--force <skill>` |

**Le bootstrap de session** (le bloc `<EXTREMELY_IMPORTANT>`“You have superpowers”)
est injecté par `superpowers.js` depuis SON cache ; notre plugin `personal-skills.js`
tourne après et **remplace ce texte** par la version du hub miroir (`using-superpowers`).
Même ordre de victoire : les deux hooks suivent l'ordre du tableau `plugin`.

### Le mini-plugin `plugin/personal-skills.js`

Installé à `~/.config/opencode/plugins/personal-skills.js` (par `init-machine.sh`),
déclaré APRÈS `superpowers@git+…` dans `"plugin"`. Deux hooks :

1. `config()` — ajoute `~/.config/opencode/personal-skills` en **dernière** position
   de `config.skills.paths` (après le cache poussé par superpowers).
2. `experimental.chat.messages.transform` — remplace le bootstrap injecté par le
   texte personnel lu depuis `personal-skills/using-superpowers/SKILL.md` (ou injecte
   son propre texte si `EXTREMELY_IMPORTANT` est absent du premier message).

Tests : `tests/plugin-unit.test.mjs` (unitaires Node), `tests/test_plugin_loader.sh`
(intégration loader : 13 → miroir). Le plugin est sans dépendance (`path`/`fs`/`os`).

## Installation — init-machine + init-project

Ce dépôt est **autonome** : il ne patche jamais le cache du paquet, aucun chemin
machine en dur dans le code versionné. Workflow complet :

### 1. Nouvelle machine — `./init-machine.sh` (UNE fois)

```bash
git clone https://github.com/Userdebug/superpowers-patches.git
cd superpowers-patches
./init-machine.sh
# → déclare le plugin superpowers dans ~/.config/opencode/opencode.json(c)
#   + installe notre mini-plugin personnel APRÈS + lance propager_skills.sh
```

`init-machine.sh` fait trois choses :
1. s'assure que `superpowers@git+…` est déclaré ;
2. copie `plugin/personal-skills.js` vers `~/.config/opencode/plugins/` et l'ajoute
   DANS le tableau `"plugin"`, APRÈS superpowers (JSON strict injecté par python3,
   sinon ACTION MANUELLE affichée) ;
3. lance `propager_skills.sh` (miroir opencode + `~/.agents/skills/`).

Redémarrer OpenCode : les 13 extensions et le hub personnel sont alors
**automatiquement actifs** (le cache du paquet reste intouché).

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

**Rien à faire pour la session OpenCode** : la mise à jour écrase le cache du paquet,
mais le mini-plugin personnel re-pousse le miroir en dernière position à chaque
démarrage → les 13 extensions + le hub restent en vigueur, inchangés.

```bash
./propager_skills.sh   # OBLIGATOIRE seulement si le miroir/agents est incomplet
```

- **Miroir opencode** `~/.config/opencode/personal-skills/` : toujours écrasé,
  fidèle au patch. Modifier une skill = éditer `skills/<nom>/SKILL.md` + relancer
  `./propager_skills.sh` + redémarrer opencode.
- **`~/.agents/skills/`** : les skills déjà présentes (curatées) ne sont jamais
  écrasées ; `./propager_skills.sh --force <skill>` resynchronise avec backup
  (`~/.agents/skills_backup/<horodatage>/`). Le hub `using-superpowers` suit le
  patch : lancer `./propager_skills.sh --force using-superpowers` après toute
  retouche du hub.

**Vérification de cohérence** : le miroir `personal-skills/` doit être identique au
patch — `cmp` entre `skills/<nom>` et `~/.config/opencode/personal-skills/<nom>`
(SKILL.md + annexes `references/`). `~/.agents/skills/<nom>` peut volontairement
différer du patch pour les curatées (sauf après `--force`).

## Pilotage générique d'OpenCode — le hub et sa référence de plateforme

Le but est de **piloter OpenCode depuis ses sources de pilotage** de façon
**générique** : la config injectée ne doit rien connaître du projet courant.
Elle s'applique à tout harnais opencode — CLI/TUI, extension VS Code (config
réinjectée telle quelle), JetBrains via le pont `pycharm_*` — bref, partout où
opencode démarre avec ces sources.

### Les sources de pilotage (hiérarchie)

1. **`using-superpowers/SKILL.md` (le hub)** — racine du pilotage, chargé à
   chaque session (version PERSONNELLE depuis le miroir) : règle d'invocation,
   priorités de skills, « STEP 0 » de découverte des capacités, mapping sémantique
   fournisseur-agnostique.
2. **`using-superpowers/references/opencode.md`** — fiche plateforme : carte
   des outils natifs (`todowrite`/`task`/`skill`/`edit`/…), conventions subagents,
   providers sémantiques (JetBrains / VS Code LSP / mode CLI natif), règles git.
3. **Les autres SKILL.md du miroir** — implémentations, invoquées via le
   déclencheur du hub ou leur `description` (`<available_skills>`).
4. **`AGENTS.md` / instructions projet** — projet uniquement, jamais injectées
   ici ; elles *supplantent* les skills si conflit.

### 21/09/2026 — variante B : extensions séparées du cache

Le cache des skills upstream n'est plus jamais ré-injecté (script de ré-injection dans
le cache supprimé le 21/09/2026).
Une mise à jour du paquet superpowers, qui écrase le cache, n'affecte plus nos 13
extensions : le mini-plugin personnel pousse le miroir en dernière position.

### Cycle de vie d'une amélioration de pilotage

```
1. Modifier le patch : superpowers-patches/skills/<nom>/SKILL.md (+ references/ au besoin)
2. ./propager_skills.sh                 → miroir opencode + skills absentes de ~/.agents/skills/
3. SI le hub a changé : ./propager_skills.sh --force using-superpowers  → ~/.agents/skills/ (autres harnais)
4. Commiter + pousser ici               → disponible sur la prochaine machine/VSCode
5. Redémarrer opencode                  → inventaire des skills reconstruit
```

## Restauration

Le cache du paquet n'est pas touché (rien à restaurer). Pour revenir en arrière
sur une skill : éditer `skills/<nom>/` puis relancer `./propager_skills.sh`.
Pour restaurer une curatée `~/.agents/skills/` écrasée par `--force` : recopier
le contenu voulu depuis `~/.agents/skills_backup/<horodatage>/<skill>/` vers
`~/.agents/skills/<skill>/`.