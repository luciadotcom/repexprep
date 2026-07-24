#!/usr/bin/env python3

"""
Crop paired-end FASTQ reads to a target length stored in a
global_target_length.tsv file.

A pair is retained only when both R1 and R2 are at least as long as the
selected target. Both reads are cropped to exactly the same length.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import re
import sys
from pathlib import Path
from typing import TextIO


VERSION = "0.1.0"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Crop paired FASTQ reads using one dataset-wide "
            "target read length."
        )
    )

    parser.add_argument(
        "--r1",
        required=True,
        type=Path,
        help="Input R1 FASTQ or FASTQ.GZ.",
    )

    parser.add_argument(
        "--r2",
        required=True,
        type=Path,
        help="Input R2 FASTQ or FASTQ.GZ.",
    )

    parser.add_argument(
        "--sample",
        required=True,
        help="Sample identifier.",
    )

    parser.add_argument(
        "--target-file",
        required=True,
        type=Path,
        help="TSV containing the global_target_length column.",
    )

    parser.add_argument(
        "--output-r1",
        required=True,
        type=Path,
        help="Output cropped R1 FASTQ.GZ.",
    )

    parser.add_argument(
        "--output-r2",
        required=True,
        type=Path,
        help="Output cropped R2 FASTQ.GZ.",
    )

    parser.add_argument(
        "--report",
        required=True,
        type=Path,
        help="Output crop report TSV.",
    )

    parser.add_argument(
        "--version",
        action="version",
        version=VERSION,
    )

    return parser.parse_args()


def open_input(path: Path) -> TextIO:
    if not path.is_file():
        raise FileNotFoundError(
            f"Input FASTQ does not exist: {path}"
        )

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


def open_output(path: Path) -> TextIO:
    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    if path.suffix.lower() == ".gz":
        return gzip.open(
            path,
            mode="wt",
            encoding="utf-8",
            newline="",
        )

    return path.open(
        mode="w",
        encoding="utf-8",
        newline="",
    )


def normalize_read_id(header: str) -> str:
    token = header[1:].split()[0]
    return re.sub(r"/[12]$", "", token)


def read_fastq_record(
    handle: TextIO,
    source: Path,
    record_number: int,
) -> tuple[str, str, str, str] | None:
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
            f"Invalid FASTQ header in record {record_number} "
            f"of {source}"
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

    return (
        header,
        sequence,
        separator,
        quality,
    )


def read_global_target(target_file: Path) -> int:
    if not target_file.is_file():
        raise FileNotFoundError(
            f"Global target file does not exist: {target_file}"
        )

    with target_file.open(
        newline="",
        encoding="utf-8",
    ) as handle:
        reader = csv.DictReader(
            handle,
            delimiter="\t",
        )

        if not reader.fieldnames:
            raise ValueError(
                f"Target file has no header: {target_file}"
            )

        if "global_target_length" not in reader.fieldnames:
            raise ValueError(
                "Target file must contain a column named "
                "'global_target_length'."
            )

        row = next(reader, None)

    if row is None:
        raise ValueError(
            f"Target file contains no data rows: {target_file}"
        )

    value = row["global_target_length"].strip()

    try:
        target_length = int(value)
    except ValueError as error:
        raise ValueError(
            f"Invalid global_target_length value: {value!r}"
        ) from error

    if target_length < 1:
        raise ValueError(
            "global_target_length must be greater than zero."
        )

    return target_length


def write_record(
    handle: TextIO,
    header: str,
    sequence: str,
    separator: str,
    quality: str,
) -> None:
    handle.write(f"{header}\n")
    handle.write(f"{sequence}\n")
    handle.write(f"{separator}\n")
    handle.write(f"{quality}\n")


def write_report(
    report: Path,
    sample: str,
    target_length: int,
    input_pairs: int,
    retained_pairs: int,
) -> None:
    report.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    discarded_pairs = input_pairs - retained_pairs

    retained_fraction = (
        retained_pairs / input_pairs
        if input_pairs > 0
        else 0.0
    )

    fieldnames = [
        "sample",
        "target_read_length",
        "input_pairs",
        "retained_pairs",
        "discarded_pairs",
        "retained_fraction",
    ]

    with report.open(
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
                "target_read_length": target_length,
                "input_pairs": input_pairs,
                "retained_pairs": retained_pairs,
                "discarded_pairs": discarded_pairs,
                "retained_fraction": (
                    f"{retained_fraction:.6f}"
                ),
            }
        )


def run(args: argparse.Namespace) -> None:
    target_length = read_global_target(
        args.target_file
    )

    input_pairs = 0
    retained_pairs = 0

    with (
        open_input(args.r1) as r1_handle,
        open_input(args.r2) as r2_handle,
        open_output(args.output_r1) as r1_output,
        open_output(args.output_r2) as r2_output,
    ):
        while True:
            record_number = input_pairs + 1

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

            (
                r1_header,
                r1_sequence,
                r1_separator,
                r1_quality,
            ) = r1_record

            (
                r2_header,
                r2_sequence,
                r2_separator,
                r2_quality,
            ) = r2_record

            r1_id = normalize_read_id(r1_header)
            r2_id = normalize_read_id(r2_header)

            if r1_id != r2_id:
                raise ValueError(
                    f"Paired-read identifiers differ at pair "
                    f"{record_number}: {r1_id!r} != {r2_id!r}"
                )

            input_pairs += 1

            if (
                len(r1_sequence) < target_length
                or len(r2_sequence) < target_length
            ):
                continue

            write_record(
                r1_output,
                r1_header,
                r1_sequence[:target_length],
                r1_separator,
                r1_quality[:target_length],
            )

            write_record(
                r2_output,
                r2_header,
                r2_sequence[:target_length],
                r2_separator,
                r2_quality[:target_length],
            )

            retained_pairs += 1

    if input_pairs == 0:
        raise ValueError(
            "Input FASTQ files contain no read pairs."
        )

    if retained_pairs == 0:
        raise ValueError(
            f"No complete read pairs reach the selected target "
            f"length of {target_length} bp."
        )

    write_report(
        report=args.report,
        sample=args.sample,
        target_length=target_length,
        input_pairs=input_pairs,
        retained_pairs=retained_pairs,
    )


def main() -> int:
    args = parse_arguments()

    try:
        run(args)
    except (OSError, ValueError) as error:
        print(
            f"ERROR: {error}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())