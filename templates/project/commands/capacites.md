---
description: Sonde les capacités outils de la session et régénère .opencode/instructions/capacites-outils.md
---

Exécute le protocole STEP 0 défini dans la skill using-superpowers, puis régénère le fichier d'état :

1. Identifie le provider sémantique disponible dans cette session (`pycharm_*`, `vscode_*`/LSP, ou aucun).
2. Health-check chaque capacité avancée (symbol search, call hierarchy, symbol info, rename, diagnostics, database query) sur le symbole sonde canonique indiqué dans AGENTS.md — à défaut, un symbole bien connu du projet.
3. Régénère INTÉGRALEMENT `.opencode/instructions/capacites-outils.md` au format canonique ci-dessous. Ne modifie AUCUN autre fichier.

Format canonique :

```markdown
<!-- GÉNÉRÉ PAR /capacites — ne pas éditer à la main -->
# État des capacités outils

Dernière sonde : YYYY-MM-DD
Provider : <jetbrains | vscode-lsp | cli>
Symbole sonde canonique : <module.fonction>

Sondes OK :
- symbol search : <outil utilisé>
- ...

Défaillants (datés, fallback officiel) :
- call hierarchy (YYYY-MM-DD) → fallback : recherche textuelle sur l'identifiant

Base de données :
- data source IDE : <oui/non> ; fallback : script sqlite3 jetable
```

Règles :
- Marque chaque outil défaillant avec la date du jour et son fallback retenu.
- Si AGENTS.md ne définit pas de symbole sonde, propose-en un et demande confirmation AVANT de l'y ajouter (section « Outils sémantiques »).
- Idempotent : relançable à tout moment pour rafraîchir l'état.
