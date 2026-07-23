# Samplesheet Contract

This document specifies the schema, type validation, and fallback logic for the input samplesheet (`--input`).

## Current Column Specifications

| Column | Status | Type | Validation Rule | Global Fallback / Notes |
|---|---|---|---|---|
| `sample` | **Required** | String | Non-empty, unique, matching `^[A-Za-z0-9_.-]+$` | Unique sample identifier. Used for outputs and tags. |
| `fastq_1` | **Required** | Path | Existing `.fastq`, `.fq`, `.fastq.gz`, or `.fq.gz` file | Path to Read 1 FASTQ file. |
| `fastq_2` | **Required** | Path | Existing `.fastq`, `.fq`, `.fastq.gz`, or `.fq.gz` file | Path to Read 2 FASTQ file. |
| `organism` | **Optional** | String | Any text | Biological label for taxonomy or downstream reports. |
| `genome_size_bp` | **Conditional** | Integer | Integer $> 0$ if provided | Haploid genome size in base pairs. Required for coverage planning unless `--genome_size_bp` is supplied globally. |
| `ploidy` | **Optional** | Integer | Integer $> 0$ if provided | Species ploidy level. (informational metadata; not currently used in coverage calculations) |
| `organelle_fasta` | **Conditional** | Path | Existing FASTA file when required | Path to organelle reference. Required if `--skip_organelle_filter false` and no global `params.organelle_fasta` is given. |
| `target_coverage` | **Optional** | Number | Float $> 0$ if provided | Desired low-pass coverage. Falls back to `params.target_coverage` (default: `0.20`) if omitted. |
| `target_read_length` | **Optional** | Integer | Integer $> 0$ if provided | Read length normalization. Overrides global strategy if target_length_mode= 'per_sample'|

---

## Architectural Decisions & Fallback Rules

### 1. Essential Sample Identification
* **`sample`**, **`fastq_1`**, and **`fastq_2`** are strictly **mandatory** per row. A row lacking any of these three fields will cause `validate_samplesheet.py` to terminate execution immediately.

### 2. Genome Size & Coverage Target Logic
* **`genome_size_bp`**: Must be specified per sample unless a global default (`--genome_size_bp`) is passed at runtime.
* **`target_coverage`**: Overrides the global `--target_coverage` setting for specific samples when present. If left empty, the pipeline defaults to the global setting (e.g., `0.20`).

### 3. Organelle Reference Logic (Conditional)
* If `--skip_organelle_filter false`:
  * `organelle_fasta` must be provided in the samplesheet **OR** passed globally via `--organelle_fasta`.
* If `--skip_organelle_filter true`:
  * `organelle_fasta` is ignored and can be safely left blank.

### 4. Read Length Trimming (Optional)
* **`target_read_length`**: Optional per sample. If empty, reads are cropped to `params.target_read_length` (if specified) or kept at their native length.

## Target read-length modes

### `global_auto`

- Intended for comparative RepeatExplorer analysis.
- The `target_read_length` samplesheet column must be empty.
- Every sample is profiled independently.
- A single target is selected for the complete dataset.
- All samples are cropped to that target.

### `global_fixed`

- Intended for explicitly controlled comparative analyses.
- `--target_read_length` is required.
- The samplesheet column must be empty.
- Every sample is cropped to the supplied global value.

### `per_sample`

- Intended for samples that will be analyzed independently.
- The samplesheet column may supply one value per sample.
- When the value is empty, the pipeline may calculate a candidate for
  that sample.
- Outputs are not guaranteed to be mutually compatible for comparative
  RepeatExplorer analysis.

## Validation rules

| Mode | Global parameter | Samplesheet column | Behaviour |
|---|---|---|---|
| `global_auto` | Must be empty | Must be empty | Calculate one dataset-wide target |
| `global_fixed` | Required | Must be empty | Use the supplied global target |
| `per_sample` | Must be empty | Optional or required according to policy | Select independently |

## Automatic global selection

For every sample:

1. Calculate the minimum length of each complete read pair.
2. Select the lower quantile corresponding to the desired retained fraction.
3. Produce one robust candidate target length.

For the complete dataset:

1. Collect all per-sample candidates.
2. Select the minimum candidate.
3. Check the configured minimum and maximum target lengths.
4. Broadcast the selected target to all samples.

## Safety checks

The pipeline must fail when:

- the automatic global target is below `min_target_read_length`;
- `min_target_read_length` is greater than `max_target_read_length`;
- a per-sample target is supplied in a global mode;
- `global_fixed` is selected without `target_read_length`;
- the requested fixed target cannot retain any complete pairs for one
  or more samples.
