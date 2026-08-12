# REPEXPREP

## Overview

REPEXPREP is a Nextflow DSL2 pipeline for preprocessing paired-end
whole-genome sequencing reads for repeatome analysis with RepeatExplorer2.

The pipeline validates the input samplesheet, audits paired-end FASTQ files, calculates raw-read statistics, normalizes read length, removes
read pairs matching organelle reference sequences, plans coverage-based
subsampling, samples paired reads reproducibly, and generates validated
RepeatExplorer2-compatible FASTA files.

```mermaid
flowchart TD
    A[Input samplesheet] --> B[VALIDATE_SAMPLESHEET]
    B --> C[Parsed sample channel]

    C --> D[RAW_FASTQ_STATS]
    C --> E[PAIR_AUDIT]
    C --> F[ORGANELLE_FILTER]

    F --> G[PROFILE_LENGTH]
    G --> H[SELECT_GLOBAL_TARGET_LENGTH]
    H --> I[CROP_FIXED_LENGTH]
    I --> J[PLAN_COVERAGE]
    J --> K[SAMPLE_PAIRS]
    K --> L[RENAME_FASTQ_TO_FASTA]
    L --> M[VALIDATE_REPEX_FASTA]
    M --> N[Accepted RepeatExplorer FASTA]
```

## Current status

REPEXPREP is currently under active development.

The current pipeline baseline has been tested:

- locally using four subsampled *Carex* datasets;
- on the MetaCentrum PBS Pro computing infrastructure;
- with organelle-read filtering enabled;
- using paired-end compressed FASTQ input.

The corresponding functional baseline is tagged as:

```text
baseline-local-hpc-orgfilter-2026-07-20
```
This tag represents a functional development baseline, not a stable public release.

Dataset-wide read-length normalization has been implemented for
comparative RepeatExplorer analyses.

The current implementation supports:

- `global_auto`: calculates one robust target for the complete dataset;
- `global_fixed`: applies one user-supplied target to all samples.

Both modes have been smoke-tested with two paired-end samples. The
`per_sample` mode remains planned but is not currently exposed as a supported execution mode.

General FASTQ statistics are generated with the nf-core `seqkit/stats` module.FASTQC generates diagnostic quality reports. The custom `pair_audit.py` script validates paired-read integrity and synchronisation.


## Workflow overview

1. **Samplesheet validation**.- Validate the input CSV samplesheet and resolve file paths. Module involved: *VALIDATE_SAMPLESHEET*
2. **Parallel raw QC and pair audit**.-
    2.1. Calculate raw FASQ statistics. Module involved: standarized nf-core module *SeqKit stats*. Previously, *RAW_FASTQ_STATS* (currently in `legacy`).
    2.2. Audit paired-end FASTQ integrity and read-pairing consistency. Module involved: *PAIR_AUDIT*
    2.3.Qualiy control per-file. Module involved: *FASTQC*
3. **Organelle filtering**.- Remove read pairs matching chloroplast or mitochondrial reference sequences. Module involved:*ORGANELLE_FILTER*
4. **Read-length planning**.- Determine the target read-length across samples. Module involved: *CHOOSE_TARGET_LENGTH*
5. **Read trimming**.- Crop paired reads to the exact target fixed length. Module involved: *CROP_FIXED_LENGTH*
6. **Coverage planning**.- Calculate the exact number of read pairs needed based on genome size, ploidy, and target coverage. Module involved: *PLAN_COVERAGE*
7. **Paired subsampling**.-Subsample paired-end reads reproducibly using a fixed random seed. Module involved: *SAMPLE_PAIRS*
8. **RepeatExplorer formatting**.- Interleave paired reads, convert FASTQ to FASTA, and format read headers to conform strictly to RepeatExplorer2 requirements. Module involved: *RENAME_FASTQ_TO_FASTA*
9. **Final FASTA validation**.- Audit the generated FASTA file against RepeatExplorer2 structural rules to issue a final acceptance report. Module involved: *VALIDATE_REPEX_FASTA*

## Main processing stages

| Stage | Purpose | Main output |
|---|---|---|
| Samplesheet validation | Checks input columns, metadata, and file paths | `samplesheet.validated.csv` |
| Paired-end read audit | Verifies consistency between R1 and R2 files | `${meta.id}.pair_audit.tsv` |
| Raw FASTQ statistics | Records basic properties of the input reads | `${meta.id}.raw_fastq_stats.tsv` |
| Target read-length selection | Determines the normalization length | `${sample_id}.target_length.tsv` |
| Fixed-length normalization | Crops paired reads to a common length | `${meta.id}_R*.fixed.fastq.gz` |
| Organelle filtering | Removes read pairs matching organelle references | `*_R*.organelle_filtered.fastq.gz` |
| Coverage planning | Calculates the required number of read pairs | `${sample_id}.coverage_plan.tsv` |
| Paired-read subsampling | Samples reads according to the coverage plan | `${meta.id}_R*.sampled.fastq.gz` |
| RepeatExplorer formatting | Converts paired reads into a RepeatExplorer2-compatible FASTA file | `${meta.id}.repex.fasta` |
| FASTA validation | Checks the structure of the final FASTA file | `${meta.id}.repex_validation.tsv` |

## Architecture documentation

Architecture documentation can be found in `docs/architecture`. For detailed process contracts, execution graph diagrams, component maintenance decisions, and intermediate file schemas, refer to the following specs:

- **Process Inventory:** `docs/architecture/process_inventory.tsv`. Also, an additional process_inventory document is available at a readable format at `docs/architecture/process_inventory.md`
- **Workflow Map:** `docs/architecture/workflow_map.md`
- **Component Refactoring Plan:** `docs/architecture/component_decisions.tsv`

