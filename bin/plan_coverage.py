#!/usr/bin/env python3

import argparse
import csv
import gzip
import math
import sys
from pathlib import Path
from typing import TextIO


COVERAGE_BASIS = "haploid_1C"

COVERAGE_PLAN_FIELDS = [
    "sample",
    "coverage_basis",
    "genome_size_1C_bp",
    "ploidy",
    "effective_genome_size_bp",
    "target_coverage",
    "target_read_length",
    "available_pairs",
    "requested_pairs",
    "sampled_pairs",
    "achieved_coverage",
    "coverage_limited_by_available_reads",
    "sampling_seed",
]


def open_text(path: str) -> TextIO:
    """Open an uncompressed or gzip-compressed text file."""

    if path.endswith(".gz"):
        return gzip.open(path, mode="rt", encoding="utf-8")

    return open(path, mode="rt", encoding="utf-8")


def count_fastq_reads(path: str) -> int:
    """Count FASTQ records and verify the four-line FASTQ structure."""

    lines = 0

    with open_text(path) as handle:
        for _ in handle:
            lines += 1

    if lines % 4 != 0:
        raise ValueError(
            f"FASTQ line count is not divisible by four: {path}"
        )

    return lines // 4


def parse_positive_int(value: object, name: str) -> int:
    """Parse an integer strictly greater than zero."""

    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{name} must be a positive integer, got: {value}"
        ) from exc

    if parsed <= 0:
        raise ValueError(
            f"{name} must be a positive integer, got: {value}"
        )

    return parsed


def parse_nonnegative_int(value: object, name: str) -> int:
    """Parse an integer greater than or equal to zero."""

    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{name} must be a non-negative integer, got: {value}"
        ) from exc

    if parsed < 0:
        raise ValueError(
            f"{name} must be a non-negative integer, got: {value}"
        )

    return parsed


def parse_positive_float(value: object, name: str) -> float:
    """Parse a floating-point number strictly greater than zero."""

    try:
        parsed = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{name} must be a positive number, got: {value}"
        ) from exc

    if parsed <= 0:
        raise ValueError(
            f"{name} must be a positive number, got: {value}"
        )

    return parsed


