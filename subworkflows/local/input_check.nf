include { VALIDATE_SAMPLESHEET } from '../../modules/local/validate_samplesheet/main'

workflow INPUT_CHECK {

    take:
    samplesheet

    main:
    VALIDATE_SAMPLESHEET(samplesheet)

    emit:
    validated_samplesheet = VALIDATE_SAMPLESHEET.out.validated
}
