#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path


ALLOWED_BASES = set("ACGTN")


def fasta_records(path: str):
    header = None
    seq_chunks = []

    with open(path) as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.rstrip()

            if not line:
                continue

            if line.startswith(">"):
                if header is not None:
                    yield header, "".join(seq_chunks)

                header = line[1:].strip()
                seq_chunks = []

                if not header:
                    raise ValueError(f"Empty FASTA header at line {line_number}")

            else:
                if header is None:
                    raise ValueError(
                        f"Sequence line found before first FASTA header at line {line_number}"
                    )

                seq_chunks.append(line.strip().upper())

        if header is not None:
            yield header, "".join(seq_chunks)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate RepeatExplorer-style interleaved paired FASTA."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--input-fasta", required=True)
    parser.add_argument("--report", required=True)

    args = parser.parse_args()

    records = list(fasta_records(args.input_fasta))

    total_sequences = len(records)
    total_pairs = total_sequences // 2
    duplicate_headers = 0
    invalid_base_records = 0
    malformed_pair_headers = 0
    empty_sequences = 0

    headers_seen = set()
    min_length = None
    max_length = 0
    total_bases = 0

    for header, seq in records:
        if header in headers_seen:
            duplicate_headers += 1
        headers_seen.add(header)

        if not seq:
            empty_sequences += 1
            continue

        invalid_bases = set(seq.upper()) - ALLOWED_BASES
        if invalid_bases:
            invalid_base_records += 1

        seq_len = len(seq)
        min_length = seq_len if min_length is None else min(min_length, seq_len)
        max_length = max(max_length, seq_len)
        total_bases += seq_len

    if total_sequences % 2 != 0:
        malformed_pair_headers += 1

    for index in range(0, total_sequences - 1, 2):
        h1 = records[index][0]
        h2 = records[index + 1][0]

        if not h1.endswith("_R1") or not h2.endswith("_R2"):
            malformed_pair_headers += 1
            continue

        root1 = h1[:-3]
        root2 = h2[:-3]

        if root1 != root2:
            malformed_pair_headers += 1

    mean_length = total_bases / total_sequences if total_sequences else 0

    status = "PASS"

    if (
        total_sequences == 0
        or total_sequences % 2 != 0
        or duplicate_headers > 0
        or invalid_base_records > 0
        or malformed_pair_headers > 0
        or empty_sequences > 0
    ):
        status = "FAIL"

    with open(args.report, "w") as out:
        out.write(
            "sample\tinput_fasta\ttotal_sequences\ttotal_pairs\ttotal_bases\t"
            "min_length\tmax_length\tmean_length\tduplicate_headers\t"
            "invalid_base_records\tempty_sequences\tmalformed_pair_headers\tstatus\n"
        )
        out.write(
            f"{args.sample}\t{Path(args.input_fasta).name}\t"
            f"{total_sequences}\t{total_pairs}\t{total_bases}\t"
            f"{min_length if min_length is not None else 0}\t{max_length}\t"
            f"{mean_length:.2f}\t{duplicate_headers}\t"
            f"{invalid_base_records}\t{empty_sequences}\t"
            f"{malformed_pair_headers}\t{status}\n"
        )

    print(
        f"[validate_repex_fasta] sample={args.sample} "
        f"sequences={total_sequences} pairs={total_pairs} status={status}"
    )

    if status != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()