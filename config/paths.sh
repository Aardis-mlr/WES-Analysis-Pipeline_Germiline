#!/usr/bin/env bash
PROJECT=$(pwd)

RAW=${PROJECT}/data/raw_fastq
TRIM=${PROJECT}/data/trimmed
REF=${PROJECT}/data/reference
KNOWN=${PROJECT}/data/known_sites

RESULTS=${PROJECT}/results
FASTQC=${RESULTS}/fastqc
MULTIQC=${RESULTS}/multiqc
TRIMMED_RESULTS=${RESULTS}/trimmed
ALIGN=${RESULTS}/alignment
BAM=${RESULTS}/bam
METRICS=${RESULTS}/metrics
GVCF=${RESULTS}/gvcf
VCF=${RESULTS}/vcf
FILTERED_VCF=${RESULTS}/filtered_vcf
ANNOT=${RESULTS}/annotation
ACMG=${RESULTS}/acmg
POPULATION=${RESULTS}/population
FIGURES=${RESULTS}/figures
TABLES=${RESULTS}/tables

LOGS=${PROJECT}/logs
SCRIPTS=${PROJECT}/scripts
CONFIG=${PROJECT}/config
