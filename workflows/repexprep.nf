/*
 * workflows/repexprep.nf
 *
 * Workflow principal del prototipo.
 * Por ahora no procesa FASTQ. Solo comprueba que Nextflow,
 * la configuración y la estructura del proyecto funcionan.
 */

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

    /*
     * Emitimos un canal ficticio para comprobar que el workflow existe.
     * Más adelante aquí conectaremos:
     *
     * INPUT_CHECK
     * READ_QC
     * TRIM_FILTER
     * LENGTH_NORMALIZATION
     * COVERAGE_SAMPLING
     * REPEX_FORMATTING
     * REPORTING
     */
    done_ch= Channel.value("REPEXPREP skeleton completed")

    done_ch.view()

    emit:
    done = done_ch
}