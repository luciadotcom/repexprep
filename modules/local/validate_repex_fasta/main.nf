process VALIDATE_REPEX_FASTA {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/repex/validation", mode: 'copy'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.repex_validation.tsv"), emit: report

    script:
    """
    validate_repex_fasta.py \
        --sample ${meta.id} \
        --input-fasta ${fasta} \
        --report ${meta.id}.repex_validation.tsv
    """
}