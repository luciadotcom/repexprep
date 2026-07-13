#!/usr/bin/env python3

import argparse
import gzip
import itertools
import sys
from pathlib import Path


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "rt")


def normalize_read_id(header: str) -> str:
    """
    Normalize FASTQ read IDs so R1 and R2 can be compared.

    Handles examples such as:
    @read0001/1
    @read0001/2
    @instrument:run:flowcell 1:N:0:index
    @instrument:run:flowcell 2:N:0:index
    """
    header = header.strip()

    if header.startswith("@"):
        header = header[1:]

    first_token = header.split()[0]

    if first_token.endswith("/1") or first_token.endswith("/2"):
        first_token = first_token[:-2]

    return first_token


def fastq_headers(path: str):
    with open_text(path) as handle:
        record_number = 0

        while True:
            header = handle.readline().rstrip()

            if not header:
                break

            seq = handle.readline()
            plus = handle.readline()
            qual = handle.readline()

            record_number += 1

            if not seq or not plus or not qual:
                raise ValueError(
                    f"Incomplete FASTQ record in {path} around record {record_number}"
                )

            if not header.startswith("@"):
                raise ValueError(
                    f"Invalid FASTQ header in {path} around record {record_number}: {header}"
                )

            yield record_number, header, normalize_read_id(header)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit paired-end FASTQ files for read count and ID consistency."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--max-mismatches-to-report",
        type=int,
        default=10,
        help="Maximum number of mismatching IDs to print to stderr.",
    )

    args = parser.parse_args()

    r1_iter = fastq_headers(args.r1)
    r2_iter = fastq_headers(args.r2)

    r1_reads = 0
    r2_reads = 0
    compared_pairs = 0
    id_mismatches = 0
    first_mismatches = []

    for r1_item, r2_item in itertools.zip_longest(r1_iter, r2_iter):
        if r1_item is None:
            r2_reads += 1
            id_mismatches += 1
            if len(first_mismatches) < args.max_mismatches_to_report:
                first_mismatches.append(("missing_R1", "NA", r2_item[2]))
            continue

        if r2_item is None:
            r1_reads += 1
            id_mismatches += 1
            if len(first_mismatches) < args.max_mismatches_to_report:
                first_mismatches.append(("missing_R2", r1_item[2], "NA"))
            continue

        r1_reads += 1
        r2_reads += 1
        compared_pairs += 1

        r1_id = r1_item[2]
        r2_id = r2_item[2]

        if r1_id != r2_id:
            id_mismatches += 1
            if len(first_mismatches) < args.max_mismatches_to_report:
                first_mismatches.append((compared_pairs, r1_id, r2_id))

    status = "PASS"

    if r1_reads != r2_reads or id_mismatches > 0:
        status = "FAIL"

    with open(args.output, "w") as out:
        out.write(
            "sample\tr1_file\tr2_file\tr1_reads\tr2_reads\t"
            "compared_pairs\tid_mismatches\tstatus\n"
        )
        out.write(
            f"{args.sample}\t{Path(args.r1).name}\t{Path(args.r2).name}\t"
            f"{r1_reads}\t{r2_reads}\t{compared_pairs}\t"
            f"{id_mismatches}\t{status}\n"
        )

    print(f"[pair_audit] Wrote: {args.output}")
    print(
        f"[pair_audit] sample={args.sample} "
        f"r1_reads={r1_reads} r2_reads={r2_reads} "
        f"id_mismatches={id_mismatches} status={status}"
    )

    if first_mismatches:
        print("[pair_audit] First mismatches:", file=sys.stderr)
        for item in first_mismatches:
            print(f"[pair_audit] {item}", file=sys.stderr)

    if status != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()
    