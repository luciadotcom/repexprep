# Week 2 Thursday: 1C coverage implementation

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

## Validation milestones
| Check                                  | Result |
| -------------------------------------- | ------ |
| Formula independently reproduced       | PASS   |
| Ploidy does not alter 1C coverage      | PASS   |
| Requested pairs capped by availability | PASS   |
| Achieved coverage reported             | PASS   |
| Same seed reproduces R1                | PASS   |
| Same seed reproduces R2                | PASS   |
| Complete local workflow finishes       | PASS   |
