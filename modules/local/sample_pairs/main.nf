process SAMPLE_PAIRS {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/coverage_sampling/sampled_reads", mode: 'copy', pattern: "*.fastq.gz"
    publishDir "${params.outdir}/coverage_sampling/reports", mode: 'copy', pattern: "*.sampling_report.tsv"

    input:
    tuple val(meta), path(reads), path(coverage_plan)

    output:
    tuple val(meta), path("${meta.id}_R*.sampled.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.sampling_report.tsv"), emit: report

    script:
    """
    sample_pairs.py \
        --sample ${meta.id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --coverage-plan ${coverage_plan} \
        --seed ${params.sampling_seed} \
        --out-r1 ${meta.id}_R1.sampled.fastq.gz \
        --out-r2 ${meta.id}_R2.sampled.fastq.gz \
        --report ${meta.id}.sampling_report.tsv
    """
}