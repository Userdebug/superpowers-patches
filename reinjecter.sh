#!/usr/bin/env bash
# Réinjecte les patches de skills superpowers (règles « racine d'abord ») dans le
# cache opencode, après chaque mise à jour du paquet superpowers.
#
# - Détecte automatiquement tout dossier ~/.cache/opencode/packages/superpowers@*/node_modules/superpowers
# - Sauvegarde l'état courant du cache dans _backup_cache/<horodatage>/ avant écrasement
# - Idempotent : relançable sans risque
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_ROOT="${HOME}/.cache/opencode/packages"

# Le nom du paquet contient des sous-répertoires (superpowers@git+https:/github.com/...),
# donc un simple glob ne suffit pas : on cherche en profondeur.
mapfile -t cibles < <(find "${PACKAGES_ROOT}" -type d -path "*/node_modules/superpowers" 2>/dev/null | sort)

if [ ${#cibles[@]} -eq 0 ]; then
    echo "ERREUR : aucun dossier superpowers trouvé sous ${PACKAGES_ROOT}" >&2
    echo "Vérifiez que le paquet superpowers est installé." >&2
    exit 1
fi

horodatage=$(date +%Y%m%d-%H%M%S)
nb_fichiers=0

for cible in "${cibles[@]}"; do
    if [ ! -d "${cible}/skills" ]; then
        echo "AVERTISSEMENT : ${cible}/skills introuvable, ignoré." >&2
        continue
    fi
    echo "=== Cible : ${cible}"
    for src in "${PATCH_DIR}"/skills/*/SKILL.md; do
        skill=$(basename "$(dirname "$src")")
        skill_dir="$(dirname "$src")"
        dest="${cible}/skills/${skill}/SKILL.md"
        if [ ! -f "$dest" ]; then
            # Skill absente du paquet upstream : AJOUT complet du dossier
            # (nouvelles skills personnelles, ex. ui-governance).
            dest_dir="$(dirname "$dest")"
            if diff -rq "$skill_dir" "$dest_dir" >/dev/null 2>&1; then
                echo "  ${skill}/ : déjà à jour (ajout inchangé)"
                continue
            fi
            mkdir -p "$dest_dir"
            cp -r "${skill_dir}"/. "$dest_dir/"
            echo "  ${skill}/ : AJOUTÉE (skill nouvelle, absente upstream)"
            nb_fichiers=$((nb_fichiers + 1))
            continue
        fi
        backup_dir="${PATCH_DIR}/_backup_cache/${horodatage}/${skill}"
        mkdir -p "$backup_dir"
        cp "$dest" "${backup_dir}/SKILL.md"
        cp "$src" "$dest"
        nb_fichiers=$((nb_fichiers + 1))
        if cmp -s "$src" "${backup_dir}/SKILL.md"; then
            echo "  ${skill}/SKILL.md : déjà à jour (backup inchangé)"
        else
            echo "  ${skill}/SKILL.md : patché (ancienne version → _backup_cache/${horodatage}/${skill}/)"
        fi
        # Fichiers annexes (ex. references/) présents dans le patch : synchronisés
        # pour les skills patchées (les skills AJOUTÉES sont copiées complètes plus haut).
        if [ -d "${skill_dir}/references" ]; then
            dest_refs="${cible}/skills/${skill}/references"
            mkdir -p "${dest_refs}" "${backup_dir}/references"
            for annexe in "${skill_dir}"/references/*; do
                nom_annexe="$(basename "$annexe")"
                cp "$annexe" "${dest_refs}/${nom_annexe}"
                cp "$annexe" "${backup_dir}/references/${nom_annexe}" 2>/dev/null || true
                nb_fichiers=$((nb_fichiers + 1))
                echo "  ${skill}/references/${nom_annexe} : synchronisé"
            done
        fi
    done
done

echo ""
echo "Terminé : ${nb_fichiers} fichier(s) réinjecté(s). Backups dans _backup_cache/${horodatage}/"
