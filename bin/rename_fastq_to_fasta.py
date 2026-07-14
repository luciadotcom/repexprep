#!/usr/bin/env python3

import argparse
import gzip
import sys
from pathlib import Path


def open_text(path: str):
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, "rt")


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

            yield record_number, header, seq, qual


def wrap_sequence(seq: str, width: int = 80):
    for start in range(0, len(seq), width):
        yield seq[start:start + width]


def write_fasta_record(handle, header: str, seq: str) -> None:
    handle.write(f">{header}\n")
    for chunk in wrap_sequence(seq):
        handle.write(f"{chunk}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert paired sampled FASTQ files into one interleaved RepeatExplorer-style FASTA."
    )
    parser.add_argument("--sample", required=True)
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--output-fasta", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument(
        "--header-prefix",
        default="",
        help="Optional FASTA header prefix. Defaults to sample name.",
    )

    args = parser.parse_args()

    prefix = args.header_prefix if args.header_prefix else args.sample

    total_pairs = 0
    written_pairs = 0
    written_sequences = 0
    id_mismatches = 0
    min_length = None
    max_length = 0
    total_bases = 0

    r1_iter = fastq_records(args.r1)
    r2_iter = fastq_records(args.r2)

    with open(args.output_fasta, "w") as out:
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

            _r1_number, r1_header, r1_seq, _r1_qual = r1
            _r2_number, r2_header, r2_seq, _r2_qual = r2

            if normalize_read_id(r1_header) != normalize_read_id(r2_header):
                id_mismatches += 1
                continue

            pair_number = written_pairs + 1

            r1_fasta_header = f"{prefix}_pair{pair_number:09d}_R1"
            r2_fasta_header = f"{prefix}_pair{pair_number:09d}_R2"

            r1_seq = r1_seq.upper()
            r2_seq = r2_seq.upper()

            write_fasta_record(out, r1_fasta_header, r1_seq)
            write_fasta_record(out, r2_fasta_header, r2_seq)

            written_pairs += 1
            written_sequences += 2

            for seq in [r1_seq, r2_seq]:
                seq_len = len(seq)
                min_length = seq_len if min_length is None else min(min_length, seq_len)
                max_length = max(max_length, seq_len)
                total_bases += seq_len

    status = "PASS"

    if id_mismatches > 0 or written_pairs == 0:
        status = "FAIL"

    mean_length = total_bases / written_sequences if written_sequences else 0

    with open(args.report, "w") as report:
        report.write(
            "sample\tr1_file\tr2_file\toutput_fasta\ttotal_pairs\twritten_pairs\t"
            "written_sequences\ttotal_bases\tmin_length\tmax_length\tmean_length\t"
            "id_mismatches\tstatus\n"
        )
        report.write(
            f"{args.sample}\t{Path(args.r1).name}\t{Path(args.r2).name}\t"
            f"{Path(args.output_fasta).name}\t{total_pairs}\t{written_pairs}\t"
            f"{written_sequences}\t{total_bases}\t"
            f"{min_length if min_length is not None else 0}\t{max_length}\t"
            f"{mean_length:.2f}\t{id_mismatches}\t{status}\n"
        )

    print(
        f"[rename_fastq_to_fasta] sample={args.sample} "
        f"written_pairs={written_pairs} written_sequences={written_sequences} "
        f"output={args.output_fasta} status={status}"
    )

    if status != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()