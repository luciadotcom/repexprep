include { RAW_FASTQ_STATS } from '../../modules/local/raw_fastq_stats/main'
include { PAIR_AUDIT } from '../../modules/local/pair_audit/main'
include { FASTQC } from '../../modules/nf-core/fastqc/main.nf'

workflow READ_QC {

    take:
    ch_reads

    main:
    ch_versions= Channel.empty()

    FASTQC (ch_reads)
    ch_versions = ch_versions.mix(FASTQC.out.versions)

    PAIR_AUDIT(ch_reads)

    RAW_FASTQ_STATS(ch_reads)

    emit:
    fastqc_html = FASTQC.out.html
    fastqc_zip  = FASTQC.out.zip
    pair_audit  = PAIR_AUDIT.out.audit
    stats       = RAW_FASTQ_STATS.out.stats
    versions    = ch_versions

}
