#Local baseline execution

#Working directory:
/home/_lucia_/work/repex-pipeline/preproc

#Git version:
- Commit: 1e9bf02
- Tag: baseline-local-hpc-orgfilter-2026-07-20

#Tag samplesheet:

samplesheets/local_test_subsample_portable.orgfix.csv

#Validated sdamplesheet used by Nextflow:
samplesheets/validated/local_test_subsample_portable.orgfix.validated.csv

#Exact command

```bash
nextflow run . \
-profile test \
--input samplesheets/validated/local_test_subsample_portable.orgfix.validated.csv \
--outdir results/local_test_organelle_filter_test_2

#Resume command: 
```bash
nextflow run . \
-profile test \
--input samplesheets/validated/local_test_subsample_portable.orgfix.validated.csv \
--outdir results/local_test_organelle_filter_test_2 \
-resume
