include { CHOOSE_TARGET_LENGTH } from '../../modules/local/choose_target_length/main'
include { CROP_FIXED_LENGTH }   from '../../modules/local/crop_fixed_length/main'

workflow LENGTH_NORMALIZATION {

    take:
    samples

    main:

    ch_samples_keyed = samples.map { sample_meta, reads ->
        tuple(sample_meta.id, sample_meta, reads)
    }

    CHOOSE_TARGET_LENGTH(ch_samples_keyed)

    ch_crop_input = ch_samples_keyed
        .join(CHOOSE_TARGET_LENGTH.out.target_length)
        .map { sample_id, sample_meta, reads, target_meta, target_length_tsv ->
            tuple(sample_meta, reads, target_length_tsv)
        }

    CROP_FIXED_LENGTH(ch_crop_input)

    emit:
    target_lengths   = CHOOSE_TARGET_LENGTH.out.target_length
    normalized_reads = CROP_FIXED_LENGTH.out.reads
    crop_reports     = CROP_FIXED_LENGTH.out.report
}