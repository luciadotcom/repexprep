# Package 4 QC smoke test

## Result

PASS

## Input

- samplesheet: `tests/samplesheets/main_local_valid.csv`
- profile: `local`
- Nextflow: 26.04.4

## Processes verified in `trace.txt`

- `VALIDATE_SAMPLESHEET`: executed successfully
- `FASTQ_INTEGRITY`: COMPLETED
- `FASTQC`: COMPLETED
- `SEQKIT_STATS`: COMPLETED
- `PAIR_AUDIT`: COMPLETED
- `RAW_FASTQ_STATS`: absent, as required

## QC routing

The validated local paired FASTQ input passed through `FASTQ_INTEGRITY`.
The integrity-checked reads were then consumed by FastQC, SeqKit statistics,
and PAIR_AUDIT.

The smoke workflow completed with Nextflow exit status 0.

Warnings about unmatched process selectors were expected because the isolated
QC smoke workflow does not instantiate downstream preprocessing processes.

## Veredict

QC SMOKE: PASS
