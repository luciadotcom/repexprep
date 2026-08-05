# Week 2 Friday morning: output-publication contract

## Objective

Centralise output publication in `conf/modules.config`, prevent
unnecessary duplication of large intermediates and define a stable
results-directory contract before the final local/HPC validation.

## Existing publishDir at the very beggining of the day

modules/local/validate_samplesheet/main.nf:7:    publishDir "${params.outdir}/pipeline_info", mode: 'copy'
modules/local/pair_audit/main.nf:7:    publishDir "${params.outdir}/raw_qc/pair_audit", mode: 'copy'
modules/local/organelle_filter/main.nf:9:    publishDir "${params.outdir}/organelle_filter/fastq",
modules/local/organelle_filter/main.nf:13:    publishDir "${params.outdir}/organelle_filter/reports",
modules/local/sample_pairs/main.nf:7:    publishDir "${params.outdir}/coverage_sampling/sampled_reads", mode: 'copy', pattern: "*.fastq.gz"
modules/local/sample_pairs/main.nf:8:    publishDir "${params.outdir}/coverage_sampling/reports", mode: 'copy', pattern: "*.sampling_report.tsv"
modules/local/rename_convert_fasta/main.nf:7:    publishDir "${params.outdir}/repex/fasta", mode: 'copy', pattern: "*.repex.fasta"
modules/local/rename_convert_fasta/main.nf:8:    publishDir "${params.outdir}/repex/reports", mode: 'copy', pattern: "*.repex_format_report.tsv"
modules/local/validate_repex_fasta/main.nf:6:    publishDir "${params.outdir}/repex/validation",
modules/local/plan_coverage/main.nf:7:    publishDir "${params.outdir}/coverage_sampling/plans", mode: 'copy'
modules/local/choose_target_length/main.nf:7:    publishDir "${params.outdir}/length_normalization/target_length", mode: 'copy'
modules/local/legacy/raw_fastq_stats/main.nf:7:    publishDir "${params.outdir}/raw_qc/fastq_stats", mode: 'copy'
modules/nf-core/fastqc/main.nf:5:    publishDir "${params.outdir}/raw_qc/fastqc", mode: 'copy'
modules/nf-core/seqkit/stats/main.nf:5:    publishDir "${params.outdir}/raw_qc/seqkit_stats", mode: 'copy'
conf/modules.config:3:        publishDir = [
conf/modules.config:9:        publishDir = [
conf/modules.config:15:        publishDir = [
conf/modules.config:26:    publishDir = [

## Results publication policy

A publication policy was defined to determine which pipeline outputs should be copied from the Nextflow working directory (`work/`) into the final results directory (`results/`).

### Published outputs

The following scientifically interpretable checkpoints and reports are published:

- validated samplesheet;
- input provenance records;
- remote provider resolution;
- acquisition manifests;
- integrity, FastQC, SeqKit, and pair-audit reports;
- organelle-filtered FASTQ files;
- organelle-filtering reports and metadata;
- read-length profiles and the global target-length decision;
- coverage plans;
- subsampled FASTQ files and sampling reports;
- final FASTA files prepared for RepeatExplorer;
- formatting and validation reports;
- RepeatExplorer outputs, logs, and run reports.

### Outputs retained only in `work/`

The following files remain only in the Nextflow working directory:

- original local FASTQ files;
- newly downloaded remote FASTQ files;
- temporary `prefetch` and `fasterq-dump` files;
- FASTQ files cropped during read-length normalization;
- individual `versions.yml` files;
- temporary RepeatExplorer analysis files;
- legacy `RAW_FASTQ_STATS` outputs.

### Rationale

Downloaded remote FASTQ files and cropped normalization FASTQ files can be reproduced from the accession, original inputs, and pipeline parameters. Publishing them would duplicate large volumes of data without creating an additional scientifically meaningful output.

Organelle-filtered FASTQ files, subsampled FASTQ files, and final RepeatExplorer FASTA files are retained because they represent clearly defined and scientifically interpretable checkpoints in the preprocessing workflow.

### Target results directory structure

```text
results/
├── pipeline_info/
│   └── samplesheet.validated.csv
│
├── input_acquisition/
│   ├── provenance/
│   ├── provider_resolution/
│   └── manifests/
│
├── raw_qc/
│   ├── integrity/
│   ├── fastqc/
│   ├── seqkit_stats/
│   └── pair_audit/
│
├── organelle_filter/
│   ├── fastq/
│   ├── reports/
│   └── metadata/
│
├── length_normalization/
│   ├── profiles/
│   ├── target_length/
│   └── reports/
│
├── coverage_sampling/
│   ├── plans/
│   ├── sampled_reads/
│   └── reports/
│
├── repex/
│   ├── fasta/
│   ├── reports/
│   └── validation/
│
└── repeatexplorer/
    ├── results/
    ├── logs/
    └── reports/
```

## Publication policy

Output publication is now controlled centrally through
`conf/modules.config`.

### Published large files

- organelle-filtered FASTQ;
- coverage-sampled FASTQ;
- final RepeatExplorer-compatible FASTA;
- RepeatExplorer results when enabled.

### Non-published large intermediates

- original local FASTQ;
- remotely downloaded raw FASTQ;
- temporary SRA files;
- fixed-length cropped FASTQ.

These files remain in the Nextflow work directory and can be reproduced
from the input source, commit and parameters.

### Published audit files

- validated samplesheet;
- input provenance;
- provider-resolution reports;
- acquisition manifests;
- QC reports;
- organelle-filtering reports and metadata;
- read-length profiles;
- coverage plans;
- sampling reports;
- REPEX validation reports;
- RepeatExplorer execution logs and reports.

### Validation

| Check | Result |
|---|---|
| No `publishDir` remains in modules | PASS |
| Configuration parses | PASS |
| Local workflow completes | PASS |
| Output-layout checker passes | PASS |
| No scattered `versions.yml` files | PASS |
| No remote raw FASTQ duplication | PASS |
| No normalized FASTQ duplication | PASS |
| Resume preserves output layout | PASS |