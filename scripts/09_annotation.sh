#!/bin/bash
#SBATCH --job-name=vep_annot
#SBATCH --output=logs/09_annot_%j.out
#SBATCH --error=logs/09_annot_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=infinite

# ============================================================
# 09_annotation.sh
# Annotates the filtered cohort VCF (from step 08) using VEP
# in OFFLINE mode (local cache), with ClinVar and gnomAD
# frequency data as custom/plugin annotations.
#
# Requires local VEP cache + ClinVar VCF to already be present
# (both are large downloads - use the same PC-download-then-
# rsync-upload workaround as the reference genome if the HPC
# has no outbound internet, which is likely given prior tests).
#
# Run from project root: sbatch scripts/09_annotation.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
FILTERED_DIR=${PROJECT}/results/filtered_vcf
ANNOT_DIR=${PROJECT}/results/annotation
REF=${PROJECT}/data/reference/Homo_sapiens_assembly38.fasta
VEP_CACHE_DIR=${PROJECT}/resources/vep_cache
CLINVAR=${PROJECT}/resources/clinvar.vcf.gz

INPUT_VCF=${FILTERED_DIR}/cohort.filtered.merged.vcf.gz
ANNOTATED_VCF=${ANNOT_DIR}/cohort.annotated.vcf.gz
VEP_STATS=${ANNOT_DIR}/cohort.vep_summary.html

VEP_SPECIES="homo_sapiens"
VEP_ASSEMBLY="GRCh38"
THREADS=8

mkdir -p "${ANNOT_DIR}" "${PROJECT}/logs" "${PROJECT}/tmp"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes2

if [ ! -s "${INPUT_VCF}" ]; then
    echo "ERROR: Filtered cohort VCF missing (${INPUT_VCF}). Check step 08 completed."
    exit 1
fi

if [ ! -d "${VEP_CACHE_DIR}" ]; then
    echo "ERROR: VEP cache directory not found at ${VEP_CACHE_DIR}."
    echo "Download it locally and rsync to the HPC before running this step:"
    echo "  On your PC: vep_install -a cf -s homo_sapiens -y GRCh38 -c ./vep_cache --CACHE_VERSION 111"
    echo "  Then: rsync -avP ./vep_cache/ rmulondo@kla-ac-hpc-02:${VEP_CACHE_DIR}/"
    exit 1
fi

if [ ! -s "${CLINVAR}" ]; then
    echo "WARNING: ClinVar VCF not found at ${CLINVAR}. Proceeding WITHOUT ClinVar annotation."
    echo "Download it locally and rsync to the HPC if you want ClinVar significance calls:"
    echo "  https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/clinvar.vcf.gz (+ .tbi)"
    CLINVAR_ARGS=()
else
    echo "=== $(date) : ClinVar found — will annotate clinical significance ==="
    CLINVAR_ARGS=(--custom "${CLINVAR}",ClinVar,vcf,exact,0,CLNSIG,CLNREVSTAT,CLNDN)
fi

echo "=== $(date) : Running VEP annotation ==="
vep \
    --input_file "${INPUT_VCF}" \
    --output_file "${ANNOTATED_VCF}" \
    --vcf \
    --compress_output bgzip \
    --stats_file "${VEP_STATS}" \
    --offline \
    --cache \
    --dir_cache "${VEP_CACHE_DIR}" \
    --cache_version 111 \
    --species "${VEP_SPECIES}" \
    --assembly "${VEP_ASSEMBLY}" \
    --fasta "${REF}" \
    --fork "${THREADS}" \
    --everything \
    --pick_allele_gene \
    "${CLINVAR_ARGS[@]}" \
    --force_overwrite

echo "=== $(date) : Indexing annotated VCF ==="
tabix -p vcf "${ANNOTATED_VCF}"

echo "=== $(date) : DONE. Annotation complete: ${ANNOTATED_VCF} ==="
echo "VEP summary report: ${VEP_STATS}"
