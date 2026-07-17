#!/usr/bin/env python3

import argparse
import csv
import re
import sys
from pathlib import Path


REQUIRED_COLUMNS = ["sample", "fastq_1", "fastq_2"]

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
    print(f"[validate_samplesheet] ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def resolve_input_path(raw_path: str, base_dir: Path) -> Path:
    path = Path(raw_path)

    if path.is_absolute():
        return path

    return (base_dir / path).resolve()


def check_fastq_path(path: Path, row_number: int, column: str) -> None:
    if not path.exists():
        die(f"Row {row_number}: file in column '{column}' does not exist: {path}")

    if not path.is_file():
        die(f"Row {row_number}: path in column '{column}' is not a file: {path}")

    name = path.name
    valid_suffix = (
        name.endswith(".fastq.gz")
        or name.endswith(".fq.gz")
        or name.endswith(".fastq")
        or name.endswith(".fq")
    )

    if not valid_suffix:
        die(
            f"Row {row_number}: file in column '{column}' does not look like FASTQ/FASTQ.GZ: {path}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate a paired-end WGS samplesheet for repexprep."
    )
    parser.add_argument("--input", required=True, help="Input samplesheet CSV")
    parser.add_argument("--output", required=True, help="Validated output CSV")
    parser.add_argument(
        "--base-dir",
        default=".",
        help="Base directory used to resolve relative FASTQ paths",
    )

    args = parser.parse_args()

    samplesheet = Path(args.input)
    base_dir = Path(args.base_dir).resolve()

    if not samplesheet.exists():
        die(f"Samplesheet does not exist: {samplesheet}")

    rows = []

    with open(samplesheet, newline="") as handle:
        reader = csv.DictReader(handle)

        if reader.fieldnames is None:
            die("Samplesheet is empty or has no header.")

        missing = [col for col in REQUIRED_COLUMNS if col not in reader.fieldnames]
        if missing:
            die(f"Missing required column(s): {', '.join(missing)}")

        for row_number, row in enumerate(reader, start=2):
            clean = {k: (v.strip() if isinstance(v, str) else v) for k, v in row.items()}

            sample = clean.get("sample", "")
            if not sample:
                die(f"Row {row_number}: sample is empty.")

            if not SAMPLE_RE.match(sample):
                die(
                    f"Row {row_number}: sample '{sample}' contains unsafe characters. "
                    "Use letters, numbers, underscore, dot or hyphen."
                )

            for col in ["fastq_1", "fastq_2"]:
                if not clean.get(col):
                    die(f"Row {row_number}: column '{col}' is empty.")

                resolved = resolve_input_path(clean[col], base_dir)
                check_fastq_path(resolved, row_number, col)
                clean[col] = str(resolved)

            if not clean.get("lane"):
                clean["lane"] = "L001"

            genome_size = clean.get("genome_size_bp", "")
            if genome_size:
                try:
                    if int(genome_size) <= 0:
                        raise ValueError
                except ValueError:
                    die(f"Row {row_number}: genome_size_bp must be a positive integer.")

            ploidy = clean.get("ploidy", "")
            if ploidy:
                try:
                    if int(ploidy) <= 0:
                        raise ValueError
                except ValueError:
                    die(f"Row {row_number}: ploidy must be a positive integer.")

            target_coverage = clean.get("target_coverage", "")
            if target_coverage:
                try:
                    cov = float(target_coverage)
                    if cov <= 0:
                        raise ValueError
                except ValueError:
                    die(f"Row {row_number}: target_coverage must be a positive number.")

            target_read_length = clean.get("target_read_length", "")
            if target_read_length:
                try:
                    if int(target_read_length) <= 0:
                        raise ValueError
                except ValueError:
                    die(f"Row {row_number}: target_read_length must be a positive integer.")

            rows.append(clean)

    if not rows:
        die("Samplesheet has no data rows.")

    seen = set()
    for row in rows:
        key = (row["sample"], row.get("lane", "L001"))
        if key in seen:
            die(f"Duplicated sample/lane combination: {key[0]} / {key[1]}")
        seen.add(key)

    output_columns = REQUIRED_COLUMNS + OPTIONAL_COLUMNS

    with open(args.output, "w", newline="") as out_handle:
        writer = csv.DictWriter(out_handle, fieldnames=output_columns)
        writer.writeheader()

        for row in rows:
            writer.writerow({col: row.get(col, "") for col in output_columns})

    print(f"[validate_samplesheet] OK: {len(rows)} row(s) validated.")
    print(f"[validate_samplesheet] Output: {args.output}")


if __name__ == "__main__":
    main()