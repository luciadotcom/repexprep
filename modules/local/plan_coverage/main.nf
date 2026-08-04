process PLAN_COVERAGE {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/coverage_sampling/plans", mode: 'copy'

    input:
    tuple val(meta), path(reads), path(target_length_tsv)

    output:
    tuple val(meta), path("${meta.id}.coverage_plan.tsv"), emit: plan

    script:
    def coverageBasis = params.coverage_basis ?: 'haploid_1C'

    if (coverageBasis != 'haploid_1C') {
     error(
        "ERROR [plan_coverage]: Unsupported coverage_basis " +
        "'${coverageBasis}'. Currently supported: haploid_1C."
    )
    }

    /*
    * Canonical genome size: haploid 1C.
    * Ploidy is metadata only and is intentionally not multiplied here.
    */
    def genomeSize1C =
     meta.genome_size_1C_bp ?: params.genome_size_1C_bp

    /*
    * Temporary compatibility alias.
    */
    def legacyGenomeSize =
     meta.genome_size_bp ?: params.genome_size_bp

    if (!genomeSize1C && legacyGenomeSize) {
        log.warn(
            "Sample '${meta.id}' uses deprecated 'genome_size_bp'. " +
            "Rename it to 'genome_size_1C_bp'."
        )

        genomeSize1C = legacyGenomeSize
    }

    def effectiveGenomeSizeBp = genomeSize1C
    def targetCov = meta.target_coverage ?: params.target_coverage

    if (!effectiveGenomeSizeBp) {
        error(
        "ERROR [plan_coverage]: Missing haploid 1C genome size for " +
        "sample '${meta.id}'. Specify 'genome_size_1C_bp' in the " +
        "samplesheet or pass '--genome_size_1C_bp'."
        )
    }

    if (!targetCov) {
        error(
        "ERROR [plan_coverage]: Missing target coverage for sample " +
        "'${meta.id}'. Specify 'target_coverage' in the samplesheet " +
        "or pass '--target_coverage'."
        )
    }

    """
    plan_coverage.py \\
        --sample ${meta.id} \\
        --r1 ${reads[0]} \\
        --r2 ${reads[1]} \\
        --target-length-file ${target_length_tsv} \\
        --genome-size-1c-bp ${effectiveGenomeSizeBp} \\
        --ploidy ${meta.ploidy} \\
        --coverage-basis ${coverageBasis} \\
        --target-coverage ${targetCov} \\
        --sampling-seed ${meta.sampling_seed != null ? meta.sampling_seed : params.sampling_seed} \\
        --output ${meta.id}.coverage_plan.tsv
    """
}