include {
    PROFILE_READ_LENGTH
} from '../../../modules/local/profile_read_length/main'

include {
    SELECT_GLOBAL_TARGET_LENGTH
} from '../../../modules/local/select_global_target_length/main'

include {
    CROP_FIXED_LENGTH
} from '../../../modules/local/crop_fixed_length/main'


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
     * Validate dataset-wide target-length configuration before
     * launching any read-processing tasks.
     */

    mode = target_length_mode
        .toString()
        .trim()

    allowed_modes = [
        'global_auto',
        'global_fixed'
    ]

    if (!allowed_modes.contains(mode)) {
        error(
            "Invalid target_length_mode='${mode}'. " +
            "Currently supported modes are: " +
            "${allowed_modes.join(', ')}."
        )
    }


    retained_fraction = min_retained_fraction as Double

    if (
        retained_fraction <= 0.0 ||
        retained_fraction > 1.0
    ) {
        error(
            "min_retained_fraction must be greater than 0 " +
            "and less than or equal to 1. " +
            "Received: ${min_retained_fraction}"
        )
    }


    minimum_length = min_target_read_length as Integer
    maximum_length = max_target_read_length as Integer

    if (minimum_length < 1) {
        error(
            "min_target_read_length must be greater than zero. " +
            "Received: ${minimum_length}"
        )
    }

    if (maximum_length < 1) {
        error(
            "max_target_read_length must be greater than zero. " +
            "Received: ${maximum_length}"
        )
    }

    if (minimum_length > maximum_length) {
        error(
            "min_target_read_length cannot be greater than " +
            "max_target_read_length. Received minimum=${minimum_length}, " +
            "maximum=${maximum_length}."
        )
    }


    target_text = (
        target_read_length == null
        ? ''
        : target_read_length.toString().trim()
    )

    has_global_target = target_text != ''


    if (
        has_global_target &&
        !target_text.isInteger()
    ) {
        error(
            "target_read_length must be a positive integer. " +
            "Received: '${target_text}'."
        )
    }


    fixed_target = (
        has_global_target
        ? target_text.toInteger()
        : null
    )


    if (
        mode == 'global_auto' &&
        has_global_target
    ) {
        error(
            "--target_read_length must not be supplied when " +
            "target_length_mode=global_auto. Remove the parameter " +
            "or use target_length_mode=global_fixed."
        )
    }


    if (
        mode == 'global_fixed' &&
        !has_global_target
    ) {
        error(
            "--target_read_length is required when " +
            "target_length_mode=global_fixed."
        )
    }


    if (
        mode == 'global_fixed' &&
        fixed_target < 1
    ) {
        error(
            "target_read_length must be greater than zero. " +
            "Received: ${fixed_target}."
        )
    }


    if (
        mode == 'global_fixed' &&
        (
            fixed_target < minimum_length ||
            fixed_target > maximum_length
        )
    ) {
        error(
            "target_read_length=${fixed_target} is outside the " +
            "allowed interval ${minimum_length}-${maximum_length} bp."
        )
    }

        /*
     * Per-sample target lengths are forbidden in both global modes.
     *
     * The validated samplesheet stores sample-level properties
     * in the metadata map.
     */

    ch_reads_checked = ch_reads.map {
        meta,
        reads ->

        def sample_target = (
            meta.containsKey('target_read_length')
            ? meta.target_read_length
            : null
        )

        def sample_target_text = (
            sample_target == null
            ? ''
            : sample_target.toString().trim()
        )

        def has_sample_target = (
            sample_target_text != ''
        )

        if (has_sample_target) {
            error(
                "Sample '${meta.id}' contains a per-sample " +
                "target_read_length='${sample_target_text}', but " +
                "target_length_mode=${mode} requires one " +
                "dataset-wide target. Remove target_read_length " +
                "values from the samplesheet."
            )
        }

        tuple(
            meta,
            reads
        )
    }


    /*
     * PROFILE_READ_LENGTH runs once per sample.
     *
     * DSL2 automatically broadcasts ch_reads, so the same input channel
     * can later be reused for cropping.
     */

    PROFILE_READ_LENGTH(
        ch_reads_checked,
        retained_fraction
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
        mode== 'global_fixed'
        ? fixed_target
        : -1
    )


    SELECT_GLOBAL_TARGET_LENGTH(
        ch_all_profiles,
        mode, 
        fixed_target_value,
        retained_fraction,
        minimum_length,
        maximum_length
    )


    /*
     * SELECT_GLOBAL_TARGET_LENGTH emits one file.
     *
     * combine() creates one tuple for every sample:
     *
     * [meta, reads, global_target_length.tsv]
     */

    ch_crop_input = ch_reads_checked
        .combine(
            SELECT_GLOBAL_TARGET_LENGTH.out.global_target
        )
        .map {
            meta,
            reads,
            global_target_file ->

            tuple(
                meta,
                reads,
                global_target_file
            )
        }


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