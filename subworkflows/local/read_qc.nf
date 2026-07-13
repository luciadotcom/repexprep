include { RAW_FASTQ_STATS } from '../../modules/local/raw_fastq_stats/main'
include { PAIR_AUDIT } from '../../modules/local/pair_audit/main'

workflow READ_QC {

    take:
    samples

    main:
    RAW_FASTQ_STATS(samples)
    PAIR_AUDIT(samples)

    emit:
    raw_fastq_stats = RAW_FASTQ_STATS.out.stats
    pair_audit = PAIR_AUDIT.out.audit

}
