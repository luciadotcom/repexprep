# Week 2 Monday: QC and trimming migration

## Starting commit

9ed50da (HEAD -> week2/qc-trimming, feat/global-target-length) feat: normalize read length across comparative datasets

## Reference sample

tests/samplesheets/valid_minimal.csv

## Baseline command

Week 1: subworkflow `READ_QC`executing modules `RAW_FASTQ_STATS` and `PAIR_AUDIT`. 
Scripts: `bin/raw_fastq_stats.py` and `bin/pair_audit.py`
It was running with `nextflow run .     -main-script tests/workflows/length_normalization_two_samples.nf     -work-dir work/test_invalid_global_fixed     --input tests/samplesheets/valid_two_samples_global_auto.csv     --target_length_mode global_fixed     --min_target_read_length 100     --max_target_read_length 200`

## Baseline Audit

* **Quality Trimming:** No (read-only inspection).
* **Adapter Removal:** No.
* **Quality Trimming Thresholds:** None.
* **Short Read Filtering:** None (metrics recorded only).
* **Orphan Read Handling:** N/A (input FASTQs remain unmodified).
* **QC Execution Timing:** Initial raw input evaluation.
* **Downstream Inputs:** Unmodified raw FASTQ files.
* **Preserved Metrics:** Total reads, total bases, min/max/mean read lengths, N base counts, GC base counts, and GC percentage.

### Module Migration Strategy

| Legacy Function | New Implementation | Status |
| :--- | :--- | :--- |
| General FASTQ Statistics | `nf-core/seqkit/stats` | To integrate |
| Quality Report | `nf-core/fastqc` | To integrate |
| Paired-end Synchronization | `bin/pair_audit.py` + `modules/local/pair_audit` | Retain |
| Quality Trimming | Not identified in baseline | Do not implement |
| Length Normalization | `PROFILE` + `SELECT_GLOBAL` + `CROP` | Already implemented |

## New local Nextflow command
nextflow run . \
    -profile local \
    --input samplesheets/valid_minimal.csv \
    --outdir results/week2_monday_qc \
    --target_length_mode global_auto \
    -with-report results/week2_monday_qc/pipeline_info/report.html \
    -with-trace results/week2_monday_qc/pipeline_info/trace.txt \
    -with-timeline results/week2_monday_qc/pipeline_info/timeline.html

