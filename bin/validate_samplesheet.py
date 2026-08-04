#!/usr/bin/env python3

import argparse
import csv
import re
import sys
from pathlib import Path


REQUIRED_COLUMNS = [
    "sample",
    "source",
    "provider",
    "fastq_1",
    "fastq_2",
    "accession",
    "organism",
    "genome_size_1C_bp",
    "ploidy",
    "target_coverage",
    "organelle_fasta",
]

OPTIONAL_COLUMNS = [
    "target_read_length",
    "sampling_seed",
]

OUTPUT_COLUMNS = REQUIRED_COLUMNS + OPTIONAL_COLUMNS

ALLOWED_SOURCES = {"local", "accession"}
ALLOWED_PROVIDERS = {"local", "auto", "ena", "ncbi_sra"}

SAMPLE_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
RUN_ACCESSION_PATTERN = re.compile(r"^(SRR|ERR|DRR)[0-9]+$", flags=re.IGNORECASE)

VALID_FASTQ_SUFFIXES = (
    ".fastq.gz",
    ".fq.gz",
    ".fastq",
    ".fq",
)


def die(message: str) -> None:
    """Some scripts validations were not met. Check the stucture and integrity of the samplesheet, the format of the sample name and revise if the source or the providers present any kind of conflict. Also, watch out the files provided and the data attached to numeric columns."""
    print(f"[validate_samplesheet] ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def is_blank(value: object) -> bool:
    """True if the variable is empty or entirely constituted by blank spaces."""
    return value is None or str(value).strip() == ""


def resolve_input_path(raw_path: str, base_dir: Path) -> Path:
    """Resolves relative routes"""
    path = Path(raw_path)
    if path.is_absolute():
        return path.resolve()
    return (base_dir / path).resolve()


def check_fastq_path(
    path: Path, row_number: int, column: str, base_dir: Path
) -> Path:
    """Verifies the existence, type and extension of the local input FASTQ files."""
    resolved_path = resolve_input_path(str(path), base_dir)

    if not resolved_path.exists():
        die(f"Row {row_number}: {column} does not exist: {resolved_path}")

    if not resolved_path.is_file():
        die(f"Row {row_number}: {column} is not a file: {resolved_path}")

    if not resolved_path.name.endswith(VALID_FASTQ_SUFFIXES):
        die(
            f"Row {row_number}: {column} does not look like FASTQ or FASTQ.GZ: {resolved_path}"
        )

    return resolved_path


def require_positive_integer(
    value: object, field: str, row_number: int
) -> str:
    """Validates and parses integer numbers strictly above zero."""
    text = str(value).strip() if value is not None else ""
    try:
        number = int(text)
    except ValueError:
        die(
            f"Row {row_number}: '{field}' must be an integer; received '{text}'."
        )

    if number < 1:
        die(f"Row {row_number}: '{field}' must be at least 1.")

    return str(number)

def require_nonnegative_integer(
    value: object, field: str, row_number: int
) -> str:
    """Validates and parses integer numbers greater than or equal to zero."""
    text = str(value).strip() if value is not None else ""

    try:
        number = int(text)
    except ValueError:
        die(
            f"Row {row_number}: '{field}' must be an integer; "
            f"received '{text}'."
        )

    if number < 0:
        die(f"Row {row_number}: '{field}' must be at least 0.")

    return str(number)

def require_positive_float(
    value: object, field: str, row_number: int
) -> str:
    """Validates and parses decimal numbers strictly above zero."""
    text = str(value).strip() if value is not None else ""
    try:
        number = float(text)
    except ValueError:
        die(
            f"Row {row_number}: '{field}' must be numeric; received '{text}'."
        )

    if number <= 0:
        die(f"Row {row_number}: '{field}' must be greater than zero.")

    return str(number)


def validate_source_fields(
    row: dict[str, str], row_number: int, base_dir: Path
) -> dict[str, str]:
    """Validates the consistency between mutually-exclusive columns."""
    source = row.get("source", "").strip().lower()
    provider = row.get("provider", "").strip().lower()
    accession = row.get("accession", "").strip().upper()

    row["source"] = source
    row["provider"] = provider
    row["accession"] = accession

    fastq_1 = row.get("fastq_1", "").strip()
    fastq_2 = row.get("fastq_2", "").strip()

    if source not in ALLOWED_SOURCES:
        die(
            f"Row {row_number}: source must be one of {sorted(ALLOWED_SOURCES)}; received '{source}'."
        )

    if provider not in ALLOWED_PROVIDERS:
        die(
            f"Row {row_number}: provider must be one of {sorted(ALLOWED_PROVIDERS)}; received '{provider}'."
        )

    if source == "local":
        if is_blank(fastq_1) or is_blank(fastq_2):
            die(
                f"Row {row_number}: local input requires both 'fastq_1' and 'fastq_2'."
            )

        if fastq_1 == fastq_2:
            die(
                f"Row {row_number}: 'fastq_1' and 'fastq_2' must be different files."
            )

        if not is_blank(accession):
            die(
                f"Row {row_number}: local input must not define an accession."
            )

        if provider not in {"", "local"}:
            die(
                f"Row {row_number}: local input requires provider='local' or an empty provider."
            )

        res_r1 = check_fastq_path(Path(fastq_1), row_number, "fastq_1", base_dir)
        res_r2 = check_fastq_path(Path(fastq_2), row_number, "fastq_2", base_dir)

        row["fastq_1"] = str(res_r1)
        row["fastq_2"] = str(res_r2)

    elif source == "accession":
        if is_blank(accession):
            die(
                f"Row {row_number}: accession input requires the 'accession' field."
            )

        if not RUN_ACCESSION_PATTERN.fullmatch(accession):
            die(
                f"Row {row_number}: unsupported run accession '{accession}'. Expected SRR, ERR, or DRR."
            )

        if not is_blank(fastq_1) or not is_blank(fastq_2):
            die(
                f"Row {row_number}: accession input must not define local FASTQ paths."
            )

        if provider not in {"auto", "ena", "ncbi_sra"}:
            die(
                f"Row {row_number}: accession input requires provider 'auto', 'ena', or 'ncbi_sra'."
            )

    return row


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate a paired-end WGS samplesheet for REPEXPREP."
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
    parser.add_argument(
        "--skip-organelle-filter",
        action="store_true",
        help="Skip validation of organelle_fasta path if provided.",
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

    with samplesheet.open(mode="r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)

        if reader.fieldnames is None:
            die("Samplesheet is empty or has no header.")

        fieldnames = [
            field.strip() if isinstance(field, str) else field
            for field in reader.fieldnames
        ]
        reader.fieldnames = fieldnames

        missing_columns = [
            col for col in REQUIRED_COLUMNS if col not in fieldnames
        ]
        if missing_columns:
            die(f"Missing required column(s): {', '.join(missing_columns)}")

        for row_number, row in enumerate(reader, start=2):
            clean = {
                key: value.strip() if isinstance(value, str) else value
                for key, value in row.items()
            }

            sample = clean.get("sample", "")
            if is_blank(sample):
                die(f"Row {row_number}: sample is empty.")

            if not SAMPLE_RE.fullmatch(sample):
                die(
                    f"Row {row_number}: sample '{sample}' contains unsafe characters."
                )

        
            clean = validate_source_fields(clean, row_number, base_dir)

            clean["ploidy"] = require_positive_integer(
                clean.get("ploidy"), "ploidy", row_number
            )
            clean["genome_size_1C_bp"] = require_positive_integer(
                clean.get("genome_size_1C_bp"), "genome_size_1C_bp", row_number
            )
            clean["target_coverage"] = require_positive_float(
                clean.get("target_coverage"), "target_coverage", row_number
            )

            if is_blank(clean.get("target_read_length")):
                clean["target_read_length"] = ""
            else:
                clean["target_read_length"] = require_positive_integer(
                    clean.get("target_read_length"),
                    "target_read_length",
                    row_number,
                )

            if is_blank(clean.get("sampling_seed")):
                clean["sampling_seed"] = ""
            else:
                clean["sampling_seed"] = require_nonnegative_integer(
                    clean.get("sampling_seed"),
                    "sampling_seed",
                    row_number,
                )

            organelle_fasta = clean.get("organelle_fasta", "")
            if not is_blank(organelle_fasta) and not args.skip_organelle_filter:
                org_path = resolve_input_path(organelle_fasta, base_dir)
                if not org_path.exists():
                    die(
                        f"Row {row_number}: organelle_fasta does not exist: {org_path}"
                    )
                if not org_path.is_file():
                    die(
                        f"Row {row_number}: organelle_fasta is not a file: {org_path}"
                    )
                clean["organelle_fasta"] = str(org_path)

            rows.append(clean)

    if not rows:
        die("Samplesheet has no data rows.")


    seen_samples = set()
    for row in rows:
        sample = row["sample"]
        if sample in seen_samples:
            die(f"Duplicated sample identifier: {sample}")
        seen_samples.add(sample)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open(mode="w", newline="", encoding="utf-8") as out_handle:
        writer = csv.DictWriter(
            out_handle,
            fieldnames=OUTPUT_COLUMNS,
            extrasaction="ignore",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({col: row.get(col, "") for col in OUTPUT_COLUMNS})

    print(f"[validate_samplesheet] OK: {len(rows)} row(s) validated.")
    print(f"[validate_samplesheet] Output: {output_path}")


if __name__ == "__main__":
    main()