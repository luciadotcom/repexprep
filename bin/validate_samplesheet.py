#!/usr/bin/env python3

import argparse
import csv
import re
import sys
from pathlib import Path


REQUIRED_COLUMNS = [
    "sample",
    "fastq_1",
    "fastq_2",
]

OPTIONAL_COLUMNS = [
    "organism",
    "genome_size_bp",
    "ploidy",
    "organelle_fasta",
    "target_coverage",
    "target_read_length",
]

SAMPLE_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


def die(message: str) -> None:
    """Print an error message and terminate the program."""
    print(f"[validate_samplesheet] ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def resolve_input_path(raw_path: str, base_dir: Path) -> Path:
    """Resolve a relative input path against the selected base directory."""
    path = Path(raw_path)

    if path.is_absolute():
        return path.resolve()

    return (base_dir / path).resolve()


def check_fastq_path(path: Path, row_number: int, column: str) -> None:
    """Check that a FASTQ path exists and has an accepted extension."""
    if not path.exists():
        die(
            f"Row {row_number}: file in column "
            f"'{column}' does not exist: {path}"
        )

    if not path.is_file():
        die(
            f"Row {row_number}: path in column "
            f"'{column}' is not a file: {path}"
        )

    valid_suffixes = (
        ".fastq.gz",
        ".fq.gz",
        ".fastq",
        ".fq",
    )

    if not path.name.endswith(valid_suffixes):
        die(
            f"Row {row_number}: file in column '{column}' "
            f"does not look like FASTQ or FASTQ.GZ: {path}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a paired-end WGS samplesheet for REPEXPREP."
        )
    )

    parser.add_argument(
        "--input",
        required=True,
        help="Input samplesheet CSV",
    )

    parser.add_argument(
        "--output",
        required=True,
        help="Validated output CSV",
    )

    parser.add_argument(
        "--base-dir",
        default=".",
        help="Base directory used to resolve relative FASTQ paths",
    )

    args = parser.parse_args()

    samplesheet = Path(args.input)
    output_path = Path(args.output)
    base_dir = Path(args.base_dir).resolve()

    if not samplesheet.exists():
        die(f"Samplesheet does not exist: {samplesheet}")

    if not samplesheet.is_file():
        die(f"Samplesheet path is not a file: {samplesheet}")

    rows = []

    with samplesheet.open(
        mode="r",
        newline="",
        encoding="utf-8",
    ) as handle:
        reader = csv.DictReader(handle)

        if reader.fieldnames is None:
            die("Samplesheet is empty or has no header.")

        fieldnames = [
            field.strip() if isinstance(field, str) else field
            for field in reader.fieldnames
        ]

        reader.fieldnames = fieldnames

        missing_columns = [
            column
            for column in REQUIRED_COLUMNS
            if column not in fieldnames
        ]

        if missing_columns:
            die(
                "Missing required column(s): "
                + ", ".join(missing_columns)
            )

        for row_number, row in enumerate(reader, start=2):
            clean = {
                key: value.strip() if isinstance(value, str) else value
                for key, value in row.items()
            }

            sample = clean.get("sample", "")

            if not sample:
                die(f"Row {row_number}: sample is empty.")

            if not SAMPLE_RE.fullmatch(sample):
                die(
                    f"Row {row_number}: sample '{sample}' contains "
                    "unsafe characters. Use only letters, numbers, "
                    "underscores, dots, or hyphens."
                )

            for column in ("fastq_1", "fastq_2"):
                raw_path = clean.get(column, "")

                if not raw_path:
                    die(
                        f"Row {row_number}: column "
                        f"'{column}' is empty."
                    )

                resolved_path = resolve_input_path(
                    raw_path,
                    base_dir,
                )

                check_fastq_path(
                    resolved_path,
                    row_number,
                    column,
                )

                clean[column] = str(resolved_path)

            genome_size = clean.get("genome_size_bp", "")

            if genome_size:
                try:
                    genome_size_value = int(genome_size)
                except ValueError:
                    die(
                        f"Row {row_number}: genome_size_bp "
                        "must be a positive integer."
                    )

                if genome_size_value <= 0:
                    die(
                        f"Row {row_number}: genome_size_bp "
                        "must be a positive integer."
                    )

            ploidy = clean.get("ploidy", "")

            if ploidy:
                try:
                    ploidy_value = int(ploidy)
                except ValueError:
                    die(
                        f"Row {row_number}: ploidy must be "
                        "a positive integer."
                    )

                if ploidy_value <= 0:
                    die(
                        f"Row {row_number}: ploidy must be "
                        "a positive integer."
                    )

            target_coverage = clean.get("target_coverage", "")

            if target_coverage:
                try:
                    target_coverage_value = float(target_coverage)
                except ValueError:
                    die(
                        f"Row {row_number}: target_coverage "
                        "must be a positive number."
                    )

                if target_coverage_value <= 0:
                    die(
                        f"Row {row_number}: target_coverage "
                        "must be a positive number."
                    )

            target_read_length = clean.get(
                "target_read_length",
                "",
            )

            if target_read_length:
                try:
                    target_read_length_value = int(
                        target_read_length
                    )
                except ValueError:
                    die(
                        f"Row {row_number}: target_read_length "
                        "must be a positive integer."
                    )

                if target_read_length_value <= 0:
                    die(
                        f"Row {row_number}: target_read_length "
                        "must be a positive integer."
                    )

            rows.append(clean)

    if not rows:
        die("Samplesheet has no data rows.")

    seen_samples = set()

    for row in rows:
        sample = row["sample"]

        if sample in seen_samples:
            die(f"Duplicated sample identifier: {sample}")

        seen_samples.add(sample)

    output_columns = REQUIRED_COLUMNS + OPTIONAL_COLUMNS

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with output_path.open(
        mode="w",
        newline="",
        encoding="utf-8",
    ) as out_handle:
        writer = csv.DictWriter(
            out_handle,
            fieldnames=output_columns,
            extrasaction="ignore",
        )

        writer.writeheader()

        for row in rows:
            writer.writerow(
                {
                    column: row.get(column, "")
                    for column in output_columns
                }
            )

    print(
        f"[validate_samplesheet] OK: "
        f"{len(rows)} row(s) validated."
    )
    print(
        f"[validate_samplesheet] Output: "
        f"{output_path}"
    )


if __name__ == "__main__":
    main()
