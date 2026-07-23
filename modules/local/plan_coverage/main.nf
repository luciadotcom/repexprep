process PLAN_COVERAGE {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/coverage_sampling/plans", mode: 'copy'

    input:
    tuple val(meta), path(reads), path(target_length_tsv)

    output:
    tuple val(meta), path("${meta.id}.coverage_plan.tsv"), emit: plan

    script:
    def genome_size = meta.genome_size_bp ?: params.genome_size_bp
    def target_cov  = meta.target_coverage  ?: params.target_coverage 

    if (!genome_size) {
        error "ERROR [plan_coverage]: Missing genome size for sample '${meta.id}'. Specify 'genome_size_bp' in the samplesheet or pass '--genome_size_bp'."
    }
    if (!target_cov) {
        error "ERROR [plan_coverage]: Missing target coverage for sample '${meta.id}'. Specify 'target_coverage' in the samplesheet or pass '--target_coverage'."
    }

    """
    plan_coverage.py \\
        --sample ${meta.id} \\
        --r1 ${reads[0]} \\
        --r2 ${reads[1]} \\
        --target-length-file ${target_length_tsv} \\
        --genome-size-bp ${genome_size} \\
        --target-coverage ${target_cov} \\
        --output ${meta.id}.coverage_plan.tsv
    """
}