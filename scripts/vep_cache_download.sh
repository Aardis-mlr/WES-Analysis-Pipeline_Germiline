#!/bin/bash
#SBATCH --job-name=vep_cache_dl
#SBATCH --output=logs/vep_cache_dl_%j.out
#SBATCH --error=logs/vep_cache_dl_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=infinite

# ============================================================
# download_vep_cache.sh
# Downloads and extracts the VEP indexed cache for GRCh38
# directly on the HPC, if connectivity allows.
# Run from project root: sbatch scripts/download_vep_cache.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
CACHE_URL="http://ftp.ensembl.org/pub/release-111/variation/indexed_vep_cache/homo_sapiens_vep_111_GRCh38.tar.gz"
DOWNLOAD_DIR="${PROJECT}/resources/vep_cache_download"
CACHE_DIR="${PROJECT}/resources/vep_cache"

mkdir -p "${DOWNLOAD_DIR}" "${CACHE_DIR}" "${PROJECT}/logs"

echo "=== $(date) : Checking connectivity to Ensembl FTP ==="
if ! wget --spider -q "${CACHE_URL}"; then
    echo "ERROR: Cannot reach ${CACHE_URL} from this node."
    echo "Fall back to downloading on your PC and rsync-ing to the HPC instead."
    exit 1
fi
echo "Connectivity OK — proceeding with download."

echo "=== $(date) : Downloading VEP cache (this is large, ~15-20GB) ==="
cd "${DOWNLOAD_DIR}"
wget -c "${CACHE_URL}"

echo "=== $(date) : Extracting cache ==="
tar -xzf homo_sapiens_vep_111_GRCh38.tar.gz -C "${CACHE_DIR}"

echo "=== $(date) : Verifying extracted cache ==="
ls -lh "${CACHE_DIR}"

echo "=== $(date) : DONE. VEP cache ready at ${CACHE_DIR} ==="
