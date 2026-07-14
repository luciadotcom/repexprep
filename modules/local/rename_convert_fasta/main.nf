process RENAME_FASTQ_TO_FASTA {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/repex/fasta", mode: 'copy', pattern: "*.repex.fasta"
    publishDir "${params.outdir}/repex/reports", mode: 'copy', pattern: "*.repex_format_report.tsv"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.repex.fasta"), emit: fasta
    tuple val(meta), path("${meta.id}.repex_format_report.tsv"), emit: report

    script:
    """
    rename_fastq_to_fasta.py \
        --sample ${meta.id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --output-fasta ${meta.id}.repex.fasta \
        --report ${meta.id}.repex_format_report.tsv
    """
}