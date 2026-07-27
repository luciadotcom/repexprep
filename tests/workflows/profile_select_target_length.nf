include { PROFILE_SELECT_TARGET_LENGTH } from '../../subworkflows/local/profile_select_target_length'

workflow {

    ch_reads = Channel.of(
        [ [ id: params.sample ], [ file(params.r1), file(params.r2) ] ]
    )

def min_fraction = params.min_retained_fraction ?: 0.95
def select_mode  = params.mode ?: 'global_auto'
def target_len = params.target_read_length ?: ' '

    PROFILE_SELECT_TARGET_LENGTH (
        ch_reads,
        params.min_retained_fraction ?: 0.95,
        params.mode ?: 'global_auto',
        params.target_read_length ?: null
    )
}