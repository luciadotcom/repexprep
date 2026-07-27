include { PLAN_COVERAGE } from '../../modules/local/plan_coverage/main'
include { SAMPLE_PAIRS }  from '../../modules/local/sample_pairs/main'

workflow COVERAGE_SAMPLING {

    take:
    normalized_reads
    target_lengths

    main:

    ch_plan_input = normalized_reads
        .combine(target_lengths)
        .map { sample_meta, reads, target_length_tsv ->
            tuple(sample_meta, reads, target_length_tsv)
        }

    PLAN_COVERAGE(ch_plan_input)

    ch_sample_input = normalized_reads
        .map { meta, reads -> tuple(meta.id, meta, reads) }
        .join(
            PLAN_COVERAGE.out.plan.map { item ->
                if (item instanceof List && item[0] instanceof Map) {
                    return tuple(item[0].id, item[0], item[1])
                } else {
                    return item
                }
            }
        )
        .map { sample_id, sample_meta, reads, plan_meta, coverage_plan ->
            tuple(sample_meta, reads, coverage_plan)
        }

    SAMPLE_PAIRS(ch_sample_input)

    emit:
    coverage_plans  = PLAN_COVERAGE.out.plan
    sampled_reads   = SAMPLE_PAIRS.out.reads
    sampling_reports = SAMPLE_PAIRS.out.report
}