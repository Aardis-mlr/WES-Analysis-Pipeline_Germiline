#!/usr/bin/env bash
#
# check_env.sh
#
# Verify the Uganda WES bioinformatics environment.
#
# Usage:
#   ./check_env.sh
#
# A report is written to:
#   environment_report.txt
#

set -uo pipefail

REPORT="environment_report.txt"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

TOOLS=(
python
pip
fastqc
multiqc
fastp
bwa
samtools
bedtools
picard
gatk
bcftools
vcftools
tabix
vep
parallel
pigz
wget
curl
unzip
Rscript
)

PYTHON_PACKAGES=(
pandas
numpy
scipy
matplotlib
plotly
yaml
Bio
)

R_PACKAGES=(
tidyverse
data.table
optparse
pheatmap
ggrepel
)

missing_tools=0
missing_python=0
missing_r=0

exec > >(tee "$REPORT") 2>&1

echo
echo "=========================================================================="
echo "            Uganda WES Environment Verification Report"
echo "=========================================================================="
echo "Date      : $(date)"
echo "Hostname  : $(hostname)"
echo "User      : $(whoami)"
echo "Conda Env : ${CONDA_DEFAULT_ENV:-Not Activated}"
echo "=========================================================================="
echo

printf "%-15s %-10s %-45s\n" "Tool" "Status" "Version"
printf "%-15s %-10s %-45s\n" "---------------" "----------" "---------------------------------------------"

get_version() {

    case "$1" in

        python)
            python --version 2>&1
            ;;

        pip)
            pip --version 2>&1 | awk '{print $2}'
            ;;

        fastqc)
            fastqc --version 2>&1
            ;;

        multiqc)
            multiqc --version 2>&1
            ;;

        fastp)
            fastp --version 2>&1 | head -1
            ;;

        bwa)
            bwa 2>&1 | awk '/Version/{print $2; exit}'
            ;;

        samtools)
            samtools --version 2>&1 | grep -m1 "Version"
            ;;

        bedtools)
            bedtools --version 2>&1
            ;;

        picard)
            picard CreateSequenceDictionary --version 2>&1 | head -1
            ;;

        gatk)
            gatk --version 2>&1 | grep -m1 "Genome Analysis Tookkit"
            ;;

        bcftools)
            bcftools --version 2>&1 | head -1
            ;;

        vcftools)
            vcftools --version 2>&1 | head -1
            ;;

        tabix)
            tabix --version 2>&1 | head -1
            ;;

        vep)
            vep --help 2>&1 | grep -m1 "ensembl-vep"
            ;;

        parallel)
            parallel --version | head -1
            ;;

        pigz)
            pigz --version 2>&1 | head -1
            ;;

        wget)
            wget --version | head -1
            ;;

        curl)
            curl --version | head -1
            ;;

        unzip)
            unzip -v | head -1
            ;;

        Rscript)
            Rscript --version 2>&1
            ;;

        *)
            echo "Unknown"
            ;;
    esac
}

for tool in "${TOOLS[@]}"; do

    if command -v "$tool" >/dev/null 2>&1; then

        version=$(get_version "$tool")

        printf "%-15s ${GREEN}%-10s${NC} %-45s\n" \
            "$tool" "OK" "$version"

    else

        printf "%-15s ${RED}%-10s${NC} %-45s\n" \
            "$tool" "MISSING" "-"

        ((missing_tools++))

    fi

done

echo
echo "========================================================================="
echo "Python Packages"
echo "========================================================================="

python <<'EOF'
import importlib

packages = [
"pandas",
"numpy",
"scipy",
"matplotlib",
"plotly",
"yaml",
"Bio"
]

print(f'{"Package":15} {"Status":10} Version')
print("-"*45)

for pkg in packages:

    try:
        module = importlib.import_module(pkg)
        version = getattr(module,"__version__","Installed")
        print(f'{pkg:15} OK         {version}')

    except ImportError:
        print(f'{pkg:15} MISSING')
EOF

echo
echo "========================================================================="
echo "R Packages"
echo "========================================================================="

Rscript - <<'EOF'

pkgs <- c(
"tidyverse",
"data.table",
"optparse",
"pheatmap",
"ggrepel"
)

cat(sprintf("%-15s %-10s %s\n","Package","Status","Version"))
cat(rep("-",45),"\n",sep="")

for(p in pkgs){

    if(requireNamespace(p,quietly=TRUE)){

        cat(sprintf("%-15s %-10s %s\n",
            p,
            "OK",
            as.character(packageVersion(p))))

    }else{

        cat(sprintf("%-15s %-10s %s\n",
            p,
            "MISSING",
            "-"))

    }

}
EOF

echo
echo "========================================================================="
echo "SUMMARY"
echo "========================================================================="

echo "Missing command-line tools : $missing_tools"

echo
echo "Report saved to: $REPORT"

echo "========================================================================="
