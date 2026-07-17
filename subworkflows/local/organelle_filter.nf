include { ORGANELLE_FILTER } from '../../modules/local/organelle_filter/main'

workflow ORGANELLE_FILTERING {

    take:
    samples

    main:
    ORGANELLE_FILTER(samples)

    emit:
    filtered_samples = ORGANELLE_FILTER.out.reads
    reports          = ORGANELLE_FILTER.out.report
}