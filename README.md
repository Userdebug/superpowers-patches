# Superpowers Patches

Extension de [Superpowers](https://github.com/obra/superpowers) pour OpenCode.

Ce dépôt contient des **skills superpowers externes** — des extensions personnelles
curatées et des skills ajoutées — ainsi qu'un **mini-plugin** qui améliore l'intégration
de Superpowers dans OpenCode.

## Ce que ça fait

- Ajoute des skills supplémentaires au catalogue superpowers (elles ne font pas partie
  du paquet upstream).
- Surcharge des skills existantes par des versions personnelles étendues/améliorées.
- Assure que ces skills sont bien chargées par OpenCode à chaque session, grâce à un
  plugin qui les enregistre après superpowers (OpenCode 2 : `ctx.skill.transform`,
  remplacement par id ; OpenCode 1 : dernière position dans `skills.paths`, loader
  « dernier écrit gagne ») — sans jamais modifier le cache du paquet superpowers.
- Remplace le bootstrap de session injecté par superpowers par la version personnelle
  du hub `using-superpowers` (OpenCode 2 : hook `context` ; OpenCode 1 :
  `experimental.chat.messages.transform`), avec le mapping d'outils adapté (shell/subagent/patch en v2).

## Installation

```
./init-machine.sh
```

Puis redémarrer OpenCode.

## Scripts

| Script | Rôle |
|---|---|
| `init-machine.sh` | Configure une machine : déclare le plugin superpowers, installe le mini-plugin personnel après, ajoute la commande `/capacites` |
| `propager_skills.sh` | Copie les skills du dépôt vers les répertoires de skills locaux (`~/.config/opencode/personal-skills/`, `~/.agents/skills/`) |
| `plugin/personal-skills.js` | Mini-plugin OpenCode dual V1/V2 : enregistre le miroir personnel (`skills.paths` en V1, `skill.transform` en V2) et remplace le bootstrap de session (`messages.transform` en V1, hook `context` en V2) |

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| `skills/` | Les skills personnelles (source du dépôt) |
| `plugin/` | Le mini-plugin OpenCode |
| `templates/` | Templates d'installation (projet, commandes) |
| `tests/` | Tests unitaires et d'intégration |
| `rules/` | Règles de contribution/qualité |
| `docs/` | Documentation complémentaire |