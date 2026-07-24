nextflow.enable.dsl = 2

include {
    PROFILE_READ_LENGTH
} from '../../modules/local/profile_read_length/main'


params.r1 = null
params.r2 = null
params.sample = 'profile_test'
params.min_retained_fraction = 0.95


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
            [id: params.sample],
            [r1_file, r2_file]
        )
    )

    PROFILE_READ_LENGTH(
        ch_reads,
        params.min_retained_fraction
    )

    PROFILE_READ_LENGTH.out.profiles.view {
        meta, profile ->
            "PROFILE ${meta.id}: ${profile}"
    }
}