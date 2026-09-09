#!/bin/bash
#SBATCH --job-name=hard_filter
#SBATCH --output=logs/08_filter_%j.out
#SBATCH --error=logs/08_filter_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=infinite

# ============================================================
# 08_variant_filtering.sh
# Hard-filters the joint-genotyped cohort VCF (from step 07)
# using GATK best-practice thresholds, separately for SNPs
# and indels (their filter criteria differ).
#
# VQSR is not used here since it requires large sample sizes
# (typically dozens to hundreds) to train reliably - not
# appropriate for this small cohort.
#
# Run from project root: sbatch scripts/08_variant_filtering.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
VCF_DIR=${PROJECT}/results/vcf
FILTERED_DIR=${PROJECT}/results/filtered_vcf
REF=${PROJECT}/data/reference/Homo_sapiens_assembly38.fasta
COHORT_VCF=${VCF_DIR}/cohort.joint.vcf.gz

SNP_VCF=${FILTERED_DIR}/cohort.snps.vcf.gz
SNP_FILTERED=${FILTERED_DIR}/cohort.snps.filtered.vcf.gz
INDEL_VCF=${FILTERED_DIR}/cohort.indels.vcf.gz
INDEL_FILTERED=${FILTERED_DIR}/cohort.indels.filtered.vcf.gz
FINAL_VCF=${FILTERED_DIR}/cohort.filtered.merged.vcf.gz

mkdir -p "${FILTERED_DIR}" "${PROJECT}/logs" "${PROJECT}/tmp"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${COHORT_VCF}" ]; then
    echo "ERROR: Cohort VCF missing (${COHORT_VCF}). Check step 07 completed."
    exit 1
fi

echo "=== $(date) : Selecting SNPs ==="
gatk SelectVariants \
    -R "${REF}" \
    -V "${COHORT_VCF}" \
    --select-type-to-include SNP \
    -O "${SNP_VCF}"

echo "=== $(date) : Applying hard filters to SNPs (GATK best-practice thresholds) ==="
gatk VariantFiltration \
    -R "${REF}" \
    -V "${SNP_VCF}" \
    --filter-expression "QD < 2.0" --filter-name "QD2" \
    --filter-expression "FS > 60.0" --filter-name "FS60" \
    --filter-expression "MQ < 40.0" --filter-name "MQ40" \
    --filter-expression "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
    --filter-expression "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    --filter-expression "SOR > 3.0" --filter-name "SOR3" \
    -O "${SNP_FILTERED}"

echo "=== $(date) : Selecting indels ==="
gatk SelectVariants \
    -R "${REF}" \
    -V "${COHORT_VCF}" \
    --select-type-to-include INDEL \
    -O "${INDEL_VCF}"

echo "=== $(date) : Applying hard filters to indels (GATK best-practice thresholds) ==="
gatk VariantFiltration \
    -R "${REF}" \
    -V "${INDEL_VCF}" \
    --filter-expression "QD < 2.0" --filter-name "QD2" \
    --filter-expression "FS > 200.0" --filter-name "FS200" \
    --filter-expression "ReadPosRankSum < -20.0" --filter-name "ReadPosRankSum-20" \
    --filter-expression "SOR > 10.0" --filter-name "SOR10" \
    -O "${INDEL_FILTERED}"

echo "=== $(date) : Merging filtered SNPs and indels back into one VCF ==="

bcftools concat \
-a \
-O z \
-o "${FINAL_VCF}" \
"${SNP_FILTERED}" \
"${INDEL_FILTERED}"
echo "=== $(date) : Indexing final merged VCF ==="
tabix -p vcf "${FINAL_VCF}"

echo "=== $(date) : Filter summary (PASS vs filtered counts) ==="
bcftools view -H "${FINAL_VCF}" | awk '{print $7}' | sort | uniq -c

echo "=== $(date) : DONE. Hard filtering complete: ${FINAL_VCF} ==="
