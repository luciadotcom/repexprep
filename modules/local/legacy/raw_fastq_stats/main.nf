process RAW_FASTQ_STATS {

    tag "${meta.id}"

    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.raw_fastq_stats.tsv"), emit: stats

    script:
    """
    raw_fastq_stats.py \
        --sample ${meta.id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --output ${meta.id}.raw_fastq_stats.tsv
    """
}