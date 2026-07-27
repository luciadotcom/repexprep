# Output

> Output paths and names may change during development.

## Overview

REPEXPREP produces quality-control reports, intermediate paired-end
FASTQ files and RepeatExplorer-compatible final files.

## Output categories

### Samplesheet validation

Validated input metadata can be found in `results/samplesheets/validated/`.

### FASTQ audit

Reports describing FASTQ integrity, read counts, and paired-end consistency can be found in **`results/<sample_id>/raw_qc/`**, organized into:
* `fastq_stats/`: Summary statistics of raw FASTQ files.
* `pair_audit/`: Integrity and pairing consistency logs.It records whether R1 and R2 contain the same number of reads, identifiers correspond, record order is synchronised, malformed or incomplete records were detected and the sample passed or failed the audit.
* `fastqc/`: within there are both .html and .zip files of each of the samples analyzed. The HTML file is intended for visual inspection. The ZIP file contains the underlying FastQC data and module results. Quality reports.

### Organelle filtering

Paired reads retained after removing organelle-matching reads, along with depletion reports, can be found in **`results/<sample_id>/organelle_filter/`**:
* `fastq/`: Organelle-depleted paired-end FASTQ files.
* `reports/`: Filtering statistics and alignment logs.

(((((((

    ## Read-length selection reports

The pipeline will produce:

- one read-length profile per sample;
- one dataset-wide target-length report in global modes;
- one table showing expected or observed retention per sample;
- one cropping report per sample.

In comparative modes, all final FASTA files must report the same target
read length.
    
    ### Read-length normalization

Paired reads normalized to the requested target length can be found in **`results/<sample_id>/length_normalization/cropped_reads/`**.
Additionally, within the `length_normalization/` folder, you can access:
* `reports/`: Trimming/cropping process execution logs.
* `target_length/`: Selected or calculated target length per sample.

    ## Read-length normalization outputs

    ### Per-sample profile

`*.read_length_profile.tsv`

Contains the observed paired-read length range, candidate target length,
expected retained pairs and expected retained fraction.

### Dataset-wide target

`global_target_length.tsv`

Contains the selected execution mode and the single target length used
for the dataset.

### Per-sample target report

`target_length_per_sample.tsv`

Compares every sample candidate with the dataset-wide target and
identifies the sample limiting automatic selection.

### Crop report

`*.crop_report.tsv`

Contains input pairs, retained pairs, discarded pairs, final target
length and retained fraction.

In global comparative modes, every final FASTQ and downstream FASTA
must contain reads cropped to the same target length.

)))))))



### Coverage planning and sampling

Coverage calculations and reproducibly sampled paired reads are accessible at:
* **`results/<sample_id>/coverage_sampling/plans/`**: Target coverage and sub-sampling calculations.
* **`results/<sample_id>/coverage_sampling/sampled_reads/`**: Subsampled FASTQ files.
* **`results/<sample_id>/coverage_sampling/reports/`**: Subsampling process logs.

### RepeatExplorer export

Interleaved and renamed reads exported in a RepeatExplorer-compatible format can be found in **`results/<sample_id>/repex/fasta/`**.

This section also includes:
* **`results/<sample_id>/repex/validation/`**: Validation reports with the final status (`PASS` or `FAIL`).
* **`results/<sample_id>/repex/reports/`**: Formatting and header transformation reports.

## Final outputs

Final outputs will be documented with exact file names after the output structure has been frozen and validated.