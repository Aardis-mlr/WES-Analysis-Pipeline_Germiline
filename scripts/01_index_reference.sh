#!/bin/bash
#SBATCH --job-name=ref_index
#SBATCH --output=logs/01_index_%j.out
#SBATCH --error=logs/01_index_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# ============================================================
# 01_index_reference.sh
# Indexes the already-downloaded GRCh38 reference genome.
# Assumes Homo_sapiens_assembly38.fasta already exists in
# data/reference/ (downloaded separately, not by this script).
# Run from project root: sbatch scripts/01_index_reference.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
REF_DIR=${PROJECT}/data/reference
FASTA=${REF_DIR}/Homo_sapiens_assembly38.fasta

mkdir -p "${PROJECT}/logs"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

echo "=== $(date) : Checking reference FASTA exists and is non-empty ==="
if [ ! -s "${FASTA}" ]; then
    echo "ERROR: ${FASTA} is missing or empty. Cannot index."
    exit 1
fi
ls -lh "${FASTA}"

echo "=== $(date) : Running samtools faidx ==="
samtools faidx "${FASTA}"

echo "=== $(date) : Running bwa index (this is the slow step, 10-30+ min) ==="
bwa index "${FASTA}"

echo "=== $(date) : Indexing complete. Files in ${REF_DIR}: ==="
ls -lh "${REF_DIR}"

echo "=== $(date) : DONE ==="
