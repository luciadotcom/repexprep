nextflow.enable.dsl = 2


include {
    LENGTH_NORMALIZATION
} from '../../subworkflows/local/length_normalization/main'


params.r1 = null
params.r2 = null
params.sample = 'length_test'

params.target_length_mode = 'global_auto'
params.target_read_length = null
params.min_retained_fraction = 0.95
params.min_target_read_length = 1
params.max_target_read_length = 1000


workflow {

    if (!params.r1) {
        error "Missing required parameter: --r1"
    }

    if (!params.r2) {
        error "Missing required parameter: --r2"
    }

    def r1_file = file(
        params.r1,
        checkIfExists: true
    )

    def r2_file = file(
        params.r2,
        checkIfExists: true
    )

    ch_reads = Channel.of(
        tuple(
            [
                id: params.sample
            ],
            [
                r1_file,
                r2_file
            ]
        )
    )

    LENGTH_NORMALIZATION(
        ch_reads,
        params.target_length_mode,
        params.target_read_length,
        params.min_retained_fraction,
        params.min_target_read_length,
        params.max_target_read_length
    )

    LENGTH_NORMALIZATION.out.global_target.view {
        file ->
            "GLOBAL TARGET: ${file}"
    }

    LENGTH_NORMALIZATION.out.normalized_reads.view {
        meta,
        reads ->

            "CROPPED ${meta.id}: ${reads}"
    }

    LENGTH_NORMALIZATION.out.crop_reports.view {
        meta,
        report ->

            "REPORT ${meta.id}: ${report}"
    }
}