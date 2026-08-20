# ADR-001: Dataset-wide target read length

## Status

Accepted for implementation.

## Context

RepeatExplorer comparative analyses require all reads included in the
same combined analysis to have a uniform read length.

The current pipeline can select a different target length independently
for every sample. This may produce internally uniform sample outputs
that are not mutually compatible for comparative analysis.

## Decision

The pipeline will support three target-length modes.

### global_auto

Default mode for comparative analyses.

1. Profile paired-read lengths independently for each sample.
2. Calculate a candidate target length corresponding to the configured retained fraction.
3. Select the minimum robust candidate across all samples.
4. Crop every sample to this single dataset-wide target length.

### global_fixed

The user supplies one explicit value through:

`--target_read_length`

All samples are cropped to that value.

### per_sample

Each sample obtains its own target length.

This mode is intended only for samples that will be analyzed separately.
The pipeline must warn that the outputs are not guaranteed to be
compatible for comparative RepeatExplorer analysis.

## Default parameters

- `target_length_mode = global_auto`
- `target_read_length = null`
- `min_retained_fraction = 0.95`
- `min_target_read_length = 100`
- `max_target_read_length = 300`

## Samplesheet rules

- In `global_auto`, per-sample `target_read_length` cells must be empty.
- In `global_fixed`, `--target_read_length` is required and the
  samplesheet column must be empty.
- In `per_sample`, the samplesheet column may define a value for each
  sample.
- Mixed or ambiguous configurations must fail with a clear error.

## Implementation consequence

The current per-sample target-selection stage will be replaced by:

1. `PROFILE_READ_LENGTH`
2. `SELECT_GLOBAL_TARGET_LENGTH`
3. `CROP_FIXED_LENGTH`

For implementation details and validation rules see `docs/architecture/samplesheet_contract.md`