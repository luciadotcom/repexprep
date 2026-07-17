/*
 * workflows/repexprep.nf
 *
 * Workflow principal del prototipo local.
 */

include { INPUT_CHECK }           from '../subworkflows/local/input_check'
include { READ_QC }               from '../subworkflows/local/read_qc'
include { ORGANELLE_FILTERING }     from '../subworkflows/local/organelle_filter'
include { LENGTH_NORMALIZATION }  from '../subworkflows/local/length_normalization'
include { COVERAGE_SAMPLING }     from '../subworkflows/local/coverage_sampling'
include { REPEX_FORMATTING }      from '../subworkflows/local/repex_formatting'



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
     * Parse validated CSV into sample channel.
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

    ch_samples.view { sm, reads ->
        "Sample channel item: ${sm.id} | R1=${reads[0]} | R2=${reads[1]}"
    }

    /*
     * Step 3:
     * Raw FASTQ statistics and pair audit.
     */
    READ_QC(ch_samples)

    READ_QC.out.raw_fastq_stats.view { sm, stats_file ->
        "Raw FASTQ stats: ${sm.id} | ${stats_file}"
    }

    READ_QC.out.pair_audit.view { sm, audit_file ->
        "Pair audit: ${sm.id} | ${audit_file}"
    }

    /*
    *Step 4: filter out organelles's DNA
    */

    ORGANELLE_FILTERING(ch_samples)

    ORGANELLE_FILTERING.out.reports.view { sm, report_file ->
    "Organelle filter report: ${sm.id} | ${report_file}"
}

    ORGANELLE_FILTERING.out.filtered_samples.view { sm, reads ->
    "Organelle-filtered reads: ${sm.id} | R1=${reads[0]} | R2=${reads[1]}"
}

    /*
     * Step 5:
     * Choose target length and crop reads to fixed length.
     */
    LENGTH_NORMALIZATION(ORGANELLE_FILTERING.out.filtered_samples)

    LENGTH_NORMALIZATION.out.target_lengths.view { sample_id, sm, target_file ->
        "Target length: ${sm.id} | ${target_file}"
    }

    LENGTH_NORMALIZATION.out.normalized_reads.view { sm, reads ->
        "Normalized reads: ${sm.id} | R1=${reads[0]} | R2=${reads[1]}"
    }

    LENGTH_NORMALIZATION.out.crop_reports.view { sm, crop_report ->
        "Crop report: ${sm.id} | ${crop_report}"
    }

    /*
     * Step 6:
     * Plan target coverage and randomly sample complete read pairs.
     */
    COVERAGE_SAMPLING(
        LENGTH_NORMALIZATION.out.normalized_reads,
        LENGTH_NORMALIZATION.out.target_lengths
    )

    COVERAGE_SAMPLING.out.coverage_plans.view { sample_id, sm, plan_file ->
        "Coverage plan: ${sm.id} | ${plan_file}"
    }

    COVERAGE_SAMPLING.out.sampled_reads.view { sm, reads ->
        "Sampled reads: ${sm.id} | R1=${reads[0]} | R2=${reads[1]}"
    }

    COVERAGE_SAMPLING.out.sampling_reports.view { sm, report_file ->
        "Sampling report: ${sm.id} | ${report_file}"
    }

    /*
     * Step 7:
     * Convert sampled FASTQ pairs to final RepeatExplorer-style FASTA
     * and validate the final FASTA.
     */
    REPEX_FORMATTING(COVERAGE_SAMPLING.out.sampled_reads)

    REPEX_FORMATTING.out.repex_fasta.view { sm, fasta_file ->
        "RepeatExplorer FASTA: ${sm.id} | ${fasta_file}"
    }

    REPEX_FORMATTING.out.formatting_reports.view { sm, report_file ->
        "RepeatExplorer formatting report: ${sm.id} | ${report_file}"
    }

    REPEX_FORMATTING.out.validation_reports.view { sm, report_file ->
        "RepeatExplorer FASTA validation: ${sm.id} | ${report_file}"
    }

    emit:
    samples             = ch_samples
    raw_fastq_stats     = READ_QC.out.raw_fastq_stats
    pair_audit          = READ_QC.out.pair_audit
    organelle_filtered_reads   = ORGANELLE_FILTERING.out.filtered_samples
    organelle_filter_reports   = ORGANELLE_FILTERING.out.reports
    target_lengths      = LENGTH_NORMALIZATION.out.target_lengths
    normalized_reads    = LENGTH_NORMALIZATION.out.normalized_reads
    crop_reports        = LENGTH_NORMALIZATION.out.crop_reports
    coverage_plans      = COVERAGE_SAMPLING.out.coverage_plans
    sampled_reads       = COVERAGE_SAMPLING.out.sampled_reads
    sampling_reports    = COVERAGE_SAMPLING.out.sampling_reports
    repex_fasta         = REPEX_FORMATTING.out.repex_fasta
    formatting_reports  = REPEX_FORMATTING.out.formatting_reports
    validation_reports  = REPEX_FORMATTING.out.validation_reports
}