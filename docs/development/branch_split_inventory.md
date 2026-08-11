# Branch split inventory

## Initial repository state

```text
Date: 2026-08-11T13:01:24+02:00
Host: penguin
Current branch: week3/pilot
Current commit: e9d26a70547998f40cb3d42ecb85a332c33d0d79

On branch week3/pilot
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	...
	SRR38519255_Carex_boryana_R1.organelle_filtered.fastq.gz
	SRR38519255_Carex_boryana_R2.organelle_filtered.fastq.gz
	assets/test_data/samplesheet_toyA_with_organelle.csv
	carex_breviculmis_mitochondrion.fasta
	containers/repexprep-tools_1.0.0.image.json
	containers/repexprep-tools_1.0.0.packages.json
	containers/repexprep-tools_1.0.0.sif.sha256
	containers/repexprep-tools_1.0.0.versions.txt
	docs/development/branch_split_inventory.md
	docs/development/week3_monday_pilot.md
	docs/validation/organelle_references.tsv
	docs/validation/week3_pilot_candidate_runs.tsv
	docs/validation/week3_pilot_candidate_runs_paired.tsv
	docs/validation/week3_pilot_candidates.tsv
	docs/validation/week3_pilot_multirun_samples.tsv
	docs/validation/week3_pilot_selection.tsv
	organelle_filter_pair_audit.tsv
	validation_runs/

nothing added to commit but untracked files present (use "git add" to track)

* e9d26a7 (HEAD -> week3/pilot, week2/container-parity) feat: add equivalent Docker and Singularity profiles
* 677556d (week2/output-publication) test: validate published output layout
* 9849027 refactor: centralize output publication configuration
* fadca7b (week2/repeatexplorer-hardening) refactor: harden optional RepeatExplorer execution
* 8796596 fix: gate RepeatExplorer input on FASTA validation
* a196f02 (tag: snapshot-2026-08-04-1521, week2/repeatexplorer-call, week2/fetch-reads) feat: implement haploid 1C coverage sampling
* 8d5385d feat: unify local and remote paired-end read inputs
* 0dc2eba feat: add reproducible remote FASTQ acquisition
* 7834b9f (week2/unified-input) feat: validate unified local and accession inputs
* ad788e8 docs: define unified input and 1C coverage contracts
* b673d47 feat: unify pipeline input handling
* 9c6a10f (origin/week2/qc-trimming, week2/qc-trimming) test: validate organelle filtering equivalence
* b9ecd9e fix: use validated organelle filter container
* 2ccc896 fix: use combined minimap2 and samtools container
* 218d601 fix: use verified minimap2+samtools singularity image
* 9f0e12d fix: update valid container URI for organelle filter
* 9ea567a fix: set hardcoded container in organelle filter module
* 7c1364c fix: enable singularity and assign container for organelle filter
* 400933d fix: clean metacentrum config syntax
* d45c620 fix: resolve variable scope conflict in CROP_FIXED_LENGTH module
```
## Target branch architecture

### Stable branch: main

`main` is the production-oriented workflow for experimentally generated paired-end WGS data.

Inputs are local paired FASTQ files.

The following biological metadata are mandatory:

- `genome_size_1C_bp`
- `ploidy`

Remote input acquisition and automated genome-property inference are
intentionally outside the scope of `main`.

### Experimental branch

`experimental/input-acquisition` preserves the generalized input
architecture supporting local and accession-based inputs.

Future genome-characterization experiments will be developed only on
this branch unless explicitly promoted to `main`.

## Component classification

| Component | Main | Experimental | Notes |
|---|---:|---:|---|
| Local paired FASTQ input | KEEP | KEEP | Core input |
| `genome_size_1C_bp` | KEEP | KEEP | Required in main |
| `ploidy` | KEEP | KEEP | Required metadata |
| 1C coverage semantics | KEEP | KEEP | Ploidy does not multiply coverage denominator |
| FastQC | KEEP | KEEP | |
| SeqKit stats | KEEP | KEEP | |
| Pair audit | KEEP | KEEP | |
| FASTQ integrity | KEEP | KEEP | |
| Organelle filtering | KEEP | KEEP | |
| Three target-length modes | KEEP | KEEP | |
| Global target-length selection | KEEP | KEEP | Where applicable |
| Coverage planning | KEEP | KEEP | |
| Deterministic sampling | KEEP | KEEP | |
| REPEX FASTA formatting | KEEP | KEEP | |
| REPEX FASTA validation | KEEP | KEEP | |
| PREPROC workflow | KEEP | KEEP | |
| REPEXANALYSIS workflow | KEEP | KEEP | |
| Optional PREPROC → REPEXANALYSIS | KEEP | KEEP | CLI controlled |
| RepeatExplorer module | KEEP | KEEP | |
| Local profile | KEEP | KEEP | |
| MetaCentrum profile | KEEP | KEEP | |
| `source` | REMOVE | KEEP | |
| `provider` | REMOVE | KEEP | |
| `accession` | REMOVE | KEEP | |
| `resolved_provider` | REMOVE | KEEP | |
| RESOLVE_REMOTE_PROVIDER | REMOVE | KEEP | |
| ENA download | REMOVE | KEEP | |
| NCBI/SRA acquisition | REMOVE | KEEP | |
| FETCH_READS | REMOVE | KEEP | |
| Remote materialization | REMOVE | KEEP | |
| Acquisition manifest | REMOVE | KEEP | |
| Remote input provenance | REMOVE | KEEP | |
| K-mer profiling | NOT IMPLEMENTED | FUTURE | |
| GenomeScope | NOT IMPLEMENTED | FUTURE | |
| Smudgeplot | NOT IMPLEMENTED | FUTURE | |
| Genome metadata inference | NOT IMPLEMENTED | FUTURE | |

