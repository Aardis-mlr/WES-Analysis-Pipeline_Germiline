#!/bin/bash
#SBATCH --job-name=wes_mark_dup
#SBATCH --output=logs/04_markdup_%j.out
#SBATCH --error=logs/04_markdup_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=infinite

# ============================================================
# 04_markduplicates.sh
# Marks PCR/optical duplicates on sorted BAMs (from step 03)
# using GATK MarkDuplicates. Required before BQSR.
# Run from project root: sbatch scripts/04_markduplicates.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
BAM_DIR=${PROJECT}/results/bam
METRICS_DIR=${PROJECT}/results/metrics
SAMPLES_CSV=${PROJECT}/config/samples.csv

mkdir -p "${BAM_DIR}" "${METRICS_DIR}" "${PROJECT}/logs" "${PROJECT}/tmp"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${SAMPLES_CSV}" ]; then
    echo "ERROR: ${SAMPLES_CSV} not found or empty."
    exit 1
fi

tail -n +2 "${SAMPLES_CSV}" | while IFS=',' read -r SAMPLE_ID R1 R2; do

    [ -z "${SAMPLE_ID}" ] && continue

    BAM_IN="${BAM_DIR}/${SAMPLE_ID}.sorted.bam"
    BAM_DEDUP="${BAM_DIR}/${SAMPLE_ID}.dedup.bam"
    DUP_METRICS="${METRICS_DIR}/${SAMPLE_ID}.dup_metrics.txt"

    echo "=== $(date) : Processing sample ${SAMPLE_ID} ==="

    if [ ! -s "${BAM_IN}" ]; then
        echo "ERROR: Missing sorted BAM for ${SAMPLE_ID} (${BAM_IN}). Skipping."
        echo "Check that step 03 (bwa alignment) completed for this sample."
        continue
    fi

    echo "--- $(date) : Marking duplicates (${SAMPLE_ID}) ---"
    gatk MarkDuplicates \
        -I "${BAM_IN}" \
        -O "${BAM_DEDUP}" \
        -M "${DUP_METRICS}" \
        --TMP_DIR "${PROJECT}/tmp"

    echo "--- $(date) : Indexing deduplicated BAM (${SAMPLE_ID}) ---"
    samtools index "${BAM_DEDUP}"

    echo "--- $(date) : Duplicate rate summary (${SAMPLE_ID}) ---"
    grep -A1 "LIBRARY" "${DUP_METRICS}" | head -2

    echo "=== $(date) : Finished ${SAMPLE_ID} ==="

done

echo "=== $(date) : DONE. Duplicate marking complete for all samples. ==="
