#!/usr/bin/env python3

"""
Select a single global target read length across all sample profiles.

Supports two modes:
- global_auto: Choose the minimum candidate target length among robust samples.
- global_fixed: Enforce a user-defined target read length.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

VERSION = "0.1.0"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Select a global target read length from multiple sample profiles."
    )

    parser.add_argument(
        "--profiles",
        nargs="+",
        type=Path,
        required=True,
        help="List of input read-length profile TSV files from PROFILE_READ_LENGTH.",
    )

    parser.add_argument(
        "--mode",
        choices=["global_auto", "global_fixed"],
        required=True,
        help="Selection mode: 'global_auto' or 'global_fixed'.",
    )

    parser.add_argument(
        "--target-read-length",
        type=int,
        default=None,
        help="Fixed target read length (required if mode is 'global_fixed').",
    )

    parser.add_argument(
        "--output-global",
        type=Path,
        required=True,
        help="Output TSV path for global dataset target metrics.",
    )

    parser.add_argument(
        "--output-per-sample",
        type=Path,
        required=True,
        help="Output TSV path for per-sample target breakdown.",
    )

    parser.add_argument(
        "--version",
        action="version",
        version=VERSION,
    )

    parser.add_argument(
        "--min-retained-fraction",
        type=float,
        default=None,
        help="Minimum retained fraction threshold used for profiling.",
    )

    parser.add_argument(
        "--min-target-read-length",
        type=int,
        default=None,
        help="Minimum allowable global target read length (clamp lower bound).",
    )

    parser.add_argument(
        "--max-target-read-length",
        type=int,
        default=None,
        help="Maximum allowable global target read length (clamp upper bound).",
    )

    args = parser.parse_args()

    if args.mode == "global_fixed" and args.target_read_length is None:
        parser.error("--target-read-length is required when --mode is 'global_fixed'.")

    return args


def read_profile(path: Path) -> dict[str, str]:
    """Read a single-row profile TSV file."""
    if not path.is_file():
        raise FileNotFoundError(f"Profile file not found: {path}")

    with path.open(mode="r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

        if len(rows) != 1:
            raise ValueError(f"Expected exactly 1 row in {path}, got {len(rows)}")

        return rows[0]


def run(args: argparse.Namespace) -> None:
    samples_data = []

    for profile_path in args.profiles:
        data = read_profile(profile_path)
        samples_data.append(
            {
                "sample": data["sample"],
                "total_pairs": int(data["total_pairs"]),
                "candidate_length": int(data["candidate_target_length"]),
                "expected_retained_pairs": int(data["expected_retained_pairs"]),
                "expected_retained_fraction": float(data["expected_retained_fraction"]),
            }
        )

    if not samples_data:
        raise ValueError("No profile files provided.")

    total_samples = len(samples_data)

    
    if args.mode == "global_auto":
        #Global target is the min of all candidate target lengths.
        limiting_sample_entry = min(samples_data, key=lambda x: x["candidate_length"])
        global_target_length = limiting_sample_entry["candidate_length"]
        limiting_sample = limiting_sample_entry["sample"]

        if args.min_target_read_length is not None and global_target_length < args.min_target_read_length:
            global_target_length = args.min_target_read_length
            limiting_sample = "min_target_read_length_threshold"

        if args.max_target_read_length is not None and global_target_length > args.max_target_read_length:
            global_target_length = args.max_target_read_length
            limiting_sample = "max_target_read_length_threshold"

    elif args.mode == "global_fixed":
        global_target_length = args.target_read_length
        limiting_sample = "N/A"  

        for sample_entry in samples_data:
            if sample_entry["candidate_length"] == global_target_length:
                limiting_sample = sample_entry["sample"]
                break

    args.output_global.parent.mkdir(parents=True, exist_ok=True)
    with args.output_global.open(mode="w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["mode", "global_target_length", "total_samples", "limiting_sample"],
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerow(
            {
                "mode": args.mode,
                "global_target_length": global_target_length,
                "total_samples": total_samples,
                "limiting_sample": limiting_sample,
            }
        )

    args.output_per_sample.parent.mkdir(parents=True, exist_ok=True)
    with args.output_per_sample.open(mode="w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "sample",
            "candidate_target_length",
            "global_target_length",
            "expected_retained_fraction",
            "is_limiting",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()

        for s in samples_data:
            is_limiting = (s["candidate_length"] == global_target_length) if args.mode == "global_auto" else (s["sample"] == limiting_sample)
            writer.writerow(
                {
                    "sample": s["sample"],
                    "candidate_target_length": s["candidate_length"],
                    "global_target_length": global_target_length,
                    "expected_retained_fraction": f"{s['expected_retained_fraction']:.6f}",
                    "is_limiting": "true" if is_limiting else "false",
                }
            )


def main() -> int:
    args = parse_arguments()

    try:
        run(args)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())