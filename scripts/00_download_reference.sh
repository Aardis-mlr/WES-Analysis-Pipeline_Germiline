#!/bin/bash
#SBATCH --job-name=ref_download
#SBATCH --output=logs/00_download_%j.out
#SBATCH --error=logs/00_download_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00

# ============================================================
# 00_download_reference.sh
# Downloads GRCh38 reference + known-sites VCFs from the
# corrected Broad references bucket.
# Run from project root: sbatch scripts/00_download_reference.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
REF_DIR=${PROJECT}/data/reference
KNOWN_DIR=${PROJECT}/data/known_sites
BASE_URL="https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0"

mkdir -p "${REF_DIR}" "${KNOWN_DIR}" "${PROJECT}/logs"

echo "=== $(date) : Checking connectivity to ${BASE_URL} ==="
if ! wget --spider -q "${BASE_URL}/Homo_sapiens_assembly38.fasta"; then
    echo "ERROR: Still cannot reach this bucket from the HPC."
    echo "This confirms the cluster's outbound restriction applies here too."
    echo "Fall back to downloading on your PC and uploading via rsync instead."
    exit 1
fi
echo "Connectivity OK — proceeding with downloads."

echo "=== $(date) : Downloading reference genome ==="
cd "${REF_DIR}"
wget -c "${BASE_URL}/Homo_sapiens_assembly38.fasta"
wget -c "${BASE_URL}/Homo_sapiens_assembly38.dict"
wget -c "${BASE_URL}/Homo_sapiens_assembly38.fasta.fai"

echo "=== $(date) : Downloading known-sites files ==="
cd "${KNOWN_DIR}"
wget -c "${BASE_URL}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
wget -c "${BASE_URL}/Homo_sapiens_assembly38.dbsnp138.vcf.gz.tbi"
wget -c "${BASE_URL}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
wget -c "${BASE_URL}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi"

echo "=== $(date) : Verifying downloads ==="
echo "--- Reference files ---"
ls -lh "${REF_DIR}"
echo "--- Known-sites files ---"
ls -lh "${KNOWN_DIR}"

echo "=== $(date) : DONE. Files downloaded successfully. ==="
echo "Next step: run the indexing script (samtools faidx + bwa index)."
