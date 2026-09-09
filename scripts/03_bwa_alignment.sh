#!/bin/bash
#SBATCH --job-name=bwa_align
#SBATCH --output=logs/03_align_%j.out
#SBATCH --error=logs/03_align_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=infinite

# ============================================================
# 03_bwa_alignment.sh
# Aligns trimmed reads (from step 02) to the reference genome
# using BWA-MEM, piped directly into samtools sort, then
# indexes and generates QC metrics.
#
# NFS WORKAROUND: this cluster's storage has a known issue
# where samtools/htslib fails to open output files directly on
# the NFS mount ("No such file or directory" even though the
# directory exists and is writable). Sorting/indexing happens
# on local node scratch space (/tmp) first, then the finished
# BAM is copied back to project storage with a plain cp, which
# does not hit the same htslib/NFS incompatibility.
#
# Run from project root: sbatch scripts/03_bwa_alignment.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
TRIM_DIR=${PROJECT}/data/trimmed
REF=${PROJECT}/data/reference/Homo_sapiens_assembly38.fasta
BAM_DIR=${PROJECT}/results/bam
ALIGN_DIR=${PROJECT}/results/alignment
METRICS_DIR=${PROJECT}/results/metrics
SAMPLES_CSV=${PROJECT}/config/samples.csv
THREADS=8
PLATFORM="ILLUMINA"

mkdir -p "${BAM_DIR}" "${ALIGN_DIR}" "${METRICS_DIR}" "${PROJECT}/logs"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${SAMPLES_CSV}" ]; then
    echo "ERROR: ${SAMPLES_CSV} not found or empty."
    exit 1
fi

if [ ! -s "${REF}" ] || [ ! -s "${REF}.bwt" ]; then
    echo "ERROR: Reference FASTA or BWA index missing/incomplete at ${REF}."
    echo "Confirm step 01 (indexing) finished successfully before running this."
    exit 1
fi

echo "=================================================="
echo "Uganda WES Pipeline"
echo "Step 03 : BWA-MEM Alignment"
echo "=================================================="
echo "Reference : ${REF}"
echo "Start Time: $(date)"
echo

TOTAL=0

# NOTE: process substitution (< <(...)) is used instead of piping into
# the while loop, so that "exit 1" on error actually stops this script
# rather than only killing a subshell created by a pipe.
while IFS=',' read -r SAMPLE_ID R1 R2; do

    [ -z "${SAMPLE_ID}" ] && continue

    R1_TRIM="${TRIM_DIR}/${SAMPLE_ID}_R1.trim.fastq.gz"
    R2_TRIM="${TRIM_DIR}/${SAMPLE_ID}_R2.trim.fastq.gz"
    BAM_SORTED="${BAM_DIR}/${SAMPLE_ID}.sorted.bam"

    echo "----------------------------------------"
    echo "$(date) : Aligning ${SAMPLE_ID}"
    echo "----------------------------------------"

    if [ ! -s "${R1_TRIM}" ] || [ ! -s "${R2_TRIM}" ]; then
        echo "ERROR: Missing trimmed FASTQ for ${SAMPLE_ID} (${R1_TRIM} / ${R2_TRIM})."
        echo "Check that step 02 (fastqc/fastp) completed for this sample."
        exit 1
    fi

    READ_GROUP="@RG\tID:${SAMPLE_ID}\tSM:${SAMPLE_ID}\tPL:${PLATFORM}\tLB:${SAMPLE_ID}_lib1\tPU:1"

    # Sort/index on local node scratch to avoid the NFS write issue,
    # then copy the finished files back to project storage.
    LOCAL_SCRATCH="/tmp/${USER}_${SLURM_JOB_ID:-manual}_${SAMPLE_ID}"
    mkdir -p "${LOCAL_SCRATCH}"
    LOCAL_BAM="${LOCAL_SCRATCH}/${SAMPLE_ID}.sorted.bam"

    echo "--- $(date) : BWA-MEM alignment piped into samtools sort (${SAMPLE_ID}) ---"
    bwa mem \
        -M \
        -t "${THREADS}" \
        -R "${READ_GROUP}" \
        "${REF}" \
        "${R1_TRIM}" \
        "${R2_TRIM}" | \
    samtools sort \
        -@ "${THREADS}" \
        -o "${LOCAL_BAM}" -

    echo "--- $(date) : Indexing BAM on local scratch (${SAMPLE_ID}) ---"
    samtools index "${LOCAL_BAM}"

    echo "--- $(date) : Copying finished BAM back to project storage (${SAMPLE_ID}) ---"
    cp "${LOCAL_BAM}" "${BAM_SORTED}"
    cp "${LOCAL_BAM}.bai" "${BAM_SORTED}.bai"

    echo "--- $(date) : Cleaning up local scratch (${SAMPLE_ID}) ---"
    rm -rf "${LOCAL_SCRATCH}"

    echo "--- $(date) : Generating QC metrics (${SAMPLE_ID}) ---"
    samtools flagstat "${BAM_SORTED}" > "${METRICS_DIR}/${SAMPLE_ID}.flagstat.txt"
    samtools stats "${BAM_SORTED}" > "${METRICS_DIR}/${SAMPLE_ID}.stats.txt"
    cat "${METRICS_DIR}/${SAMPLE_ID}.flagstat.txt"

    TOTAL=$((TOTAL+1))
    echo "=== $(date) : Finished ${SAMPLE_ID} ==="
    echo

done < <(tail -n +2 "${SAMPLES_CSV}")

echo "=================================================="
echo "Alignment Completed Successfully"
echo "Samples Processed : ${TOTAL}"
echo "Sorted BAMs        : ${BAM_DIR}"
echo "Metrics             : ${METRICS_DIR}"
echo "End Time            : $(date)"
echo "=================================================="
