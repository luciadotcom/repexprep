nextflow.enable.dsl = 2

params.input = null

include {
    INPUT_CHECK
} from '../../../subworkflows/local/input_check'

include {
    MATERIALIZE_READS
} from '../../../subworkflows/local/materialize_reads'

include {
    READ_QC
} from '../../../subworkflows/local/read_qc'


workflow {

    if (!params.input) {
        error "Provide --input <samplesheet.csv>"
    }

    INPUT_CHECK(
        Channel.value(
            file(
                params.input,
                checkIfExists: true
            )
        )
    )

    certificate_ch = Channel.value([])

    MATERIALIZE_READS(
        INPUT_CHECK.out.validated_samplesheet,
        certificate_ch
    )

    READ_QC(
        MATERIALIZE_READS.out.reads
    )

    READ_QC.out.reads.view {
        meta,
        reads ->

        "QC_PASS: ${meta.id} | " +
        "source=${meta.source} | " +
        "provider=${meta.resolved_provider ?: meta.provider} | " +
        "reads=${reads}"
    }
}
