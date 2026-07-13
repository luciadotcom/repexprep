#!/usr/bin/env python3

import argparse
import gzip
from pathlib import Path


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "rt")


def fastq_iter(path: str):
    with open_text(path) as handle:
        while True:
            header = handle.readline().rstrip()
            if not header:
                break

            seq = handle.readline().rstrip()
            plus = handle.readline().rstrip()
            qual = handle.readline().rstrip()

            if not seq or not plus or not qual:
                raise ValueError(f"Incomplete FASTQ record in {path}")

            yield header, seq, qual


def summarize_fastq(path: str) -> dict:
    reads = 0
    bases = 0
    min_len = None
    max_len = 0
    n_bases = 0
    gc_bases = 0

    for _header, seq, _qual in fastq_iter(path):
        seq_upper = seq.upper()
        length = len(seq_upper)

        reads += 1
        bases += length
        max_len = max(max_len, length)
        min_len = length if min_len is None else min(min_len, length)

        n_bases += seq_upper.count("N")
        gc_bases += seq_upper.count("G") + seq_upper.count("C")

    mean_len = bases / reads if reads else 0
    gc_percent = (gc_bases / bases * 100) if bases else 0

    return {
        "reads": reads,
        "bases": bases,
        "min_length": min_len if min_len is not None else 0,
        "max_length": max_len,
        "mean_length": f"{mean_len:.2f}",
        "n_bases": n_bases,
        "gc_bases": gc_bases,
        "gc_percent": f"{gc_percent:.2f}",
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create basic FASTQ statistics for paired-end reads."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--output", required=True)

    args = parser.parse_args()

    r1_stats = summarize_fastq(args.r1)
    r2_stats = summarize_fastq(args.r2)

    with open(args.output, "w") as out:
        out.write(
            "sample\tmate\tfile\treads\tbases\tmin_length\tmax_length\t"
            "mean_length\tn_bases\tgc_bases\tgc_percent\n"
        )

        for mate, path, stats in [
            ("R1", args.r1, r1_stats),
            ("R2", args.r2, r2_stats),
        ]:
            out.write(
                f"{args.sample}\t{mate}\t{Path(path).name}\t"
                f"{stats['reads']}\t{stats['bases']}\t"
                f"{stats['min_length']}\t{stats['max_length']}\t"
                f"{stats['mean_length']}\t{stats['n_bases']}\t"
                f"{stats['gc_bases']}\t{stats['gc_percent']}\n"
            )

    print(f"[raw_fastq_stats] Wrote: {args.output}")


if __name__ == "__main__":
    main()
    