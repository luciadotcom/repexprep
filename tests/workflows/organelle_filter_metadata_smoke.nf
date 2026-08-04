nextflow.enable.dsl = 2

include {
    ORGANELLE_FILTERING
} from '../../subworkflows/local/organelle_filter'

params.r1        = null
params.r2        = null
params.reference = null
params.sample_id = 'toyA'

workflow {

    if (!params.r1) {
        error "Missing --r1"
    }

    if (!params.r2) {
        error "Missing --r2"
    }

    if (!params.reference) {
        error "Missing --reference"
    }

    def meta = [
        id: params.sample_id,
        organelle_fasta: file(params.reference).toAbsolutePath().toString()
    ]

    def reads = [
        file(params.r1),
        file(params.r2)
    ]

    ch_samples = channel.of(
        tuple(meta, reads)
    )

    ORGANELLE_FILTERING(ch_samples)

    ORGANELLE_FILTERING.out.filtered_samples.view { sample_meta, filtered_reads ->
        "FILTERED: ${sample_meta.id} | R1=${filtered_reads[0]} | R2=${filtered_reads[1]}"
    }

    ORGANELLE_FILTERING.out.reports.view { sample_meta, report ->
        "REPORT: ${sample_meta.id} | ${report}"
    }

    ORGANELLE_FILTERING.out.method_metadata.view { metadata ->
        "METHOD METADATA: ${metadata}"
    }

    ORGANELLE_FILTERING.out.reference_registry.view { registry ->
        "REFERENCE REGISTRY: ${registry}"
    }
}
