include { RENAME_FASTQ_TO_FASTA } from '../../modules/local/rename_convert_fasta/main'
include { VALIDATE_REPEX_FASTA }  from '../../modules/local/validate_repex_fasta/main'

workflow REPEX_FORMATTING {

    take:
    sampled_reads

    main:

    RENAME_FASTQ_TO_FASTA(sampled_reads)

    VALIDATE_REPEX_FASTA(RENAME_FASTQ_TO_FASTA.out.fasta)

    emit:
    repex_fasta        = VALIDATE_REPEX_FASTA.out.fasta
    formatting_reports = RENAME_FASTQ_TO_FASTA.out.report
    validation_reports = VALIDATE_REPEX_FASTA.out.report
}