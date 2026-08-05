process PAIR_AUDIT {

    tag "${meta.id}"

    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.pair_audit.tsv"), emit: audit

    script:
    """
    pair_audit.py \
        --sample ${meta.id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --output ${meta.id}.pair_audit.tsv
    """
}