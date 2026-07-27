include { PAIR_AUDIT } from '../../modules/local/pair_audit/main'
include { FASTQC } from '../../modules/nf-core/fastqc/main'
include { SEQKIT_STATS } from '../../modules/nf-core/seqkit/stats/main'

workflow READ_QC {

    take:
    ch_reads

    main:
    ch_versions= Channel.empty()

    FASTQC (ch_reads)
    ch_versions = ch_versions.mix(FASTQC.out.versions)

    SEQKIT_STATS(ch_reads)


    PAIR_AUDIT(ch_reads)


    emit:
    fastqc_html = FASTQC.out.html
    fastqc_zip  = FASTQC.out.zip
    pair_audit  = PAIR_AUDIT.out.audit
    stats_seqkit = SEQKIT_STATS.out.stats
    versions    = ch_versions

}
