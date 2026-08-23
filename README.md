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

### Skills ajoutées (absentes du paquet upstream)

Depuis le 23/08/2026, le script **ajoute** aussi des skills personnelles
complètes (copie du dossier entier quand la skill n'existe pas dans le cache).
Source : bibliothèque `/media/Nak/6BF6-E97C/multiagent/skills`, retravaillées
selon la méthodologie `writing-skills` (frontmatter correct, triggers précis,
outils désignés par capacités et non par providers, chemins génériques).

| Skill ajoutée | Apport | Origine |
|---|---|---|
| `ui-governance/SKILL.md` | Réutilisation obligatoire des composants/tokens UI existants avant toute création ; zéro style codé en dur | Skill personnelle (`ui-governance.md` sans SKILL.md → ne chargeait jamais) ; réécrite |
| `resolve-ambiguity/SKILL.md` | Protocole de résolution d'ambiguïté : discovery → triage blocking/deferrable → questions compactes avec défauts | Adoptée quasi telle quelle (qualité déjà au niveau writing-skills) |
| `simplification/SKILL.md` | Nettoyage tactique + cascades d'élimination conceptuelle ; VCS plutôt que .bak ; diagnostics IDE d'abord | Améliorée depuis la source Kilo Code |
| `code-refactor/SKILL.md` | Refactoring universel ; découverte par capacités sémantiques (search_symbol → call hierarchy → fallback texte), rename sémantique obligatoire, règle « un producteur par donnée dérivée » | Réécrite (la source était grep-centrée, aveugle aux alias) |
| `learning/SKILL.md` | Base de connaissances persistante `{repo}/docs/learnings/` : find / evaluate (tiers) / draft / micro-approval / maintenance JIT | Généralisée (chemins Kilo retirés) |

**Note de chargement** : les skills ajoutées n'apparaissent dans une session
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
```

Le script détecte automatiquement toutes les versions installées, sauvegarde l'état
courant dans `_backup_cache/<horodatage>/` puis applique les patches. Idempotent.

Si une mise à jour upstream restructure un fichier (skill renommée, etc.), le script
avertit et ignore ce fichier : mettre à jour alors manuellement le patch ici.

## Restauration

Chaque réinjection sauvegarde la version écrasée. Pour revenir en arrière, copier
le contenu voulu depuis `_backup_cache/<horodatage>/<skill>/SKILL.md` vers le cache.
