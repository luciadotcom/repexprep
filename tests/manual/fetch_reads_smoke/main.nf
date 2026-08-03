nextflow.enable.dsl = 2

include {
    FETCH_READS
} from '../../../subworkflows/local/fetch_reads'


params.accession = null
params.provider  = 'auto'


workflow {

    if (!params.accession) {
        error "Provide --accession SRR..., ERR..., or DRR..."
    }

    meta_ch = Channel.of(
        [
            id                 : 'remote_smoke',
            sample             : 'remote_smoke',
            source             : 'accession',
            provider           : params.provider,
            accession          : params.accession,
            single_end         : false,
            organism           : 'test_organism',
            genome_size_1C_bp  : 1000000L,
            ploidy             : 2,
            target_coverage    : 0.001d,
            organelle_fasta    : ''
        ]
    )

    /*
     * Use the empty certificate representation required by the
     * installed nf-core SRA subworkflow.
     */
    certificate_ch = Channel.value([])

    FETCH_READS(
        meta_ch,
        certificate_ch
    )

    FETCH_READS.out.reads.view {
        meta, reads ->
        "FETCHED: ${meta.id} | ${reads}"
    }
}
