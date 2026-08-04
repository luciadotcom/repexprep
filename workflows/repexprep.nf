/*
 * workflows/repexprep.nf
 *
 * Main workflow. All the subworkflows are called and executed here.
 */

include { INPUT_CHECK }           from '../subworkflows/local/input_check'
include { MATERIALIZE_READS }     from '../subworkflows/local/materialize_reads'
include { READ_QC }               from '../subworkflows/local/read_qc'
include { ORGANELLE_FILTERING }   from '../subworkflows/local/organelle_filter'
include { LENGTH_NORMALIZATION }  from '../subworkflows/local/length_normalization'
include { COVERAGE_SAMPLING }     from '../subworkflows/local/coverage_sampling'
include { REPEX_FORMATTING }      from '../subworkflows/local/repex_formatting'



workflow REPEXPREP {

    main:

    ch_versions = Channel.empty()

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
    * Materialize local or remote paired-end FASTQ files.
     */
    validated_samplesheet_ch =
        INPUT_CHECK.out.validated_samplesheet

    /*
    * Empty dbGaP certificate input for public SRA accessions.
    */
    certificate_ch = Channel.value([])

    MATERIALIZE_READS(
        validated_samplesheet_ch,
        certificate_ch
    )

    ch_versions = ch_versions.mix (MATERIALIZE_READS.out.versions)
   
    ch_samples = MATERIALIZE_READS.out.reads

    ch_samples.view { sm, reads ->
        "Sample channel item: ${sm.id} | R1=${reads[0]} | R2=${reads[1]}"
    }

    /*
     * Step 3:
     * Raw FASTQ statistics, pair audit and FastQC visual reports.
     */
    READ_QC(ch_samples)
    ch_versions = ch_versions.mix(READ_QC.out.versions)

    READ_QC.out.stats_seqkit.view { sm, seqkit_file ->
        "SeqKit stats: ${sm.id} | ${seqkit_file}"
    }

    READ_QC.out.pair_audit.view { sm, audit_file ->
        "Pair audit: ${sm.id} | ${audit_file}"
    }

    READ_QC.out.fastqc_html.view { sm, html_file ->
        "FastQC HTML report: ${sm.id} | ${html_file}"
    }
    /*
    *Step 4: filter out organelles's DNA
    */

    ORGANELLE_FILTERING(READ_QC.out.reads)

    ORGANELLE_FILTERING.out.reports.view { sm, report_file ->
        "Organelle filter report: ${sm.id} | ${report_file}"
    }

    ORGANELLE_FILTERING.out.filtered_samples.view { sm, reads ->
        "Organelle-filtered reads: ${sm.id} | R1=${reads[0]} | R2=${reads[1]}"
    }

    ORGANELLE_FILTERING.out.method_metadata.view { file ->
        "Organelle filter method metadata: ${file}"
    }

    ORGANELLE_FILTERING.out.reference_registry.view { file ->
        "Organelle reference registry: ${file}"
    }

    /*
     * Step 5:
     * Choose target length and crop reads to fixed length.
     */
    LENGTH_NORMALIZATION(
        ORGANELLE_FILTERING.out.filtered_samples,
        params.target_length_mode,
        params.target_read_length,
        params.min_retained_fraction,
        params.min_target_read_length,
        params.max_target_read_length
        )

    LENGTH_NORMALIZATION.out.global_target.view { target_file ->
        "Target length: ${target_file}"
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
        LENGTH_NORMALIZATION.out.global_target
    )

    COVERAGE_SAMPLING.out.coverage_plans.view { plan_file ->
        "Coverage plan: ${plan_file}"
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
    materialized_reads       = MATERIALIZE_READS.out.reads
    remote_provider_reports  = MATERIALIZE_READS.out.remote_provider_reports
    remote_manifests         = MATERIALIZE_READS.out.remote_manifests
    qc_reads                 = READ_QC.out.reads
    fastq_integrity_reports  = READ_QC.out.integrity_report
    stats_seqkit             = READ_QC.out.stats_seqkit
    pair_audit               = READ_QC.out.pair_audit
    fastqc_html              = READ_QC.out.fastqc_html
    fastqc_zip               = READ_QC.out.fastqc_zip
    organelle_filtered_reads   = ORGANELLE_FILTERING.out.filtered_samples
    organelle_filter_reports   = ORGANELLE_FILTERING.out.reports
    organelle_filter_method_metadata = ORGANELLE_FILTERING.out.method_metadata
    organelle_filter_reference_registry = ORGANELLE_FILTERING.out.reference_registry
    target_lengths      = LENGTH_NORMALIZATION.out.global_target
    normalized_reads    = LENGTH_NORMALIZATION.out.normalized_reads
    crop_reports        = LENGTH_NORMALIZATION.out.crop_reports
    coverage_plans      = COVERAGE_SAMPLING.out.coverage_plans
    sampled_reads       = COVERAGE_SAMPLING.out.sampled_reads
    sampling_reports    = COVERAGE_SAMPLING.out.sampling_reports
    repex_fasta         = REPEX_FORMATTING.out.repex_fasta
    formatting_reports  = REPEX_FORMATTING.out.formatting_reports
    validation_reports  = REPEX_FORMATTING.out.validation_reports
}