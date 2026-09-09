# Pipeline Workflow

Full sequence, step by step. Each script is idempotent-ish (safe to
rerun) and checks for its required input before starting, failing
loudly rather than silently skipping if something upstream is
missing.

## Prerequisites (one-time setup)

| # | Script | What it does |
|---|---|---|
| 00 | `00_download_reference.sh` | Downloads GRCh38 reference FASTA + dbSNP/Mills known-sites VCFs |
| 01 | `01_index_reference.sh` | `samtools faidx` + `bwa index` on the reference |

Manual (not scripted, license/registration required):
- **ANNOVAR**: register at openbioinformatics.org, download, extract to `tools/annovar/`
- **InterVar**: `git clone https://github.com/WGLab/InterVar.git tools/InterVar`
- **VEP cache**: download the indexed cache tarball for the installed VEP release, extract to `resources/vep_cache/`
- **ClinVar VCF**: download to `resources/clinvar.vcf.gz` (+ `.tbi`)
- **ANNOVAR humandb databases**: refGene, clinvar, gnomad211_exome, dbnsfp42a via `annotate_variation.pl -downdb` (see `download_annovar_db.sh`)
- **InterVar's own databases + `mim2gene.txt`**: auto-downloaded on first run of step 10, or fetched manually

## Main pipeline

| # | Script | Input | Output | Tool(s) | Env |
|---|---|---|---|---|---|
| 02 | `02_fastqc_fastp.sh` | `data/raw_fastq/*.fastq.gz` | `data/trimmed/*.trim.fastq.gz`, QC reports | FastQC, fastp, MultiQC | uganda_wes |
| 03 | `03_bwa_alignment.sh` | trimmed FASTQs | `results/bam/*.sorted.bam` | BWA-MEM, samtools | uganda_wes |
| 04 | `04_markduplicates.sh` | sorted BAM | `results/bam/*.dedup.bam` | GATK MarkDuplicates | uganda_wes |
| 05 | `05_bqsr.sh` | dedup BAM + known sites | `results/bam/*.recal.bam` | GATK BaseRecalibrator/ApplyBQSR | uganda_wes |
| 06 | `06_variant_calling.sh` | recal BAM | `results/gvcf/*.g.vcf.gz` | GATK HaplotypeCaller | uganda_wes |
| 07 | `07_joint_genotyping.sh` | all sample GVCFs | `results/vcf/cohort.joint.vcf.gz` | GATK GenomicsDBImport, GenotypeGVCFs | uganda_wes |
| 08 | `08_variant_filtering.sh` | joint VCF | `results/filtered_vcf/cohort.filtered.merged.vcf.gz` | GATK SelectVariants, VariantFiltration | uganda_wes |
| 09 | `09_annotation.sh` | filtered VCF | `results/annotation/cohort.annotated.vcf.gz` | VEP + ClinVar custom annotation | **uganda_wes2** |
| 10 | `10_acmg_classification.sh` | filtered VCF | `results/acmg/cohort.intervar.hg38_multianno.txt.intervar` | ANNOVAR → InterVar | **uganda_wes2** |
| 11 | `11_population_comparison.sh` | annotated VCF | `results/tables/candidate_population_specific_variants.csv` | bcftools, `population_comparison.py` | uganda_wes |

## Sample scaling

All scripts (02–11) loop over `config/samples.csv`. Adding samples
requires only appending rows there — no script changes needed. Steps
06 onward (per-sample calling → joint genotyping) benefit statistically
from a larger cohort; joint genotyping in particular is why calling is
split per-sample (06) before combining (07), rather than calling
directly on a merged BAM set.

## Running

**Step by step** (recommended while validating a new sample batch):
```bash
sbatch scripts/03_bwa_alignment.sh
myjobs
cat logs/03_align_<jobid>.out    # confirm success before proceeding
sbatch scripts/04_markduplicates.sh
...
```

**All at once** (once the chain is validated):
```bash
sbatch scripts/run_full_pipeline.sh
```
Comment out any steps already completed at the top of that script
before submitting, to avoid redoing finished work.

## Output map

```
results/
├── bam/            sorted, dedup, and recalibrated BAMs per sample
├── gvcf/            per-sample GVCFs
├── vcf/              joint-genotyped cohort VCF
├── filtered_vcf/  hard-filtered SNPs/indels, merged
├── annotation/    VEP + ClinVar annotated VCF, summary HTML
├── acmg/              ANNOVAR + InterVar classification output
├── population/    cohort VCF with computed allele frequencies
├── tables/            population_comparison.csv, candidate_population_specific_variants.csv
├── metrics/          QC metrics per sample (flagstat, dup rate, BQSR table)
└── multiqc/          aggregated QC report (HTML)
```

`results/tables/candidate_population_specific_variants.csv` and
`results/acmg/cohort.intervar.hg38_multianno.txt.intervar` are the
two files that most directly answer the project's core objectives —
population-specific variant candidates and ACMG clinical
classification, respectively.
