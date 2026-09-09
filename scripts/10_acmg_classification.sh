#!/bin/bash
#SBATCH --job-name=acmg_classify
#SBATCH --output=logs/10_acmg_%j.out
#SBATCH --error=logs/10_acmg_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=infinite

# ============================================================
# 10_acmg_classification.sh
# Runs ANNOVAR annotation on the filtered cohort VCF, then
# InterVar to produce ACMG/AMP classification (Pathogenic,
# Likely Pathogenic, VUS, Likely Benign, Benign) per variant.
#
# Requires manual one-time setup (not scripted, per ANNOVAR
# license terms - registration required):
#   1. Register and download ANNOVAR: https://www.openbioinformatics.org/annovar/annovar_download_form.php
#   2. Extract to tools/annovar/
#   3. Download humandb databases (refGene, clinvar, gnomad, dbnsfp etc):
#        perl tools/annovar/annotate_variation.pl -buildver hg38 -downdb -webfrom annovar refGene tools/annovar/humandb/
#        perl tools/annovar/annotate_variation.pl -buildver hg38 -downdb -webfrom annovar clinvar_20240611 tools/annovar/humandb/
#        perl tools/annovar/annotate_variation.pl -buildver hg38 -downdb -webfrom annovar gnomad211_exome tools/annovar/humandb/
#      (run these on your PC if the HPC has no outbound internet, then rsync humandb/ over)
#   4. Clone InterVar: git clone https://github.com/WGLab/InterVar.git tools/InterVar
#      InterVar bundles its own intervardb - no extra download needed for that part.
#
# Run from project root: sbatch scripts/10_acmg_classification.sh
# ============================================================

set -euo pipefail

PROJECT=$(pwd)
FILTERED_DIR=${PROJECT}/results/filtered_vcf
ACMG_DIR=${PROJECT}/results/acmg
ANNOVAR_DIR=${PROJECT}/tools/annovar
INTERVAR_DIR=${PROJECT}/tools/InterVar
HUMANDB=${ANNOVAR_DIR}/humandb

INPUT_VCF=${FILTERED_DIR}/cohort.filtered.merged.vcf.gz
ANNOVAR_INPUT=${ACMG_DIR}/cohort.avinput
ANNOVAR_PREFIX=${ACMG_DIR}/cohort.annovar

mkdir -p "${ACMG_DIR}" "${PROJECT}/logs"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate uganda_wes2

# WORKAROUND: this environment's perl build dynamically links against
# libnsl.so.1, but conda's activation doesn't automatically put the
# env's lib/ directory on the library search path for it. Without this,
# perl (and anything that calls it, like ANNOVAR's .pl scripts) fails
# with "cannot open shared object file: No such file or directory".
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

if [ ! -s "${INPUT_VCF}" ]; then
    echo "ERROR: Filtered cohort VCF missing (${INPUT_VCF}). Check step 08 completed."
    exit 1
fi

if [ ! -d "${ANNOVAR_DIR}" ] || [ ! -d "${HUMANDB}" ]; then
    echo "ERROR: ANNOVAR and/or humandb directory not found."
    echo "See the setup instructions in the header of this script - ANNOVAR"
    echo "requires manual registration/download and cannot be automated."
    exit 1
fi

if [ ! -d "${INTERVAR_DIR}" ]; then
    echo "ERROR: InterVar not found at ${INTERVAR_DIR}."
    echo "Clone it: git clone https://github.com/WGLab/InterVar.git ${INTERVAR_DIR}"
    exit 1
fi

echo "=== $(date) : Converting VCF to ANNOVAR input format ==="
perl "${ANNOVAR_DIR}/convert2annovar.pl" \
    -format vcf4 "${INPUT_VCF}" \
    -outfile "${ANNOVAR_INPUT}" \
    -allsample -withfreq

echo "=== $(date) : Running ANNOVAR table_annovar.pl ==="
perl "${ANNOVAR_DIR}/table_annovar.pl" \
    "${ANNOVAR_INPUT}" \
    "${HUMANDB}" \
    -buildver hg38 \
    -out "${ANNOVAR_PREFIX}" \
    -remove \
    -protocol refGene,clinvar_20240611,gnomad211_exome,dbnsfp42a \
    -operation g,f,f,f \
    -nastring . \
    -polish

echo "=== $(date) : Configuring InterVar to use absolute ANNOVAR paths ==="
# InterVar's config.ini defaults to relative paths (./annotate_variation.pl,
# ./convert2annovar.pl, ./table_annovar.pl), which only resolve correctly if
# InterVar is run from inside the ANNOVAR directory. Since we run it from
# the project root, rewrite these to absolute paths so it can find them
# regardless of working directory.
CONFIG_INI="${INTERVAR_DIR}/config.ini"
if [ -s "${CONFIG_INI}" ]; then
    sed -i \
        -e "s|^convert2annovar\s*=.*|convert2annovar = ${ANNOVAR_DIR}/convert2annovar.pl|" \
        -e "s|^table_annovar\s*=.*|table_annovar = ${ANNOVAR_DIR}/table_annovar.pl|" \
        -e "s|^annotate_variation\s*=.*|annotate_variation = ${ANNOVAR_DIR}/annotate_variation.pl|" \
        "${CONFIG_INI}"
else
    echo "ERROR: InterVar config.ini not found at ${CONFIG_INI}."
    exit 1
fi

echo "=== $(date) : Running InterVar for ACMG classification ==="
# NOTE: Older InterVar releases require Python 2, but this project's
# conda env (uganda_wes) only has Python 3.11 - there is no python2
# binary available here. Check which InterVar version you cloned:
#   - If it's the WGLab/InterVar main branch (2020+), it supports Python 3
#     and you can just use "python" below.
#   - If you hit "print" statement SyntaxErrors, that confirms it's the
#     old Python 2 version - in that case, create a separate small env:
#       mamba create -n intervar_py2 python=2.7 -y
#     and activate it just for this step, or ask about porting the script.
if ! command -v python2 &> /dev/null; then
    echo "python2 not found in this environment - using python3 instead."
    PYTHON_BIN="python"
else
    PYTHON_BIN="python2"
fi

"${PYTHON_BIN}" "${INTERVAR_DIR}/Intervar.py" \
    -b hg38 \
    -i "${ANNOVAR_PREFIX}.hg38_multianno.txt" \
    --input_type=AVinput \
    -o "${ACMG_DIR}/cohort.intervar" \
    -d "${HUMANDB}" \
    -t "${INTERVAR_DIR}/intervardb"

echo "=== $(date) : ACMG classification summary ==="
if [ -s "${ACMG_DIR}/cohort.intervar.hg38_multianno.txt.intervar" ]; then
    awk -F'\t' 'NR>1 {print $NF}' "${ACMG_DIR}/cohort.intervar.hg38_multianno.txt.intervar" | \
        grep -oP '(Pathogenic|Likely pathogenic|Uncertain significance|Likely benign|Benign)' | \
        sort | uniq -c
fi

echo "=== $(date) : DONE. ACMG classification output in ${ACMG_DIR} ==="
