#!/usr/bin/env bash
# propager_skills.sh — synchronise les skills opérationnelles vers deux destinations :
#
#   1) ~/.config/opencode/personal-skills/   — MIROIR OpenCode (variante B).
#      La session opencode charge les skills depuis ce dossier : le mini-plugin
#      plugin/personal-skills.js le pousse en DERNIÈRE position de skills.paths
#      (le loader « dernier écrit gagne »), donc nos versions gagnent sur le
#      cache du paquet superpowers. Toujours écrasé = miroir fidèle du patch.
#
#   2) ~/.agents/skills/   — AUTRES harnais (Claude Code, Cursor, …).
#      Règles : NE JAMAIS écraser une skill déjà présente (curatée, respectée) ;
#      seule une dérogation explicite (--force <skill>) resynchronise, avec
#      backup dans ~/.agents/skills_backup/<horodatage>/ avant écrasement.
#
# Idempotent : relançable sans risque.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SKILLS="${HOME}/.agents/skills"
PERSONAL_SKILLS="${HOME}/.config/opencode/personal-skills"

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
            ts="$(date +%Y%m%d-%H%M%S)"
            i=0
            suffix=""
            while [ -e "${HOME}/.agents/skills_backup/${ts}${suffix}/${skill}" ]; do
                i=$((i + 1)); suffix=".${i}"
            done
            bkp="${HOME}/.agents/skills_backup/${ts}${suffix}/${skill}"
            mkdir -p "$bkp"
            cp -r "${dest}"/. "$bkp/"
            rm -rf "$dest"
            cp -r "$(dirname "$src")"/. "$dest/"
            echo "  ${skill}/ : FORCÉE (curatée → ${bkp})"
            nb=$((nb + 1))
        else
            # opencode 2 découvre nativement ~/.agents/skills : une curatée
            # divergente y sert une version périmée des skills partagées. On ne
            # l'écrase pas (politique autres harnais) mais on signale l'écart.
            if ! cmp -s "$src" "${dest}/SKILL.md"; then
                echo "  ${skill}/ : PRÉSERVÉE mais DIFFÉRENTE du patch — opencode 2 lit ~/.agents/skills, resynchroniser : $0 --force ${skill}"
            else
                echo "  ${skill}/ : déjà présent (curatée identique, ignorée)"
            fi
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

# --- Miroir OpenCode : ~/.config/opencode/personal-skills/ (TOUJOURS écrasé) ---
mkdir -p "${PERSONAL_SKILLS}"
nb_perso=0
for src in "${SCRIPT_DIR}"/skills/*/; do
    [ -d "$src" ] || continue
    skill="$(basename "$src")"
    rm -rf "${PERSONAL_SKILLS}/${skill}"
    cp -r "$src" "${PERSONAL_SKILLS}/${skill}"
    nb_perso=$((nb_perso + 1))
done

echo ""
echo "Miroir OpenCode : ${nb_perso} skill(s) → ${PERSONAL_SKILLS}/"
echo "~/.agents/skills : ${nb} skill(s) propagée(s) — curatées préservées (jamais écrasées sans --force)."
