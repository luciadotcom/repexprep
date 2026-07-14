include { PLAN_COVERAGE } from '../../modules/local/plan_coverage/main'
include { SAMPLE_PAIRS }  from '../../modules/local/sample_pairs/main'

workflow COVERAGE_SAMPLING {

    take:
    normalized_reads
    target_lengths

    main:

    ch_norm_keyed = normalized_reads.map { sample_meta, reads ->
        tuple(sample_meta.id, sample_meta, reads)
    }

    ch_plan_input = ch_norm_keyed
        .join(target_lengths)
        .map { sample_id, sample_meta, reads, target_meta, target_length_tsv ->
            tuple(sample_id, sample_meta, reads, target_length_tsv)
        }

    PLAN_COVERAGE(ch_plan_input)

    ch_sample_input = ch_plan_input
        .join(PLAN_COVERAGE.out.plan)
        .map { sample_id, sample_meta, reads, target_length_tsv, plan_meta, coverage_plan ->
            tuple(sample_meta, reads, coverage_plan)
        }

    SAMPLE_PAIRS(ch_sample_input)

    emit:
    coverage_plans  = PLAN_COVERAGE.out.plan
    sampled_reads   = SAMPLE_PAIRS.out.reads
    sampling_reports = SAMPLE_PAIRS.out.report
}