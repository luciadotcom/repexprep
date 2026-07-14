#!/usr/bin/env python3

import argparse
import csv
import gzip
import math
import sys
from pathlib import Path


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "rt")


def count_fastq_reads(path: str) -> int:
    lines = 0
    with open_text(path) as handle:
        for _ in handle:
            lines += 1

    if lines % 4 != 0:
        raise ValueError(f"FASTQ line count is not divisible by 4: {path}")

    return lines // 4


def read_target_length(path: str) -> int:
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    if len(rows) != 1:
        raise ValueError(f"Expected exactly one row in target length file: {path}")

    return int(rows[0]["target_length"])


def parse_positive_int(value: str, name: str) -> int:
    try:
        parsed = int(value)
        if parsed <= 0:
            raise ValueError
        return parsed
    except Exception:
        raise ValueError(f"{name} must be a positive integer, got: {value}")


def parse_positive_float(value: str, name: str) -> float:
    try:
        parsed = float(value)
        if parsed <= 0:
            raise ValueError
        return parsed
    except Exception:
        raise ValueError(f"{name} must be a positive number, got: {value}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Plan paired-end read sampling for a target genome coverage."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--target-length-file", required=True)
    parser.add_argument("--genome-size-bp", required=True)
    parser.add_argument("--target-coverage", required=True)
    parser.add_argument("--output", required=True)

    args = parser.parse_args()

    genome_size_bp = parse_positive_int(args.genome_size_bp, "genome_size_bp")
    target_coverage = parse_positive_float(args.target_coverage, "target_coverage")
    target_length = read_target_length(args.target_length_file)

    r1_reads = count_fastq_reads(args.r1)
    r2_reads = count_fastq_reads(args.r2)

    if r1_reads != r2_reads:
        raise ValueError(
            f"R1/R2 read counts differ for {args.sample}: R1={r1_reads}, R2={r2_reads}"
        )

    available_pairs = r1_reads
    bases_per_pair = 2 * target_length

    requested_pairs = math.ceil((genome_size_bp * target_coverage) / bases_per_pair)

    if requested_pairs <= 0:
        requested_pairs = 1

    if requested_pairs > available_pairs:
        sampled_pairs = available_pairs
        status = "WARN_INSUFFICIENT_READS_KEEP_ALL"
    else:
        sampled_pairs = requested_pairs
        status = "PASS"

    planned_bases = sampled_pairs * bases_per_pair
    achieved_coverage = planned_bases / genome_size_bp

    with open(args.output, "w") as out:
        out.write(
            "sample\tgenome_size_bp\ttarget_coverage\ttarget_length\t"
            "bases_per_pair\tavailable_pairs\trequested_pairs\tsampled_pairs\t"
            "planned_bases\tachieved_coverage\tstatus\n"
        )

        out.write(
            f"{args.sample}\t{genome_size_bp}\t{target_coverage}\t{target_length}\t"
            f"{bases_per_pair}\t{available_pairs}\t{requested_pairs}\t{sampled_pairs}\t"
            f"{planned_bases}\t{achieved_coverage:.8f}\t{status}\n"
        )

    print(
        f"[plan_coverage] sample={args.sample} "
        f"target_coverage={target_coverage} "
        f"target_length={target_length} "
        f"available_pairs={available_pairs} "
        f"sampled_pairs={sampled_pairs} "
        f"achieved_coverage={achieved_coverage:.6f} "
        f"status={status}"
    )

    if sampled_pairs == 0:
        print("[plan_coverage] No pairs selected.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
    