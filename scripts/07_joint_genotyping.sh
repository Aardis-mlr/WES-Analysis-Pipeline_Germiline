#!/bin/bash
#SBATCH --job-name=joint_geno
#SBATCH --output=logs/07_jointgeno_%j.out
#SBATCH --error=logs/07_jointgeno_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=infinite

# ============================================================
# 07_joint_genotyping.sh
# Combines all per-sample GVCFs (from step 06) into a
# GenomicsDB workspace, then runs joint genotyping to
# produce a single cohort-level multi-sample VCF.
#
# Uses the same target BED as step 06 if present, otherwise
# genome-wide (must match step 06's interval choice).
#
# Run from project root: sbatch scripts/07_joint_genotyping.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
GVCF_DIR=${PROJECT}/results/gvcf
VCF_DIR=${PROJECT}/results/vcf
REF=${PROJECT}/data/reference/Homo_sapiens_assembly38.fasta
TARGET_BED=${PROJECT}/data/reference/target_regions.bed
SAMPLES_CSV=${PROJECT}/config/samples.csv
GENOMICSDB=${PROJECT}/tmp/genomicsdb_workspace
COHORT_VCF=${VCF_DIR}/cohort.joint.vcf.gz

mkdir -p "${VCF_DIR}" "${PROJECT}/logs" "${PROJECT}/tmp"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes

if [ ! -s "${SAMPLES_CSV}" ]; then
    echo "ERROR: ${SAMPLES_CSV} not found or empty."
    exit 1
fi

# GenomicsDBImport requires the workspace directory to NOT already exist
if [ -d "${GENOMICSDB}" ]; then
    echo "=== $(date) : Removing existing GenomicsDB workspace before rebuilding ==="
    rm -rf "${GENOMICSDB}"
fi

# Build -V arguments for every sample's GVCF, checking each exists first
VARIANT_ARGS=()
while IFS=',' read -r SAMPLE_ID R1 R2; do
    [ -z "${SAMPLE_ID}" ] && continue
    GVCF="${GVCF_DIR}/${SAMPLE_ID}.g.vcf.gz"
    if [ ! -s "${GVCF}" ]; then
        echo "ERROR: Missing GVCF for ${SAMPLE_ID} (${GVCF})."
        echo "Check that step 06 (variant calling) completed for this sample."
        exit 1
    fi
    VARIANT_ARGS+=(-V "${GVCF}")
done < <(tail -n +2 "${SAMPLES_CSV}")

if [ ${#VARIANT_ARGS[@]} -eq 0 ]; then
    echo "ERROR: No valid GVCFs found. Aborting."
    exit 1
fi

# Determine interval restriction (must match step 06's choice)
# NOTE: GenomicsDBImport requires at least one -L interval argument,
# unlike HaplotypeCaller which can run with none. If no target BED
# exists, we generate a whole-genome interval list from the .fai.
INTERVAL_ARGS=()
if [ -s "${TARGET_BED}" ]; then
    echo "=== $(date) : Using target BED ${TARGET_BED} for joint genotyping ==="
    INTERVAL_ARGS=(-L "${TARGET_BED}" -ip 100)
else
    echo "=== $(date) : WARNING: No target BED found — generating whole-genome intervals from .fai ==="
    echo "This must match whatever step 06 used, or results will be inconsistent."
    # NOTE: file extension matters to GATK - ".interval_list" forces the
    # strict Picard format (SAM header + 5 tab-separated columns), which
    # our plain "chr:start-end" lines don't match. Using ".list" instead
    # tells GATK to parse it as a simple one-interval-per-line file.
    WHOLE_GENOME_INTERVALS="${PROJECT}/tmp/whole_genome.list"
    awk '{print $1":1-"$2}' "${REF}.fai" > "${WHOLE_GENOME_INTERVALS}"
    INTERVAL_ARGS=(-L "${WHOLE_GENOME_INTERVALS}")
fi

echo "=== $(date) : Building GenomicsDB workspace from ${#VARIANT_ARGS[@]} sample GVCFs ==="
gatk --java-options "-Xmx28g" GenomicsDBImport \
    "${VARIANT_ARGS[@]}" \
    --genomicsdb-workspace-path "${GENOMICSDB}" \
    --tmp-dir "${PROJECT}/tmp" \
    "${INTERVAL_ARGS[@]}"

echo "=== $(date) : Running joint genotyping ==="
gatk --java-options "-Xmx28g" GenotypeGVCFs \
    -R "${REF}" \
    -V "gendb://${GENOMICSDB}" \
    -O "${COHORT_VCF}" \
    --tmp-dir "${PROJECT}/tmp"

echo "=== $(date) : Indexing cohort VCF ==="
tabix -p vcf "${COHORT_VCF}"

echo "=== $(date) : Quick variant count summary ==="
bcftools stats "${COHORT_VCF}" | grep "number of SNPs\|number of indels\|number of samples"

echo "=== $(date) : DONE. Joint genotyping complete: ${COHORT_VCF} ==="
