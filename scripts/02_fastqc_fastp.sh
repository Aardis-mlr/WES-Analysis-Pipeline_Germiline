#!/bin/bash
#SBATCH --job-name=qc_trim
#SBATCH --output=logs/02_qc_trim_%j.out
#SBATCH --error=logs/02_qc_trim_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=infinite

# ============================================================
# 02_fastqc_fastp.sh
# Runs FastQC on raw reads -> fastp trimming -> FastQC on
# trimmed reads, for every sample listed in config/samples.csv
# Run from project root: sbatch scripts/02_fastqc_fastp.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
RAW_DIR=${PROJECT}/data/raw_fastq
TRIM_DIR=${PROJECT}/data/trimmed
FASTQC_RAW=${PROJECT}/results/fastqc/raw
FASTQC_TRIM=${PROJECT}/results/fastqc/trimmed
TRIM_REPORTS=${PROJECT}/results/trimmed
SAMPLES_CSV=${PROJECT}/config/samples.csv
THREADS=8

mkdir -p "${TRIM_DIR}" "${FASTQC_RAW}" "${FASTQC_TRIM}" "${TRIM_REPORTS}" "${PROJECT}/logs"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${SAMPLES_CSV}" ]; then
    echo "ERROR: ${SAMPLES_CSV} not found or empty."
    exit 1
fi

# Skip header line, loop over each sample
tail -n +2 "${SAMPLES_CSV}" | while IFS=',' read -r SAMPLE_ID R1 R2; do

    # Skip blank lines
    [ -z "${SAMPLE_ID}" ] && continue

    R1_PATH="${PROJECT}/${R1}"
    R2_PATH="${PROJECT}/${R2}"

    echo "=== $(date) : Processing sample ${SAMPLE_ID} ==="

    if [ ! -s "${R1_PATH}" ] || [ ! -s "${R2_PATH}" ]; then
        echo "ERROR: Missing or empty FASTQ for ${SAMPLE_ID} (${R1_PATH} / ${R2_PATH}). Skipping."
        continue
    fi

    echo "--- $(date) : FastQC on raw reads (${SAMPLE_ID}) ---"
    fastqc -t "${THREADS}" -o "${FASTQC_RAW}" "${R1_PATH}" "${R2_PATH}"

    echo "--- $(date) : fastp trimming (${SAMPLE_ID}) ---"
    fastp \
        -i "${R1_PATH}" -I "${R2_PATH}" \
        -o "${TRIM_DIR}/${SAMPLE_ID}_R1.trim.fastq.gz" \
        -O "${TRIM_DIR}/${SAMPLE_ID}_R2.trim.fastq.gz" \
        --thread "${THREADS}" \
        --detect_adapter_for_pe \
        --html "${TRIM_REPORTS}/${SAMPLE_ID}_fastp.html" \
        --json "${TRIM_REPORTS}/${SAMPLE_ID}_fastp.json"

    echo "--- $(date) : FastQC on trimmed reads (${SAMPLE_ID}) ---"
    fastqc -t "${THREADS}" -o "${FASTQC_TRIM}" \
        "${TRIM_DIR}/${SAMPLE_ID}_R1.trim.fastq.gz" \
        "${TRIM_DIR}/${SAMPLE_ID}_R2.trim.fastq.gz"

    echo "=== $(date) : Finished ${SAMPLE_ID} ==="

done

echo "=== $(date) : Running MultiQC to aggregate all reports ==="
multiqc "${FASTQC_RAW}" "${FASTQC_TRIM}" "${TRIM_REPORTS}" \
    -o "${PROJECT}/results/multiqc" -n multiqc_report

echo "=== $(date) : DONE. QC and trimming complete for all samples. ==="
