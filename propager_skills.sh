#!/usr/bin/env bash
# propager_skills.sh — synchronise les skills opérationnelles vers ~/.agents/skills/.
#
# La session OpenCode charge les skills depuis ~/.agents/skills/, PAS depuis le
# cache du plugin superpowers. Or reinjecter.sh ne maintient que le cache plugin.
# Afin que les skills ajoutées (ui-governance, security-review, coding-standards, …)
# restent disponibles après une MISE À JOUR du paquet superpowers (cache écrasé)
# ou sur une NOUVELLE MACHINE, ce script copie le dossier skill complet depuis
# superpowers-patches/skills/<nom>/ vers ~/.agents/skills/<nom>/.
#
# Règles :
#   - NE JAMAIS écraser une skill déjà présente dans ~/.agents/skills/ :
#     ce dossier est la source CURATÉE (versions retravaillées) — on respecte.
#   - Idempotent : relançable sans risque.
#   - N'agit que sur les skills ABSENTES de ~/.agents/skills/.
#   - EXCEPTION : using-superpowers (le hub) doit SUIVRE le patch. Sa copie
#     dans ~/.agents/skills/ est donc resynchronisée à la main après toute
#     modification du hub (reinjecter.sh + cp manuel, voir README).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SKILLS="${HOME}/.agents/skills"

FORCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --force) if [ $# -ge 2 ]; then FORCE="$2"; shift 2; else echo "usage: $0 [--force <skill>]" >&2; exit 1; fi ;;
        *) echo "usage: $0 [--force <skill>]" >&2; exit 1 ;;
    esac
done

if [ ! -d "${AGENTS_SKILLS}" ]; then
    mkdir -p "${AGENTS_SKILLS}"
    echo "[OK] Dossier ${AGENTS_SKILLS} créé."
fi

if [ ! -d "${SCRIPT_DIR}/skills" ]; then
    echo "ERREUR : ${SCRIPT_DIR}/skills introuvable." >&2
    exit 1
fi

nb=0
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

echo ""
echo "Terminé : ${nb} skill(s) propagée(s). Source : ${SCRIPT_DIR}/skills/ → ${AGENTS_SKILLS}/"
echo "Note : les skills déjà présentes sont préservées (jamais écrasées)."
