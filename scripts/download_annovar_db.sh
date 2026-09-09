#!/bin/bash
#SBATCH --job-name=annovar_db_dl
#SBATCH --output=logs/annovar_db_dl_%j.out
#SBATCH --error=logs/annovar_db_dl_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=infinite

# ============================================================
# download_annovar_db.sh
# Downloads the remaining ANNOVAR humandb databases needed for
# step 10 (ACMG classification): ClinVar, gnomAD exomes, dbNSFP.
# refGene was already downloaded separately.
#
# Run from project root: sbatch scripts/download_annovar_db.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
ANNOVAR_DIR=${PROJECT}/tools/annovar
HUMANDB=${ANNOVAR_DIR}/humandb

mkdir -p "${HUMANDB}" "${PROJECT}/logs"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes2

# Same libnsl fix needed for perl in this env
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

if [ ! -d "${ANNOVAR_DIR}" ]; then
    echo "ERROR: ANNOVAR not found at ${ANNOVAR_DIR}."
    exit 1
fi

echo "=== $(date) : Downloading ClinVar database ==="
perl "${ANNOVAR_DIR}/annotate_variation.pl" \
    -buildver hg38 -downdb -webfrom annovar clinvar_20240611 "${HUMANDB}/"

echo "=== $(date) : Downloading dbNSFP database (functional prediction scores) ==="
perl "${ANNOVAR_DIR}/annotate_variation.pl" \
    -buildver hg38 -downdb -webfrom annovar dbnsfp42a "${HUMANDB}/"

echo "=== $(date) : Downloading gnomAD exomes database (this is the largest, expect it to take a while) ==="
perl "${ANNOVAR_DIR}/annotate_variation.pl" \
    -buildver hg38 -downdb -webfrom annovar gnomad211_exome "${HUMANDB}/"

echo "=== $(date) : Verifying downloaded files ==="
ls -lh "${HUMANDB}/"

echo "=== $(date) : DONE. All ANNOVAR humandb databases downloaded. ==="
