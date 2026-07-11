/*
 * workflows/repexprep.nf
 *
 * Workflow principal del prototipo.
 * Por ahora no procesa FASTQ. Solo comprueba que Nextflow,
 * la configuración y la estructura del proyecto funcionan.
 */

 include  { INPUT_CHECK} from '../subworkflows/local/input_check'

workflow REPEXPREP {

    main:

    log.info ""
    log.info "=============================================="
    log.info " laynez-21-repexprep"
    log.info " WGS preprocessing for RepeatExplorer2"
    log.info "=============================================="
    log.info "Input samplesheet : ${params.input}"
    log.info "Output directory  : ${params.outdir}"
    log.info "Test mode         : ${params.test_mode}"
    log.info ""

    if (!params.input) {
        error "No input samplesheet specified. Use --input samplesheet.csv"
    }

    INPUT_CHECK (file(params.input))

    INPUT_CHECK.out.validated_samplesheet.view {validated ->
        "Validated samplesheet: ${validated}"
    }

    emit:
    validated_samplesheet= INPUT_CHECK.out.validated_samplesheet
}