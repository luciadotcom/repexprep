include {
    PROFILE_READ_LENGTH
} from '../../modules/local/profile_read_length/main'

include {
    SELECT_GLOBAL_TARGET_LENGTH
} from '../../modules/local/select_global_target_length/main'

include {
    CROP_FIXED_LENGTH
} from '../../modules/local/crop_fixed_length/main'


workflow LENGTH_NORMALIZATION {

    take:
    ch_reads

    target_length_mode

    target_read_length

    min_retained_fraction

    min_target_read_length

    max_target_read_length


    main:

    /*
     * PROFILE_READ_LENGTH runs once per sample.
     *
     * DSL2 automatically broadcasts ch_reads, so the same input channel
     * can later be reused for cropping.
     */

    PROFILE_READ_LENGTH(
        ch_reads,
        min_retained_fraction
    )


    /*
     * Remove metadata from the profile tuples and collect all profile
     * files into one list.
     *
     * SELECT_GLOBAL_TARGET_LENGTH will therefore run exactly once.
     */

    ch_all_profiles = PROFILE_READ_LENGTH.out.profiles
        .map {
            meta,
            profile_file ->

            profile_file
        }
        .collect()


    /*
     * target_read_length must not be null inside a queue/value input.
     * Internally, -1 represents an unset fixed target.
     */

    fixed_target_value = (
        target_read_length == null
        ? -1
        : target_read_length as Integer
    )


    SELECT_GLOBAL_TARGET_LENGTH(
        ch_all_profiles,
        target_length_mode,
        fixed_target_value,
        min_retained_fraction,
        min_target_read_length,
        max_target_read_length
    )


    /*
     * SELECT_GLOBAL_TARGET_LENGTH emits one file.
     *
     * combine() creates one tuple for every sample:
     *
     * [meta, reads, global_target.tsv]
     */

    ch_crop_input = ch_reads
        .combine(
            SELECT_GLOBAL_TARGET_LENGTH.out.global_target
        )


    CROP_FIXED_LENGTH(
        ch_crop_input
    )


    emit:

    profiles = PROFILE_READ_LENGTH.out.profiles

    global_target =
        SELECT_GLOBAL_TARGET_LENGTH.out.global_target

    per_sample_target_report =
        SELECT_GLOBAL_TARGET_LENGTH.out.per_sample_report

    normalized_reads =
        CROP_FIXED_LENGTH.out.reads

    crop_reports =
        CROP_FIXED_LENGTH.out.reports

    versions = PROFILE_READ_LENGTH.out.versions
        .mix(
            SELECT_GLOBAL_TARGET_LENGTH.out.versions
        )
        .mix(
            CROP_FIXED_LENGTH.out.versions
        )
}