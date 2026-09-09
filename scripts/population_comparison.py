#!/usr/bin/env python3
"""
population_comparison.py

Parses a VEP-annotated, cohort-AF-tagged VCF and compares cohort
allele frequency against gnomAD allele frequency (as annotated by
VEP's --af_gnomad in step 09). Flags variants as candidate
population-specific if they are common in this cohort but rare or
absent in gnomAD.

Usage:
    python3 population_comparison.py --input-vcf cohort.with_af.vcf.gz \\
        --output-csv population_comparison.csv \\
        --output-candidates candidate_population_specific_variants.csv
"""

import argparse
import gzip
import csv
import re
import sys


def open_vcf(path):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "r")


def parse_info_field(info_str, key):
    """Extract a single key's value from a VCF INFO field string."""
    match = re.search(rf"(?:^|;){re.escape(key)}=([^;]+)", info_str)
    return match.group(1) if match else None


def parse_csq_field(info_str, csq_format_fields):
    """
    Extract the CSQ (VEP consequence) annotation block and return it
    as a dict using the field order from the VCF header's CSQ format.
    Only the first transcript/allele annotation is used, matching the
    --pick_allele_gene option used in step 09.
    """
    csq_raw = parse_info_field(info_str, "CSQ")
    if not csq_raw:
        return {}
    first_annotation = csq_raw.split(",")[0]
    values = first_annotation.split("|")
    return dict(zip(csq_format_fields, values))


def get_csq_format_fields(vcf_path):
    """Read the VCF header to find the CSQ field order VEP used."""
    with open_vcf(vcf_path) as f:
        for line in f:
            if line.startswith("##INFO=<ID=CSQ"):
                match = re.search(r'Format: ([^">]+)', line)
                if match:
                    return match.group(1).split("|")
            if not line.startswith("#"):
                break
    return []


def main():
    parser = argparse.ArgumentParser(description="Compare cohort AF vs gnomAD AF")
    parser.add_argument("--input-vcf", required=True)
    parser.add_argument("--output-csv", required=True)
    parser.add_argument("--output-candidates", required=True)
    parser.add_argument(
        "--gnomad-rare-threshold",
        type=float,
        default=0.01,
        help="gnomAD AF below this is considered rare/absent (default 0.01)",
    )
    parser.add_argument(
        "--cohort-common-threshold",
        type=float,
        default=0.10,
        help="Cohort AF above this is considered common in this cohort (default 0.10)",
    )
    args = parser.parse_args()

    csq_fields = get_csq_format_fields(args.input_vcf)
    if not csq_fields:
        print(
            "WARNING: Could not find CSQ format fields in VCF header. "
            "gnomAD/consequence columns may be empty.",
            file=sys.stderr,
        )

    gnomad_af_field_candidates = ["gnomADe_AF", "gnomAD_AF", "gnomADg_AF"]

    rows = []
    with open_vcf(args.input_vcf) as f:
        for line in f:
            if line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 8:
                continue
            chrom, pos, variant_id, ref, alt, qual, filt, info = fields[:8]

            if filt not in (".", "PASS"):
                continue

            cohort_af_str = parse_info_field(info, "AF")
            try:
                cohort_af = float(cohort_af_str.split(",")[0]) if cohort_af_str else None
            except ValueError:
                cohort_af = None

            csq = parse_csq_field(info, csq_fields)
            gene = csq.get("SYMBOL", csq.get("Gene", "."))
            consequence = csq.get("Consequence", ".")
            clinvar_sig = csq.get("CLIN_SIG", csq.get("CLNSIG", "."))

            gnomad_af = None
            for field_name in gnomad_af_field_candidates:
                if field_name in csq and csq[field_name] not in ("", "."):
                    try:
                        gnomad_af = float(csq[field_name])
                        break
                    except ValueError:
                        continue

            rows.append(
                {
                    "CHROM": chrom,
                    "POS": pos,
                    "ID": variant_id,
                    "REF": ref,
                    "ALT": alt,
                    "GENE": gene,
                    "CONSEQUENCE": consequence,
                    "CLINVAR_SIG": clinvar_sig,
                    "COHORT_AF": cohort_af,
                    "GNOMAD_AF": gnomad_af,
                }
            )

    if not rows:
        print("WARNING: No PASS variants found in input VCF.", file=sys.stderr)

    with open(args.output_csv, "w", newline="") as out_f:
        writer = csv.DictWriter(out_f, fieldnames=list(rows[0].keys()) if rows else [])
        writer.writeheader()
        writer.writerows(rows)

    candidates = [
        r
        for r in rows
        if r["COHORT_AF"] is not None
        and r["COHORT_AF"] >= args.cohort_common_threshold
        and (r["GNOMAD_AF"] is None or r["GNOMAD_AF"] < args.gnomad_rare_threshold)
    ]

    with open(args.output_candidates, "w", newline="") as out_f:
        writer = csv.DictWriter(out_f, fieldnames=list(rows[0].keys()) if rows else [])
        writer.writeheader()
        writer.writerows(candidates)

    print(f"Total PASS variants processed: {len(rows)}")
    print(f"Candidate population-specific variants flagged: {len(candidates)}")


if __name__ == "__main__":
    main()
