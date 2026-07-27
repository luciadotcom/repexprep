include { PROFILE_READ_LENGTH          } from '../../modules/local/profile_read_length/main'
include { SELECT_GLOBAL_TARGET_LENGTH  } from '../../modules/local/select_global_target_length/main'

workflow PROFILE_SELECT_TARGET_LENGTH {
    take:
    ch_reads               
    min_retained_fraction  
    mode                   
    target_read_length     

    main:

    PROFILE_READ_LENGTH (
        ch_reads,
        min_retained_fraction
    )

    ch_profiles = PROFILE_READ_LENGTH.out.profiles
        .map { meta, profile -> profile }
        .collect()

    def safe_target_length = target_read_length ?: ''
    
    SELECT_GLOBAL_TARGET_LENGTH (
        ch_profiles,
        mode,
        target_read_length
    )

    emit:
    global_target     = SELECT_GLOBAL_TARGET_LENGTH.out.global_target
    per_sample_target = SELECT_GLOBAL_TARGET_LENGTH.out.per_sample_target
    versions          = PROFILE_READ_LENGTH.out.versions.mix(SELECT_GLOBAL_TARGET_LENGTH.out.versions)
}