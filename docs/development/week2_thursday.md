# Week 2 Thursday: 1C coverage implementation and RE hardening

The pipeline now calculates the requested number of read pairs relative
to the haploid 1C genome size:

```text
requested_pairs =
    ceil(
        genome_size_1C_bp
        * target_coverage
        / (2 * target_read_length)
    )
```

ploidy is validated and retained as biological metadata but does not
multiply the denominator when coverage_basis = haploid_1C.

The sampling plan records requested, available and sampled pairs,
achieved coverage and whether the requested coverage was limited by
read availability.

## Validation milestones of coverage sampling refactoring
| Check                                  | Result |
| -------------------------------------- | ------ |
| Formula independently reproduced       | PASS   |
| Ploidy does not alter 1C coverage      | PASS   |
| Requested pairs capped by availability | PASS   |
| Achieved coverage reported             | PASS   |
| Same seed reproduces R1                | PASS   |
| Same seed reproduces R2                | PASS   |
| Complete local workflow finishes       | PASS   |

## Existing RepeatExplorer module hardening

The RepeatExplorer process and optional workflow call already existed
before this work block. The afternoon work therefore focused on
validation, portability and traceability rather than reimplementation.

### Corrected dependency

The previous formatting subworkflow emitted the FASTA directly from
`RENAME_FASTQ_TO_FASTA`. RepeatExplorer could therefore consume the
file independently of the final validation result.

The accepted FASTA is now emitted by `VALIDATE_REPEX_FASTA`, creating
an explicit execution dependency:

```text
RENAME_FASTQ_TO_FASTA
        ↓
VALIDATE_REPEX_FASTA
        ↓
REPEATEXPLORER
```
## Added execution metadata
- complete RepeatExplorer log;
- exit status;
- start and end time;
- requested CPU and memory;
- output-directory validation;
- configurable taxonomic preset;
- centrally configured publication;

## Validation results
| Check                                 | Result |
| ------------------------------------- | ------ |
| Default workflow skips RepeatExplorer | PASS   |
| Valid FASTA reaches RepeatExplorer    | PASS   |
| Invalid FASTA is blocked              | PASS   |
| Output directory is non-empty         | PASS   |
| Log generated                         | PASS   |
| Run report generated                  | PASS   |
| Version recorded                      | PASS   |
| Resume reuses completed tasks         | PASS   |

## Supported scope
Only independent per-sample RepeatExplorer execution is currently
validated. Comparative multi-sample execution remains outside the
validated scope.