## Candidate clean main base

Candidate commit:

`b673d47`

Reason:

This commit is the current candidate base for rebuilding the stable
`main` branch because it retains the established local-input
preprocessing and quality-control functionality while still predating
the introduction of accession-aware input validation and remote read
acquisition.

At this point in the history, the pipeline already contains the Week 2
quality-control and preprocessing work, including the reproducible QC
block, SeqKit-based read statistics, paired-end handling, read-length
normalization, and validated organelle filtering.

The subsequent commits introduce the experimental remote-input
architecture:

- `ad788e8` introduces the unified local/accession input contract and
  accession/provider-oriented documentation and test samplesheets;
- `7834b9f` introduces accession-aware samplesheet validation;
- `0dc2eba` introduces reproducible remote FASTQ acquisition;
- later commits further integrate local and remote paired-end input
  handling.

The intended branch split is therefore to retain the stable local
preprocessing and QC functionality on `main`, while keeping
accession/provider resolution and remote acquisition functionality on
experimental branches.

This commit has NOT yet been used to reset or rewrite `main`.

## Post-base commit classification

The following commits occur after candidate clean-main base `b673d47`.

Classification rules:

- `KEEP`: stable functionality that should be reincorporated into `main`;
- `EXPERIMENTAL`: accession/provider/remote-acquisition functionality
  that should remain outside stable `main`;
- `MIXED`: contains both stable and experimental changes and therefore
  requires selective reconstruction rather than direct cherry-picking.

## Post-base commit classification

The following commits occur after candidate clean-main base `b673d47`.

Classification rules:

- `KEEP`: stable functionality that belongs in `main`;
- `EXPERIMENTAL`: accession/provider/remote-acquisition functionality
  that should remain outside stable `main`;
- `MIXED`: contains both stable and experimental functionality and must
  be reconstructed selectively rather than cherry-picked wholesale.

| Commit | Classification | Reason |
|---|---|---|
| `ad788e8` | MIXED | Defines the haploid 1C coverage contract that should be retained, but also introduces the unified local/accession contract, provider metadata, accession-oriented documentation, and remote-input test samplesheets. |
| `7834b9f` | MIXED | Introduces accession-aware samplesheet validation, while also modifying stable preprocessing components including organelle filtering, coverage planning, and the PREPROC workflow. |
| `0dc2eba` | EXPERIMENTAL | Implements reproducible remote FASTQ acquisition, including provider resolution, ENA downloading, NCBI SRA prefetch/fasterq-dump support, and FETCH_READS. |
| `8d5385d` | MIXED | Introduces useful general functionality such as FASTQ integrity checking, input provenance, and READ_QC improvements, but couples these changes to local/remote read materialization and accession-based acquisition. |
| `a196f02` | MIXED | Implements the stable haploid 1C coverage-sampling architecture, including coverage planning and deterministic sampling, but also modifies accession-aware validation, remote materialization, and remote-input samplesheets. |
| `8796596` | KEEP | Correctly gates RepeatExplorer input on successful REPEX FASTA validation. This is stable downstream validation logic independent of remote acquisition. |
| `fadca7b` | KEEP | Hardens optional RepeatExplorer execution and adds dedicated RepeatExplorer workflow configuration, validation data, and smoke testing. This functionality belongs in the stable downstream pipeline. |
| `9849027` | MIXED | Centralizes output publication, which is a stable architectural improvement that should be retained, but the publication configuration was created after remote-input integration and may contain acquisition-specific output rules. Stable publication logic must therefore be reconstructed selectively. |
| `677556d` | MIXED | Adds an output-layout validator and publication validation documentation that should be retained, but the resulting output contract includes optional remote/ENA acquisition outputs and therefore cannot be transferred unchanged to a local-only stable `main`. |
| `e9d26a7` | MIXED | Adds reproducible Docker/Singularity container parity and container metadata that should be retained, but also modifies global configuration, `main.nf`, publication configuration, and RepeatExplorer wiring on top of the experimental architecture. Container functionality should therefore be reconstructed selectively. |
| `c15a9cb` | EXPERIMENTAL | Preservation snapshot created explicitly before the branch split. It contains the experimental architecture together with generated validation outputs, pilot inventories, historical container metadata, and other working-state artifacts. It must not be replayed onto stable `main`. |

No `MIXED` commit will be cherry-picked wholesale. Stable functionality from
mixed commits will be reconstructed selectively on the rebuilt `main`.

`KEEP` classification denotes functionality that belongs in stable `main`;
it does not guarantee that the original commit can be cherry-picked without
dependency conflicts.