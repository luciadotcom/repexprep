include { RAW_FASTQ_STATS } from '../../modules/local/raw_fastq_stats/main'

workflow READ_QC {

    take:
    samples

    main:
    RAW_FASTQ_STATS(samples)

    emit:
    raw_fastq_stats = RAW_FASTQ_STATS.out.stats
}