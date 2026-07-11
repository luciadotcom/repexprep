/*
 * workflows/repexprep.nf
 *
 * Workflow principal del prototipo.
 * Ahora valida la samplesheet y convierte la tabla validada
 * en un canal de muestras paired-end.
 */

include { INPUT_CHECK } from '../subworkflows/local/input_check'

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

    /*
     * Step 1:
     * Validate input samplesheet.
     */
    INPUT_CHECK(file(params.input))

    /*
     * Step 2:
     * Convert the validated CSV into a Nextflow channel.
     *
     * Each item becomes:
     *
     * tuple(
     *   meta,
     *   [R1, R2]
     * )
     *
     * This tuple shape is what later modules will use.
     */
    ch_samples = INPUT_CHECK.out.validated_samplesheet
        .splitCsv(header: true)
        .map { row ->

            def sample_meta = [
                id                : row.sample,
                sample            : row.sample,
                lane              : row.lane,
                organism          : row.organism,
                genome_size_bp    : row.genome_size_bp,
                ploidy            : row.ploidy,
                organelle_fasta   : row.organelle_fasta,
                target_coverage   : row.target_coverage,
                target_read_length: row.target_read_length
            ]

            tuple(
                sample_meta,
                [
                    file(row.fastq_1),
                    file(row.fastq_2)
                ]
            )
        }

    /*
     * Temporary debug view.
     * Later this channel will go into READ_QC.
     */
    ch_samples.view { sample_meta, reads ->
        "Sample channel item: ${sample_meta.id} | R1=${reads[0]} | R2=${reads[1]}"
    }

    emit:
    samples = ch_samples
}