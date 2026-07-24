nextflow.enable.dsl = 2


include {
    LENGTH_NORMALIZATION
} from '../../subworkflows/local/length_normalization/main'


params.input                  = null
params.target_length_mode     = 'global_auto'
params.target_read_length     = null
params.min_retained_fraction  = 0.95
params.min_target_read_length = 1
params.max_target_read_length = 1000


workflow {

    if (!params.input) {
        error "Missing required parameter: --input"
    }

    /*
     * Read the two-sample CSV and create:
     *
     * tuple(meta, [R1, R2])
     */

    ch_reads = Channel
        .fromPath(
            params.input,
            checkIfExists: true
        )
        .splitCsv(
            header: true
        )
        .map { row ->

            def sample_id = row.sample
                .toString()
                .trim()

            if (!sample_id) {
                error "A samplesheet row has an empty sample identifier."
            }

            def r1_path = row.fastq_1
                .toString()
                .trim()

            def r2_path = row.fastq_2
                .toString()
                .trim()

            if (!r1_path || !r2_path) {
                error(
                    "Sample '${sample_id}' is missing fastq_1 or fastq_2."
                )
            }

            def meta = [
                id: sample_id
            ]

            /*
             * Preserve the column for validation when it exists.
             */

            if (row.containsKey('target_read_length')) {
                meta.target_read_length =
                    row.target_read_length
            }

            tuple(
                meta,
                [
                    file(
                        r1_path,
                        checkIfExists: true
                    ),
                    file(
                        r2_path,
                        checkIfExists: true
                    )
                ]
            )
        }


    LENGTH_NORMALIZATION(
        ch_reads,
        params.target_length_mode,
        params.target_read_length,
        params.min_retained_fraction,
        params.min_target_read_length,
        params.max_target_read_length
    )


    LENGTH_NORMALIZATION.out.profiles.view {
        meta,
        profile ->

        "PROFILE ${meta.id}: ${profile}"
    }


    LENGTH_NORMALIZATION.out.global_target.view {
        target ->

        "GLOBAL TARGET: ${target}"
    }


    LENGTH_NORMALIZATION.out.normalized_reads.view {
        meta,
        reads ->

        "CROPPED ${meta.id}: ${reads}"
    }


    LENGTH_NORMALIZATION.out.crop_reports.view {
        meta,
        report ->

        "CROP REPORT ${meta.id}: ${report}"
    }
}
