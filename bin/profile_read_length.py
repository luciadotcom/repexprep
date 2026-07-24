#!/usr/bin/env python3

"""
Profile paired-end FASTQ read lengths and calculate one candidate
target length for a single sample.

The candidate is the greatest target length that retains at least the
requested fraction of complete read pairs.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import math
import re
import sys
from collections import Counter
from pathlib import Path
from typing import TextIO


VERSION = "0.1.0"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Profile paired-end FASTQ read lengths and calculate a "
            "retention-controlled candidate target length."
        )
    )

    parser.add_argument(
        "--r1",
        required=True,
        type=Path,
        help="R1 FASTQ or FASTQ.GZ file.",
    )

    parser.add_argument(
        "--r2",
        required=True,
        type=Path,
        help="R2 FASTQ or FASTQ.GZ file.",
    )

    parser.add_argument(
        "--sample",
        required=True,
        help="Sample identifier written to the output report.",
    )

    parser.add_argument(
        "--min-retained-fraction",
        required=True,
        type=float,
        help="Minimum desired fraction of complete read pairs retained.",
    )

    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Output read-length profile TSV.",
    )

    parser.add_argument(
        "--version",
        action="version",
        version=VERSION,
    )

    return parser.parse_args()


def open_fastq(path: Path) -> TextIO:
    """Open plain-text or gzipped FASTQ input."""

    if not path.is_file():
        raise FileNotFoundError(f"FASTQ file does not exist: {path}")

    if path.suffix.lower() == ".gz":
        return gzip.open(
            path,
            mode="rt",
            encoding="utf-8",
            newline="",
        )

    return path.open(
        mode="rt",
        encoding="utf-8",
        newline="",
    )


def normalize_read_id(header: str) -> str:
    """
    Return the primary FASTQ identifier without a terminal /1 or /2.

    Illumina headers containing read information after a space already
    share the same first token between R1 and R2.
    """

    token = header[1:].split()[0]
    return re.sub(r"/[12]$", "", token)


def read_fastq_record(
    handle: TextIO,
    source: Path,
    record_number: int,
) -> tuple[str, str] | None:
    """Read and validate one four-line FASTQ record."""

    header = handle.readline()

    if header == "":
        return None

    sequence = handle.readline()
    separator = handle.readline()
    quality = handle.readline()

    if sequence == "" or separator == "" or quality == "":
        raise ValueError(
            f"Incomplete FASTQ record {record_number} in {source}"
        )

    header = header.rstrip("\r\n")
    sequence = sequence.rstrip("\r\n")
    separator = separator.rstrip("\r\n")
    quality = quality.rstrip("\r\n")

    if not header.startswith("@"):
        raise ValueError(
            f"Invalid FASTQ header in record {record_number} of {source}: "
            f"{header!r}"
        )

    if not separator.startswith("+"):
        raise ValueError(
            f"Invalid FASTQ separator in record {record_number} "
            f"of {source}"
        )

    if len(sequence) != len(quality):
        raise ValueError(
            f"Sequence and quality lengths differ in record "
            f"{record_number} of {source}"
        )

    return header, sequence


def choose_candidate_length(
    histogram: Counter[int],
    total_pairs: int,
    min_retained_fraction: float,
) -> tuple[int, int, float]:
    """
    Choose the greatest length retaining the requested pair fraction.
    """

    required_pairs = math.ceil(
        total_pairs * min_retained_fraction
    )

    retained_pairs = 0
    candidate_length: int | None = None

    for read_length in sorted(histogram, reverse=True):
        retained_pairs += histogram[read_length]

        if retained_pairs >= required_pairs:
            candidate_length = read_length
            break

    if candidate_length is None:
        raise RuntimeError(
            "Unable to select a candidate target length."
        )

    retained_fraction = retained_pairs / total_pairs

    return (
        candidate_length,
        retained_pairs,
        retained_fraction,
    )


def write_report(
    output: Path,
    sample: str,
    total_pairs: int,
    observed_min: int,
    observed_max: int,
    candidate_length: int,
    retained_pairs: int,
    retained_fraction: float,
    requested_fraction: float,
) -> None:
    """Write the one-row read-length profile report."""

    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    fieldnames = [
        "sample",
        "total_pairs",
        "observed_min_pair_length",
        "observed_max_pair_length",
        "candidate_target_length",
        "expected_retained_pairs",
        "expected_retained_fraction",
        "requested_min_retained_fraction",
    ]

    with output.open(
        mode="w",
        encoding="utf-8",
        newline="",
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=fieldnames,
            delimiter="\t",
            lineterminator="\n",
        )

        writer.writeheader()

        writer.writerow(
            {
                "sample": sample,
                "total_pairs": total_pairs,
                "observed_min_pair_length": observed_min,
                "observed_max_pair_length": observed_max,
                "candidate_target_length": candidate_length,
                "expected_retained_pairs": retained_pairs,
                "expected_retained_fraction": (
                    f"{retained_fraction:.6f}"
                ),
                "requested_min_retained_fraction": (
                    f"{requested_fraction:.6f}"
                ),
            }
        )


def run(args: argparse.Namespace) -> None:
    if not 0 < args.min_retained_fraction <= 1:
        raise ValueError(
            "--min-retained-fraction must be greater than 0 "
            "and less than or equal to 1."
        )

    length_histogram: Counter[int] = Counter()
    total_pairs = 0

    with open_fastq(args.r1) as r1_handle, open_fastq(
        args.r2
    ) as r2_handle:

        while True:
            record_number = total_pairs + 1

            r1_record = read_fastq_record(
                r1_handle,
                args.r1,
                record_number,
            )

            r2_record = read_fastq_record(
                r2_handle,
                args.r2,
                record_number,
            )

            if r1_record is None and r2_record is None:
                break

            if r1_record is None or r2_record is None:
                raise ValueError(
                    "R1 and R2 contain different numbers of records."
                )

            r1_header, r1_sequence = r1_record
            r2_header, r2_sequence = r2_record

            r1_id = normalize_read_id(r1_header)
            r2_id = normalize_read_id(r2_header)

            if r1_id != r2_id:
                raise ValueError(
                    f"Paired-read identifiers differ at pair "
                    f"{record_number}: {r1_id!r} != {r2_id!r}"
                )

            pair_min_length = min(
                len(r1_sequence),
                len(r2_sequence),
            )

            length_histogram[pair_min_length] += 1
            total_pairs += 1

    if total_pairs == 0:
        raise ValueError(
            "The paired FASTQ files contain no read pairs."
        )

    (
        candidate_length,
        retained_pairs,
        retained_fraction,
    ) = choose_candidate_length(
        histogram=length_histogram,
        total_pairs=total_pairs,
        min_retained_fraction=args.min_retained_fraction,
    )

    write_report(
        output=args.output,
        sample=args.sample,
        total_pairs=total_pairs,
        observed_min=min(length_histogram),
        observed_max=max(length_histogram),
        candidate_length=candidate_length,
        retained_pairs=retained_pairs,
        retained_fraction=retained_fraction,
        requested_fraction=args.min_retained_fraction,
    )


def main() -> int:
    args = parse_arguments()

    try:
        run(args)
    except (OSError, RuntimeError, ValueError) as error:
        print(
            f"ERROR: {error}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
