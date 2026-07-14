#!/usr/bin/env python3

import argparse
import csv
import gzip
import sys
from pathlib import Path


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "rt")


def open_gzip_text(path: str):
    return gzip.open(path, "wt")


def normalize_read_id(header: str) -> str:
    header = header.strip()

    if header.startswith("@"):
        header = header[1:]

    first_token = header.split()[0]

    if first_token.endswith("/1") or first_token.endswith("/2"):
        first_token = first_token[:-2]

    return first_token


def fastq_records(path: str):
    with open_text(path) as handle:
        record_number = 0

        while True:
            header = handle.readline().rstrip()

            if not header:
                break

            seq = handle.readline().rstrip()
            plus = handle.readline().rstrip()
            qual = handle.readline().rstrip()

            record_number += 1

            if not seq or not plus or not qual:
                raise ValueError(
                    f"Incomplete FASTQ record in {path} around record {record_number}"
                )

            if not header.startswith("@"):
                raise ValueError(
                    f"Invalid FASTQ header in {path} around record {record_number}: {header}"
                )

            yield header, seq, plus, qual


def read_target_length(path: str) -> int:
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    if len(rows) != 1:
        raise ValueError(f"Expected exactly one row in target length file: {path}")

    return int(rows[0]["target_length"])


def write_record(handle, header: str, seq: str, plus: str, qual: str, length: int) -> None:
    handle.write(f"{header}\n")
    handle.write(f"{seq[:length]}\n")
    handle.write(f"{plus}\n")
    handle.write(f"{qual[:length]}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Crop paired-end FASTQ reads to a fixed length, preserving complete pairs."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--target-length-file", required=True)
    parser.add_argument("--out-r1", required=True)
    parser.add_argument("--out-r2", required=True)
    parser.add_argument("--report", required=True)

    args = parser.parse_args()

    target_length = read_target_length(args.target_length_file)

    total_pairs = 0
    retained_pairs = 0
    dropped_short_pairs = 0
    id_mismatches = 0

    r1_iter = fastq_records(args.r1)
    r2_iter = fastq_records(args.r2)

    with open_gzip_text(args.out_r1) as out_r1, open_gzip_text(args.out_r2) as out_r2:
        while True:
            try:
                r1 = next(r1_iter)
            except StopIteration:
                r1 = None

            try:
                r2 = next(r2_iter)
            except StopIteration:
                r2 = None

            if r1 is None and r2 is None:
                break

            total_pairs += 1

            if r1 is None or r2 is None:
                id_mismatches += 1
                continue

            r1_header, r1_seq, r1_plus, r1_qual = r1
            r2_header, r2_seq, r2_plus, r2_qual = r2

            if normalize_read_id(r1_header) != normalize_read_id(r2_header):
                id_mismatches += 1
                continue

            if len(r1_seq) < target_length or len(r2_seq) < target_length:
                dropped_short_pairs += 1
                continue

            write_record(out_r1, r1_header, r1_seq, r1_plus, r1_qual, target_length)
            write_record(out_r2, r2_header, r2_seq, r2_plus, r2_qual, target_length)

            retained_pairs += 1

    status = "PASS"

    if id_mismatches > 0 or retained_pairs == 0:
        status = "FAIL"

    with open(args.report, "w") as out:
        out.write(
            "sample\ttarget_length\ttotal_pairs\tretained_pairs\t"
            "dropped_short_pairs\tid_mismatches\tstatus\n"
        )
        out.write(
            f"{args.sample}\t{target_length}\t{total_pairs}\t{retained_pairs}\t"
            f"{dropped_short_pairs}\t{id_mismatches}\t{status}\n"
        )

    print(
        f"[crop_pairs_to_length] sample={args.sample} "
        f"target_length={target_length} retained_pairs={retained_pairs}/{total_pairs} "
        f"status={status}"
    )

    if status != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()
    
