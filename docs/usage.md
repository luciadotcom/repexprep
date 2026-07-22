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
| `genome_size_bp` | Optional | Estimated haploid genome size in base pairs |
| `ploidy` | Optional | Ploidy used by the coverage calculation. Must be a positive integer if provided |
| `organelle_fasta` | Conditional | Organelle reference FASTA. Required if organelle filtering is enabled |
| `target_coverage` | Optional | Desired low-pass coverage. Defaults to global (0.2) if omitted |
| `target_read_length` | Optional | Requested normalized read length |

## Local execution

The verified local baseline command is documented in:

`docs/baseline/local_execution.md`

## MetaCentrum execution

The verified MetaCentrum command is documented in:

`docs/baseline/metacentrum_execution.md`

## Development status

The command-line interface and parameters may change before version 1.0.0.