## Preliminary requirements

The pipeline currently requires:

- Nextflow;
- Java 17 or a compatible Java version;
- Python 3;
- the command-line software required by the individual pipeline processes;
- access to a PBS Pro scheduler when using the MetaCentrum profile.

The local `test` profile currently uses software available directly in
the local environment. Container support has not yet been finalized.

## Input information

The pipeline accepts a comma-separated samplesheet in CSV format.

Example:

```csv
sample,fastq_1,fastq_2,organism,genome_size_bp,ploidy,organelle_fasta,target_coverage,target_read_length
SRR38519255_Carex_boryana,data/sample_R1.fastq.gz,data/sample_R2.fastq.gz,Carex_boryana,1350000000,2,org_reference/combined/carex_combined_orgs.fasta,0.001,
```

Relative paths are recommended when the same samplesheet is intended to
be used on different systems.

## Samplesheet columns

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
| `target_read_length` | Optional | Requested normalized read length. Might remain empty when operating in global modes |

## Quick start

Run all commands from the root directory of the pipeline repository.

### Local test execution

```bash
nextflow run . \
    -profile test \
    --input samplesheets/validated/local_test_subsample_portable.orgfix.validated.csv \
    --outdir results/local_test_organelle_filter_test_2
```

### Resume a local execution

Resume an interrupted or previously cached execution with:

```bash
nextflow run . \
    -profile test \
    --input samplesheets/validated/local_test_subsample_portable.orgfix.validated.csv \
    --outdir results/local_test_organelle_filter_test_2 \
    -resume
```

### MetaCentrum test execution

After logging in to MetaCentrum, load an available Nextflow module:

```bash
module avail nextflow/
module add nextflow
nextflow -version
```

Run the pipeline with the MetaCentrum profile:

```bash
nextflow run . \
    -profile metacentrum \
    --input samplesheets/local_test_subsample_metacentrum.csv \
    --outdir results/metacentrum_organelle_filter_test
```

### Resume a MetaCentrum execution

```bash
nextflow run . \
    -profile metacentrum \
    --input samplesheets/local_test_subsample_metacentrum.csv \
    --outdir results/metacentrum_organelle_filter_test \
    -resume
```

## Main parameters

| Parameter | Description |
|---|---|
| `--input` | Path to the input samplesheet |
| `--outdir` | Output directory |
| `--skip_organelle_filter` | Skip organelle filtering when set to `true` |
| `--target_length_mode` | Select the trimming method that fits better post hoc sample analysis |
| `--help` | Display the pipeline help message |

Additional parameters are defined in:
```text
nextflow_schema.json
```
### Target length mode clarification

- **Global modes**: select for multispecies comparative analyses:
    - **Global_auto**: a single target read length is calculated for the complete dataset and applied to all samples.
    - **Global_fixed**: the user supplies an explicit value to which every sample of the dataset will be cropped. 
- **Per-sample mode**: individual sample analysis. Each sample is trimmed to an individually-targetted length.Each sample obtains its own target length.*Not advisable for comparative analysis in RepeatExplorer*

Additional information is explicited in `docs/architecture/ADR-001-target-read-length.md` and `docs/architecture/samplesheet_contract.md`. 


## Organelle references

Small organelle reference FASTA files used during development are stored
under:

```text
org_reference/
```

The current combined references include:

- *Arabidopsis thaliana*, used as a model dicot reference;
- *Oryza sativa*, used as a model monocot reference;
- *Carex*, represented by *Carex agglomerata* chloroplast sequences and
  *Carex breviculmis* mitochondrial sequences.

Additional information about the sequences can be found in `docs/usage.md`. 

## Output structure

```text
results/
├── pipeline_info/
│   └── samplesheet.validated.csv
├── raw_qc/
│   ├── pair_audit/
│   └── fastq_stats/
├── length_normalization/
│   ├── target_length/
│   ├── cropped_reads/
│   └── reports/
├── organelle_filter/
│   ├── fastq/
│   └── reports/
├── coverage_sampling/
│   ├── plans/
│   ├── sampled_reads/
│   └── reports/
└── repex/
    ├── fasta/
    ├── reports/
    └── validation/
```

The principal final output is:

```text
${params.outdir}/repex/fasta/*.repex.fasta
```
## Data acceptance criterion

A run is considered successful and accepted for downstream RepeatExplorer analysis ONLY when the corresponding validation report is generated (`${params.outdir}/repex/validation/${sample}.repex_validation.tsv`), containing:

```text
status = PASS
```

## Development warning and known limitations

- The pipeline is under active development.
- Parameters, interfaces, and output structure may change before the
  first stable release.
- Container support has not yet been finalized.
- Testing has so far focused on four subsampled *Carex* datasets.
- The full dataset has not yet been used for systematic performance benchmarking.
- Organelle-reference provenance still requires complete documentation.
- The pipeline is not yet fully compliant with nf-core guidelines.

## Planned developments

Planned developments include:

- reproducible container support;
- testing with the complete dataset;
- improved automated testing;
- progressive alignment with nf-core guidelines;
- filling out the conf/modules.config with all the publishDir routes to easily change the result tree;
- integration of the ploidy data into de plan_coverage.py script to normalize coverage taking into account chromosomal sets. 

## Documentation

Baseline execution records, software versions, reference-sample
inventories, and input/output documentation are stored in:

```text
docs/baseline/
```

## Citation

Citation information is provided in:

```text
CITATIONS.md
```

When using REPEXPREP, please cite Nextflow, RepeatExplorer2, and the
software executed by the individual pipeline modules.

## License

License information is provided in:

```text
LICENSE
```