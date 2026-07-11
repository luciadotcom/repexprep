#!/usr/bin/env python3

import argparse
import gzip
import random
from pathlib import Path


def random_dna(length: int) -> str:
    return "".join(random.choice("ACGT") for _ in range(length))


def write_fastq(path: Path, sample: str, mate: int, pairs: int, length: int, qual: int) -> None:
    qchar = chr(qual + 33)
    quality = qchar * length

    with gzip.open(path, "wt") as out:
        for i in range(1, pairs + 1):
            read_id = f"{sample}_{i:08d}/{mate}"
            seq = random_dna(length)
            out.write(f"@{read_id}\n")
            out.write(f"{seq}\n")
            out.write("+\n")
            out.write(f"{quality}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create tiny paired-end gzipped FASTQ files for testing."
    )
    parser.add_argument("--sample", required=True, help="Sample name, e.g. toyA")
    parser.add_argument("--pairs", type=int, default=1000, help="Number of read pairs")
    parser.add_argument("--length", type=int, default=150, help="Read length")
    parser.add_argument("--quality", type=int, default=35, help="Phred quality score")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument("--outdir", required=True, help="Output directory")

    args = parser.parse_args()

    random.seed(args.seed)

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    r1 = outdir / f"{args.sample}_R1.fastq.gz"
    r2 = outdir / f"{args.sample}_R2.fastq.gz"

    write_fastq(r1, args.sample, 1, args.pairs, args.length, args.quality)
    write_fastq(r2, args.sample, 2, args.pairs, args.length, args.quality)

    print(f"Created: {r1}")
    print(f"Created: {r2}")


if __name__ == "__main__":
    main()