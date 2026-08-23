<!-- EXEMPLE — sortie type de /capacites. Ne pas utiliser tel quel :
     laisser /capacites générer le fichier réel depuis des sondes live. -->
<!-- GÉNÉRÉ PAR /capacites — ne pas éditer à la main -->
# État des capacités outils

Dernière sonde : 2026-08-23
Provider : jetbrains (pycharm_*)
Symbole sonde canonique : database.db_manager.se_connecter

Sondes OK :
- symbol search : pycharm_search_symbol
- symbol info : pycharm_get_symbol_info
- diagnostics : lint_files / get_file_problems
- environnement python : get_python_environment (.venv détecté)

Défaillants (datés, fallback officiel) :
- call hierarchy / analyze_calls (2026-08-23) → fallback : recherche textuelle
  sur l'identifiant + subagents explore en parallèle

Base de données :
- data source IDE : non configurée ; fallback : script sqlite3 jetable
