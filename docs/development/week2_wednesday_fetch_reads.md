# Week 2 wednesday: remote read acquisition

## Objective
Materialise paired-end FASTQ files from remote run accessions and emit
the same downstream data contract used by local paired-end inputs.

## Supported input

- `source = accession`
- run accessions with prefixes `SRR`, `ERR`, or `DRR`
- `provider = auto`, `ena`, or `ncbi_sra`

## Expected output contract

```groovy
tuple val(meta), path(reads)

## Implemented architecture

```text
accession
    ↓
RESOLVE_REMOTE_PROVIDER
    ├── ena
    │     ↓
    │  ENA_FASTQ_DOWNLOAD
    │
    └── ncbi_sra
          ↓
       nf-core SRA download subworkflow
```
## Provider semantics
| Requested provider | Resolution                                                                              |
| ------------------ | --------------------------------------------------------------------------------------- |
| `ena`              | ENA is mandatory; failure is fatal                                                      |
| `ncbi_sra`         | NCBI SRA Toolkit is mandatory                                                           |
| `auto`             | ENA is preferred when exactly two FASTQ files are available; otherwise NCBI SRA is used |

## Validation results
| Test                               | Expected | Observed |
| ---------------------------------- | -------- | -------- |
| ENA resolver returns two URLs      | PASS     |          |
| ENA MD5 verification               | PASS     |          |
| ENA gzip integrity                 | PASS     |          |
| NCBI prefetch                      | PASS     |          |
| NCBI fasterq-dump                  | PASS     |          |
| Two FASTQ.GZ files emitted         | PASS     |          |
| R1/R2 pair audit                   | PASS     |          |
| Acquisition manifest emitted       | PASS     |          |
| `versions.yml` emitted             | PASS     |          |
| `provider=auto` resolves correctly | PASS     |          |

## Current limitations
- Only run accessions with prefixes SRR, ERR, or DRR are supported.
- Only paired-end runs are accepted.
- ENA inputs must resolve to exactly two FASTQ files.
- Local and remote channels are not yet merged.
- Remote reads do not yet enter READ_QC.
- MetaCentrum scratch requirements have not yet been calibrated

## Unified read-channel implementation

### Architecture

```text
validated samplesheet
        ↓
MATERIALIZE_READS
       / \
  local   accession
    |         |
    |     FETCH_READS
    |         |
    └────┬────┘
         ↓
 unified tuple(meta, [R1, R2])
         ↓
 FASTQ_INTEGRITY
         ↓
 FASTQC + SEQKIT_STATS + PAIR_AUDIT
``` 
All downstream processes receive tuple val(meta), path (reads). The source of the input is retained in metada but does not alter the QC, organelle filtering, normalisation or smapling logic. 

## Required metadata preserved
- id
- sample
- source
- provider
- resolved_provider
- accession
- organism
- genome size_1C_bp
- ploidy
- target_coverage
- organelle_fasta