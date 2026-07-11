process VALIDATE_SAMPLESHEET {

    tag "samplesheet"

    label 'process_low'

    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    path samplesheet

    output:
    path "samplesheet.validated.csv", emit: validated

    script:
    """
    validate_samplesheet.py \
        --input ${samplesheet} \
        --output samplesheet.validated.csv \
        --base-dir ${projectDir}
    """
}