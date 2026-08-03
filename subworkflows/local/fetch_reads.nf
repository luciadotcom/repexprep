include {
    RESOLVE_REMOTE_PROVIDER
} from '../../modules/local/resolve_remote_provider/main'

include {
    ENA_FASTQ_DOWNLOAD
} from '../../modules/local/ena_fastq_download/main'

// Replace this alias and path with the exact include statement printed
// by `nf-core subworkflows install`.
include {
    FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS
} from '../../subworkflows/nf-core/fastq_download_prefetch_fasterqdump_sratools/main'


workflow FETCH_READS {

    take:
    accession_meta_ch
    certificate_ch

    main:

    RESOLVE_REMOTE_PROVIDER(accession_meta_ch)

    resolved_ch = RESOLVE_REMOTE_PROVIDER.out.resolution.map {
        meta, resolution_file ->

        def resolution = new groovy.json.JsonSlurper().parseText(
            resolution_file.text
        )

        def resolved_meta = meta + [
            requested_provider : resolution.requested_provider,
            resolved_provider  : resolution.resolved_provider,
            remote_urls        : resolution.urls ?: [],
            remote_md5s        : resolution.md5s ?: [],
            remote_bytes       : resolution.bytes ?: []
        ]

        resolved_meta
    }

    provider_branches = resolved_ch.branch {
        ena:
            it.resolved_provider == 'ena'

        ncbi_sra:
            it.resolved_provider == 'ncbi_sra'
    }

    ena_input_ch = provider_branches.ena.map { meta ->
        tuple(
            meta,
            meta.remote_urls,
            meta.remote_md5s
        )
    }

    ENA_FASTQ_DOWNLOAD(ena_input_ch)

    ncbi_input_ch = provider_branches.ncbi_sra.map { meta ->
    tuple(
        meta,
        meta.accession
    )
}

    /*
     * Inspect the installed nf-core subworkflow and adapt this call
     * to its exact `take:` signature.
     */
    FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS(
        ncbi_input_ch,
        certificate_ch
    )

    remote_reads_ch = ENA_FASTQ_DOWNLOAD.out.reads.mix(
        FASTQ_DOWNLOAD_PREFETCH_FASTERQDUMP_SRATOOLS.out.reads
    )

    versions_ch = RESOLVE_REMOTE_PROVIDER.out.versions.mix(
        ENA_FASTQ_DOWNLOAD.out.versions
    )

    emit:
    reads             = remote_reads_ch
    ena_manifest      = ENA_FASTQ_DOWNLOAD.out.manifest
    provider_reports  = RESOLVE_REMOTE_PROVIDER.out.resolution
    versions          = versions_ch
}
