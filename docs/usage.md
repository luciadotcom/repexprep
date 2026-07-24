# Usage

> This document describes the current development version of REPEXPREP.

## Requirements

REPEXPREP requires:

- Nextflow
- Java
- A supported software environment or container runtime
- Paired-end FASTQ files
- An organelle reference FASTA when organelle filtering is enabled

## Input samplesheet

The pipeline accepts a comma-separated samplesheet.

The current development samplesheet contains the following columns:

| Column | Required | Description |
|---|---:|---|
| `sample` | Yes | Unique sample identifier |
| `fastq_1` | Yes | Path to the R1 FASTQ file |
| `fastq_2` | Yes | Path to the R2 FASTQ file |
| `organism` | Optional | Organism or project-specific taxon label |
| `genome_size_bp` | Optional: Required for coverage planning | Estimated haploid genome size in base pairs |
| `ploidy` | Optional: Required for coverage planning | Expected ploidy level. Must be a positive integer if provided |
| `organelle_fasta` | Conditional: Required if organelle filtering is enabled | Organelle reference FASTA. |
| `target_coverage` | Optional | Desired low-pass coverage. Defaults to global (0.2) if omitted |
| `target_read_length` | Optional | Requested normalized read length. When operation in global modes, this column may remain empty |

## Local execution

The verified local baseline command is documented in:

`docs/baseline/local_execution.md`

## MetaCentrum execution

The verified MetaCentrum command is documented in:

`docs/baseline/metacentrum_execution.md`

## Read-lengths normalization modes

### Automatic comparative mode

```bash
nextflow run . \
    --input samplesheet.csv \
    --target_length_mode global_auto \
    --min_retained_fraction 0.95
```
### Fixed comparative mode

Example in which all sampkles are cropped to 100bp. 

```bash
nextflow run . \
    --input samplesheet.csv \
    --target_length_mode global_fixed \
    --target_read_length 100
```
### Independent per-sample mode

```bash
nextflow run . \
    --input samplesheet.csv \
    --target_length_mode per_sample
```
***The per_sample mode is not yet implemented in the executable
workflow. Per-sample target_read_length values are rejected in global
modes.***

## Development status

The command-line interface and parameters may change before version 1.0.0.