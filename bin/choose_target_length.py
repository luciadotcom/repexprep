#!/usr/bin/env python3

import argparse
import gzip
import math
from pathlib import Path


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "rt")


def fastq_sequences(path: str):
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

            yield seq


def percentile(values, percentile_value: float) -> int:
    if not values:
        return 0

    values = sorted(values)

    if percentile_value <= 0:
        return values[0]

    if percentile_value >= 100:
        return values[-1]

    rank = (percentile_value / 100) * (len(values) - 1)
    lower = math.floor(rank)
    upper = math.ceil(rank)

    if lower == upper:
        return values[int(rank)]

    interpolated = values[lower] + (values[upper] - values[lower]) * (rank - lower)
    return int(math.floor(interpolated))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Choose a fixed target read length for paired-end FASTQ files."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--requested-length",
        default="",
        help="Optional user-specified target length. If empty, percentile is used.",
    )
    parser.add_argument(
        "--percentile",
        type=float,
        default=95.0,
        help="Percentile of per-pair minimum read length to use when requested length is empty.",
    )

    args = parser.parse_args()

    pair_min_lengths = []

    r1_iter = fastq_sequences(args.r1)
    r2_iter = fastq_sequences(args.r2)

    total_pairs = 0

    for r1_seq, r2_seq in zip(r1_iter, r2_iter):
        total_pairs += 1
        pair_min_lengths.append(min(len(r1_seq), len(r2_seq)))

    if total_pairs == 0:
        raise ValueError(f"No read pairs found for sample {args.sample}")

    observed_min = min(pair_min_lengths)
    observed_max = max(pair_min_lengths)

    if args.requested_length:
        target_length = int(args.requested_length)
        decision_mode = "requested_length"
    else:
        target_length = percentile(pair_min_lengths, args.percentile)
        decision_mode = f"percentile_{args.percentile:g}"

    if target_length <= 0:
        raise ValueError("Target length must be positive.")

    if target_length > observed_max:
        raise ValueError(
            f"Requested target length {target_length} is longer than observed maximum {observed_max}"
        )

    pairs_at_or_above_target = sum(length >= target_length for length in pair_min_lengths)
    retained_fraction = pairs_at_or_above_target / total_pairs

    with open(args.output, "w") as out:
        out.write(
            "sample\ttotal_pairs\tobserved_min_pair_length\tobserved_max_pair_length\t"
            "decision_mode\ttarget_length\tpairs_at_or_above_target\tretained_fraction\n"
        )
        out.write(
            f"{args.sample}\t{total_pairs}\t{observed_min}\t{observed_max}\t"
            f"{decision_mode}\t{target_length}\t{pairs_at_or_above_target}\t"
            f"{retained_fraction:.6f}\n"
        )

    print(
        f"[choose_target_length] sample={args.sample} "
        f"target_length={target_length} "
        f"retained_pairs={pairs_at_or_above_target}/{total_pairs}"
    )


if __name__ == "__main__":
    main()
    