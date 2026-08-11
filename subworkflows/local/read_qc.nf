include { PAIR_AUDIT } from '../../modules/local/pair_audit/main'
include { FASTQC } from '../../modules/nf-core/fastqc/main'
include { SEQKIT_STATS } from '../../modules/nf-core/seqkit/stats/main'
include { FASTQ_INTEGRITY } from '../../modules/local/fastq_integrity/main'

workflow READ_QC {

    take:
    ch_reads

    main:

    FASTQ_INTEGRITY (ch_reads)

    checked_reads_ch = FASTQ_INTEGRITY.out.reads

    FASTQC (checked_reads_ch)
    SEQKIT_STATS(checked_reads_ch)
    PAIR_AUDIT(checked_reads_ch)

    ch_versions = FASTQ_INTEGRITY.out.versions.mix(
        FASTQC.out.versions,
        SEQKIT_STATS.out.versions_seqkit
        )

    emit:
    reads            = checked_reads_ch
    integrity_report = FASTQ_INTEGRITY.out.report
    fastqc_html      = FASTQC.out.html
    fastqc_zip       = FASTQC.out.zip
    pair_audit       = PAIR_AUDIT.out.audit
    stats_seqkit     = SEQKIT_STATS.out.stats
    versions         = ch_versions

}
