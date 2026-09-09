#!/bin/bash
#SBATCH --job-name=bqsr
#SBATCH --output=logs/05_bqsr_%j.out
#SBATCH --error=logs/05_bqsr_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=infinite

# ============================================================
# 05_bqsr.sh
# Runs GATK BaseRecalibrator + ApplyBQSR on deduplicated BAMs
# (from step 04), using dbSNP and Mills known-sites VCFs.
# Run from project root: sbatch scripts/05_bqsr.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
BAM_DIR=${PROJECT}/results/bam
METRICS_DIR=${PROJECT}/results/metrics
REF=${PROJECT}/data/reference/Homo_sapiens_assembly38.fasta
DBSNP=${PROJECT}/data/known_sites/Homo_sapiens_assembly38.dbsnp138.vcf.gz
MILLS=${PROJECT}/data/known_sites/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
SAMPLES_CSV=${PROJECT}/config/samples.csv

mkdir -p "${BAM_DIR}" "${METRICS_DIR}" "${PROJECT}/logs" "${PROJECT}/tmp"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${SAMPLES_CSV}" ]; then
    echo "ERROR: ${SAMPLES_CSV} not found or empty."
    exit 1
fi

if [ ! -s "${DBSNP}" ] || [ ! -s "${MILLS}" ]; then
    echo "ERROR: Known-sites files missing (${DBSNP} or ${MILLS})."
    exit 1
fi

tail -n +2 "${SAMPLES_CSV}" | while IFS=',' read -r SAMPLE_ID R1 R2; do

    [ -z "${SAMPLE_ID}" ] && continue

    BAM_IN="${BAM_DIR}/${SAMPLE_ID}.dedup.bam"
    RECAL_TABLE="${METRICS_DIR}/${SAMPLE_ID}.recal_data.table"
    BAM_RECAL="${BAM_DIR}/${SAMPLE_ID}.recal.bam"

    echo "=== $(date) : Processing sample ${SAMPLE_ID} ==="

    if [ ! -s "${BAM_IN}" ]; then
        echo "ERROR: Missing dedup BAM for ${SAMPLE_ID} (${BAM_IN}). Skipping."
        echo "Check that step 04 (markduplicates) completed for this sample."
        continue
    fi

    echo "--- $(date) : BaseRecalibrator (${SAMPLE_ID}) ---"
    gatk BaseRecalibrator \
        -I "${BAM_IN}" \
        -R "${REF}" \
        --known-sites "${DBSNP}" \
        --known-sites "${MILLS}" \
        -O "${RECAL_TABLE}" \
        --tmp-dir "${PROJECT}/tmp"

    echo "--- $(date) : ApplyBQSR (${SAMPLE_ID}) ---"
    gatk ApplyBQSR \
        -I "${BAM_IN}" \
        -R "${REF}" \
        --bqsr-recal-file "${RECAL_TABLE}" \
        -O "${BAM_RECAL}" \
        --tmp-dir "${PROJECT}/tmp"

    echo "--- $(date) : Indexing recalibrated BAM (${SAMPLE_ID}) ---"
    samtools index "${BAM_RECAL}"

    echo "=== $(date) : Finished ${SAMPLE_ID} ==="

done

echo "=== $(date) : DONE. BQSR complete for all samples. ==="
