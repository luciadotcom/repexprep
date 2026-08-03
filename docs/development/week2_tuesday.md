# Week 2 Tuesday: Organelle filtering and unified samplsheet contract

## Baseline audit
- Reference checked: PASS
- Reference checksum recorded: PASS
- Container validated: PASS
- Minimap2 version: 2.31-r1302
- Samtools version: 1.24
- Input/output files reviewed: PASS
- R1/R2 counts equal: PASS
- Pair identifiers synchronised: PASS
- Baseline equivalence: PASS / PENDING / ACCEPTED DIFFERENCE
- Index strategy: FASTA runtime indexing / prebuilt MMI

## Objectives

1. Confirm equivalence and pairing preservation after organelle filtering.
2. Freeze the biological definition of 1C-based coverage.
3. Define one samplesheet interface for local FASTQ and remote accessions.
4. Extend samplesheet validation without changing downstream scientific logic.

## Coverage semantics

The default sampling objective is equal coverage relative to the 1C
genome size.

```text
requested_pairs =
    ceil(
        genome_size_1C_bp
        * target_coverage
        / (2 * target_read_length)
    )
```
## Unified samplesheet columns

| Column          | Use                               |
| ------------------- | ----------------------------------- |
| `sample`            | Sample identifier             |
| `source`            | `local` o `accession`               |
| `provider`          | `local`, `auto`, `ena` o `ncbi_sra` |
| `fastq_1`           | FASTQ R1 local                      |
| `fastq_2`           | FASTQ R2 local                      |
| `accession`         | Run remote accession             |
| `organism`          | taxon, spp,...                 |
| `genome_size_1C_bp` | Haploid genomic size at 1C       |
| `ploidy`            | Number of chromosomal sets           |
| `target_coverage`   | Explicited 1C coverage       |
| `organelle_fasta`   | Organelle reference           |

The samplesheet can combine both local and accession samples. 

### Local run requirements

- source = "local"
- provider = "local"/ " "
- fastq_1 and fastq_2 are mandatory
- accession = " "

### Accession run requirements

- source = "accession"
- provider = auto, ena, ncbi_sra
- accession column is mandatory
- fastq_1 and fastq_2 must remain empty

# Current `validate_samplesheet.py` behaviour

The current validator was inspected before implementing the unified
local/accession input model. The observations below are based on the
current contents of `bin/validate_samplesheet.py`.

### Recognised samplesheet columns

#### Required columns

| Column | Current role | Validation performed |
|---|---|---|
| `sample` | Unique sample identifier used throughout the workflow | Must not be empty. Only letters, numbers, underscores, dots and hyphens are allowed. |
| `fastq_1` | Path to the forward paired-end FASTQ file | Must not be empty. The path must exist, must be a regular file and must have an accepted FASTQ extension. |
| `fastq_2` | Path to the reverse paired-end FASTQ file | Must not be empty. The path must exist, must be a regular file and must have an accepted FASTQ extension. |

#### Optional columns

| Column | Current role | Validation performed |
|---|---|---|
| `organism` | Organism or taxon associated with the sample | No explicit content validation is visible in the inspected section. |
| `genome_size_bp` | Genome-size value used by downstream coverage calculations | When present, it must be a positive integer. |
| `ploidy` | Sample ploidy | When present, it must be a positive integer. |
| `organelle_fasta` | Path or identifier for the organellar reference | No path validation is visible in the inspected section. |
| `target_coverage` | Per-sample target sequencing coverage | When present, it must be a positive numeric value. |
| `target_read_length` | Per-sample fixed target read length | When present, it must be a positive integer. |

The current validator does not recognise the planned unified-input
columns:

