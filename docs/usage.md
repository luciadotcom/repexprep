# Usage

> This document describes the current development version of REPEXPREP.

## Pipeline requirements

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

## Paired-end input requirements

For each sample: 
- both R1 and R2 must exist;
- both files must be readable;
- the sample identifier must be unique;
- R1 and R2 must be supplied together;
- single-end input is not currently supported;
- orphan reads are not propagated downstream.

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

## Initial FASTQ quality control

Each samplesheet row must provide a valid paired-end FASTQ input.

The initial quality-control block performs three separate operations:

1. FASTQ summary statistics
2. FASTQC quality assessment
3. Paired-read integrity and synchronisation validation

These operations have different purposes and should not be interpreted
as interchangeable.

### FASTQ statistics

General statistics are generated using a standard module. These may
include:

- number of sequences;
- total number of bases;
- minimum read length;
- maximum read length;
- average read length;
- file format and compression status.

The previous `raw_fastq_stats.py` script is not used in the migrated
workflow when the same information can be produced by the standard
module.

### FASTQC

FASTQC is used to inspect characteristics such as:

- per-base sequence quality;
- sequence-length distribution;
- GC-content distribution;
- adapter-content signals;
- overrepresented sequences;
- duplication levels.

FASTQC reports are diagnostic outputs. FASTQC does not modify the reads.

### Paired-read audit

The custom `pair_audit.py` script is retained and executed through a
local Nextflow module.

The audit verifies:

- that both FASTQ files contain the same number of records;
- that R1 and R2 records occur in the same order;
- that paired identifiers correspond;
- that FASTQ records are structurally complete;
- that no truncated or displaced pair is accepted.

A failed paired-read audit stops the affected sample before downstream
processing.

### Trimming behaviour

The current workflow does not introduce new quality or adapter trimming
unless this operation is present in the validated baseline pipeline.

The later `CROP_FIXED_LENGTH` process is not considered quality
trimming. It applies a common read length selected for comparative
analysis.

## Development status

The command-line interface and parameters may change before version 1.0.0.