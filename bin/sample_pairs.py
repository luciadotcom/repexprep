#!/usr/bin/env python3

import argparse
import csv
import gzip
import random
import sys


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

            yield record_number, header, seq, plus, qual


def count_fastq_reads(path: str) -> int:
    lines = 0
    with open_text(path) as handle:
        for _ in handle:
            lines += 1

    if lines % 4 != 0:
        raise ValueError(f"FASTQ line count is not divisible by 4: {path}")

    return lines // 4


def read_sampled_pairs_from_plan(path: str) -> int:
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    if len(rows) != 1:
        raise ValueError(f"Expected exactly one row in coverage plan: {path}")

    return int(rows[0]["sampled_pairs"])


def write_record(handle, header: str, seq: str, plus: str, qual: str) -> None:
    handle.write(f"{header}\n")
    handle.write(f"{seq}\n")
    handle.write(f"{plus}\n")
    handle.write(f"{qual}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Randomly sample paired-end FASTQ records while preserving read pairing."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--coverage-plan", required=True)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-r1", required=True)
    parser.add_argument("--out-r2", required=True)
    parser.add_argument("--report", required=True)

    args = parser.parse_args()

    r1_total = count_fastq_reads(args.r1)
    r2_total = count_fastq_reads(args.r2)

    if r1_total != r2_total:
        raise ValueError(
            f"R1/R2 read counts differ for {args.sample}: R1={r1_total}, R2={r2_total}"
        )

    total_pairs = r1_total
    requested_pairs = read_sampled_pairs_from_plan(args.coverage_plan)

    if requested_pairs <= 0:
        raise ValueError(f"sampled_pairs must be positive, got: {requested_pairs}")

    if requested_pairs >= total_pairs:
        selected_indices = set(range(1, total_pairs + 1))
        sampling_mode = "keep_all"
    else:
        rng = random.Random(args.seed)
        selected_indices = set(rng.sample(range(1, total_pairs + 1), requested_pairs))
        sampling_mode = "random_without_replacement"

    written_pairs = 0
    id_mismatches = 0

    r1_iter = fastq_records(args.r1)
    r2_iter = fastq_records(args.r2)

    with open_gzip_text(args.out_r1) as out_r1, open_gzip_text(args.out_r2) as out_r2:
        for r1_record, r2_record in zip(r1_iter, r2_iter):
            pair_index = r1_record[0]

            r1_header, r1_seq, r1_plus, r1_qual = r1_record[1:]
            r2_header, r2_seq, r2_plus, r2_qual = r2_record[1:]

            if normalize_read_id(r1_header) != normalize_read_id(r2_header):
                id_mismatches += 1
                continue

            if pair_index not in selected_indices:
                continue

            write_record(out_r1, r1_header, r1_seq, r1_plus, r1_qual)
            write_record(out_r2, r2_header, r2_seq, r2_plus, r2_qual)

            written_pairs += 1

    status = "PASS"

    if id_mismatches > 0 or written_pairs != len(selected_indices):
        status = "FAIL"

    with open(args.report, "w") as out:
        out.write(
            "sample\ttotal_pairs\trequested_pairs\tselected_indices\t"
            "written_pairs\tid_mismatches\tsampling_mode\tseed\tstatus\n"
        )
        out.write(
            f"{args.sample}\t{total_pairs}\t{requested_pairs}\t"
            f"{len(selected_indices)}\t{written_pairs}\t{id_mismatches}\t"
            f"{sampling_mode}\t{args.seed}\t{status}\n"
        )

    print(
        f"[sample_pairs] sample={args.sample} "
        f"total_pairs={total_pairs} requested_pairs={requested_pairs} "
        f"written_pairs={written_pairs} mode={sampling_mode} status={status}"
    )

    if status != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()