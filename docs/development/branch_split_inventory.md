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
