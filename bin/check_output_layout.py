#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path


REQUIRED_PATTERNS = {
    "validated samplesheet":
        "pipeline_info/samplesheet.validated.csv",

    "input provenance":
        "input_acquisition/provenance/*.input_provenance.tsv",

    "FASTQ integrity":
        "raw_qc/integrity/*.fastq_integrity.tsv",

    "FastQC HTML":
        "raw_qc/fastqc/*.html",

    "FastQC ZIP":
        "raw_qc/fastqc/*.zip",

    "SeqKit statistics":
        "raw_qc/seqkit_stats/*.tsv",

    "pair audit":
        "raw_qc/pair_audit/*.pair_audit.tsv",

    "organelle-filtered FASTQ":
        "organelle_filter/fastq/*.organelle_filtered.fastq.gz",

    "organelle filtering report":
        "organelle_filter/reports/*.organelle_filter_report.tsv",

    "read-length profiles":
        "length_normalization/profiles/*.read_length_profile.tsv",

    "global target length":
        "length_normalization/target_length/global_target_length.tsv",

    "per-sample target lengths":
        "length_normalization/target_length/"
        "target_length_per_sample.tsv",

    "crop reports":
        "length_normalization/reports/*.crop_report.tsv",

    "coverage plans":
        "coverage_sampling/plans/*.coverage_plan.tsv",

    "sampled FASTQ":
        "coverage_sampling/sampled_reads/*.sampled.fastq.gz",

    "sampling reports":
        "coverage_sampling/reports/*.sampling_report.tsv",

    "RepeatExplorer FASTA":
        "repex/fasta/*.repex.fasta",

    "REPEX formatting reports":
        "repex/reports/*.repex_format_report.tsv",

    "REPEX validation reports":
        "repex/validation/*.repex_validation.tsv",
}


OPTIONAL_PATTERNS = {
    "remote provider resolution":
        "input_acquisition/provider_resolution/"
        "*.remote_resolution.json",

    "ENA acquisition manifest":
        "input_acquisition/manifests/"
        "*.acquisition_manifest.tsv",

    "RepeatExplorer output directory":
        "repeatexplorer/results/*_repex",

    "RepeatExplorer log":
        "repeatexplorer/logs/*.repeatexplorer.log",

    "RepeatExplorer run report":
        "repeatexplorer/reports/*.repeatexplorer_run.tsv",
}


def require_matches(
    outdir: Path,
    label: str,
    pattern: str,
) -> bool:
    matches = list(outdir.glob(pattern))

    if not matches:
        print(
            f"FAIL\t{label}\t{pattern}",
            file=sys.stderr,
        )
        return False

    print(
        f"PASS\t{label}\t{len(matches)}"
    )

    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check the published REPEXPREP output layout."
    )

    parser.add_argument(
        "--outdir",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--expect-remote",
        action="store_true",
    )

    parser.add_argument(
        "--expect-ena",
        action="store_true",
    )

    parser.add_argument(
        "--expect-repeatexplorer",
        action="store_true",
    )

    args = parser.parse_args()

    outdir = args.outdir.resolve()

    if not outdir.is_dir():
        raise SystemExit(
            f"Output directory does not exist: {outdir}"
        )

    passed = True

    for label, pattern in REQUIRED_PATTERNS.items():
        passed &= require_matches(
            outdir,
            label,
            pattern,
        )

    if args.expect_remote:
        passed &= require_matches(
            outdir,
            "remote provider resolution",
            OPTIONAL_PATTERNS["remote provider resolution"],
        )

    if args.expect_ena:
        passed &= require_matches(
            outdir,
            "ENA acquisition manifest",
            OPTIONAL_PATTERNS["ENA acquisition manifest"],
        )

    if args.expect_repeatexplorer:
        for label in (
            "RepeatExplorer output directory",
            "RepeatExplorer log",
            "RepeatExplorer run report",
        ):
            passed &= require_matches(
                outdir,
                label,
                OPTIONAL_PATTERNS[label],
            )

    unexpected_versions = list(
        outdir.rglob("versions.yml")
    )

    if unexpected_versions:
        passed = False

        for filename in unexpected_versions:
            print(
                f"FAIL\tunexpected versions.yml\t{filename}",
                file=sys.stderr,
            )
    else:
        print("PASS\tno scattered versions.yml\t0")

    downloaded_fastq = list(
        (
            outdir
            / "input_acquisition"
        ).rglob("*.fastq.gz")
    )

    if downloaded_fastq:
        passed = False

        for filename in downloaded_fastq:
            print(
                f"FAIL\tunexpected downloaded FASTQ\t{filename}",
                file=sys.stderr,
            )
    else:
        print(
            "PASS\tno duplicated acquisition FASTQ\t0"
        )

    normalized_fastq = list(
        (
            outdir
            / "length_normalization"
        ).rglob("*.fastq.gz")
    )

    if normalized_fastq:
        passed = False

        for filename in normalized_fastq:
            print(
                f"FAIL\tunexpected normalized FASTQ\t{filename}",
                file=sys.stderr,
            )
    else:
        print(
            "PASS\tno duplicated normalized FASTQ\t0"
        )

    if not passed:
        raise SystemExit(1)

    print("OUTPUT_LAYOUT_PASS")


if __name__ == "__main__":
    main()
