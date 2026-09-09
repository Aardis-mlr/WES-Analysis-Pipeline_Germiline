#!/bin/bash
#SBATCH --job-name=pop_compare
#SBATCH --output=logs/11_popcompare_%j.out
#SBATCH --error=logs/11_popcompare_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=infinite

# ============================================================
# 11_population_comparison.sh
# Compares cohort allele frequencies (computed from the
# filtered VCF) against gnomAD frequencies (from the VEP
# annotation in step 09), flagging variants that are rare,
# absent, or enriched in gnomAD relative to this cohort -
# i.e. candidate population-specific variants.
#
# Run from project root: sbatch scripts/11_population_comparison.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
ANNOT_DIR=${PROJECT}/results/annotation
POP_DIR=${PROJECT}/results/population
TABLES_DIR=${PROJECT}/results/tables
ANNOTATED_VCF=${ANNOT_DIR}/cohort.annotated.vcf.gz

mkdir -p "${POP_DIR}" "${TABLES_DIR}" "${PROJECT}/logs"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${ANNOTATED_VCF}" ]; then
    echo "ERROR: Annotated VCF missing (${ANNOTATED_VCF}). Check step 09 completed."
    exit 1
fi

echo "=== $(date) : Computing cohort allele frequencies (bcftools fill-tags) ==="
COHORT_AF_VCF="${POP_DIR}/cohort.with_af.vcf.gz"
bcftools +fill-tags "${ANNOTATED_VCF}" -Oz -o "${COHORT_AF_VCF}" -- -t AF,AC,AN
tabix -p vcf "${COHORT_AF_VCF}"

echo "=== $(date) : Running population frequency comparison (Python) ==="
python3 "${PROJECT}/scripts/population_comparison.py" \
    --input-vcf "${COHORT_AF_VCF}" \
    --output-csv "${TABLES_DIR}/population_comparison.csv" \
    --output-candidates "${TABLES_DIR}/candidate_population_specific_variants.csv"

echo "=== $(date) : Summary counts ==="
if [ -s "${TABLES_DIR}/candidate_population_specific_variants.csv" ]; then
    echo "Candidate population-specific variants flagged: $(( $(wc -l < "${TABLES_DIR}/candidate_population_specific_variants.csv") - 1 ))"
fi

echo "=== $(date) : DONE. Population comparison complete. ==="
echo "Full comparison table: ${TABLES_DIR}/population_comparison.csv"
echo "Candidate population-specific variants: ${TABLES_DIR}/candidate_population_specific_variants.csv"
