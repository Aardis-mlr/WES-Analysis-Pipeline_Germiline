#!/bin/bash
#SBATCH --job-name=wes_breast
#SBATCH --output=logs/full_pipeline_%j.out
#SBATCH --error=logs/full_pipeline_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=infinite

# ============================================================
# run_full_pipeline.sh
# Runs the entire Uganda WES pipeline (steps 02-11) as ONE
# SLURM job, in sequence. Each step script handles its own
# conda environment activation internally, so they are called
# directly here rather than via sbatch.
#
# Stops immediately if any step fails (set -e), so a broken
# step won't let later steps run on incomplete/missing input.
#
# Run from project root: sbatch scripts/run_full_pipeline.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
SCRIPTS=${PROJECT}/scripts
mkdir -p "${PROJECT}/logs"

run_step () {
    local step_name="$1"
    local script_path="$2"
    echo ""
    echo "################################################################"
    echo "### $(date) : STARTING ${step_name}"
    echo "################################################################"
    bash "${script_path}"
    echo "### $(date) : FINISHED ${step_name}"
}

# Put a # on a step that has already completed, if the script stops or starts in the middle

# run_step "02 - FastQC + fastp"           "${SCRIPTS}/02_fastqc_fastp.sh"
# run_step "03 - BWA alignment"            "${SCRIPTS}/03_bwa_alignment.sh"
# run_step "04 - Mark duplicates"          "${SCRIPTS}/04_markduplicates.sh"
# run_step "05 - BQSR"                     "${SCRIPTS}/05_bqsr.sh"
# run_step "06 - Variant calling"          "${SCRIPTS}/06_variant_calling.sh"
# run_step "07 - Joint genotyping"         "${SCRIPTS}/07_joint_genotyping.sh"
# run_step "08 - Variant filtering"        "${SCRIPTS}/08_variant_filtering.sh"
run_step "09 - VEP annotation"           "${SCRIPTS}/09_annotation.sh"
run_step "10 - ACMG classification"      "${SCRIPTS}/10_acmg_classification.sh"
run_step "11 - Population comparison"    "${SCRIPTS}/11_population_comparison.sh"

echo ""
echo "################################################################"
echo "### $(date) : FULL PIPELINE COMPLETE"
echo "################################################################"
