process CROP_FIXED_LENGTH {

    tag "${meta.id}"

    label 'process_low'

    publishDir "${params.outdir}/length_normalization/cropped_reads", mode: 'copy', pattern: "*.fastq.gz"
    publishDir "${params.outdir}/length_normalization/reports", mode: 'copy', pattern: "*.crop_report.tsv"

    input:
    tuple val(meta), path(reads), path(target_length_tsv)

    output:
    tuple val(meta), path("${meta.id}_R*.fixed.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.crop_report.tsv"), emit: report

    script:
    """
    crop_pairs_to_length.py \
        --sample ${meta.id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --target-length-file ${target_length_tsv} \
        --out-r1 ${meta.id}_R1.fixed.fastq.gz \
        --out-r2 ${meta.id}_R2.fixed.fastq.gz \
        --report ${meta.id}.crop_report.tsv
    """
}