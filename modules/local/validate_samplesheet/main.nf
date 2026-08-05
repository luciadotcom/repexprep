process VALIDATE_SAMPLESHEET {

    tag "samplesheet"

    label 'process_low'

    input:
    path samplesheet

    output:
    path "samplesheet.validated.csv", emit: validated

    script:
    """
    validate_samplesheet.py \
        --input ${samplesheet} \
        --output samplesheet.validated.csv \
        --base-dir "${launchDir}"
    """
}