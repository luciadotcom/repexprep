# Global target-length smoke test

## Execution context

- Date: 2026-07-24T15:38:28+02:00
- Branch: feat/global-target-length
- Commit before final documentation: 42ebaa40e1c54aecd5ddc1ee87cf18b7bd2253f4
- Samplesheet: `tests/samplesheets/valid_two_samples_global_auto.csv`
- Number of samples: 2

## Implemented workflow

1. `PROFILE_READ_LENGTH` profiles every sample independently.
2. `SELECT_GLOBAL_TARGET_LENGTH` selects one target for the dataset.
3. `CROP_FIXED_LENGTH` applies the selected target to every sample.

## Global automatic mode

- Mode: `global_auto`
- Minimum retained fraction: `0.95`
- Selected dataset-wide target: `150 bp`
- Expected process executions:
  - `PROFILE_READ_LENGTH`: 2
  - `SELECT_GLOBAL_TARGET_LENGTH`: 1
  - `CROP_FIXED_LENGTH`: 2

### Validation

- Both samples were processed.
- One dataset-wide target was selected.
- Both R1 and R2 files were cropped to exactly `150 bp`.
- Paired-end read counts remained synchronized.

## Global fixed mode

- Mode: `global_fixed`
- Requested target: `100 bp`
- Selected target: `100 bp`

### Validation

- Both samples were cropped to exactly 100 bp.
- Paired-end read counts remained synchronized.
- Running `global_fixed` without `--target_read_length` failed as expected.

## Difference from the original baseline

The original implementation could select a different target read length
for each sample.

The new comparative modes select one dataset-wide target and apply it
to all samples. This difference is intentional and required to produce
mutually compatible outputs for comparative RepeatExplorer analysis.

## Result

PASS

The dataset-wide target-length architecture passed smoke tests using
two samples in both `global_auto` and `global_fixed` modes.
