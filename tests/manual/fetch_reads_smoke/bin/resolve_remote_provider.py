#!/usr/bin/env python3

import argparse
import csv
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ALLOWED_PROVIDERS = {"auto", "ena", "ncbi_sra"}


def fail(message: str) -> None:
    print(
        f"[resolve_remote_provider] ERROR: {message}",
        file=sys.stderr,
    )
    raise SystemExit(1)


def normalise_ena_url(value: str) -> str:
    """Convert an ENA FTP path into an HTTPS URL."""
    url = value.strip()

    if not url:
        return ""

    if url.startswith(("https://", "http://", "ftp://")):
        return url

    return f"https://{url}"


def query_ena(accession: str) -> dict[str, object] | None:
    """Query the ENA filereport API for one run accession."""

    params = urllib.parse.urlencode(
        {
            "accession": accession,
            "result": "read_run",
            "fields": (
                "run_accession,"
                "fastq_ftp,"
                "fastq_md5,"
                "fastq_bytes"
            ),
            "format": "tsv",
        }
    )

    url = (
        "https://www.ebi.ac.uk/ena/portal/api/filereport?"
        f"{params}"
    )

    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "REPEXPREP/0.1 remote-read-resolver",
        },
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=60,
        ) as response:
            text = response.read().decode("utf-8")
    except (
        urllib.error.HTTPError,
        urllib.error.URLError,
        TimeoutError,
    ):
        return None

    rows = list(csv.DictReader(text.splitlines(), delimiter="\t"))

    if len(rows) != 1:
        return None

    row = rows[0]

    urls = [
        normalise_ena_url(value)
        for value in row.get("fastq_ftp", "").split(";")
        if value.strip()
    ]

    md5s = [
        value.strip()
        for value in row.get("fastq_md5", "").split(";")
        if value.strip()
    ]

    sizes = [
        value.strip()
        for value in row.get("fastq_bytes", "").split(";")
        if value.strip()
    ]

    if md5s and len(md5s) != len(urls):
        return None

    if sizes and len(sizes) != len(urls):
        return None

    # ENA can provide an additional unpaired FASTQ alongside the
    # paired files. Select explicitly the _1 and _2 mates and ignore
    # any extra unpaired FASTQ.
    paired_files = {}

    for index, url in enumerate(urls):
        filename = Path(
            urllib.parse.urlparse(url).path
        ).name

        if filename.endswith("_1.fastq.gz"):
            mate = 1
        elif filename.endswith("_2.fastq.gz"):
            mate = 2
        else:
            continue

        if mate in paired_files:
            return None

        paired_files[mate] = {
            "url": url,
            "md5": md5s[index] if md5s else "",
            "bytes": sizes[index] if sizes else "",
        }

    if set(paired_files) != {1, 2}:
        return None

    urls = [
        paired_files[1]["url"],
        paired_files[2]["url"],
    ]

    md5s = (
        [
            paired_files[1]["md5"],
            paired_files[2]["md5"],
        ]
        if md5s
        else []
    )

    sizes = (
        [
            paired_files[1]["bytes"],
            paired_files[2]["bytes"],
        ]
        if sizes
        else []
    )

    return {
        "run_accession": row.get(
            "run_accession",
            accession,
        ),
        "urls": urls,
        "md5s": md5s,
        "bytes": sizes,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve the remote provider for one sequencing run."
        )
    )

    parser.add_argument(
        "--sample",
        required=True,
    )

    parser.add_argument(
        "--accession",
        required=True,
    )

    parser.add_argument(
        "--provider",
        required=True,
        choices=sorted(ALLOWED_PROVIDERS),
    )

    parser.add_argument(
        "--output",
        required=True,
    )

    args = parser.parse_args()

    requested_provider = args.provider.lower()
    accession = args.accession.upper()

    ena_result = None

    if requested_provider in {"auto", "ena"}:
        ena_result = query_ena(accession)

    if requested_provider == "ena":
        if ena_result is None:
            fail(
                f"ENA did not return exactly two paired FASTQ "
                f"files for accession {accession}."
            )

        resolved_provider = "ena"

    elif requested_provider == "ncbi_sra":
        resolved_provider = "ncbi_sra"

    else:
        resolved_provider = (
            "ena"
            if ena_result is not None
            else "ncbi_sra"
        )

    result: dict[str, object] = {
        "sample": args.sample,
        "accession": accession,
        "requested_provider": requested_provider,
        "resolved_provider": resolved_provider,
        "urls": [],
        "md5s": [],
        "bytes": [],
    }

    if resolved_provider == "ena":
        assert ena_result is not None
        result.update(ena_result)

    output_path = Path(args.output)
    output_path.write_text(
        json.dumps(
            result,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

