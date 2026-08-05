process CHOOSE_TARGET_LENGTH {

    tag "${meta.id}"

    label 'process_low'

    input:
    tuple val(sample_id), val(meta), path(reads)

    output:
    tuple val(sample_id), val(meta), path("${sample_id}.target_length.tsv"), emit: target_length

    script:
    def requested_length = meta.target_read_length ?: ""

    """
    choose_target_length.py \
        --sample ${sample_id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --requested-length '${requested_length}' \
        --output ${sample_id}.target_length.tsv
    """
}