```text
source
provider
accession

Therefore, the current implementation supports local paired-end FASTQ
inputs only.

## Global and default values


| Setting or rule                   | Current value                                                                                      | Effect                                                                                                   |
| --------------------------------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Required input columns            | `sample`, `fastq_1`, `fastq_2`                                                                     | Validation stops when any of these columns is absent.                                                    |
| Optional columns                  | `organism`, `genome_size_bp`, `ploidy`, `organelle_fasta`, `target_coverage`, `target_read_length` | These values are validated only when present and non-empty.                                              |
| Default path-resolution directory | `.`                                                                                                | Relative FASTQ paths are resolved against the current working directory unless `--base-dir` is supplied. |
| Sample-name pattern               | `^[A-Za-z0-9_.-]+$`                                                                                | Spaces and other unsafe characters are rejected.                                                         |
| Accepted FASTQ extensions         | `.fastq.gz`, `.fq.gz`, `.fastq`, `.fq`                                                             | Other filename extensions are rejected.                                                                  |
| Genome-size constraint            | Positive integer                                                                                   | Zero, negative values and non-integer values are rejected.                                               |
| Ploidy constraint                 | Positive integer                                                                                   | Zero, negative values and decimal values are rejected.                                                   |
| Coverage constraint               | Positive number                                                                                    | Zero, negative and non-numeric values are rejected.                                                      |
| Target-read-length constraint     | Positive integer                                                                                   | Zero, negative and non-integer values are rejected.                                                      |
| Whitespace handling               | Leading and trailing whitespace is removed                                                         | Header names and row values are stripped before validation.                                              |

The validator itself does not currently apply pipeline-level fallback
values for:

genome_size_bp
ploidy
target_coverage
target_read_length

It only validates values supplied in the samplesheet. Any global
defaults or overrides must therefore be applied elsewhere in the
Nextflow workflow or configuration.

Current limitations

| Limitation                                                          | Consequence                                                                                                                                                                                               |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fastq_1` and `fastq_2` are mandatory for every row                 | Remote accessions cannot be represented.                                                                                                                                                                  |
| No `source` field                                                   | The workflow cannot distinguish local and remotely acquired inputs.                                                                                                                                       |
| No `provider` field                                                 | ENA and NCBI acquisition strategies cannot be selected or recorded.                                                                                                                                       |
| No `accession` field                                                | SRA run accessions cannot be validated.                                                                                                                                                                   |
| `genome_size_bp` is biologically ambiguous                          | It is not explicit whether the value represents 1C, monoploid size, assembly size or total nuclear DNA.                                                                                                   |
| No explicit `coverage_basis`                                        | Coverage relative to 1C and coverage relative to total nuclear DNA cannot be distinguished.                                                                                                               |
| `organelle_fasta` is not visibly validated in the inspected section | Missing organellar-reference files may fail later in the workflow.                                                                                                                                        |
| FASTQ validation is path-level only                                 | The validator does not inspect gzip integrity, FASTQ structure, record counts or R1/R2 synchronisation. These checks correctly remain the responsibility of downstream QC processes such as `PAIR_AUDIT`. |
| No acquisition provenance                                           | The current metadata cannot record whether reads were local, downloaded from ENA or downloaded using NCBI SRA Toolkit.                                                                                    |
## Refactoring target

The planned unified validator should extend the current model to:

sample
source
provider
fastq_1
fastq_2
accession
organism
genome_size_1C_bp
ploidy
target_coverage
organelle_fasta

The principal conditional rules will be:

source = local
    fastq_1 and fastq_2 required
    accession forbidden

source = accession
    accession and provider required
    fastq_1 and fastq_2 forbidden

After local files are resolved or remote reads are downloaded, both
routes must converge on the same downstream contract:

tuple val(meta), path([fastq_1, fastq_2])

## Unified samplesheet implementation

### Supported sources

- `local`
- `accession`

### Supported providers

- `local`
- `auto`
- `ena`
- `ncbi_sra`

### Validation behaviour

Local rows require paired FASTQ paths and reject accessions.

Accession rows require a run accession and provider and reject local
FASTQ paths.

### Current limitation

Remote accessions are validated but are not yet materialised into FASTQ.
The forthcoming `FETCH_READS` subworkflow will convert accession rows
into the same `meta + [R1, R2]` contract used by local inputs.

Until `FETCH_READS` is implemented, accession rows stop after validation
with an explicit `ERROR [remote_input]` message and do not enter
`READ_QC`.

### Tests

| Fixture | Expected | Observed |
|---|---|---|
| `valid_local_unified.csv` | PASS | PASS end-to-end |
| `valid_accession_unified.csv` | PASS validation | PASS validation; stopped intentionally before `READ_QC` |
| `valid_mixed_unified.csv` | PASS validation | PASS validation; remote row stopped intentionally |
| `invalid_local_and_accession.csv` | FAIL | Not tested yet |
| `invalid_accession_missing_provider.csv` | FAIL | Not tested yet |
| `invalid_ploidy.csv` | FAIL | Not tested yet |
