#!/usr/bin/env python3
"""
build_cancer_gene_bed.py

Extracts exon coordinates for a curated panel of well-established
hereditary cancer genes from UCSC refGene.txt (already downloaded
for ANNOVAR), and writes a BED file usable as -L target_regions.bed
for HaplotypeCaller / GenomicsDBImport.

Usage:
    python3 build_cancer_gene_bed.py \\
        --refgene tools/annovar/humandb/hg38_refGene.txt \\
        --output data/reference/target_regions.bed \\
        --padding 20
"""

import argparse
import csv

# Curated hereditary cancer gene panel - covers the major syndromes:
# breast/ovarian, Lynch/colorectal, and other high-penetrance
# cancer predisposition genes commonly included in clinical panels.
CANCER_GENE_PANEL = [
    # Breast/ovarian
    "BRCA1", "BRCA2", "PALB2", "CHEK2", "ATM", "BARD1",
    "RAD51C", "RAD51D", "BRIP1", "TP53", "PTEN", "STK11", "CDH1",
    # Lynch syndrome / colorectal
    "MLH1", "MSH2", "MSH6", "PMS2", "EPCAM", "APC", "MUTYH",
    "POLE", "POLD1",
    # Other well-established cancer predisposition genes
    "VHL", "RET", "MEN1", "SDHB", "SDHC", "SDHD", "SDHAF2",
    "TSC1", "TSC2", "NF1", "NF2", "WT1", "RB1", "SMAD4",
    "BMPR1A", "PTCH1", "MSH3", "AXIN2", "GREM1", "POT1",
    "FH", "FLCN", "MET", "CDKN2A", "CDK4", "TERT",
]

REFGENE_COLUMNS = [
    "bin", "name", "chrom", "strand", "txStart", "txEnd",
    "cdsStart", "cdsEnd", "exonCount", "exonStarts", "exonEnds",
    "score", "name2", "cdsStartStat", "cdsEndStat", "exonFrames",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--refgene", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--padding", type=int, default=20,
                         help="Bases to pad each exon by (default 20, catches splice sites)")
    args = parser.parse_args()

    panel_set = set(CANCER_GENE_PANEL)
    found_genes = set()
    intervals = []

    with open(args.refgene) as f:
        reader = csv.reader(f, delimiter="\t")
        for row in reader:
            record = dict(zip(REFGENE_COLUMNS, row))
            gene = record.get("name2", "")
            if gene not in panel_set:
                continue
            found_genes.add(gene)
            chrom = record["chrom"]
            # Skip alt contigs / non-standard chromosomes
            if "_" in chrom:
                continue
            exon_starts = record["exonStarts"].strip(",").split(",")
            exon_ends = record["exonEnds"].strip(",").split(",")
            for start, end in zip(exon_starts, exon_ends):
                padded_start = max(0, int(start) - args.padding)
                padded_end = int(end) + args.padding
                intervals.append((chrom, padded_start, padded_end, gene))

    missing = panel_set - found_genes
    if missing:
        print(f"WARNING: {len(missing)} genes not found in refGene: {sorted(missing)}")

    # Sort by chromosome then start position
    intervals.sort(key=lambda x: (x[0], x[1]))

    with open(args.output, "w") as out:
        for chrom, start, end, gene in intervals:
            out.write(f"{chrom}\t{start}\t{end}\t{gene}\n")

    print(f"Genes found: {len(found_genes)}/{len(panel_set)}")
    print(f"Exon intervals written: {len(intervals)}")
    print(f"Output: {args.output}")
    print("NOTE: run 'bedtools sort | bedtools merge' on this file next to collapse overlapping exons.")


if __name__ == "__main__":
    main()
