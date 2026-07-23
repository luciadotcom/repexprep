# Global target-length implementation plan

## Current implementation

The current implementation selects a target read length independently
for each sample.

## Required architecture

### 1. PROFILE_READ_LENGTH

Execution frequency: once per sample.

Input:

- metadata;
- filtered paired-end FASTQ files;
- `min_retained_fraction`.

Output:

- sample metadata;
- read-length profile TSV;
- candidate target length.

Suggested profile columns:

- `sample`
- `total_pairs`
- `observed_min_pair_length`
- `observed_max_pair_length`
- `candidate_target_length`
- `expected_retained_pairs`
- `expected_retained_fraction`

### 2. SELECT_GLOBAL_TARGET_LENGTH

Execution frequency: once per dataset.

Input:

- all sample profile TSV files;
- target-length mode;
- optional fixed target;
- minimum and maximum target lengths.

Output:

- `global_target_length.tsv`
- per-sample retention projection table.

### 3. CROP_FIXED_LENGTH

Execution frequency: once per sample.

Input:

- metadata;
- paired-end reads;
- selected global-target file.

Output:

- cropped paired-end reads;
- cropping and retained-pair report.

## Nextflow data flow

1. Profile every sample.
2. Collect all profile files.
3. Select one global target.
4. Broadcast the target to all samples.
5. Crop every sample using the same value.

## Migration notes

- Remove the current interpretation of the 95th percentile as a
  retention target.
- Replace `target_length_percentile` with `min_retained_fraction`.
- Preserve the current implementation until equivalence tests are
  available.
- Implement the new architecture on a feature branch.
