process PLAN_COVERAGE {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/coverage_sampling/plans", mode: 'copy'

    input:
    tuple val(sample_id), val(meta), path(reads), path(target_length_tsv)

    output:
    tuple val(sample_id), val(meta), path("${sample_id}.coverage_plan.tsv"), emit: plan

    script:
    def genome_size = meta.genome_size_bp ?: params.genome_size_bp ?: ""
    def target_cov  = params.target_coverage ?: meta.target_coverage ?: 0.2

    """
    plan_coverage.py \
        --sample ${sample_id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --target-length-file ${target_length_tsv} \
        --genome-size-bp '${genome_size}' \
        --target-coverage '${target_cov}' \
        --output ${sample_id}.coverage_plan.tsv
    """
}