def read_target_length(path: str) -> int:
    """Read the selected read length from a one-row TSV file."""

    possible_keys = [
        "global_target_length",
        "target_length",
        "target_read_length",
        "selected_length",
    ]

    with open(path, mode="r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    if len(rows) != 1:
        raise ValueError(
            "Expected exactly one row in target-length file: "
            f"{path}; received {len(rows)}."
        )

    row = rows[0]

    for key in possible_keys:
        value = row.get(key)

        if value is not None and str(value).strip():
            return parse_positive_int(
                value,
                "target_read_length",
            )

    raise KeyError(
        "None of the expected target-length columns were found "
        f"with a value: {possible_keys}. "
        f"Observed columns: {list(row.keys())}"
    )


def calculate_coverage_plan(
    genome_size_1c_bp: int,
    target_coverage: float,
    target_read_length: int,
    available_pairs: int,
) -> dict[str, int | float | bool]:
    """Calculate paired-end sampling relative to the haploid 1C genome."""

    if genome_size_1c_bp <= 0:
        raise ValueError(
            "genome_size_1C_bp must be a positive integer."
        )

    if target_coverage <= 0:
        raise ValueError(
            "target_coverage must be greater than zero."
        )

    if target_read_length <= 0:
        raise ValueError(
            "target_read_length must be a positive integer."
        )

    if available_pairs < 0:
        raise ValueError(
            "available_pairs must not be negative."
        )

    requested_pairs = math.ceil(
        (
            genome_size_1c_bp
            * target_coverage
        )
        / (
            2
            * target_read_length
        )
    )

    sampled_pairs = min(
        requested_pairs,
        available_pairs,
    )

    achieved_coverage = (
        sampled_pairs
        * 2
        * target_read_length
        / genome_size_1c_bp
    )

    return {
        "effective_genome_size_bp": genome_size_1c_bp,
        "requested_pairs": requested_pairs,
        "available_pairs": available_pairs,
        "sampled_pairs": sampled_pairs,
        "achieved_coverage": achieved_coverage,
        "coverage_limited_by_available_reads": (
            available_pairs < requested_pairs
        ),
    }


def write_coverage_plan(
    output_path: str,
    sample: str,
    coverage_basis: str,
    genome_size_1c_bp: int,
    ploidy: int,
    target_coverage: float,
    target_read_length: int,
    sampling_seed: int,
    plan: dict[str, int | float | bool],
) -> None:
    """Write the coverage plan as a one-row tab-separated table."""

    limited = bool(
        plan["coverage_limited_by_available_reads"]
    )

    row = {
        "sample": sample,
        "coverage_basis": coverage_basis,
        "genome_size_1C_bp": genome_size_1c_bp,
        "ploidy": ploidy,
        "effective_genome_size_bp": plan[
            "effective_genome_size_bp"
        ],
        "target_coverage": target_coverage,
        "target_read_length": target_read_length,
        "available_pairs": plan["available_pairs"],
        "requested_pairs": plan["requested_pairs"],
        "sampled_pairs": plan["sampled_pairs"],
        "achieved_coverage": (
            f"{float(plan['achieved_coverage']):.8f}"
        ),
        "coverage_limited_by_available_reads": (
            "true" if limited else "false"
        ),
        "sampling_seed": sampling_seed,
    }

    with open(
        output_path,
        mode="w",
        newline="",
        encoding="utf-8",
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=COVERAGE_PLAN_FIELDS,
            delimiter="\t",
            lineterminator="\n",
        )

        writer.writeheader()
        writer.writerow(row)


def build_parser() -> argparse.ArgumentParser:
    """Construct the command-line interface."""

    parser = argparse.ArgumentParser(
        description=(
            "Plan paired-end read sampling relative to the "
            "haploid 1C genome size."
        )
    )

    parser.add_argument(
        "--sample",
        required=True,
        help="Sample identifier.",
    )

    parser.add_argument(
        "--r1",
        required=True,
        help="R1 FASTQ or FASTQ.GZ file.",
    )

    parser.add_argument(
        "--r2",
        required=True,
        help="R2 FASTQ or FASTQ.GZ file.",
    )

    parser.add_argument(
        "--target-length-file",
        required=True,
        help="One-row TSV containing the selected target read length.",
    )

    genome_group = parser.add_mutually_exclusive_group(
        required=True
    )

    genome_group.add_argument(
        "--genome-size-1c-bp",
        dest="genome_size_1c_bp",
        help="Haploid 1C genome size in base pairs.",
    )

    genome_group.add_argument(
        "--genome-size-bp",
        dest="legacy_genome_size_bp",
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--ploidy",
        default=None,
        help=(
            "Optional biological ploidy recorded as metadata. It is not "
            "used to multiply genome_size_1C_bp."
        ),
    )

    parser.add_argument(
        "--coverage-basis",
        default=COVERAGE_BASIS,
        choices=[COVERAGE_BASIS],
        help="Genome-size basis used for coverage calculations.",
    )

    parser.add_argument(
        "--target-coverage",
        required=True,
        help="Requested coverage relative to the haploid 1C genome.",
    )

    parser.add_argument(
        "--sampling-seed",
        required=True,
        help="Non-negative random seed used for read-pair sampling.",
    )

    parser.add_argument(
        "--output",
        required=True,
        help="Output coverage-plan TSV file.",
    )

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.genome_size_1c_bp is not None:
        genome_size_1c_bp = parse_positive_int(
            args.genome_size_1c_bp,
            "genome_size_1C_bp",
        )
    else:
        print(
            "[plan_coverage] WARNING: --genome-size-bp is "
            "deprecated; use --genome-size-1c-bp.",
            file=sys.stderr,
        )

        genome_size_1c_bp = parse_positive_int(
            args.legacy_genome_size_bp,
            "genome_size_bp",
        )

    ploidy = (
        parse_positive_int(
            args.ploidy,
            "ploidy",
        )
        if args.ploidy is not None
        else None
    )

    target_coverage = parse_positive_float(
        args.target_coverage,
        "target_coverage",
    )

    sampling_seed = parse_nonnegative_int(
        args.sampling_seed,
        "sampling_seed",
    )

    target_read_length = read_target_length(
        args.target_length_file
    )

    r1_reads = count_fastq_reads(args.r1)
    r2_reads = count_fastq_reads(args.r2)

    if r1_reads != r2_reads:
        raise ValueError(
            f"R1/R2 read counts differ for {args.sample}: "
            f"R1={r1_reads}, R2={r2_reads}."
        )

    available_pairs = r1_reads

    plan = calculate_coverage_plan(
        genome_size_1c_bp=genome_size_1c_bp,
        target_coverage=target_coverage,
        target_read_length=target_read_length,
        available_pairs=available_pairs,
    )

    write_coverage_plan(
        output_path=args.output,
        sample=args.sample,
        coverage_basis=args.coverage_basis,
        genome_size_1c_bp=genome_size_1c_bp,
        ploidy=ploidy,
        target_coverage=target_coverage,
        target_read_length=target_read_length,
        sampling_seed=sampling_seed,
        plan=plan,
    )

    print(
        f"[plan_coverage] sample={args.sample} "
        f"coverage_basis={args.coverage_basis} "
        f"genome_size_1C_bp={genome_size_1c_bp} "
        f"ploidy={ploidy} "
        f"effective_genome_size_bp="
        f"{plan['effective_genome_size_bp']} "
        f"target_coverage={target_coverage} "
        f"target_read_length={target_read_length} "
        f"available_pairs={plan['available_pairs']} "
        f"requested_pairs={plan['requested_pairs']} "
        f"sampled_pairs={plan['sampled_pairs']} "
        f"achieved_coverage="
        f"{float(plan['achieved_coverage']):.8f} "
        f"coverage_limited_by_available_reads="
        f"{plan['coverage_limited_by_available_reads']} "
        f"sampling_seed={sampling_seed}"
    )

    if int(plan["sampled_pairs"]) == 0:
        print(
            "[plan_coverage] WARNING: No read pairs are "
            "available for sampling.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, csv.Error) as error:
        print(
            f"[plan_coverage] ERROR: {error}",
            file=sys.stderr,
        )
        sys.exit(1)
